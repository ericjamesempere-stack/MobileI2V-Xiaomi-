"""Opt-in real-model smoke test. Requires downloaded weights and GPU.
Run: REDRAW_REAL_TEST=1 python -m pytest -q ai_redraw/test_real_inference.py
Never substitutes mocks or fabricated image outputs.
"""
import io
import os
import pytest
from PIL import Image, ImageChops
from fastapi.testclient import TestClient
from ai_redraw.server import app

@pytest.mark.skipif(os.getenv("REDRAW_REAL_TEST") != "1", reason="GPU and model weights required")
def test_real_controlnet_generates_a_distinct_frame():
    import base64
    reference = Image.new("RGB", (384, 512), (235, 225, 215))
    source = io.BytesIO()
    reference.save(source, format="PNG")
    # OpenPose guide: simple visible skeleton, no reference identity claim.
    pose = Image.new("RGB", (384, 512), (0, 0, 0))
    from PIL import ImageDraw
    draw = ImageDraw.Draw(pose)
    for a, b in [((192, 90), (192, 190)), ((192, 190), (140, 280)),
                 ((192, 190), (244, 280)), ((192, 190), (140, 145)),
                 ((192, 190), (244, 145)), ((140, 280), (125, 400)),
                 ((244, 280), (265, 400))]:
        draw.line((a, b), fill=(255, 180, 50), width=9)
    guide = io.BytesIO()
    pose.save(guide, format="PNG")
    payload = {
        "image_base64": base64.b64encode(source.getvalue()).decode(),
        "pose_image_base64": base64.b64encode(guide.getvalue()).decode(),
        "prompt": "A full-body hand drawn cartoon character, standing, clean lines",
        "frame_index": 0, "total_frames": 2
    }
    response = TestClient(app).post("/generate", json=payload, timeout=600)
    assert response.status_code == 200, response.text[:500]
    generated = Image.open(io.BytesIO(base64.b64decode(response.json()["image_base64"]))).convert("RGB")
    assert generated.width >= 64 and generated.height >= 64
    resized_source = reference.resize(generated.size)
    assert ImageChops.difference(generated, resized_source).getbbox() is not None
