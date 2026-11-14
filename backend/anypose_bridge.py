"""Optional AnyPose adapter for the existing MobileI2V JSON /generate contract.

Requires: pip install fastapi uvicorn pillow gradio_client
Run: MOBILEI2V_API_TOKEN=... uvicorn backend.anypose_bridge:app --host 127.0.0.1 --port 7861
Use only behind your own HTTPS proxy. Free public Space may queue, rate-limit,
require authentication, change schema, or be unavailable. Never publish photos.
"""
import base64
import logging
import hmac
import io
import os
import tempfile
import threading
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from PIL import Image, UnidentifiedImageError

SPACE = "abidlabs/Qwen-Image-Edit-2511-AnyPose"
MAX_BYTES = 8 * 1024 * 1024
MAX_PIXELS = 1024 * 1024
_lock = threading.Lock()
app = FastAPI(title="MobileI2V AnyPose Bridge")
logger = logging.getLogger("mobilei2v.anypose")


class Request(BaseModel):
    image_base64: str
    pose_image_base64: str
    prompt: str = Field(min_length=1, max_length=2000)
    frame_index: int = Field(ge=0, le=119)
    total_frames: int = Field(ge=2, le=120)
    previous_image_base64: str | None = None
    pose_action: str | None = None
    full_story: str | None = None
    loop: bool = False
    reference_strength: float = Field(default=0.85, ge=0.0, le=1.0)
    temporal_position: float = Field(default=0.0, ge=0.0, le=1.0)


def decode(value: str) -> Image.Image:
    if len(value) > MAX_BYTES * 2:
        raise HTTPException(413, "Encoded image too large")
    try:
        raw = base64.b64decode(value, validate=True)
        if len(raw) > MAX_BYTES:
            raise HTTPException(413, "Image too large")
        image = Image.open(io.BytesIO(raw))
        image.load()
        if image.width * image.height > MAX_PIXELS:
            raise HTTPException(413, "Too many pixels")
        return image.convert("RGB")
    except (ValueError, UnidentifiedImageError, OSError) as exc:
        raise HTTPException(400, "Invalid image") from exc


def first_gallery_path(value):
    """Gradio Gallery can return lists of image paths or image dictionaries."""
    if isinstance(value, (list, tuple)):
        for item in value:
            result = first_gallery_path(item)
            if result:
                return result
    elif isinstance(value, dict):
        if "path" in value and isinstance(value["path"], str):
            return value["path"]
        for key in ("image", "name", "value"):
            if key in value:
                result = first_gallery_path(value[key])
                if result:
                    return result
    elif isinstance(value, str):
        return value
    return None


@app.get("/health")
def health():
    configured = bool(os.environ.get("MOBILEI2V_API_TOKEN"))
    return {"ready": configured, "remote": SPACE, "remote_verified": False,
            "note": "Local configuration only; remote GPU inference not checked"}


@app.post("/generate")
def generate(req: Request, authorization: str | None = Header(default=None)):
    expected = os.environ.get("MOBILEI2V_API_TOKEN", "")
    if not expected:
        raise HTTPException(503, "Configure MOBILEI2V_API_TOKEN before exposing this bridge")
    if not hmac.compare_digest(authorization or "", f"Bearer {expected}"):
        raise HTTPException(401, "Unauthorized")
    if req.frame_index >= req.total_frames:
        raise HTTPException(400, "Frame index out of bounds")
    expected_progress = req.frame_index / max(1, req.total_frames - 1)
    if abs(req.temporal_position - expected_progress) > 0.02:
        raise HTTPException(400, "Temporal position inconsistent with frame index")
    reference = decode(req.image_base64)
    pose = decode(req.pose_image_base64)
    try:
        from gradio_client import Client, handle_file
        with _lock, tempfile.TemporaryDirectory(prefix="mobilei2v_anypose_") as folder:
            ref_path = Path(folder) / "reference.png"
            pose_path = Path(folder) / "pose.png"
            reference.save(ref_path)
            pose.save(pose_path)
            client = Client(SPACE, verbose=False)
            # Actual public /infer input order verified on 2026-11-14:
            # reference, pose, prompt, seed, randomize, guidance, steps,
            # height, width, rewrite_prompt.
            instruction = (
                "Keep the exact identity, clothing, hairstyle, and background "
                "of image 1. Repose the subject to match image 2 exactly. "
                "Do not copy the appearance of the guide figure. "
                + req.prompt
            )
            result = client.predict(
                handle_file(str(ref_path)), handle_file(str(pose_path)),
                instruction, 0, False, 1.0, 4, 512, 384, False,
                api_name="/infer",
            )
            gallery = result[0] if isinstance(result, (list, tuple)) else result
            output_path = first_gallery_path(gallery)
            if not output_path:
                raise ValueError("No image returned by AnyPose")
            # Only read a locally downloaded output, not arbitrary remote paths.
            output = Path(output_path)
            if not output.is_file():
                raise ValueError("No local output file")
            # Gradio may return a downloaded cache file; never open an
            # arbitrary path outside the system temporary directory.
            temp_root = Path(tempfile.gettempdir()).resolve()
            resolved = output.resolve()
            if not resolved.is_relative_to(temp_root):
                raise ValueError("Output file outside temporary directory")
            with Image.open(resolved) as generated:
                data = io.BytesIO()
                generated.convert("RGB").save(data, format="PNG")
    except Exception as exc:
        # Avoid leaking third-party error strings, paths, or request metadata
        # to the mobile client. Keep the exception type in server logs.
        logger.warning("AnyPose request failed: %s", type(exc).__name__)
        raise HTTPException(503, "AnyPose unavailable; try another generation backend",
                            headers={"Retry-After": "30"}) from exc
    return {
        "image_base64": base64.b64encode(data.getvalue()).decode("ascii"),
        "frame_index": req.frame_index,
        "model": SPACE,
        "note": "Remote pose-conditioned keyframe; identity and temporal consistency not guaranteed",
    }
