import base64
import io
from PIL import Image
from fastapi.testclient import TestClient
from ai_redraw.server import app

client = TestClient(app)

def png_b64():
    buf = io.BytesIO()
    Image.new("RGB", (64, 64), (100, 50, 50)).save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")

def payload():
    return {"image_base64": png_b64(), "pose_image_base64": png_b64(),
            "prompt": "character running", "frame_index": 0, "total_frames": 12}

def test_godot_adapter_mock_inference(monkeypatch):
    import ai_redraw.godot_adapter as adapter
    monkeypatch.setattr(adapter, "pose_redraw", lambda reference, pose, prompt, strength, seed: reference.copy())
    response = client.post("/generate", json=payload())
    assert response.status_code == 200
    body = response.json()
    assert body["identity_verified"] is False
    assert body["temporal_continuity_verified"] is False
    image = Image.open(io.BytesIO(base64.b64decode(body["image_base64"])))
    assert image.size == (64, 64)

def test_godot_adapter_rejects_bad_base64():
    body = payload()
    body["pose_image_base64"] = "bad"
    assert client.post("/generate", json=body).status_code == 422

def test_godot_adapter_reports_unavailable_inference(monkeypatch):
    import ai_redraw.godot_adapter as adapter
    def unavailable(*args):
        raise RuntimeError("no model")
    monkeypatch.setattr(adapter, "pose_redraw", unavailable)
    assert client.post("/generate", json=payload()).status_code == 503
