#!/usr/bin/env python3
"""Create ペタカレ Pro's products in App Store Connect (safe to run again: anything that exists is kept).

  - Subscription group "Pro": yearly ¥4,800 and monthly ¥500, each with a 1-week free trial
  - Non-consumable: lifetime ¥9,800
  - Japanese name and description, price and availability in Japan, a review screenshot

Prints ids, states and HTTP errors only: never the key, the token or any email address.
Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64, BUNDLE_ID, SCREENSHOT (path to a PNG).
"""
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"
TERRITORY = "JPN"
PREFIX = "com.seventhwell.petacal.pro."

SUBSCRIPTIONS = [
    {"productId": PREFIX + "yearly", "name": "Pro 年額", "period": "ONE_YEAR", "level": 1, "price": "4800",
     "title": "ペタカレ Pro（年額）", "description": "AI取り込み無制限・集計と予算・写真10枚・候補日"},
    {"productId": PREFIX + "monthly", "name": "Pro 月額", "period": "ONE_MONTH", "level": 2, "price": "500",
     "title": "ペタカレ Pro（月額）", "description": "AI取り込み無制限・集計と予算・写真10枚・候補日"},
]
LIFETIME = {"productId": PREFIX + "lifetime", "name": "Pro 買い切り", "price": "9800",
            "title": "ペタカレ Pro（買い切り）", "description": "1回の支払いで Pro の機能をずっと使えます"}
REVIEW_NOTE = "設定 → ペタカレ Pro → 「Pro の内容を見る」で購入画面が開きます。"

problems = []


def pem():
    raw = os.environ["ASC_KEY_P8_BASE64"]
    if "BEGIN PRIVATE KEY" not in raw:
        raw = base64.b64decode("".join(raw.split())).decode()
    return raw.replace("\r\n", "\n").strip() + "\n"


def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"].strip(), "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
                      pem(), algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"].strip(), "typ": "JWT"})


def call(method, path, body=None, query=None, quiet=False):
    url = (path if path.startswith("http") else API + path) + ("?" + urllib.parse.urlencode(query) if query else "")
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            raw = res.read()
            return res.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        text = e.read().decode(errors="replace")
        if not quiet:
            print(f"  {method} {path.split('?')[0]} -> HTTP {e.code}: {text[:1200]}")
            problems.append(f"{method} {path.split('?')[0]} HTTP {e.code}")
        return e.code, {}


def has(path, query=None):
    """True when the link points at something (App Store Connect answers 200 with data null when it does not)."""
    status, body = call("GET", path, query=query, quiet=True)
    return status == 200 and bool(body.get("data"))


def get_all(path, query=None):
    items, url, q = [], path, dict(query or {}, limit=200)
    while url:
        status, page = call("GET", url, query=q)
        if status != 200:
            break
        items += page.get("data", [])
        url, q = page.get("links", {}).get("next"), None
    return items


def rel(kind, id_):
    return {"data": {"type": kind, "id": id_}}


def find_price_point(path, price):
    for point in get_all(path, {"filter[territory]": TERRITORY}):
        if point["attributes"].get("customerPrice") in (price, price + ".0", price + ".00"):
            return point["id"]
    problems.append(f"price point {price} JPY not found at {path}")
    print(f"  ::warning::{price} 円の価格が見つからない（{path}）")
    return None


