#!/usr/bin/env python3
"""Checks the App Store text in store/metadata-ja.md against Apple's limits.

Limits (App Store Connect Help, app-information and platform-version-information):
name 2-30 characters, subtitle 30, promotional text 170, description 4000, keywords 100 bytes.
"""
import re
import sys
from pathlib import Path

LIMITS = {"name": 30, "subtitle": 30, "promotionalText": 170, "description": 4000}


def fields(text):
    return {m[1]: m[2].strip() for m in re.finditer(r"<!-- field:(\w+) -->\n(.*?)\n<!-- /field -->", text, re.S)}


def main(path="store/metadata-ja.md"):
    f = fields(Path(path).read_text(encoding="utf-8"))
    errors = 0
    for key, limit in LIMITS.items():
        n = len(f.get(key, ""))
        ok = 0 < n <= limit and (key != "name" or n >= 2)
        errors += not ok
        print(f"{'OK ' if ok else 'NG '} {key}: {n} / {limit} 文字")
    kw = f.get("keywords", "")
    b = len(kw.encode("utf-8"))
    words = [w for w in kw.split(",") if w]
    dup = [w for w in words if w in f.get("name", "") or w in f.get("subtitle", "")]
    ok = 0 < b <= 100 and not dup and all(w == w.strip() for w in words)
    errors += not ok
    print(f"{'OK ' if ok else 'NG '} keywords: {b} / 100 バイト（{len(words)} 語）" + (f" 名前・サブタイトルと重複: {dup}" if dup else ""))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
