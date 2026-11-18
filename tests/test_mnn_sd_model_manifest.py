import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("mnn_manifest", Path(__file__).resolve().parents[1] / "tools" / "mnn_sd_model_manifest.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ManifestTests(unittest.TestCase):
    def test_real_files_hashes(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            names = {k: k + ".mnn" for k in module.REQUIRED}
            for k, filename in names.items():
                (root / filename).write_bytes(("test-data:" + k).encode())
            result = module.create_manifest(root, names)
            self.assertEqual(len(result["components"]), 4)
            self.assertFalse(result["weights_verified"])
            self.assertEqual(result["components"]["unet"]["bytes"], len(b"test-data:unet"))
    def test_missing_and_path_traversal_fail_closed(self):
        with tempfile.TemporaryDirectory() as d:
            names = {k: k + ".mnn" for k in module.REQUIRED}
            with self.assertRaises(ValueError):
                module.create_manifest(Path(d), names)
            names["unet"] = "../escape.mnn"
            with self.assertRaises(ValueError):
                module.create_manifest(Path(d), names)

if __name__ == "__main__":
    unittest.main()
