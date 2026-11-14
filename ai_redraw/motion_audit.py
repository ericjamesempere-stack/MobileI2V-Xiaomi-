"""Fail-closed motion audit for MP4 output.

This detects near-static video, not anatomical correctness or identity.
Requires opencv-python-headless only for this optional verification.
"""
from pathlib import Path

def audit_motion(video_path: str, min_mean_difference: float = 1.0) -> dict:
    import cv2
    import numpy as np
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise ValueError("Video cannot be opened")
    frame_count = 0
    differences = []
    previous = None
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        frame_count += 1
        small = cv2.resize(frame, (128, 128), interpolation=cv2.INTER_AREA)
        if previous is not None:
            differences.append(float(np.abs(small.astype(np.float32) - previous.astype(np.float32)).mean()))
        previous = small
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.release()
    mean_difference = sum(differences) / len(differences) if differences else 0.0
    return {
        "frames_decoded": frame_count,
        "fps": fps,
        "duration_seconds": frame_count / fps if fps > 0 else None,
        "mean_adjacent_frame_difference": round(mean_difference, 4),
        "near_static_frame_ratio": round(sum(d < 1.0 for d in differences) / len(differences), 4) if differences else 1.0,
        "motion_gate_passed": frame_count > 1 and mean_difference >= min_mean_difference,
        "identity_verified": False,
        "generative_redraw_verified": False,
    }
