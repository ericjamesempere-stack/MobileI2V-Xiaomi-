import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "verify_mnn_sd_export", Path(__file__).resolve().parents[1] / "tools" / "verify_mnn_sd_export.py")
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class ExportValidation(unittest.TestCase):
    def test_missing_weights_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                mod.inspect(Path(folder))
    def test_small_graphs_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ("text_encoder", "unet", "vae_decoder"):
                (root / (name + ".mnn")).write_bytes(b"fake")
            (root / "tokenizer.mtok").write_bytes(b"fake")
            with self.assertRaises(ValueError):
                mod.inspect(root)

if __name__ == "__main__":
    unittest.main()
