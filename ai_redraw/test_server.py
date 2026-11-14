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
        assert archive.namelist() == ["frame_000.png", "frame_001.png", "frame_002.png", "manifest.json"]

def test_sequence_rejects_unbounded_request():
    response = client.post("/redraw/sequence",
        data={"actions": ",".join(["running"] * 9)},
        files={"reference": ("a.png", png(), "image/png")})
    assert response.status_code == 422

def test_sequence_anchors_each_pose_to_original(monkeypatch):
    import json
    import zipfile
    import ai_redraw.sequence as sequence
    observed = []
    def fake_redraw(image, prompt, action, strength, seed):
        observed.append(image.getpixel((0, 0)))
        image = image.copy()
        image.putpixel((0, 0), (len(observed), 0, 0))
        return image
    monkeypatch.setattr(sequence, "redraw", fake_redraw)
    response = client.post("/redraw/sequence",
        data={"actions": "standing,running,falling", "identity_mode": "reference"},
        files={"reference": ("a.png", png(), "image/png")})
    assert response.status_code == 200
    assert observed == [(100, 50, 50)] * 3
    with zipfile.ZipFile(io.BytesIO(response.content)) as archive:
        manifest = json.loads(archive.read("manifest.json"))
        assert manifest["identity_mode"] == "reference"
        assert manifest["identity_verified"] is False

def test_sequence_rejects_invalid_identity_mode():
    response = client.post("/redraw/sequence",
        data={"identity_mode": "unknown"},
        files={"reference": ("a.png", png(), "image/png")})
    assert response.status_code == 422

def test_pose_redraw_contract(monkeypatch):
    import ai_redraw.pose as pose_module
    seen = {}
    def fake_pose_redraw(reference, pose, prompt, strength, seed):
        seen["size"] = pose.size
        return reference.copy()
    monkeypatch.setattr(pose_module, "pose_redraw", fake_pose_redraw)
    response = client.post("/redraw/pose",
        data={"prompt": "running"},
        files={"reference": ("ref.png", png(), "image/png"),
               "pose": ("pose.png", png(), "image/png")})
    assert response.status_code == 200
    assert seen["size"] == (64, 64)
    assert response.headers["x-redraw-engine"] == "controlnet-openpose-img2img"
    assert response.headers["x-identity-verified"] == "false"

def test_pose_redraw_requires_skeleton():
    response = client.post("/redraw/pose",
        files={"reference": ("ref.png", png(), "image/png")})
    assert response.status_code == 422

def test_action_generates_distinct_pose_guides():
    from ai_redraw.pose_guides import render_pose
    running = render_pose("running", .25, (128, 128))
    falling = render_pose("falling", 1.0, (128, 128))
    assert running.size == (128, 128)
    assert running.tobytes() != falling.tobytes()

def test_action_endpoint_uses_generated_skeleton(monkeypatch):
    import ai_redraw.pose as pose_module
    captured = {}
    def fake_pose_redraw(reference, pose, prompt, strength, seed):
        captured["pose_size"] = pose.size
        captured["prompt"] = prompt
        return reference.copy()
    monkeypatch.setattr(pose_module, "pose_redraw", fake_pose_redraw)
    response = client.post("/redraw/action",
        data={"action": "crouch", "phase": "0.5"},
        files={"reference": ("ref.png", png(), "image/png")})
    assert response.status_code == 200
    assert captured["pose_size"] == (512, 512)
    assert "crouch" in captured["prompt"]

def test_action_endpoint_rejects_bad_phase():
    response = client.post("/redraw/action",
        data={"phase": "2"},
        files={"reference": ("ref.png", png(), "image/png")})
    assert response.status_code == 422
