import importlib.util
import tempfile
import unittest
from pathlib import Path
from PIL import Image

spec = importlib.util.spec_from_file_location("palette", Path(__file__).resolve().parents[1] / "scripts" / "karma_one_photo_palette.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PhotoPaletteTests(unittest.TestCase):
    def test_regions_sample_photo_colors(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "reference.png"
            image = Image.new("RGB", (100, 100), (10, 20, 30))
            for y in range(50, 100):
                for x in range(100):
                    image.putpixel((x,y), (210, 170, 120))
            image.save(path)
            colors = module.extract(path, {"shirt": [0.1, 0.1, 0.9, 0.4], "skin": [0.1, 0.6, 0.9, 0.9]})
            self.assertEqual(colors["shirt"], "#0a141e")
            self.assertEqual(colors["skin"], "#d2aa78")

    def test_invalid_regions_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "reference.png"
            Image.new("RGB", (20,20), "white").save(path)
            with self.assertRaises(ValueError):
                module.extract(path, {"shirt": [-0.2, 0, 0.5, 1]})

if __name__ == "__main__":
    unittest.main()
