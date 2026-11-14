"""HTTP contract tests. Fake model modules; these tests do NOT validate actual AI quality."""
import base64
import io
import os
import sys
import types
import unittest
from unittest.mock import patch
from PIL import Image

sys.path.insert(0, os.path.abspath("tools"))
import visual_backend as backend


def source_b64():
    im = Image.new("RGB", (64, 64), (150, 80, 40))
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


class VisualBackendContract(unittest.TestCase):
    def setUp(self):
        self.client = backend.app.test_client()
        backend._pose_model = None
        backend._draw_model = None

    def test_health(self):
        self.assertEqual(self.client.get("/health").status_code, 200)

    def test_pose_real_response_shape_with_stub_detector(self):
        class Landmark:
            x, y, z, visibility = 0.5, 0.4, 0.0, 0.99

        class Pose:
            def __init__(self, **kwargs): pass
            def process(self, image):
                return types.SimpleNamespace(pose_landmarks=types.SimpleNamespace(landmark=[Landmark() for _ in range(33)]))

        fake_mp = types.SimpleNamespace(solutions=types.SimpleNamespace(pose=types.SimpleNamespace(Pose=Pose)))
        with patch.dict(sys.modules, {"mediapipe": fake_mp}):
            result = self.client.post("/pose", json={"image_base64": source_b64()})
        self.assertEqual(result.status_code, 200, result.json)
        self.assertTrue(result.json["detected"])
        self.assertEqual(len(result.json["landmarks"]), 33)

    def test_invalid_base64_returns_client_error(self):
        response = self.client.post("/pose", json={"image_base64": "not-valid-@@@"})
        self.assertEqual(response.status_code, 400, response.json)

    def test_missing_image_returns_client_error(self):
        response = self.client.post("/pose", json={})
        self.assertEqual(response.status_code, 400, response.json)

    def test_tasks_pose_landmarker_contract(self):
        class Landmark:
            x, y, z, visibility = 0.5, 0.4, 0.0, 0.99

        class TaskDetector:
            @classmethod
            def create_from_options(cls, options): return cls()
            def detect(self, image):
                return types.SimpleNamespace(pose_landmarks=[[Landmark() for _ in range(33)]])

        fake_mp = types.SimpleNamespace(
            tasks=types.SimpleNamespace(
                BaseOptions=lambda **kwargs: object(),
                vision=types.SimpleNamespace(
                    PoseLandmarkerOptions=lambda **kwargs: object(),
                    RunningMode=types.SimpleNamespace(IMAGE="IMAGE"),
                    PoseLandmarker=TaskDetector)),
            Image=lambda **kwargs: object(),
            ImageFormat=types.SimpleNamespace(SRGB="SRGB"))
        with patch.dict(sys.modules, {"mediapipe": fake_mp}), patch.dict(
            os.environ, {"MOBILEI2V_POSE_TASK": "/tmp/pose_landmarker.task"}
        ), patch("os.path.isfile", return_value=True):
            response = self.client.post("/pose", json={"image_base64": source_b64()})
        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(response.json["model"], "mediapipe_tasks_pose_landmarker")
        self.assertEqual(len(response.json["landmarks"]), 33)

    def test_redraw_missing_model_is_explicit(self):
        # Diffusers import occurs before missing-model validation.
        fake_diffusers = types.SimpleNamespace(AutoPipelineForImage2Image=object)
        with patch.dict(sys.modules, {"diffusers": fake_diffusers}), patch.dict(os.environ, {"MOBILEI2V_IMAGE_MODEL": ""}):
            response = self.client.post("/generate/storyboard", json={"image_base64": source_b64(), "prompt": "standing"})
        self.assertEqual(response.status_code, 503)
        self.assertIn("MOBILEI2V_IMAGE_MODEL", response.json["error"])

    def test_redraw_returns_real_png_bytes_from_stub_pipeline(self):
        class FakePipeline:
            @classmethod
            def from_pretrained(cls, *args, **kwargs): return cls()
            def to(self, device): return self
            def __call__(self, **kwargs):
                color = (10, 20, 30) if "crouched" in kwargs["prompt"] else (30, 20, 10)
                return types.SimpleNamespace(images=[Image.new("RGB", (64, 64), color)])
        fake_diffusers = types.SimpleNamespace(AutoPipelineForImage2Image=FakePipeline)
        fake_torch = types.SimpleNamespace(cuda=types.SimpleNamespace(is_available=lambda: False), float32="float32", float16="float16")
        with patch.dict(sys.modules, {"diffusers": fake_diffusers, "torch": fake_torch}), patch.dict(os.environ, {"MOBILEI2V_IMAGE_MODEL": "mock"}):
            response = self.client.post("/generate/storyboard", json={"image_base64": source_b64(), "prompt": "character", "num_images": 2, "target_poses": ["crouched", "standing"]})
        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(len(response.json["images"]), 2)
        self.assertEqual(len(set(response.json["pixel_sha256"])), 2)
        self.assertTrue(base64.b64decode(response.json["images"][0]).startswith(b"\x89PNG\r\n\x1a\n"))


if __name__ == "__main__":
    unittest.main()
