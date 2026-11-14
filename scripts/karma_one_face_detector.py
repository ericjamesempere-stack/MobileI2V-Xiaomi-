#!/usr/bin/env python3
"""Optional OpenCV frontal-face detection; fails explicitly if unavailable or uncertain."""
from pathlib import Path

def detect_face_box(photo: Path):
    try:
        import cv2
    except ImportError as exc:
        raise RuntimeError("Automatic face detection requires opencv-python; provide --face-box instead") from exc
    image = cv2.imread(str(photo))
    if image is None:
        raise ValueError(f"Cannot read reference photo: {photo}")
    height, width = image.shape[:2]
    classifier_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    cascade = cv2.CascadeClassifier(classifier_path)
    if cascade.empty():
        raise RuntimeError("OpenCV frontal face detector is unavailable")
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(24,24))
    if len(faces) != 1:
        raise ValueError(f"Expected exactly one detectable frontal face, found {len(faces)}; use --face-box")
    x,y,w,h = [int(v) for v in faces[0]]
    margin_x, margin_y = int(w*0.12), int(h*0.12)
    return [max(0,x-margin_x)/width, max(0,y-margin_y)/height,
            min(width,x+w+margin_x)/width, min(height,y+h+margin_y)/height]
