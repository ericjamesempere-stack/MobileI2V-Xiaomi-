#!/usr/bin/env python3
"""Offline reference preprocessor for difficult illustration backgrounds.

Requires opencv-python and numpy on a desktop/CI runner; NOT an Android
on-device segmentation implementation. Outputs a transparent PNG and a mask.
Use only on artwork supplied with permission.
"""
import argparse
from pathlib import Path

import cv2
import numpy as np


def isolate(input_path: Path, output_path: Path, mask_path: Path, iterations: int = 7) -> dict:
    original = cv2.imread(str(input_path), cv2.IMREAD_UNCHANGED)
    if original is None:
        raise ValueError(f"Cannot read image: {input_path}")
    if original.ndim != 3 or original.shape[2] not in (3, 4):
        raise ValueError("Expected RGB or RGBA artwork")
    # Do not destroy an already isolated character: retain its alpha.
    if original.shape[2] == 4 and np.any(original[:, :, 3] < 250):
        alpha = original[:, :, 3]
        if not cv2.imwrite(str(output_path), original) or not cv2.imwrite(str(mask_path), alpha):
            raise IOError("Unable to write output images")
        return {"width": original.shape[1], "height": original.shape[0],
                "foreground_fraction": float(np.count_nonzero(alpha) / alpha.size),
                "method": "existing_alpha"}
    image = original[:, :, :3]
    height, width = image.shape[:2]
    if width < 50 or height < 50:
        raise ValueError("Image too small for background separation")
    scale = min(1.0, 640.0 / max(height, width))
    sw, sh = max(2, round(width * scale)), max(2, round(height * scale))
    working = cv2.resize(image, (sw, sh), interpolation=cv2.INTER_AREA)
    inset_x, inset_y = max(2, round(sw * 0.016)), max(2, round(sh * 0.05))
    rectangle = (inset_x, inset_y, sw - 2 * inset_x, sh - 2 * inset_y)
    labels = np.zeros((sh, sw), dtype=np.uint8)
    background = np.zeros((1, 65), np.float64)
    foreground = np.zeros((1, 65), np.float64)
    cv2.grabCut(working, labels, rectangle, background, foreground, iterations, cv2.GC_INIT_WITH_RECT)
    binary = np.where((labels == cv2.GC_FGD) | (labels == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    binary = cv2.resize(binary, (width, height), interpolation=cv2.INTER_NEAREST)
    rgba = cv2.cvtColor(image, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = binary
    if not cv2.imwrite(str(output_path), rgba) or not cv2.imwrite(str(mask_path), binary):
        raise IOError("Unable to write output images")
    return {"width": width, "height": height, "foreground_fraction": float(np.count_nonzero(binary) / binary.size)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path, default=Path("character_cutout.png"))
    parser.add_argument("--mask", type=Path, default=Path("character_mask.png"))
    args = parser.parse_args()
    print(isolate(args.image, args.output, args.mask))
