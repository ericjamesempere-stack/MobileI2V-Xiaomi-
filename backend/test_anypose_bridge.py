"""Offline integration test: exercises /generate with a fake Gradio client.

No network, user photos, GPU, or HF account required.
"""
import base64
import io
import os
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import HTTPException
from PIL import Image
from backend.anypose_bridge import Request, decode, first_gallery_path, generate, health


def png_b64(color):
    img = Image.new("RGB", (32, 48), color)
    buffer = io.BytesIO()
    img.save(buffer, "PNG")
    return base64.b64encode(buffer.getvalue()).decode()


class FakeClient:
    def __init__(self, *args, **kwargs):
        pass

    def predict(self, *args, **kwargs):
        assert kwargs["api_name"] == "/infer"
        assert len(args) == 10
        assert args[3:10] == (0, False, 1.0, 4, 512, 384, False)
        img = Image.new("RGB", (32, 48), "green")
        output = Path(tempfile.gettempdir()) / "mobilei2v_anypose_mock_output.png"
        img.save(output)
        return ([{"image": {"path": str(output)}}], 0, None)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.req = Request(
            image_base64=png_b64("blue"),
            pose_image_base64=png_b64("red"),
            prompt="person falls onto the ground",
            frame_index=0,
            total_frames=2,
        )

    def test_health_does_not_claim_remote_is_verified(self):
        with patch.dict(os.environ, {"MOBILEI2V_API_TOKEN": "secret"}):
            status = health()
        self.assertTrue(status["ready"])
        self.assertFalse(status["remote_verified"])

    def test_remote_failure_is_retryable_without_leaking_details(self):
        class FailingClient:
            def __init__(self, *args, **kwargs):
                pass
            def predict(self, *args, **kwargs):
                raise RuntimeError("private server path /secret/data")
        fake = types.ModuleType("gradio_client")
        fake.Client = FailingClient
        fake.handle_file = lambda path: path
        with patch.dict(sys.modules, {"gradio_client": fake}):
            with patch.dict(os.environ, {"MOBILEI2V_API_TOKEN": "secret"}):
                with self.assertRaises(HTTPException) as caught:
                    generate(self.req, authorization="Bearer secret")
        self.assertEqual(caught.exception.status_code, 503)
        self.assertEqual(caught.exception.headers["Retry-After"], "30")
        self.assertNotIn("secret", caught.exception.detail)

    def test_gallery_nested_path(self):
        self.assertEqual(first_gallery_path([{"image": {"path": "/tmp/x.png"}}]), "/tmp/x.png")

    def test_rejects_bad_image(self):
        with self.assertRaises(HTTPException) as caught:
            decode("not base64!")
        self.assertEqual(caught.exception.status_code, 400)

    def test_authentication_required(self):
        with patch.dict(os.environ, {"MOBILEI2V_API_TOKEN": "secret"}):
            with self.assertRaises(HTTPException) as caught:
                generate(self.req, authorization="Bearer wrong")
        self.assertEqual(caught.exception.status_code, 401)

    def test_end_to_end_mock_generation(self):
        fake = types.ModuleType("gradio_client")
        fake.Client = FakeClient
        fake.handle_file = lambda path: path
        with patch.dict(sys.modules, {"gradio_client": fake}):
            with patch.dict(os.environ, {"MOBILEI2V_API_TOKEN": "secret"}):
                result = generate(self.req, authorization="Bearer secret")
        self.assertEqual(result["frame_index"], 0)
        image = decode(result["image_base64"])
        self.assertEqual(image.size, (32, 48))
        self.assertEqual(image.getpixel((0, 0)), (0, 128, 0))


if __name__ == "__main__":
    unittest.main()
