#!/usr/bin/env python3
"""Gets ペタカレ's iPhone/iPad version ready for App Review, and (mode "submit") submits it.

Modes (first argument):
  check   read only: print what is set and what is missing
  apply   set everything the API can set (safe to run again):
          content rights, age rating (all "none"), price (free) and availability (Japan),
          release type MANUAL (nothing goes on sale until the owner presses the button),
          App Review contact, the 1.0 build, screenshots (store/screenshots/<display type>/),
          a reviewable version for each in-app purchase and subscription
  submit  one review submission: the app version, the subscription group, both subscriptions and
          the lifetime purchase (the first in-app purchases must go with an app version)

The answers to "App Privacy" are not in the App Store Connect API; they are set on the website.
Names and values come from Apple's OpenAPI specification 4.6 (developer.apple.com/sample-code/
app-store-connect/app-store-connect-openapi-specification.zip).

Prints ids, states and HTTP errors only: never the key, the token or the contact details.
Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64, BUNDLE_ID, REVIEW_CONTACT_* (apply).
"""
import hashlib
import os
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_products as asc  # noqa: E402  (the same key handling and HTTP helper)

ROOT = Path(__file__).resolve().parent.parent
VERSION = "1.0"
LOCALE = "ja"
TERRITORY = "JPN"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
REVIEWABLE = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "DEVELOPER_REJECTED", "REJECTED"}
# store/screenshots/<folder> -> ScreenshotDisplayType (accepted sizes: tools/store_screenshots.py)
SCREENSHOT_SETS = {
    "iphone-dynamic-island-large": "APP_IPHONE_67",
    "iphone-dynamic-island-medium": "APP_IPHONE_61",
    "ipad-13": "APP_IPAD_PRO_3GEN_129",
}
# Every content question "none" / "no": a calendar and notebook for the person's own plans and records.
# No web browsing, no messaging, no user-generated content shared with others, no ads, no gambling.
AGE_RATING = {
    "alcoholTobaccoOrDrugUseOrReferences": "NONE", "contests": "NONE", "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE", "medicalOrTreatmentInformation": "NONE", "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE", "sexualContentOrNudity": "NONE", "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE", "violenceCartoonOrFantasy": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE", "violenceRealistic": "NONE",
    "advertising": False, "gambling": False, "healthOrWellnessTopics": False, "lootBox": False,
    "messagingAndChat": False, "parentalControls": False, "ageAssurance": False, "socialMedia": False,
    "socialMediaAgeRestricted": False, "unrestrictedWebAccess": False, "userGeneratedContent": False,
    "ageRatingOverrideV2": "NONE", "koreaAgeRatingOverride": "NONE",
}

MODE = sys.argv[1] if len(sys.argv) > 1 else "check"
WRITE = MODE in ("apply", "submit")


def say(text):
    print(text, flush=True)


def patch(kind, id_, attributes, label, relationships=None, current=None):
    if current is None:
        current = asc.call("GET", f"/v1/{kind}/{id_}")[1].get("data", {}).get("attributes", {})
    changed = {k: v for k, v in attributes.items() if current.get(k) != v}
    if not changed and not relationships:
        say(f"  {label}: そのまま")
        return True
    say(f"  {label}: 変える項目 {sorted(changed) + (sorted(relationships) if relationships else [])}")
    if not WRITE:
        return False
    body = {"data": {"type": kind, "id": id_}}
    if changed:
        body["data"]["attributes"] = changed
    if relationships:
        body["data"]["relationships"] = relationships
    status, _ = asc.call("PATCH", f"/v1/{kind}/{id_}", body)
    say(f"    -> HTTP {status}")
    return status == 200


