"""MobileI2V open-source reference-guided img2img backend.

Start: pip install -r backend/requirements.txt
       uvicorn backend.image_server:app --host 127.0.0.1 --port 7860
GPU recommended. Expose HTTPS only through a trusted authenticated proxy.
"""
import base64
import io
import hmac
import os
import re
import threading
from functools import lru_cache

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, Field
from PIL import Image
import torch
from diffusers import AutoPipelineForImage2Image

app = FastAPI(title="MobileI2V Image Generator", version="0.1.0")
_lock = threading.Lock()
MAX_BYTES = 12 * 1024 * 1024
MAX_PIXELS = 1024 * 1024


class GenerateRequest(BaseModel):
    image_base64: str
    previous_image_base64: str | None = None
    prompt: str = Field(min_length=1, max_length=2000)
    frame_index: int = Field(ge=0, le=119)
    total_frames: int = Field(ge=2, le=120)
    loop: bool = False
    reference_strength: float = Field(default=0.85, ge=0.0, le=1.0)
    temporal_position: float = Field(default=0.0, ge=0.0, le=1.0)


def action_stage(prompt: str, progress: float) -> str:
    """Split a sequential description into phases for per-frame conditioning."""
    parts = [
        part.strip() for part in re.split(
            r"(?i)\b(?:et puis|puis|ensuite|then|afterwards|suddenly)\b|[.;\n]",
            prompt,
        ) if part.strip()
    ]
    if not parts:
        return prompt
    index = min(len(parts) - 1, int(max(0.0, min(progress, 0.999999)) * len(parts)))
    return parts[index]


def decode_image(encoded: str) -> Image.Image:
    if len(encoded) > MAX_BYTES * 2:
        raise HTTPException(413, "Image too large")
    try:
        raw = base64.b64decode(encoded, validate=True)
        if len(raw) > MAX_BYTES:
            raise ValueError("Image exceeds byte limit")
        img = Image.open(io.BytesIO(raw))
        img.load()
        if img.width * img.height > MAX_PIXELS:
            raise ValueError("Image exceeds pixel limit")
        return img.convert("RGB")
    except (ValueError, OSError, base64.binascii.Error) as exc:
        raise HTTPException(400, str(exc)) from exc


@lru_cache(maxsize=1)
def pipeline():
    model = os.getenv("MOBILEI2V_MODEL", "stabilityai/sd-turbo")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    pipe = AutoPipelineForImage2Image.from_pretrained(
        model, torch_dtype=dtype
    )
    pipe.to(device)
    pipe.set_progress_bar_config(disable=True)
    return pipe


def fit(image: Image.Image) -> Image.Image:
    # Preserve the original aspect ratio, within SD-Turbo-friendly bounds.
    scale = min(512 / image.width, 512 / image.height)
    width = max(64, round(image.width * scale / 8) * 8)
    height = max(64, round(image.height * scale / 8) * 8)
    return image.resize((width, height), Image.Resampling.LANCZOS)


@app.get("/health")
def health():
    return {
        "ready": torch.cuda.is_available(),
        "model_loaded": pipeline.cache_info().currsize > 0,
        "gpu": torch.cuda.is_available(),
        "model": os.getenv("MOBILEI2V_MODEL", "stabilityai/sd-turbo"),
    }


@app.post("/generate")
def generate(req: GenerateRequest, authorization: str | None = Header(default=None)):
    expected_token = os.getenv("MOBILEI2V_API_TOKEN", "")
    if expected_token and not hmac.compare_digest(authorization or "", f"Bearer {expected_token}"):
        raise HTTPException(401, "Unauthorized")
    if req.frame_index >= req.total_frames:
        raise HTTPException(400, "frame_index exceeds total_frames")
    if abs(req.temporal_position - req.frame_index / max(1, req.total_frames - 1)) > 0.02:
        raise HTTPException(400, "temporal_position inconsistent with frame_index")
    if not torch.cuda.is_available():
        raise HTTPException(503, "GPU unavailable: image generation requires CUDA")
    reference = fit(decode_image(req.image_base64))
    previous = fit(decode_image(req.previous_image_base64)) if req.previous_image_base64 else reference
    if previous.size != reference.size:
        previous = previous.resize(reference.size, Image.Resampling.LANCZOS)
    # Reference anchoring limits drift, but does not guarantee identity preservation.
    reference_weight = min(0.4, max(0.1, req.reference_strength * 0.35))
    conditioning = Image.blend(previous, reference, reference_weight)
    # Derive progress from the actual frame number; do not trust an inconsistent client value.
    phase = req.frame_index / max(1, req.total_frames - 1)
    stage = action_stage(req.prompt, phase)
    action = (
        f"Full story: {req.prompt}. Current action: {stage}. Animation keyframe {req.frame_index + 1} of "
        f"{req.total_frames}, temporal progress {phase:.3f}. "
        "Same subject identity, same outfit, consistent anatomy, coherent action, "
        "new pose appropriate to the described movement."
    )
    try:
        with _lock, torch.inference_mode():
            result = pipeline()(
                prompt=action,
                image=conditioning,
                strength=0.55,
                guidance_scale=0.0,
                num_inference_steps=2,
            ).images[0]
    except Exception as exc:
        raise HTTPException(503, f"Generation unavailable: {type(exc).__name__}: {exc}") from exc
    out = io.BytesIO()
    result.save(out, format="PNG")
    return {
        "image_base64": base64.b64encode(out.getvalue()).decode("ascii"),
        "frame_index": req.frame_index,
        "model": os.getenv("MOBILEI2V_MODEL", "stabilityai/sd-turbo"),
        "note": "Experimental img2img; no temporal pose conditioning or identity guarantee",
    }


class SequenceRequest(BaseModel):
    image_base64: str
    prompt: str = Field(min_length=1, max_length=2000)
    total_frames: int = Field(default=6, ge=2, le=24)
    reference_strength: float = Field(default=0.85, ge=0.0, le=1.0)


@app.post("/generate_sequence")
def generate_sequence(req: SequenceRequest, authorization: str | None = Header(default=None)):
    """One request generates a complete ordered sequence, chaining each prior frame.

    This is keyframe generation, not smooth motion or video synthesis.
    """
    expected_token = os.getenv("MOBILEI2V_API_TOKEN", "")
    if expected_token and not hmac.compare_digest(authorization or "", f"Bearer {expected_token}"):
        raise HTTPException(401, "Unauthorized")
    if not torch.cuda.is_available():
        raise HTTPException(503, "GPU unavailable: image generation requires CUDA")
    # Validate reference once, before loading the diffusion model.
    decode_image(req.image_base64)
    frames = []
    previous = req.image_base64
    for index in range(req.total_frames):
        single = GenerateRequest(
            image_base64=req.image_base64,
            previous_image_base64=previous,
            prompt=req.prompt,
            frame_index=index,
            total_frames=req.total_frames,
            reference_strength=req.reference_strength,
            temporal_position=index / max(1, req.total_frames - 1),
        )
        result = generate(single, authorization)
        previous = result["image_base64"]
        frames.append({"index": index, "image_base64": previous,
                       "action": action_stage(req.prompt, single.temporal_position)})
    return {"frames": frames, "count": len(frames),
            "note": "Experimental sequential keyframes; motion and identity not guaranteed"}
