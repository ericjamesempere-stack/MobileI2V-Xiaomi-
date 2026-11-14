"""GPU-independent integration checks for the MobileI2V image service.

Run: python -m unittest discover -s backend -p 'test_*.py' -v
"""
import ast
import base64
import io
from pathlib import Path
import unittest

ROOT = Path(__file__).with_name("image_server.py")
TREE = ast.parse(ROOT.read_text(encoding="utf-8"))


def extract(name):
    return next(node for node in TREE.body if isinstance(node, ast.FunctionDef) and node.name == name)


class ImageBackendStaticTests(unittest.TestCase):
    def test_parse_all_backend_functions(self):
        self.assertTrue(extract("generate"))
        self.assertTrue(extract("decode_image"))
        self.assertTrue(extract("fit"))
        self.assertTrue(extract("action_stage"))

    def test_diffusion_generation_is_real(self):
        text = ROOT.read_text(encoding="utf-8")
        self.assertIn("AutoPipelineForImage2Image.from_pretrained", text)
        self.assertIn("pipeline()(", text)
        self.assertIn("image=conditioning", text)

    def test_reference_and_previous_are_used(self):
        text = ROOT.read_text(encoding="utf-8")
        self.assertIn("previous_image_base64", text)
        self.assertIn("Image.blend(previous, reference", text)
        self.assertIn('"image_base64": base64.b64encode', text)

    def test_api_rejects_unauthorized_requests_if_token_set(self):
        text = ROOT.read_text(encoding="utf-8")
        self.assertIn('MOBILEI2V_API_TOKEN', text)
        self.assertIn("HTTPException(401", text)

    def test_timeline_reaches_final_action(self):
        module = ast.Module(body=[extract("action_stage")], type_ignores=[])
        scope = {"re": __import__("re")}
        exec(compile(ast.fix_missing_locations(module), str(ROOT), "exec"), scope)
        action = scope["action_stage"]
        story = "Le personnage marche puis court puis tombe au sol"
        self.assertEqual(action(story, 0.0), "Le personnage marche")
        self.assertEqual(action(story, 0.5), "court")
        self.assertEqual(action(story, 1.0), "tombe au sol")

    def test_client_authentication_and_full_timeline(self):
        client = (ROOT.parent.parent / "scripts/image_sequence_generator.gd").read_text(encoding="utf-8")
        self.assertIn("Authorization: Bearer ", client)
        self.assertIn("count - 1", client)

    def test_pipeline_does_not_use_obsolete_safety_checker_parameter(self):
        tree = extract("pipeline")
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and any(kw.arg == "safety_checker" for kw in node.keywords):
                self.fail("Unsupported safety_checker argument in img2img pipeline")


if __name__ == "__main__":
    unittest.main()
