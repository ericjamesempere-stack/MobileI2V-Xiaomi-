"""JSON adapter for Godot image_sequence_generator.gd.
Uses real ControlNet pose inference when model weights/GPU are installed.
No synthetic fallback: returns HTTP 503 when inference is unavailable.
"""
import base64
import binascii
import io
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from PIL import Image
from .server import validate_image
from .pose import pose_redraw

router = APIRouter()

class FrameInput(BaseModel):
    image_base64: str = Field(max_length=17_000_000)
    pose_image_base64: str = Field(max_length=17_000_000)
    previous_image_base64: str = Field(default="", max_length=17_000_000)
    prompt: str = Field(min_length=1, max_length=2000)
    pose_action: str = Field(default="repos", max_length=100)
    frame_index: int = Field(ge=0, le=239)
    total_frames: int = Field(ge=2, le=240)
    reference_strength: float = Field(default=0.85, ge=0, le=1)
    loop: bool = False

def decode_png(value: str) -> Image.Image:
    try:
        raw = base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise HTTPException(422, "Invalid base64 image") from exc
    return validate_image(raw)

@router.post("/generate")
def generate_frame(request: FrameInput):
    if request.frame_index >= request.total_frames:
        raise HTTPException(422, "Frame index outside sequence")
    reference = decode_png(request.image_base64)
    pose = decode_png(request.pose_image_base64)
    # Keep the same noise seed for every pose: per-frame random seeds cause
    # unrelated textures, faces and clothing to flicker between drawings.
    # reference_strength controls img2img denoising inversely: higher identity
    # preference means less departure from the original. Pose compliance and
    # identity are not guaranteed and must still be evaluated visually.
    denoise = max(0.35, min(0.75, 0.85 - 0.45 * request.reference_strength))
    try:
        image = pose_redraw(reference, pose, request.prompt, denoise, 1234)
    except Exception as exc:
        raise HTTPException(503, "Pose-conditioned model unavailable: " + type(exc).__name__) from exc
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return {
        "image_base64": base64.b64encode(buffer.getvalue()).decode("ascii"),
        "engine": "controlnet-openpose-img2img",
        "identity_verified": False,
        "temporal_continuity_verified": False,
        "seed": 1234,
        "denoising_strength": denoise,
    }
