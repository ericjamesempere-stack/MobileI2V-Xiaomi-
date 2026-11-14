import importlib.util
import tempfile
import unittest
from pathlib import Path
from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location(
    "assembler", Path(__file__).resolve().parents[1] / "scripts" / "karma_one_frame_assembler.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class AssemblerTests(unittest.TestCase):
    def test_distinct_drawings_to_mp4(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            folder = root / "frames"
            folder.mkdir()
            for i in range(12):
                im = Image.new("RGB", (128, 128), "white")
                draw = ImageDraw.Draw(im)
                draw.ellipse((50, 10, 78, 38), fill="tan", outline="black")
                draw.line((64, 38, 64, 83), fill="black", width=8)
                draw.line((64, 50, 38 + i*3, 65 - i), fill="blue", width=7)
                draw.line((64, 50, 90 - i*3, 65 + i), fill="blue", width=7)
                draw.line((64, 83, 40+i, 115), fill="black", width=7)
                draw.line((64, 83, 88-i, 115), fill="black", width=7)
                im.save(folder / f"frame_{i:06d}.png")
            result = mod.assemble(folder, root / "animation.mp4", 24, 12)
            self.assertTrue(result["mp4_verified"])
            self.assertEqual(result["frame_count"], 12)
            self.assertGreater((root / "animation.mp4").stat().st_size, 0)

    def test_missing_frame_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            Image.new("RGB", (64, 64), "red").save(folder / "frame_000001.png")
            with self.assertRaisesRegex(ValueError, "Missing/out-of-order"):
                mod.assemble(folder, folder / "bad.mp4", 24)

    def test_resolution_change_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            Image.new("RGB", (64, 64), "red").save(folder / "frame_000000.png")
            Image.new("RGB", (80, 64), "blue").save(folder / "frame_000001.png")
            with self.assertRaisesRegex(ValueError, "Resolution mismatch"):
                mod.assemble(folder, folder / "bad.mp4", 24)

    def test_wrong_frame_count_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            folder = Path(td)
            Image.new("RGB", (64, 64), "red").save(folder / "frame_000000.png")
            with self.assertRaisesRegex(ValueError, "Expected 9000"):
                mod.assemble(folder, folder / "bad.mp4", 30, 9000)

if __name__ == "__main__":
    unittest.main()
