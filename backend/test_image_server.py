"""Lightweight checks for the diffusion backend without downloading model weights."""
import ast
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).with_name("image_server.py").read_text()
TREE = ast.parse(SOURCE)
STAGE = next(node for node in TREE.body if isinstance(node, ast.FunctionDef) and node.name == "action_stage")
scope = {"re": re}
exec(compile(ast.Module(body=[STAGE], type_ignores=[]), "<action_stage>", "exec"), scope)


class BackendContractTests(unittest.TestCase):
    def test_story_phases(self):
        fn = scope["action_stage"]
        self.assertEqual(fn("Il marche puis il court puis il tombe", 0.0), "Il marche")
        self.assertEqual(fn("Il marche puis il court puis il tombe", 0.5), "il court")
        self.assertEqual(fn("Il marche puis il court puis il tombe", 0.99), "il tombe")

    def test_request_response_contract(self):
        self.assertIn('previous_image_base64', SOURCE)
        self.assertIn('"image_base64": base64.b64encode', SOURCE)
        self.assertIn('AutoPipelineForImage2Image', SOURCE)

    def test_aspect_ratio_preserved_in_code(self):
        self.assertIn("min(512 / image.width, 512 / image.height)", SOURCE)


if __name__ == "__main__":
    unittest.main()