def app_level(app, info):
    say("■ アプリ全体")
    patch("apps", app["id"], {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}, "第三者の作品の使用（使っていない）")
    status, body = asc.call("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")
    if status == 200 and body.get("data"):
        # This resource has no GET of its own: compare with what the app info returned.
        patch("ageRatingDeclarations", body["data"]["id"], AGE_RATING, "年齢制限の質問（すべて「なし」）",
              current=body["data"].get("attributes") or {})
    # Price: free, Japan as the base.
    status, body = asc.call("GET", f"/v1/apps/{app['id']}/appPriceSchedule", quiet=True)
    manual = asc.get_all(f"/v1/appPriceSchedules/{body['data']['id']}/manualPrices") if status == 200 and body.get("data") else []
    if manual:
        say(f"  価格: 設定済み（{len(manual)} 件）")
    else:
        say("  価格: 無料にする")
        free = next((p["id"] for p in asc.get_all(f"/v1/apps/{app['id']}/appPricePoints", {"filter[territory]": TERRITORY})
                     if float(p["attributes"].get("customerPrice") or 1) == 0), None)
        if free and WRITE:
            status, _ = asc.call("POST", "/v1/appPriceSchedules", {
                "data": {"type": "appPriceSchedules", "relationships": {
                    "app": asc.rel("apps", app["id"]), "baseTerritory": asc.rel("territories", TERRITORY),
                    "manualPrices": {"data": [{"type": "appPrices", "id": "${price}"}]}}},
                "included": [{"type": "appPrices", "id": "${price}",
                              "relationships": {"appPricePoint": asc.rel("appPricePoints", free)}}]})
            say(f"    -> HTTP {status}")
        elif not free:
            say("    ::warning::無料の価格が見つからない")
    # Availability: Japan (the in-app purchases are sold in Japan).
    status, body = asc.call("GET", f"/v1/apps/{app['id']}/appAvailabilityV2", quiet=True)
    if status == 200 and body.get("data"):
        say("  配信する国・地域: 設定済み")
    else:
        say("  配信する国・地域: 日本にする")
        if WRITE:
            # Every territory has to be listed: Japan available, the others not.
            territories = [t["id"] for t in asc.get_all("/v1/territories")]
            refs = [{"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in territories]
            included = [{"type": "territoryAvailabilities", "id": f"${{{t}}}", "attributes": {"available": t == TERRITORY},
                         "relationships": {"territory": asc.rel("territories", t)}} for t in territories]
            status, _ = asc.call("POST", "/v2/appAvailabilities", {
                "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": False},
                         "relationships": {"app": asc.rel("apps", app["id"]), "territoryAvailabilities": {"data": refs}}},
                "included": included})
            say(f"    -> HTTP {status}")


