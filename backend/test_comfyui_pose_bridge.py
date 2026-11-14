"""Offline tests: no model download or real photo transfer."""
import os
import unittest
from unittest.mock import patch
from fastapi import HTTPException
from backend.comfyui_pose_bridge import config, health, generate
from backend.anypose_bridge import Request
from backend.test_anypose_bridge import png_b64

class ComfyBridgeTests(unittest.TestCase):
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
