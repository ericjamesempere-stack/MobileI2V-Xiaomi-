import io
import shutil
from PIL import Image
from fastapi.testclient import TestClient
from ai_redraw.server import app

client = TestClient(app)

def image_bytes():
    buffer = io.BytesIO()
    Image.new("RGB", (96, 96), "navy").save(buffer, "PNG")
    return buffer.getvalue()

def test_universal_api_accepts_arbitrary_subject_and_prompt(monkeypatch):
    import ai_redraw.animate_anything as module
    seen = {}
    def fake_frames(reference, instruction, style, seed):
        seen.update({"instruction": instruction, "style": style, "size": reference.size})
        return [Image.new("RGB", (64, 64), (i * 60, 30, 50)) for i in range(4)]
    monkeypatch.setattr(module, "generate_video_frames", fake_frames)
    response = client.post("/animate-anything",
        data={"instruction": "A red bicycle rolls across a moonlit forest", "style": "manga", "fps": 4},
        files={"reference": ("scene.png", image_bytes(), "image/png")})
    if shutil.which("ffmpeg") is None:
        assert response.status_code == 503
    else:
        assert response.status_code == 200, response.text
        assert response.headers["content-type"] == "video/mp4"
        assert response.headers["x-frames"] == "4"
        assert b"ftyp" in response.content[:64]
    assert seen["style"] == "manga"
    assert "bicycle" in seen["instruction"]

def test_reject_empty_instruction():
    response = client.post("/animate-anything",
        data={"instruction": "", "style": "cartoon"},
        files={"reference": ("scene.png", image_bytes(), "image/png")})
    assert response.status_code == 422

def test_reject_unknown_style():
    response = client.post("/animate-anything",
        data={"instruction": "Make the clouds move", "style": "unsupported"},
        files={"reference": ("scene.png", image_bytes(), "image/png")})
    assert response.status_code == 422
