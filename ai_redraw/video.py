"""MP4 assembly for generated image sequences, with ffmpeg.
Uses true distinct PNG frames, not fake MP4 files or image warping.
"""
import io
import json
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

from PIL import Image
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

router = APIRouter()

def encode_zip_frames(raw: bytes, fps: int = 12, hold_frames: int = 1) -> bytes:
    if not 1 <= fps <= 30 or not 1 <= hold_frames <= 30:
        raise ValueError("Invalid timing")
    if len(raw) > 80 * 1024 * 1024:
        raise ValueError("Archive exceeds 80MB")
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("ffmpeg executable not installed")
    with tempfile.TemporaryDirectory(prefix="mobilei2v_") as tmp:
        folder = Path(tmp)
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            names = sorted(name for name in archive.namelist()
                           if name.startswith("frame_") and name.endswith(".png")
                           and "/" not in name)
            if not 1 <= len(names) <= 240:
                raise ValueError("Expected 1-240 PNG frames")
            for i, name in enumerate(names):
                info = archive.getinfo(name)
                if info.file_size > 12 * 1024 * 1024:
                    raise ValueError("Oversized frame")
                with archive.open(name) as src:
                    img = Image.open(src)
                    img.load()
                if img.width < 32 or img.height < 32 or img.width > 2048 or img.height > 2048:
                    raise ValueError("Invalid frame size")
                img = img.convert("RGB")
                if img.width % 2 or img.height % 2:
                    img = img.resize((img.width - img.width % 2, img.height - img.height % 2))
                for duplicate in range(hold_frames):
                    img.save(folder / f"render_{i * hold_frames + duplicate:06d}.png")
        target = folder / "animation.mp4"
        command = [
            ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
            "-framerate", str(fps), "-i", str(folder / "render_%06d.png"),
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
            "-frames:v", str(len(names) * hold_frames), str(target),
        ]
        subprocess.run(command, check=True, timeout=180, capture_output=True)
        data = target.read_bytes()
        if len(data) < 128 or b"ftyp" not in data[:64]:
            raise RuntimeError("Invalid MP4 output")
        return data

@router.post("/video/from-frames")
async def video_from_frames(
    frames: UploadFile = File(...),
    fps: int = Form(12),
    hold_frames: int = Form(1),
):
    if not 1 <= fps <= 30 or not 1 <= hold_frames <= 30:
        raise HTTPException(422, "Invalid timing")
    raw = await frames.read(80 * 1024 * 1024 + 1)
    try:
        video = encode_zip_frames(raw, fps, hold_frames)
    except (ValueError, zipfile.BadZipFile, OSError) as exc:
        raise HTTPException(422, str(exc)) from exc
    except (RuntimeError, subprocess.SubprocessError) as exc:
        raise HTTPException(503, f"Encoder unavailable: {type(exc).__name__}") from exc
    return Response(video, media_type="video/mp4", headers={
        "Content-Disposition": 'attachment; filename="animation.mp4"',
        "X-Video-Encoder": "ffmpeg-h264",
    })
