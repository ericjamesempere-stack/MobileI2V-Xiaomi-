#!/usr/bin/env python3
"""Extract a *color-only* character profile from manually marked photo regions.
No automatic pose, segmentation, face recognition, or photorealistic reconstruction.
Regions are normalized rectangles [left,top,right,bottom] in 0..1.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageStat

ALLOWED = ("skin", "shirt", "pants", "hair")

def extract(photo: Path, regions: dict) -> dict:
    with Image.open(photo) as source:
        image = source.convert("RGB")
    width, height = image.size
    colors = {}
    for name, box in regions.items():
        if name not in ALLOWED:
            raise ValueError(f"Unsupported region: {name}")
        if len(box) != 4 or not all(isinstance(x, (int, float)) for x in box):
            raise ValueError(f"Invalid region: {name}")
        l, t, r, b = box
        if not (0 <= l < r <= 1 and 0 <= t < b <= 1):
            raise ValueError(f"Out of bounds region: {name}")
        crop = image.crop((int(l*width), int(t*height),
                           max(int(l*width)+1,int(r*width)),
                           max(int(t*height)+1,int(b*height))))
        med = [round(v) for v in ImageStat.Stat(crop).median]
        colors[name] = "#" + "".join(f"{v:02x}" for v in med)
    return colors

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("photo", type=Path)
    parser.add_argument("regions", type=Path, help="JSON of manually defined normalized regions")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = json.loads(args.regions.read_text(encoding="utf-8"))
    colors = extract(args.photo, data)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(colors, indent=2), encoding="utf-8")
    print(f"Color profile saved: {args.output}")

if __name__ == "__main__":
    main()
