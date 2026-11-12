#!/usr/bin/env python3
"""Picks the App Store screenshots out of the CI pictures and makes them ready to upload.

Usage: python3 tools/store_screenshots.py <folder with screenshots / screenshots-mac> <out folder>

Keeps only the files named store-*.png whose pixel size App Store Connect accepts, removes the
alpha channel (App Store Connect wants opaque images) and sorts them by display type.

Accepted sizes: App Store Connect Help, "Screenshot specifications"
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
(checked 2026-11-12). Needs Pillow.
"""
import sys
from pathlib import Path

from PIL import Image

# display type (the names on the App Store Connect page) -> accepted portrait sizes (landscape is the same swapped)
ACCEPTED = {
    "iphone-dynamic-island-large": [(1260, 2736), (1290, 2796), (1320, 2868)],   # iPhone with Dynamic Island, large (optional)
    "iphone-face-id-large": [(1284, 2778), (1242, 2688)],                 # iPhone with Face ID, large
    "iphone-dynamic-island-medium": [(1179, 2556), (1206, 2622)],                 # iPhone with Dynamic Island, medium (required)
    "ipad-13": [(2064, 2752), (2048, 2732)],          # iPad 13-inch (required for iPad apps)
    "iphone-duo-outer": [(1398, 2034)],                            # iPhone Duo outer display (optional)
    "iphone-duo-inner": [(2007, 2853)],                            # iPhone Duo inner display (optional)
    "mac": [(1280, 800), (1440, 900), (2560, 1600), (2880, 1800)],  # Mac, 16:10
}


def kind(size):
    for name, sizes in ACCEPTED.items():
        if size in sizes or (size[1], size[0]) in sizes:
            return name
    return None


def main(src, out):
    out = Path(out)
    kept, skipped = 0, []
    for path in sorted(Path(src).rglob("store-*.png")):
        image = Image.open(path)
        k = kind(image.size)
        if k is None:
            skipped.append(f"{path.name} {image.size[0]}x{image.size[1]}")
            continue
        folder = out / k
        folder.mkdir(parents=True, exist_ok=True)
        flat = Image.new("RGB", image.size, (255, 255, 255))
        rgba = image.convert("RGBA")
        flat.paste(rgba, mask=rgba.split()[3])
        flat.save(folder / path.name, optimize=True)
        kept += 1
        print(f"OK  {k:30} {image.size[0]}x{image.size[1]}  {path.name}")
    for s in skipped:
        print(f"--  寸法が App Store の一覧に無いので使わない: {s}")
    print(f"{kept} 枚を {out} に書き出した")
    return 0 if kept else 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
