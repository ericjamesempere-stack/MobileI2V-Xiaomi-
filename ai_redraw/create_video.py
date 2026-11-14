"""End-to-end reference image + scripted actions -> generated frames -> real MP4.
Bounded synchronous prototype. Actual inference requires installed SD1.5
ControlNet weights and adequate GPU; no fake successful output is returned.
"""
import io
import json
import zipfile
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from .server import validate_image
from .pose_guides import render_pose
from .pose import pose_redraw
from .video import encode_zip_frames

router = APIRouter()

@router.post("/create-video")
async def create_video(
    reference: UploadFile = File(...),
    actions: str = Form("standing,running,falling"),
    prompt: str = Form("consistent manga character"),
    fps: int = Form(6),
    frames_per_action: int = Form(3),
    strength: float = Form(0.65),
    seed: int = Form(1234),
):
    steps = [s.strip() for s in actions.split(",") if s.strip()]
    if not 1 <= len(steps) <= 8 or not 1 <= frames_per_action <= 6:
        raise HTTPException(422, "Use 1-8 actions and 1-6 frames per action")
    if not 1 <= fps <= 30 or not 0.1 <= strength <= 0.95:
        raise HTTPException(422, "Invalid video settings")
    if len(prompt) > 2000 or any(len(s) > 200 for s in steps):
        raise HTTPException(422, "Prompt too long")
    original = validate_image(await reference.read())
    frames_zip = io.BytesIO()
    try:
        with zipfile.ZipFile(frames_zip, "w", zipfile.ZIP_DEFLATED) as archive:
            index = 0
            for action in steps:
                for i in range(frames_per_action):
                    phase = float(i) / float(max(1, frames_per_action - 1))
                    guide = render_pose(action, phase)
                    image = pose_redraw(original, guide, prompt + ", " + action, strength, seed)
                    if image is None or image.width < 32 or image.height < 32:
                        raise ValueError("Invalid diffusion output")
                    buffer = io.BytesIO()
                    image.save(buffer, "PNG")
                    archive.writestr(f"frame_{index:03d}.png", buffer.getvalue())
                    index += 1
            archive.writestr("manifest.json", json.dumps({
                "actions": steps, "frames": index, "fps": fps,
                "duration_seconds": index / fps, "identity_verified": False,
                "redraw_engine": "controlnet_openpose_img2img",
            }))
        video = encode_zip_frames(frames_zip.getvalue(), fps=fps)
    except Exception as exc:
        raise HTTPException(503, f"Video generation failed: {type(exc).__name__}") from exc
    return Response(video, media_type="video/mp4", headers={
        "Content-Disposition": 'attachment; filename="mobilei2v_generated.mp4"',
        "X-Video-Frames": str(index),
        "X-Video-Duration-Seconds": str(index / fps),
        "X-Identity-Verified": "false",
    })