def upload_screenshot(create_path, kind, rel_name, owner_kind, owner_id):
    """Reserve, upload and commit a review screenshot (App Store Connect upload operations)."""
    shot = os.environ.get("SCREENSHOT", "")
    if not shot or not os.path.exists(shot):
        print("  審査用の画像なし（SCREENSHOT が無い）")
        return
    data = open(shot, "rb").read()
    status, made = call("POST", create_path, {"data": {
        "type": kind, "attributes": {"fileName": os.path.basename(shot), "fileSize": len(data)},
        "relationships": {rel_name: rel(owner_kind, owner_id)}}})
    if status not in (200, 201):
        return
    attrs = made["data"]["attributes"]
    for op in attrs.get("uploadOperations") or []:
        part = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        req = urllib.request.Request(op["url"], data=part, method=op["method"], headers=headers)
        with urllib.request.urlopen(req, timeout=120):
            pass
    call("PATCH", f"{create_path}/{made['data']['id']}", {"data": {
        "type": kind, "id": made["data"]["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("  審査用の画像を登録した")


def ensure_subscriptions(app_id):
    groups = get_all(f"/v1/apps/{app_id}/subscriptionGroups")
    group = next((g for g in groups if g["attributes"].get("referenceName") == "Pro"), None)
    if group:
        print(f"サブスクリプションのグループ Pro はある（{group['id']}）")
    else:
        status, made = call("POST", "/v1/subscriptionGroups", {"data": {
            "type": "subscriptionGroups", "attributes": {"referenceName": "Pro"},
            "relationships": {"app": rel("apps", app_id)}}})
        if status not in (200, 201):
            return
        group = made["data"]
        print(f"サブスクリプションのグループ Pro を作った（{group['id']}）")
    if not get_all(f"/v1/subscriptionGroups/{group['id']}/subscriptionGroupLocalizations"):
        call("POST", "/v1/subscriptionGroupLocalizations", {"data": {
            "type": "subscriptionGroupLocalizations", "attributes": {"name": "ペタカレ Pro", "locale": "ja"},
            "relationships": {"subscriptionGroup": rel("subscriptionGroups", group["id"])}}})
        print("  グループの日本語名を付けた")

    existing = {s["attributes"]["productId"]: s for s in get_all(f"/v1/subscriptionGroups/{group['id']}/subscriptions")}
    for spec in SUBSCRIPTIONS:
        sub = existing.get(spec["productId"])
        if sub:
            print(f"{spec['productId']} はある（状態 {sub['attributes'].get('state')}）")
        else:
            status, made = call("POST", "/v1/subscriptions", {"data": {
                "type": "subscriptions",
                "attributes": {"name": spec["name"], "productId": spec["productId"], "subscriptionPeriod": spec["period"],
                               "familySharable": False, "groupLevel": spec["level"], "reviewNote": REVIEW_NOTE},
                "relationships": {"group": rel("subscriptionGroups", group["id"])}}})
            if status not in (200, 201):
                continue
            sub = made["data"]
            print(f"{spec['productId']} を作った")
        sid = sub["id"]
        if not get_all(f"/v1/subscriptions/{sid}/subscriptionLocalizations"):
            call("POST", "/v1/subscriptionLocalizations", {"data": {
                "type": "subscriptionLocalizations",
                "attributes": {"name": spec["title"], "locale": "ja", "description": spec["description"]},
                "relationships": {"subscription": rel("subscriptions", sid)}}})
            print("  日本語の名前と説明を付けた")
        if not has(f"/v1/subscriptions/{sid}/subscriptionAvailability"):
            call("POST", "/v1/subscriptionAvailabilities", {"data": {
                "type": "subscriptionAvailabilities", "attributes": {"availableInNewTerritories": False},
                "relationships": {"subscription": rel("subscriptions", sid),
                                  "availableTerritories": {"data": [{"type": "territories", "id": TERRITORY}]}}}})
            print("  販売する国：日本")
        if not get_all(f"/v1/subscriptions/{sid}/prices"):
            point = find_price_point(f"/v1/subscriptions/{sid}/pricePoints", spec["price"])
            if point:
                call("POST", "/v1/subscriptionPrices", {"data": {
                    "type": "subscriptionPrices", "attributes": {"startDate": None, "preserveCurrentPrice": False},
                    "relationships": {"subscription": rel("subscriptions", sid),
                                      "subscriptionPricePoint": rel("subscriptionPricePoints", point),
                                      "territory": rel("territories", TERRITORY)}}})
                print(f"  価格 {spec['price']} 円")
        if not get_all(f"/v1/subscriptions/{sid}/introductoryOffers"):
            call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {
                "type": "subscriptionIntroductoryOffers",
                "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                "relationships": {"subscription": rel("subscriptions", sid),
                                  "territory": rel("territories", TERRITORY)}}})
            print("  最初の1週間無料")
        if not has(f"/v1/subscriptions/{sid}/appStoreReviewScreenshot"):
            upload_screenshot("/v1/subscriptionAppStoreReviewScreenshots", "subscriptionAppStoreReviewScreenshots",
                              "subscription", "subscriptions", sid)


def ensure_lifetime(app_id):
    found = get_all(f"/v1/apps/{app_id}/inAppPurchasesV2", {"filter[productId]": LIFETIME["productId"]})
    if found:
        iap = found[0]
        print(f"{LIFETIME['productId']} はある（状態 {iap['attributes'].get('state')}）")
    else:
        status, made = call("POST", "/v2/inAppPurchases", {"data": {
            "type": "inAppPurchases",
            "attributes": {"name": LIFETIME["name"], "productId": LIFETIME["productId"],
                           "inAppPurchaseType": "NON_CONSUMABLE", "familySharable": False, "reviewNote": REVIEW_NOTE},
            "relationships": {"app": rel("apps", app_id)}}})
        if status not in (200, 201):
            return
        iap = made["data"]
        print(f"{LIFETIME['productId']} を作った")
    iid = iap["id"]
    if not get_all(f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations"):
        call("POST", "/v1/inAppPurchaseLocalizations", {"data": {
            "type": "inAppPurchaseLocalizations",
            "attributes": {"name": LIFETIME["title"], "locale": "ja", "description": LIFETIME["description"]},
            "relationships": {"inAppPurchaseV2": rel("inAppPurchases", iid)}}})
        print("  日本語の名前と説明を付けた")
    if not has(f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability"):
        call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
            "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": False},
            "relationships": {"inAppPurchase": rel("inAppPurchases", iid),
                              "availableTerritories": {"data": [{"type": "territories", "id": TERRITORY}]}}}})
        print("  販売する国：日本")
    status, schedule = call("GET", f"/v2/inAppPurchases/{iid}/iapPriceSchedule", query={"include": "manualPrices"}, quiet=True)
    if not (status == 200 and schedule.get("included")):
        point = find_price_point(f"/v2/inAppPurchases/{iid}/pricePoints", LIFETIME["price"])
        if point:
            call("POST", "/v1/inAppPurchasePriceSchedules", {
                "data": {"type": "inAppPurchasePriceSchedules",
                         "relationships": {"inAppPurchase": rel("inAppPurchases", iid),
                                           "baseTerritory": rel("territories", TERRITORY),
                                           "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]}}},
                "included": [{"type": "inAppPurchasePrices", "id": "${price}", "attributes": {"startDate": None},
                              "relationships": {"inAppPurchaseV2": rel("inAppPurchases", iid),
                                                "inAppPurchasePricePoint": rel("inAppPurchasePricePoints", point)}}]})
            print(f"  価格 {LIFETIME['price']} 円")
    if not has(f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot"):
        upload_screenshot("/v1/inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseAppStoreReviewScreenshots",
                          "inAppPurchaseV2", "inAppPurchases", iid)


def main():
    apps = get_all("/v1/apps", {"filter[bundleId]": os.environ["BUNDLE_ID"]})
    if not apps:
        sys.exit("::error::App Store Connect にこのアプリが見つからない")
    app_id = apps[0]["id"]
    print(f"アプリ {app_id}")
    ensure_subscriptions(app_id)
    ensure_lifetime(app_id)
    if problems:
        print("\nうまくいかなかったもの:")
        for p in problems:
            print(f"  - {p}")
        sys.exit(1)
    print("\nすべてそろった")


if __name__ == "__main__":
    main()
