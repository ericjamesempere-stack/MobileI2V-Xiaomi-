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

def test_distinct_pose_guides_reach_real_model_adapter(monkeypatch):
    import ai_redraw.godot_adapter as adapter
    observed = []
    def capture(reference, pose, prompt, strength, seed):
        observed.append((pose.getpixel((0, 0)), seed))
        return reference.copy()
    monkeypatch.setattr(adapter, "pose_redraw", capture)
    first = payload()
    second = payload()
    second["frame_index"] = 1
    pose = Image.new("RGB", (64, 64), (0, 200, 20))
    buf = io.BytesIO()
    pose.save(buf, format="PNG")
    second["pose_image_base64"] = base64.b64encode(buf.getvalue()).decode("ascii")
    assert client.post("/generate", json=first).status_code == 200
    assert client.post("/generate", json=second).status_code == 200
    # Pose must change while the random seed stays fixed to reduce flicker.
    assert observed == [((100, 50, 50), 1234), ((0, 200, 20), 1234)]

def test_reject_frame_index_outside_sequence():
    body = payload()
    body["frame_index"] = body["total_frames"]
    assert client.post("/generate", json=body).status_code == 422


def test_reference_fidelity_controls_denoising(monkeypatch):
    import ai_redraw.godot_adapter as adapter
    observed = []
    def capture(reference, pose, prompt, strength, seed):
        observed.append((strength, seed))
        return reference.copy()
    monkeypatch.setattr(adapter, "pose_redraw", capture)
    low = payload()
    low["reference_strength"] = 0.0
    high = payload()
    high["reference_strength"] = 1.0
    assert client.post("/generate", json=low).status_code == 200
    assert client.post("/generate", json=high).status_code == 200
    assert len(observed) == 2
    assert abs(observed[0][0] - 0.75) < 1e-8
    assert abs(observed[1][0] - 0.4) < 1e-8
    assert [seed for _, seed in observed] == [1234, 1234]
    assert observed[1][0] < observed[0][0]


def test_no_unverified_identity_claim_even_with_previous_frame(monkeypatch):
    import ai_redraw.godot_adapter as adapter
    monkeypatch.setattr(adapter, "pose_redraw", lambda *args: args[0].copy())
    body = payload()
    body["previous_image_base64"] = png_b64()
    result = client.post("/generate", json=body)
    assert result.status_code == 200
    assert result.json()["identity_verified"] is False
    assert result.json()["temporal_continuity_verified"] is False


def test_pose_health_never_claims_unverified_inference():
    result = client.get("/health/pose")
    assert result.status_code == 200
    data = result.json()
    assert data["http_ok"] is True
    assert data["real_inference_verified"] is False
    assert isinstance(data["cuda_available"], bool)
    assert isinstance(data["model_loaded"], bool)
    assert data["ready_for_inference"] == (data["cuda_available"] and data["model_loaded"])


def test_accepts_extended_storyboard_frame_limit(monkeypatch):
    import ai_redraw.godot_adapter as adapter
    monkeypatch.setattr(adapter, "pose_redraw", lambda *args: args[0].copy())
    body = payload()
    body["frame_index"] = 239
    body["total_frames"] = 240
    assert client.post("/generate", json=body).status_code == 200
    body["frame_index"] = 240
    assert client.post("/generate", json=body).status_code == 422
    body["frame_index"] = 0
    body["total_frames"] = 241
    assert client.post("/generate", json=body).status_code == 422
