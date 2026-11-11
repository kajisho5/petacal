#!/usr/bin/env python3
"""Register the app's Bundle ID with Apple if it is missing, then say whether the app record exists.

Creating the app record itself is not possible through the App Store Connect API, so that step
stays manual. No secrets are printed.

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64 (PEM or base64), BUNDLE_ID, BUNDLE_NAME.
"""
import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"


def pem():
    raw = os.environ["ASC_KEY_P8_BASE64"]
    if "BEGIN PRIVATE KEY" not in raw:
        raw = base64.b64decode("".join(raw.split())).decode()
    return raw.replace("\r\n", "\n").strip() + "\n"


def call(method, path, body=None, **query):
    now = int(time.time())
    token = jwt.encode({"iss": os.environ["ASC_ISSUER_ID"].strip(), "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
                       pem(), algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"].strip(), "typ": "JWT"})
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            return res.status, json.loads(res.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode(errors="replace")[:1500]}


def main():
    bundle_id = os.environ["BUNDLE_ID"]
    name = os.environ.get("BUNDLE_NAME", bundle_id.rsplit(".", 1)[-1])

    status, res = call("GET", "/v1/bundleIds", **{"filter[identifier]": bundle_id, "limit": "200"})
    if status != 200:
        raise SystemExit(f"GET /v1/bundleIds -> HTTP {status}: {res.get('error')}")
    # The filter matches prefixes too, so compare the identifier exactly.
    found = [b for b in res.get("data", []) if b["attributes"].get("identifier") == bundle_id]
    if found:
        print(f"Bundle ID already registered: {bundle_id} (platform {found[0]['attributes'].get('platform')})")
    else:
        status, res = call("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": bundle_id, "name": name, "platform": "UNIVERSAL"}}})
        if status not in (200, 201):
            raise SystemExit(f"POST /v1/bundleIds -> HTTP {status}: {res.get('error')}")
        print(f"Bundle ID registered: {bundle_id}")

    status, res = call("GET", "/v1/apps", **{"filter[bundleId]": bundle_id})
    if status != 200:
        raise SystemExit(f"GET /v1/apps -> HTTP {status}: {res.get('error')}")
    apps = [a for a in res.get("data", []) if a["attributes"].get("bundleId") == bundle_id]
    if apps:
        print(f"App record exists: {apps[0]['attributes'].get('name')}")
    else:
        print("App record: NOT FOUND. Create it at https://appstoreconnect.apple.com/apps (+ > New App).")


if __name__ == "__main__":
    main()
