"""Optional REAL pose + reference-conditioned redraw HTTP backend for MobileI2V.

Run on a machine with Python, model weights, and sufficient RAM/VRAM:
  pip install flask pillow mediapipe diffusers transformers accelerate torch
  MOBILEI2V_IMAGE_MODEL=<compatible image-to-image diffusion model id> python tools/visual_backend.py

Endpoints:
 POST /pose {"image_base64": "..."} -> {"landmarks": 33 normalized points}
 POST /generate/storyboard {"image_base64": "...", "prompt": "...", "num_images": 1}
     -> {"images_base64": ["..."]} (actual newly synthesized PNG images)

Neither model is bundled in the APK. This is a local/external backend, not on-device inference.
Do not expose publicly without authentication and HTTPS.
"""
import base64
import io
import os
import numpy as np

from flask import Flask, jsonify, request
from PIL import Image

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024
_pose_model = None
_draw_model = None


def decode_image(data):
    raw = base64.b64decode(data, validate=True)
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    image.load()
    if image.width * image.height > 16_000_000:
        raise ValueError("Image too large")
    return image


@app.post("/pose")
def pose():
    global _pose_model
    try:
        import mediapipe as mp
        image = decode_image(request.get_json(force=True)["image_base64"])
        task_path = os.environ.get("MOBILEI2V_POSE_TASK", "").strip()
        if task_path:
            if not os.path.isfile(task_path):
                return jsonify({"error": "MOBILEI2V_POSE_TASK file not found"}), 503
            if _pose_model is None:
                options = mp.tasks.vision.PoseLandmarkerOptions(
                    base_options=mp.tasks.BaseOptions(model_asset_path=task_path),
                    running_mode=mp.tasks.vision.RunningMode.IMAGE,
                    num_poses=1)
                _pose_model = mp.tasks.vision.PoseLandmarker.create_from_options(options)
            result = _pose_model.detect(mp.Image(image_format=mp.ImageFormat.SRGB,
                                                 data=np.asarray(image)))
            landmarks = result.pose_landmarks[0] if result.pose_landmarks else None
            model_name = "mediapipe_tasks_pose_landmarker"
        elif hasattr(mp, "solutions") and hasattr(mp.solutions, "pose"):
            if _pose_model is None:
                _pose_model = mp.solutions.pose.Pose(static_image_mode=True, model_complexity=2,
                                                     enable_segmentation=False, min_detection_confidence=0.5)
            result = _pose_model.process(np.asarray(image))
            landmarks = result.pose_landmarks.landmark if result.pose_landmarks else None
            model_name = "mediapipe_legacy_pose"
        else:
            return jsonify({"error": "Set MOBILEI2V_POSE_TASK to a downloaded pose_landmarker.task model; legacy MediaPipe solutions unavailable"}), 503
        if not landmarks or len(landmarks) != 33:
            return jsonify({"error": "No reliable human pose detected"}), 422
        points = [{"x": float(p.x), "y": float(p.y), "z": float(p.z),
                   "visibility": float(p.visibility)} for p in landmarks]
        return jsonify({"detected": True, "landmarks": points, "model": model_name})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 503


@app.post("/generate/storyboard")
def redraw():
    global _draw_model
    try:
        data = request.get_json(force=True)
        model_id = os.environ.get("MOBILEI2V_IMAGE_MODEL", "").strip()
        if not model_id:
            return jsonify({"error": "Set MOBILEI2V_IMAGE_MODEL to a compatible diffusion image-to-image model"}), 503
        from diffusers import AutoPipelineForImage2Image
        import torch
        if _draw_model is None:
            device = "cuda" if torch.cuda.is_available() else "cpu"
            _draw_model = AutoPipelineForImage2Image.from_pretrained(
                model_id, torch_dtype=torch.float16 if device == "cuda" else torch.float32)
            _draw_model = _draw_model.to(device)
        source = decode_image(data["image_base64"])
        source.thumbnail((512, 512))
        width = max(64, (source.width // 8) * 8)
        height = max(64, (source.height // 8) * 8)
        source = source.resize((width, height))
        prompt = str(data.get("prompt", "")).strip()
        if not prompt:
            return jsonify({"error": "Missing prompt"}), 400
        count = min(4, max(1, int(data.get("num_images", data.get("frames", 1)))))
        outputs = []
        for _ in range(count):
            generated = _draw_model(prompt=prompt, image=source, strength=0.65,
                                    guidance_scale=7.0, num_inference_steps=25).images[0]
            buffer = io.BytesIO()
            generated.save(buffer, format="PNG")
            outputs.append(base64.b64encode(buffer.getvalue()).decode("ascii"))
        return jsonify({"images": outputs, "model": model_id,
                        "warning": "Image-to-image generation does not guarantee character identity or continuity"})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 503


@app.get("/health")
def health():
    return jsonify({"pose": "mediapipe optional", "redraw_model": os.environ.get("MOBILEI2V_IMAGE_MODEL", ""),
                    "on_device": False})


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8765")))
