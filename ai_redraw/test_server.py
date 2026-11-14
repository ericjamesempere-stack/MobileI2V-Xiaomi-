import io
from PIL import Image
from fastapi.testclient import TestClient
from ai_redraw.server import app

client = TestClient(app)

def png(size=(64, 64)):
    image = Image.new("RGB", size, (100, 50, 50))
    output = io.BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()

def test_health_without_loading_model():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["engine"] == "diffusers_img2img"

def test_reject_invalid_image():
    response = client.post("/redraw", files={"reference": ("a.png", b"invalid", "image/png")})
    assert response.status_code == 422

def test_reject_strength():
    response = client.post("/redraw", data={"strength": "2.0"}, files={"reference": ("a.png", png(), "image/png")})
    assert response.status_code == 422

def test_inference_mock(monkeypatch):
    import ai_redraw.server as server
    monkeypatch.setattr(server, "redraw", lambda image, prompt, action, strength, seed: image)
    response = client.post("/redraw", data={"action": "running"}, files={"reference": ("a.png", png(), "image/png")})
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert Image.open(io.BytesIO(response.content)).size == (64, 64)

def test_sequence_zip(monkeypatch):
    import zipfile
    import ai_redraw.sequence as sequence
    monkeypatch.setattr(sequence, "redraw", lambda image, prompt, action, strength, seed: image.copy())
    response = client.post("/redraw/sequence",
        data={"actions": "standing,running,falling"},
        files={"reference": ("a.png", png(), "image/png")})
    assert response.status_code == 200
    with zipfile.ZipFile(io.BytesIO(response.content)) as archive:
        assert archive.namelist() == ["frame_000.png", "frame_001.png", "frame_002.png"]

def test_sequence_rejects_unbounded_request():
    response = client.post("/redraw/sequence",
        data={"actions": ",".join(["running"] * 9)},
        files={"reference": ("a.png", png(), "image/png")})
    assert response.status_code == 422
