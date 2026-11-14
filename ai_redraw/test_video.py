import io
import shutil
import subprocess
import zipfile
from PIL import Image
import pytest
from fastapi.testclient import TestClient
from ai_redraw.server import app
from ai_redraw.video import encode_zip_frames

client = TestClient(app)

def frames_zip(count=3):
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as archive:
        for i in range(count):
            frame = Image.new("RGB", (64, 64), (30 + 60 * i, 70, 90))
            encoded = io.BytesIO()
            frame.save(encoded, "PNG")
            archive.writestr(f"frame_{i:03d}.png", encoded.getvalue())
    return data.getvalue()

def test_invalid_timing():
    response = client.post("/video/from-frames",
        data={"fps": 0},
        files={"frames": ("frames.zip", frames_zip(), "application/zip")})
    assert response.status_code == 422

def test_invalid_zip():
    response = client.post("/video/from-frames",
        files={"frames": ("frames.zip", b"bad", "application/zip")})
    assert response.status_code == 422

@pytest.mark.skipif(shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None,
                    reason="ffmpeg/ffprobe not installed")
def test_real_mp4_duration_and_frame_count():
    raw = encode_zip_frames(frames_zip(3), fps=3, hold_frames=2)
    assert b"ftyp" in raw[:64]
    import tempfile
    from pathlib import Path
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "video.mp4"
        path.write_bytes(raw)
        result = subprocess.run([
            "ffprobe", "-v", "error", "-count_frames",
            "-select_streams", "v:0",
            "-show_entries", "stream=nb_read_frames,duration,codec_name",
            "-of", "json", str(path),
        ], capture_output=True, text=True, check=True)
        import json
        stream = json.loads(result.stdout)["streams"][0]
        assert stream["codec_name"] == "h264"
        assert int(stream["nb_read_frames"]) == 6
        assert abs(float(stream["duration"]) - 2.0) < 0.1
        decode = subprocess.run([
            "ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"
        ], capture_output=True)
        assert decode.returncode == 0
