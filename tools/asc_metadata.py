#!/usr/bin/env python3
"""Put the App Store text of store/metadata-ja.md into App Store Connect (safe to run again).

  - App information (Japanese): name, subtitle, privacy policy URL; categories
  - Every version that can still be edited (iPhone/iPad and Mac): description, keywords,
    promotional text, support URL, copyright, notes for App Review

Never submits anything for review. Prints ids, states, what changed and HTTP errors only:
never the key, the token or any email address.
Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64, BUNDLE_ID. Option: --dry-run (reads only).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_products as asc  # noqa: E402  (the same key handling and HTTP helper)

LOCALE = "ja"
PRIVACY_URL = "https://seventh-well.com/petacal/privacy/"
SUPPORT_URL = "https://seventh-well.com/petacal/"
CATEGORIES = {"primaryCategory": "PRODUCTIVITY", "secondaryCategory": "LIFESTYLE"}
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}

DRY = "--dry-run" in sys.argv


def fields():
    text = (Path(__file__).resolve().parent.parent / "store" / "metadata-ja.md").read_text(encoding="utf-8")
    return {m[1]: m[2].strip() for m in re.finditer(r"<!-- field:(\w+) -->\n(.*?)\n<!-- /field -->", text, re.S)}


def patch(kind, id_, attributes, label):
    current = asc.call("GET", f"/v1/{kind}/{id_}")[1].get("data", {}).get("attributes", {})
    changed = {k: v for k, v in attributes.items() if current.get(k) != v}
    if not changed:
        print(f"  {label}: そのまま（同じ内容）")
        return
    print(f"  {label}: 変える項目 {sorted(changed)}")
    if not DRY:
        status, _ = asc.call("PATCH", f"/v1/{kind}/{id_}", {"data": {"type": kind, "id": id_, "attributes": changed}})
        print(f"    -> HTTP {status}")


def localization(list_path, create_kind, parent_rel, parent_kind, parent_id, attributes, label):
    items = asc.get_all(list_path)
    loc = next((x for x in items if x["attributes"].get("locale") == LOCALE), None)
    if loc:
        patch(create_kind, loc["id"], attributes, label)
        return
    print(f"  {label}: {LOCALE} が無いので作る")
    if not DRY:
        status, _ = asc.call("POST", f"/v1/{create_kind}", {"data": {
            "type": create_kind, "attributes": dict(attributes, locale=LOCALE),
            "relationships": {parent_rel: asc.rel(parent_kind, parent_id)}}})
        print(f"    -> HTTP {status}")


def main():
    f = fields()
    status, body = asc.call("GET", "/v1/apps", query={"filter[bundleId]": asc.os.environ["BUNDLE_ID"]})
    apps = body.get("data") or []
    if status != 200 or not apps:
        sys.exit("::error::App Store Connect にこの Bundle ID のアプリが見つからない")
    app = apps[0]
    print(f"アプリ {app['id']}（主な言語 {app['attributes'].get('primaryLocale')}）")

    infos = asc.get_all(f"/v1/apps/{app['id']}/appInfos")
    for info in infos:
        state = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        print(f"App 情報 {info['id']}：{state}")
        if state not in EDITABLE:
            continue
        localization(f"/v1/appInfos/{info['id']}/appInfoLocalizations", "appInfoLocalizations", "appInfo", "appInfos",
                     info["id"], {"name": f["name"], "subtitle": f["subtitle"], "privacyPolicyUrl": PRIVACY_URL},
                     "名前・サブタイトル・プライバシーポリシー")
        print(f"  カテゴリ: {CATEGORIES}")
        if not DRY:
            rels = {k: asc.rel("appCategories", v) for k, v in CATEGORIES.items()}
            status, _ = asc.call("PATCH", f"/v1/appInfos/{info['id']}",
                                 {"data": {"type": "appInfos", "id": info["id"], "relationships": rels}})
            print(f"    -> HTTP {status}")

    versions = asc.get_all(f"/v1/apps/{app['id']}/appStoreVersions")
    if not versions:
        print("編集できるバージョンが無い（App Store Connect にまだバージョンが作られていない）")
    for v in versions:
        a = v["attributes"]
        state = a.get("appStoreState") or a.get("appVersionState")
        print(f"バージョン {a.get('versionString')}（{a.get('platform')}）：{state}")
        if state not in EDITABLE and a.get("appVersionState") not in EDITABLE:
            continue
        patch("appStoreVersions", v["id"], {"copyright": f["copyright"]}, "著作権")
        localization(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations", "appStoreVersionLocalizations",
                     "appStoreVersion", "appStoreVersions", v["id"],
                     {"description": f["description"], "keywords": f["keywords"],
                      "promotionalText": f["promotionalText"], "supportUrl": SUPPORT_URL},
                     "説明・キーワード・プロモーション用テキスト・サポート")
        status, detail = asc.call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail", quiet=True)
        notes = {"notes": f["reviewNotes"], "demoAccountRequired": False}
        if status == 200 and detail.get("data"):
            patch("appStoreReviewDetails", detail["data"]["id"], notes, "審査へのメモ")
        else:
            print("  審査へのメモ: 作る")
            if not DRY:
                status, _ = asc.call("POST", "/v1/appStoreReviewDetails", {"data": {
                    "type": "appStoreReviewDetails", "attributes": notes,
                    "relationships": {"appStoreVersion": asc.rel("appStoreVersions", v["id"])}}})
                print(f"    -> HTTP {status}")

    if asc.problems:
        print("うまくいかなかったもの:")
        for p in asc.problems:
            print("  " + p)
        sys.exit(1)
    print("おわり（審査への提出はしていない）")


if __name__ == "__main__":
    main()