def upload(set_id, path):
    data = path.read_bytes()
    status, made = asc.call("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots", "attributes": {"fileName": path.name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": asc.rel("appScreenshotSets", set_id)}}})
    if status not in (200, 201):
        return None
    shot = made["data"]
    for op in shot["attributes"].get("uploadOperations") or []:
        part = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        with urllib.request.urlopen(urllib.request.Request(op["url"], data=part, method=op["method"], headers=headers), timeout=120):
            pass
    asc.call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {
        "type": "appScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return shot["id"]


def screenshots(localization_id):
    sets = {s["attributes"]["screenshotDisplayType"]: s for s in
            asc.get_all(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")}
    for folder, display in SCREENSHOT_SETS.items():
        files = sorted((ROOT / "store" / "screenshots" / folder).glob("*.png"))
        if not files:
            say(f"  画像 {display}: 手元に無い（store/screenshots/{folder}）")
            continue
        existing = sets.get(display)
        names = []
        if existing:
            shots = asc.get_all(f"/v1/appScreenshotSets/{existing['id']}/appScreenshots")
            names = [s["attributes"].get("fileName") for s in shots]
            states = [(s["attributes"].get("assetDeliveryState") or {}).get("state") for s in shots]
            if names == [f.name for f in files] and all(st == "COMPLETE" for st in states):
                say(f"  画像 {display}: {len(files)} 枚そろっている")
                continue
            say(f"  画像 {display}: 入れ直す（今 {len(names)} 枚 {states}）")
            if WRITE:
                for s in shots:
                    asc.call("DELETE", f"/v1/appScreenshots/{s['id']}")
        else:
            say(f"  画像 {display}: {len(files)} 枚を入れる")
        if not WRITE:
            continue
        if not existing:
            status, made = asc.call("POST", "/v1/appScreenshotSets", {"data": {
                "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
                "relationships": {"appStoreVersionLocalization": asc.rel("appStoreVersionLocalizations", localization_id)}}})
            if status not in (200, 201):
                continue
            existing = made["data"]
        ids = [upload(existing["id"], f) for f in files]
        # Apple checks each picture after the upload (size, format): wait for the answer.
        for _ in range(30):
            time.sleep(5)
            shots = asc.get_all(f"/v1/appScreenshotSets/{existing['id']}/appScreenshots")
            states = [(s["attributes"].get("assetDeliveryState") or {}) for s in shots]
            if all(st.get("state") in ("COMPLETE", "FAILED") for st in states) and len(shots) == len(ids):
                break
        for s, st in zip(shots, states):
            errors = [e.get("description") or e.get("code") for e in st.get("errors") or []]
            say(f"    {s['attributes'].get('fileName')}: {st.get('state')}" + (f" {errors}" if errors else ""))
            if st.get("state") != "COMPLETE":
                asc.problems.append(f"screenshot {display} {s['attributes'].get('fileName')} {st.get('state')}")


def ios_version(app):
    versions = [v for v in asc.get_all(f"/v1/apps/{app['id']}/appStoreVersions", {"filter[platform]": "IOS"})
                if v["attributes"].get("versionString") == VERSION]
    if not versions:
        sys.exit(f"::error::iPhone／iPad のバージョン {VERSION} が App Store Connect に無い")
    v = versions[0]
    state = v["attributes"].get("appStoreState") or v["attributes"].get("appVersionState")
    say(f"■ バージョン {VERSION}（IOS）：{state}")
    return v, state


def prepare_version(app, v):
    patch("appStoreVersions", v["id"], {"releaseType": "MANUAL"}, "公開のしかた（手動：審査に通っても、公開ボタンを押すまで出ない）")
    contact = {k: os.environ.get(f"REVIEW_CONTACT_{e}", "").strip() for k, e in
               (("contactFirstName", "FIRST"), ("contactLastName", "LAST"), ("contactPhone", "PHONE"), ("contactEmail", "EMAIL"))}
    status, detail = asc.call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail", quiet=True)
    if status == 200 and detail.get("data"):
        if all(contact.values()):
            patch("appStoreReviewDetails", detail["data"]["id"], dict(contact, demoAccountRequired=False), "審査の連絡先")
        else:
            missing = [k for k, val in detail["data"]["attributes"].items() if k.startswith("contact") and not val]
            say(f"  審査の連絡先: {'そろっている' if not missing else '足りない ' + str(missing)}")
    # The 1.0 build that finished processing, newest first.
    builds = asc.get_all("/v1/builds", {"filter[app]": app["id"], "filter[preReleaseVersion.version]": VERSION,
                                       "filter[preReleaseVersion.platform]": "IOS", "filter[processingState]": "VALID",
                                       "sort": "-uploadedDate"})
    status, current = asc.call("GET", f"/v1/appStoreVersions/{v['id']}/relationships/build", quiet=True)
    current_id = (current.get("data") or {}).get("id") if status == 200 else None
    if not builds:
        say(f"  ビルド: {VERSION} の処理済みのビルドがまだ無い")
        asc.problems.append("no build")
    else:
        newest = builds[0]
        label = f"ビルド {newest['attributes'].get('version')}（暗号化の申告 {newest['attributes'].get('usesNonExemptEncryption')}）"
        if current_id == newest["id"]:
            say(f"  {label}: 選択済み")
        else:
            say(f"  {label}: 選ぶ")
            if WRITE:
                status, _ = asc.call("PATCH", f"/v1/appStoreVersions/{v['id']}/relationships/build",
                                     {"data": {"type": "builds", "id": newest["id"]}})
                say(f"    -> HTTP {status}")
    locs = asc.get_all(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")
    loc = next((x for x in locs if x["attributes"].get("locale") == LOCALE), None)
    if loc:
        screenshots(loc["id"])


def reviewable_version(list_path, create_kind, rel_name, parent_kind, parent_id, label):
    """The version of an in-app purchase that goes to App Review (made if there is none)."""
    versions = asc.get_all(list_path)
    for x in versions:
        say(f"  {label}: バージョン {x['attributes'].get('version')} {x['attributes'].get('state')}")
    pick = next((x for x in versions if x["attributes"].get("state") in REVIEWABLE), None)
    if pick or any(x["attributes"].get("state") in ("WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED") for x in versions):
        return pick
    say(f"  {label}: 審査に出すバージョンが無いので作る")
    if not WRITE:
        return None
    status, made = asc.call("POST", f"/v1/{create_kind}", {"data": {
        "type": create_kind, "relationships": {rel_name: asc.rel(parent_kind, parent_id)}}})
    say(f"    -> HTTP {status}")
    return made.get("data") if status in (200, 201) else None


def price_everywhere(s):
    """Apple wants an UPFRONT price in every territory: the Japanese price equalized by Apple's own table."""
    sid, name = s["id"], s["attributes"].get("productId")
    prices = asc.get_all(f"/v1/subscriptions/{sid}/prices", {"include": "territory,subscriptionPricePoint"})
    priced = {(p.get("relationships", {}).get("territory", {}).get("data") or {}).get("id"): p for p in prices}
    base = priced.get(TERRITORY)
    point = ((base or {}).get("relationships", {}).get("subscriptionPricePoint", {}).get("data") or {}).get("id")
    if not point:
        say(f"    {name}: 日本の価格が無いので、ほかの国の価格を決められない")
        asc.problems.append(f"{name} no JPN price")
        return
    others = asc.get_all(f"/v1/subscriptionPricePoints/{point}/equalizations", {"include": "territory"})
    missing = [(o["relationships"]["territory"]["data"]["id"], o["id"]) for o in others
               if (o.get("relationships", {}).get("territory", {}).get("data") or {}).get("id") not in priced]
    say(f"    {name}: 価格のある国 {len(priced)}、日本と同じ水準で足す国 {len(missing)}")
    if not WRITE or not missing:
        return
    failed = 0
    for terr, pp in missing:
        status, _ = asc.call("POST", "/v1/subscriptionPrices", {"data": {
            "type": "subscriptionPrices", "attributes": {"startDate": None, "preserveCurrentPrice": False, "planType": "UPFRONT"},
            "relationships": {"subscription": asc.rel("subscriptions", sid), "territory": asc.rel("territories", terr),
                              "subscriptionPricePoint": asc.rel("subscriptionPricePoints", pp)}}}, quiet=True)
        failed += status not in (200, 201)
    say(f"      -> 足した {len(missing) - failed}、失敗 {failed}")
    if failed:
        asc.problems.append(f"{name} prices failed {failed}")


def diagnose(s):
    """What a subscription has, to see why App Store Connect says metadata is missing."""
    a, sid = s["attributes"], s["id"]
    say(f"    期間 {a.get('subscriptionPeriod')} 段階 {a.get('groupLevel')} 家族共有 {a.get('familySharable')} "
        f"組織向け {a.get('multiSeatStatus')} 市場の設定 {len(a.get('marketSettings') or [])} 件 審査メモ {'あり' if a.get('reviewNote') else 'なし'}")
    say(f"    価格 {len(asc.get_all(f'/v1/subscriptions/{sid}/prices'))} 件")
    status, av = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", quiet=True)
    if status == 200 and av.get("data"):
        terr = [t["id"] for t in asc.get_all(f"/v1/subscriptionAvailabilities/{av['data']['id']}/availableTerritories")]
        say(f"    販売する国 {terr[:5]}（全 {len(terr)}）")
    else:
        say(f"    販売する国: 未設定（HTTP {status}）")
    for plan in asc.get_all(f"/v1/subscriptions/{sid}/planAvailabilities"):
        terr = [t["id"] for t in asc.get_all(f"/v1/subscriptionPlanAvailabilities/{plan['id']}/availableTerritories")]
        say(f"    プラン {plan['attributes'].get('planType')}: 国 {terr[:5]}（全 {len(terr)}）")
    status, shot = asc.call("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot", quiet=True)
    st = ((shot.get("data") or {}).get("attributes") or {}).get("assetDeliveryState") if status == 200 else None
    say(f"    審査用の画像 HTTP {status} {st}")
    locs = [(x["attributes"].get("locale"), x["attributes"].get("state")) for x in asc.get_all(f"/v1/subscriptions/{sid}/subscriptionLocalizations")]
    say(f"    説明（以前の形） {locs}")
    say(f"    お試し {len(asc.get_all(f'/v1/subscriptions/{sid}/introductoryOffers'))} 件")
    # Selling to organizations (Apple Business / Apple School) is on by default for new subscriptions;
    # this app is for one person's own calendar, so it is sold on the App Store only.
    if a.get("multiSeatStatus") != "DISABLED" or (a.get("marketSettings") or []) != ["APP_STORE"]:
        patch("subscriptions", sid, {"multiSeatStatus": "DISABLED", "marketSettings": ["APP_STORE"]},
              "組織向けの販売を止め、App Store だけで売る", current=a)


def purchases(app):
    say("■ App 内課金（最初の商品は、アプリのバージョンと一緒に審査に出す）")
    items = []
    for g in asc.get_all(f"/v1/apps/{app['id']}/subscriptionGroups"):
        gv = reviewable_version(f"/v1/subscriptionGroups/{g['id']}/versions", "subscriptionGroupVersions",
                                "subscriptionGroup", "subscriptionGroups", g["id"], f"グループ {g['attributes'].get('referenceName')}")
        if gv:
            items.append(("subscriptionGroupVersion", "subscriptionGroupVersions", gv["id"]))
        for loc in asc.get_all(f"/v1/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations"):
            say(f"    グループの表示名 {loc['attributes'].get('locale')}: {loc['attributes'].get('state')}")
        if gv:
            for loc in asc.get_all(f"/v1/subscriptionGroupVersions/{gv['id']}/localizations"):
                la = loc["attributes"]
                say(f"    グループ（審査用のバージョン）の表示名 {la.get('locale')}: 名前 {la.get('name')!r} アプリ名 {la.get('customAppName')!r}")
                want = {"name": "ペタカレ Pro", "customAppName": "ペタカレ"}
                if any(la.get(k) != v for k, v in want.items()):
                    say("      表示名とアプリ名を入れる")
                    if WRITE:
                        status, _ = asc.call("PATCH", f"/v2/subscriptionGroupLocalizations/{loc['id']}", {"data": {
                            "type": "subscriptionGroupLocalizations", "id": loc["id"], "attributes": want}})
                        say(f"      -> HTTP {status}")
        for s in asc.get_all(f"/v1/subscriptionGroups/{g['id']}/subscriptions"):
            say(f"  {s['attributes'].get('productId')}: {s['attributes'].get('state')}")
            if s["attributes"].get("state") == "MISSING_METADATA":
                diagnose(s)
                price_everywhere(s)
            sv = reviewable_version(f"/v1/subscriptions/{s['id']}/versions", "subscriptionVersions", "subscription",
                                    "subscriptions", s["id"], s["attributes"].get("name") or s["id"])
            if sv:
                locs = asc.get_all(f"/v1/subscriptionVersions/{sv['id']}/localizations")
                say(f"    説明の言語: {[x['attributes'].get('locale') for x in locs]}")
                items.append(("subscriptionVersion", "subscriptionVersions", sv["id"]))
    for i in asc.get_all(f"/v1/apps/{app['id']}/inAppPurchasesV2"):
        say(f"  {i['attributes'].get('productId')}: {i['attributes'].get('state')}")
        iv = reviewable_version(f"/v2/inAppPurchases/{i['id']}/versions", "inAppPurchaseVersions", "inAppPurchase",
                                "inAppPurchases", i["id"], i["attributes"].get("name") or i["id"])
        if iv:
            locs = asc.get_all(f"/v1/inAppPurchaseVersions/{iv['id']}/localizations")
            say(f"    説明の言語: {[x['attributes'].get('locale') for x in locs]}")
            items.append(("inAppPurchaseVersion", "inAppPurchaseVersions", iv["id"]))
    return items


ITEM_KINDS = "appStoreVersion,subscriptionVersion,subscriptionGroupVersion,inAppPurchaseVersion"


def contents(sub_id):
    """[(item id, what it holds)] of a review submission."""
    out = []
    for it in asc.get_all(f"/v1/reviewSubmissions/{sub_id}/items", {"include": ITEM_KINDS}):
        held = [k for k, val in (it.get("relationships") or {}).items() if isinstance(val, dict) and val.get("data")]
        out.append((it["id"], held))
    return out


def submit(app, v, items):
    say("■ 審査への提出")
    subs = asc.get_all(f"/v1/apps/{app['id']}/reviewSubmissions")
    for s in subs:
        say(f"  これまでの提出 {s['id']}: {s['attributes'].get('state')} {s['attributes'].get('platform')}"
            f" {[h for _, h in contents(s['id'])] if s['attributes'].get('state') in ('READY_FOR_REVIEW', 'UNRESOLVED_ISSUES') else ''}")
    if any(s["attributes"].get("state") in ("WAITING_FOR_REVIEW", "IN_REVIEW") for s in subs):
        say("  すでに審査待ち・審査中なので、何もしない")
        return
    drafts = [s for s in subs if s["attributes"].get("state") in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES")]
    # Keep the draft that already holds the app version; empty the others so nothing is held twice.
    main = next((d for d in drafts if any("appStoreVersion" in h for _, h in contents(d["id"]))), drafts[0] if drafts else None)
    for d in drafts:
        if main and d["id"] == main["id"]:
            continue
        for item_id, held in contents(d["id"]):
            status, _ = asc.call("DELETE", f"/v1/reviewSubmissionItems/{item_id}")
            say(f"  別の下書き {d['id']} から {held} を外す: HTTP {status}")
    if not main:
        status, made = asc.call("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": asc.rel("apps", app["id"])}}})
        if status not in (200, 201):
            return
        main = made["data"]
    say(f"  まとめる下書き {main['id']}")
    for rel_name, kind, id_ in [("appStoreVersion", "appStoreVersions", v["id"])] + items:
        status, _ = asc.call("POST", "/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": asc.rel("reviewSubmissions", main["id"]), rel_name: asc.rel(kind, id_)}}})
        say(f"  項目 {rel_name}: HTTP {status}")
    # A refused item (already in this submission, or not ready) is shown above; it does not stop the submission.
    asc.problems[:] = [p for p in asc.problems if "reviewSubmissionItems" not in p]
    say(f"  中身 {[h for _, h in contents(main['id'])]}")
    if asc.problems:
        say("  問題があるので提出しない")
        return
    status, done = asc.call("PATCH", f"/v1/reviewSubmissions/{main['id']}", {"data": {
        "type": "reviewSubmissions", "id": main["id"], "attributes": {"submitted": True}}})
    say(f"  提出: HTTP {status} 状態 {(done.get('data') or {}).get('attributes', {}).get('state')}")


def main():
    status, body = asc.call("GET", "/v1/apps", query={"filter[bundleId]": os.environ["BUNDLE_ID"]})
    apps = body.get("data") or []
    if status != 200 or not apps:
        sys.exit("::error::App Store Connect にこの Bundle ID のアプリが見つからない")
    app = apps[0]
    say(f"アプリ {app['id']}（モード {MODE}）")
    infos = [i for i in asc.get_all(f"/v1/apps/{app['id']}/appInfos")
             if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) in EDITABLE | {"PREPARE_FOR_SUBMISSION"}]
    if infos:
        app_level(app, infos[0])
    v, state = ios_version(app)
    if state in EDITABLE:
        prepare_version(app, v)
    items = purchases(app)
    if MODE == "submit":
        submit(app, v, items)
    if asc.problems:
        say("うまくいかなかったもの:")
        for p in asc.problems:
            say("  " + p)
        sys.exit(1)
    say("おわり" + ("" if MODE == "submit" else "（審査への提出はしていない）"))


if __name__ == "__main__":
    main()
