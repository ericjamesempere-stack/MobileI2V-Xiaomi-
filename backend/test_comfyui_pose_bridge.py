"""Offline tests: no model download or real photo transfer."""
import os
import unittest
from unittest.mock import patch
from fastapi import HTTPException
from backend.comfyui_pose_bridge import config, health, generate
from backend.anypose_bridge import Request
from backend.test_anypose_bridge import png_b64

class ComfyBridgeTests(unittest.TestCase):
    def test_complete_frame_contract_with_mock_comfyui(self):
        """Exercise upload, dynamic prompt, queue, history and returned PNG."""
        import base64
        import io
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import Mock
        from PIL import Image
        from backend.comfyui_pose_bridge import generate
        workflow = {
            "1": {"class_type": "LoadImage", "inputs": {"image": "ref.png"}},
            "2": {"class_type": "LoadImage", "inputs": {"image": "pose.png"}},
            "3": {"class_type": "CLIPTextEncode", "inputs": {"text": "old"}},
            "4": {"class_type": "ControlNetApplyAdvanced", "inputs": {"image": ["2", 0], "positive": ["3", 0]}},
            "5": {"class_type": "ImageBlend", "inputs": {"image1": ["1", 0], "image2": ["4", 0]}},
            "6": {"class_type": "SaveImage", "inputs": {"images": ["5", 0]}},
        }
        with tempfile.TemporaryDirectory() as folder:
            filename = Path(folder) / "workflow.json"
            filename.write_text(json.dumps(workflow))
            env = {"MOBILEI2V_API_TOKEN": "secret", "COMFYUI_URL": "http://127.0.0.1:8188",
                   "COMFYUI_WORKFLOW": str(filename), "COMFYUI_REFERENCE_NODE": "1",
                   "COMFYUI_POSE_NODE": "2", "COMFYUI_OUTPUT_NODE": "6", "COMFYUI_PROMPT_NODE": "3"}
            sent = []
            def fake_post(url, **kwargs):
                response = Mock()
                response.raise_for_status.return_value = None
                if url.endswith("/upload/image"):
                    response.json.return_value = {"name": "uploaded.png"}
                elif url.endswith("/prompt"):
                    sent.append(kwargs["json"]["prompt"])
                    response.json.return_value = {"prompt_id": "job123"}
                else:
                    raise AssertionError(url)
                return response
            def fake_get(url, **kwargs):
                response = Mock()
                response.raise_for_status.return_value = None
                if "/history/" in url:
                    response.json.return_value = {"job123": {"outputs": {"6": {"images": [{"filename": "out.png"}]}}}}
                elif url.endswith("/view"):
                    buffer = io.BytesIO()
                    Image.new("RGB", (8, 8), "green").save(buffer, format="PNG")
                    response.content = buffer.getvalue()
                else:
                    raise AssertionError(url)
                return response
            req = Request(image_base64=png_b64("blue"), pose_image_base64=png_b64("red"),
                          prompt="person running then falling", frame_index=0, total_frames=2)
            with patch.dict(os.environ, env, clear=True):
                with patch("backend.comfyui_pose_bridge.requests.post", side_effect=fake_post):
                    with patch("backend.comfyui_pose_bridge.requests.get", side_effect=fake_get):
                        result = generate(req, authorization="Bearer secret")
            self.assertEqual(result["backend"], "comfyui")
            self.assertEqual(result["frame_index"], 0)
            self.assertTrue(base64.b64decode(result["image_base64"]).startswith(bytes([137, 80, 78, 71])))
            self.assertIn("person running then falling", sent[0]["3"]["inputs"]["text"])
            self.assertEqual(sent[0]["1"]["inputs"]["image"], "uploaded.png")

    def test_no_configuration_is_not_ready(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(health()["ready"])

    def test_remote_url_is_rejected(self):
        env = {"MOBILEI2V_API_TOKEN": "secret", "COMFYUI_URL": "https://remote.example",
               "COMFYUI_WORKFLOW": "/tmp/w.json", "COMFYUI_REFERENCE_NODE": "1",
               "COMFYUI_POSE_NODE": "2", "COMFYUI_OUTPUT_NODE": "3"}
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(HTTPException) as error:
                config()
        self.assertEqual(error.exception.status_code, 503)

    def test_missing_prompt_node_is_rejected_before_photo_upload(self):
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import patch as mock_patch
        workflow = {
            "1": {"class_type": "LoadImage", "inputs": {"image": "reference.png"}},
            "2": {"class_type": "LoadImage", "inputs": {"image": "pose.png"}},
            "3": {"class_type": "SaveImage", "inputs": {"images": ["5", 0]}},
            "4": {"class_type": "ControlNetApplyAdvanced", "inputs": {"image": ["2", 0], "conditioning": ["1", 0]}},
            "5": {"class_type": "ImageBlend", "inputs": {"image1": ["1", 0], "image2": ["4", 0]}},
        }
        with tempfile.TemporaryDirectory() as folder:
            filename = Path(folder) / "workflow.json"
            filename.write_text(json.dumps(workflow))
            env = {"MOBILEI2V_API_TOKEN": "secret", "COMFYUI_URL": "http://127.0.0.1:8188",
                   "COMFYUI_WORKFLOW": str(filename), "COMFYUI_REFERENCE_NODE": "1",
                   "COMFYUI_POSE_NODE": "2", "COMFYUI_OUTPUT_NODE": "3"}
            req = Request(image_base64=png_b64("blue"), pose_image_base64=png_b64("red"),
                          prompt="running", frame_index=0, total_frames=2)
            with mock_patch.dict(os.environ, env, clear=True):
                with mock_patch("backend.comfyui_pose_bridge.upload") as upload:
                    with self.assertRaises(HTTPException) as error:
                        generate(req, authorization="Bearer secret")
                    upload.assert_not_called()
            self.assertEqual(error.exception.status_code, 503)

    def test_bad_prompt_node_is_rejected_before_photo_upload(self):
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import patch as mock_patch
        workflow = {
            "1": {"class_type": "LoadImage", "inputs": {"image": "reference.png"}},
            "2": {"class_type": "LoadImage", "inputs": {"image": "pose.png"}},
            "3": {"class_type": "SaveImage", "inputs": {"images": ["5", 0]}},
            "4": {"class_type": "ControlNetApplyAdvanced", "inputs": {"image": ["2", 0], "conditioning": ["1", 0]}},
            "5": {"class_type": "ImageBlend", "inputs": {"image1": ["1", 0], "image2": ["4", 0]}},
        }
        with tempfile.TemporaryDirectory() as folder:
            filename = Path(folder) / "workflow.json"
            filename.write_text(json.dumps(workflow))
            env = {"MOBILEI2V_API_TOKEN": "secret", "COMFYUI_URL": "http://127.0.0.1:8188",
                   "COMFYUI_WORKFLOW": str(filename), "COMFYUI_REFERENCE_NODE": "1",
                   "COMFYUI_POSE_NODE": "2", "COMFYUI_OUTPUT_NODE": "3",
                   "COMFYUI_PROMPT_NODE": "5"}
            req = Request(image_base64=png_b64("blue"), pose_image_base64=png_b64("red"),
                          prompt="running", frame_index=0, total_frames=2)
            with mock_patch.dict(os.environ, env, clear=True):
                with mock_patch("backend.comfyui_pose_bridge.upload") as upload:
                    with self.assertRaises(HTTPException) as error:
                        generate(req, authorization="Bearer secret")
                    upload.assert_not_called()
            self.assertEqual(error.exception.status_code, 503)

    def test_pose_must_reach_controlnet_not_just_output(self):
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import patch as mock_patch
        # Pose image goes straight to output, while ControlNet receives a
        # separate image. Graph connectivity alone must not be accepted.
        workflow = {
            "1": {"class_type": "LoadImage", "inputs": {"image": "reference.png"}},
            "2": {"class_type": "LoadImage", "inputs": {"image": "pose.png"}},
            "3": {"class_type": "SaveImage", "inputs": {"images": ["5", 0]}},
            "4": {"class_type": "ControlNetApplyAdvanced", "inputs": {"image": ["1", 0]}},
            "5": {"class_type": "ImageBlend", "inputs": {"image1": ["2", 0], "image2": ["4", 0]}},
        }
        with tempfile.TemporaryDirectory() as folder:
            filename = Path(folder) / "workflow.json"
            filename.write_text(json.dumps(workflow))
            env = {"MOBILEI2V_API_TOKEN": "secret", "COMFYUI_URL": "http://127.0.0.1:8188",
                   "COMFYUI_WORKFLOW": str(filename), "COMFYUI_REFERENCE_NODE": "1",
                   "COMFYUI_POSE_NODE": "2", "COMFYUI_OUTPUT_NODE": "3"}
            req = Request(image_base64=png_b64("blue"), pose_image_base64=png_b64("red"),
                          prompt="running", frame_index=0, total_frames=2)
            with mock_patch.dict(os.environ, env, clear=True):
                with mock_patch("backend.comfyui_pose_bridge.upload") as upload:
                    with self.assertRaises(HTTPException) as error:
                        generate(req, authorization="Bearer secret")
                    upload.assert_not_called()
            self.assertEqual(error.exception.status_code, 503)

    def test_disconnected_workflow_is_rejected_without_upload(self):
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import patch as mock_patch
        workflow = {
            "1": {"class_type": "LoadImage", "inputs": {"image": "reference.png"}},
            "2": {"class_type": "LoadImage", "inputs": {"image": "pose.png"}},
            "3": {"class_type": "SaveImage", "inputs": {"images": ["4", 0]}},
            "4": {"class_type": "EmptyLatentImage", "inputs": {}},
        }
        with tempfile.TemporaryDirectory() as folder:
            filename = Path(folder) / "workflow.json"
            filename.write_text(json.dumps(workflow))
            env = {"MOBILEI2V_API_TOKEN": "secret", "COMFYUI_URL": "http://127.0.0.1:8188",
                   "COMFYUI_WORKFLOW": str(filename), "COMFYUI_REFERENCE_NODE": "1",
                   "COMFYUI_POSE_NODE": "2", "COMFYUI_OUTPUT_NODE": "3"}
            req = Request(image_base64=png_b64("blue"), pose_image_base64=png_b64("red"),
                          prompt="running", frame_index=0, total_frames=2)
            with mock_patch.dict(os.environ, env, clear=True):
                with mock_patch("backend.comfyui_pose_bridge.upload") as upload:
                    with self.assertRaises(HTTPException) as error:
                        generate(req, authorization="Bearer secret")
                    upload.assert_not_called()
            self.assertEqual(error.exception.status_code, 503)

    def test_unauthorized_request_never_uploads_photo(self):
        env = {"MOBILEI2V_API_TOKEN": "secret", "COMFYUI_URL": "http://127.0.0.1:8188",
               "COMFYUI_WORKFLOW": "/tmp/w.json", "COMFYUI_REFERENCE_NODE": "1",
               "COMFYUI_POSE_NODE": "2", "COMFYUI_OUTPUT_NODE": "3"}
        req = Request(image_base64=png_b64("blue"), pose_image_base64=png_b64("red"),
                      prompt="running", frame_index=0, total_frames=2)
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(HTTPException) as error:
                generate(req, authorization="Bearer wrong")
        self.assertEqual(error.exception.status_code, 401)

if __name__ == "__main__":
    unittest.main()
