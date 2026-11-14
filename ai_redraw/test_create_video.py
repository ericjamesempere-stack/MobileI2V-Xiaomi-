import io
import shutil
import subprocess
import tempfile
from pathlib import Path
from PIL import Image
from fastapi.testclient import TestClient
from ai_redraw.server import app

client = TestClient(app)

def reference_png():
    buffer = io.BytesIO()
    Image.new("RGB", (64, 64), (60, 90, 120)).save(buffer, "PNG")
    return buffer.getvalue()

def test_end_to_end_mp4_without_gpu(monkeypatch):
    import ai_redraw.create_video as creator
    def fake_pose_redraw(reference, guide, prompt, strength, seed):
        assert guide.size == (512, 512)
        return reference.copy()
    monkeypatch.setattr(creator, "pose_redraw", fake_pose_redraw)
    response = client.post("/create-video",
        data={"actions": "standing,running,falling", "frames_per_action": "2", "fps": "3"},
        files={"reference": ("private.png", reference_png(), "image/png")})
    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        assert response.status_code == 503
        return
    assert response.status_code == 200, response.text
    assert response.headers["content-type"] == "video/mp4"
    assert response.headers["x-video-frames"] == "6"
    assert response.headers["x-video-duration-seconds"] == "2.0"
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "test.mp4"
        path.write_bytes(response.content)
        probe = subprocess.run([
            "ffprobe", "-v", "error", "-count_frames",
            "-select_streams", "v:0",
            "-show_entries", "stream=nb_read_frames,codec_name,duration",
            "-of", "default=noprint_wrappers=1", str(path),
        ], capture_output=True, text=True, check=True)
        assert "codec_name=h264" in probe.stdout
        assert "nb_read_frames=6" in probe.stdout
        decode = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path),
                                 "-f", "null", "-"], capture_output=True)
        assert decode.returncode == 0

def test_reject_excessive_inference():
    response = client.post("/create-video",
        data={"frames_per_action": "99"},
        files={"reference": ("private.png", reference_png(), "image/png")})
    assert response.status_code == 422
