"""Run actual MediaPipe Tasks inference against a PRIVATE image on a test computer.

Usage:
  MOBILEI2V_POSE_TASK=/path/to/pose_landmarker.task \
    python tools/test_real_pose.py /path/to/private_character.jpg --out /tmp/pose_validation.png

The script never uploads the image or writes to GitHub.
"""
import argparse
import json
import os
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw


POSE_EDGES = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16),
              (11, 23), (12, 24), (23, 24), (23, 25), (25, 27),
              (24, 26), (26, 28), (27, 29), (28, 30)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--out", default="pose_validation.png")
    args = parser.parse_args()
    model_path = os.environ.get("MOBILEI2V_POSE_TASK", "")
    if not model_path or not Path(model_path).is_file():
        sys.exit("BLOCKED: provide an existing .task file through MOBILEI2V_POSE_TASK")
    import mediapipe as mp
    options = mp.tasks.vision.PoseLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=model_path),
        running_mode=mp.tasks.vision.RunningMode.IMAGE,
        num_poses=1)
    with Image.open(args.image) as im:
        image = im.convert("RGB")
    with mp.tasks.vision.PoseLandmarker.create_from_options(options) as detector:
        result = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB,
                                          data=np.asarray(image)))
    if not result.pose_landmarks:
        sys.exit("FAILED: no body pose detected in actual reference")
    points = result.pose_landmarks[0]
    if len(points) != 33:
        sys.exit(f"FAILED: expected 33 landmarks, got {len(points)}")
    draw = ImageDraw.Draw(image)
    for connection in POSE_EDGES:
        a, b = tuple(connection)
        draw.line((points[a].x * image.width, points[a].y * image.height,
                   points[b].x * image.width, points[b].y * image.height),
                  fill=(0, 220, 40), width=4)
    for p in points:
        x, y = p.x * image.width, p.y * image.height
        draw.ellipse((x-5, y-5, x+5, y+5), fill=(255, 40, 40))
    image.save(args.out)
    report = {"detected": True, "landmarks": len(points), "overlay": args.out,
              "low_visibility": sum(p.visibility < 0.5 for p in points)}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
