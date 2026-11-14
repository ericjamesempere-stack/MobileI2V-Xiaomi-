"""Universal image-to-video pipeline: arbitrary image, subject and motion text.

No humanoid rig or closed list of actions. Backend uses image-to-video diffusion
when available. Requires an independently provisioned model and compute.
"""
import io
import os
import subprocess
import tempfile
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image

from .server import validate_image

router = APIRouter()

STYLES = {
    "manga": "Japanese manga illustration, clean inked outlines",
    "bd": "European bande dessinée comic art",
    "cartoon": "hand-drawn 2D cartoon animation",
    "anime": "Japanese anime animation",
    "natural": "naturalistic cinematic video",
    "cinema": "cinematic film photography",
}

@lru_cache(maxsize=1)
def get_video_pipeline():
    import torch
    from diffusers import I2VGenXLPipeline
    model = os.environ.get("I2V_MODEL_ID", "ali-vilab/i2vgen-xl")
    dtype = torch.float16 if torch.cuda.is_available() else torch.float32
    pipe = I2VGenXLPipeline.from_pretrained(model, torch_dtype=dtype)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    return pipe.to(device)

def generate_video_frames(reference: Image.Image, instruction: str,
                          style: str, seed: int) -> list[Image.Image]:
    import torch
    pipe = get_video_pipeline()
    image = reference.convert("RGB").resize((704, 448), Image.Resampling.LANCZOS)
    prompt = instruction.strip() + ". " + STYLES[style] + (
        ". Keep the original subjects, objects and environment recognizable."
        " Physically coherent continuous movement, consistent scene."
    )
    generator = torch.Generator(device=pipe.device).manual_seed(seed)
    result = pipe(prompt=prompt, image=image, generator=generator,
                  num_inference_steps=25, guidance_scale=9.0)
    frames = result.frames[0]
    if not frames or len(frames) < 2:
        raise RuntimeError("Video model returned insufficient frames")
    return [frame.convert("RGB") for frame in frames]

def encode_frames(frames: list[Image.Image], fps: int) -> bytes:
    if not 2 <= len(frames) <= 240 or not 1 <= fps <= 30:
        raise ValueError("Invalid video frames or FPS")
    with tempfile.TemporaryDirectory(prefix="i2v_universal_") as directory:
        root = Path(directory)
        for index, frame in enumerate(frames):
            frame.convert("RGB").save(root / f"frame_{index:06d}.png")
        output = root / "animation.mp4"
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
            "-framerate", str(fps), "-i", str(root / "frame_%06d.png"),
            "-c:v", "libx264", "-pix_fmt", "yuv420p",
            "-movflags", "+faststart", str(output),
        ], check=True, capture_output=True, timeout=180)
        data = output.read_bytes()
        if b"ftyp" not in data[:64]:
            raise RuntimeError("Invalid MP4")
        return data

@router.post("/animate-anything")
async def animate_anything(
    reference: UploadFile = File(...),
    instruction: str = Form(...),
    style: str = Form("cartoon"),
    fps: int = Form(8),
    seed: int = Form(1234),
):
    if style not in STYLES or not 1 <= fps <= 30:
        raise HTTPException(422, "Invalid style or FPS")
    if not 1 <= len(instruction.strip()) <= 2000:
        raise HTTPException(422, "Describe the intended animation")
    image = validate_image(await reference.read())
    try:
        frames = generate_video_frames(image, instruction, style, seed)
        mp4 = encode_frames(frames, fps)
    except Exception as exc:
        raise HTTPException(503, f"Video generation unavailable: {type(exc).__name__}") from exc
    return Response(mp4, media_type="video/mp4", headers={
        "Content-Disposition": 'attachment; filename="animated_scene.mp4"',
        "X-Generator": "image-to-video-diffusion",
        "X-Frames": str(len(frames)),
        "X-Identity-Verified": "false",
    })
