#!/usr/bin/env python3
"""Optional MediaPipe Pose landmark extraction from a single photo.

Requires mediapipe and a compatible Python runtime. No silent fallback to
invented landmarks. Only supports one visible person and a frontal/side pose
with all required joints sufficiently visible.
"""
import argparse
import json
from pathlib import Path

INDEX = {
    "left_shoulder": 11, "right_shoulder": 12,
    "left_elbow": 13, "right_elbow": 14,
    "left_wrist": 15, "right_wrist": 16,
    "left_hip": 23, "right_hip": 24,
    "left_knee": 25, "right_knee": 26,
    "left_ankle": 27, "right_ankle": 28,
}

def from_pose_landmarks(points, visibility_threshold=0.5):
    """Pure adapter, independently testable without MediaPipe installed."""
    if len(points) < 29:
        raise ValueError("Pose detector returned fewer than 29 landmarks")
    result = {}
    for name, index in INDEX.items():
        point = points[index]
        x, y = float(point.x), float(point.y)
        visibility = float(getattr(point, "visibility", 1.0))
        if not (0 <= x <= 1 and 0 <= y <= 1 and visibility >= visibility_threshold):
            raise ValueError(f"Joint {name} is outside the photo or insufficiently visible")
        result[name] = [round(x, 6), round(y, 6)]
    return result

def detect(photo: Path):
    try:
        import cv2
        import mediapipe as mp
    except ImportError as exc:
        raise RuntimeError("Automatic pose detection requires compatible mediapipe and opencv-python packages") from exc
    if not hasattr(mp, "solutions") or not hasattr(mp.solutions, "pose"):
        raise RuntimeError("Installed MediaPipe has no solutions.pose API; use compatible version or manual landmarks")
    image = cv2.imread(str(photo))
    if image is None:
        raise ValueError(f"Cannot read photo: {photo}")
    with mp.solutions.pose.Pose(static_image_mode=True, model_complexity=1,
                                min_detection_confidence=0.6) as pose:
        result = pose.process(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    if result.pose_landmarks is None:
        raise ValueError("No reliable human pose detected; supply manual body landmarks")
    return from_pose_landmarks(result.pose_landmarks.landmark)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("photo", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    landmarks = detect(args.photo)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(landmarks, indent=2), encoding="utf-8")
    print(f"Saved {len(landmarks)} joints to {args.output}")
