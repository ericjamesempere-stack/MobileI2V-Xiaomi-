import json
from zipfile import ZipFile
from PIL import Image, ImageDraw
import pytest
from ai_redraw.storyboard_stream import produce_storyboard_to_file

def test_streaming_storyboard_has_all_drawings(tmp_path):
    target = tmp_path / "story.zip"
    def renderer(req):
        image = Image.new("RGB", (128, 128), "white")
        ImageDraw.Draw(image).rectangle(
            (req.frame_index * 6, 20, req.frame_index * 6 + 8, 40), fill="black")
        return image
    report = produce_storyboard_to_file(
        Image.new("RGB", (64, 64), "green"),
        "A figure walks. Then it stops.", renderer, target,
        duration_seconds=2, fps=4, width=128, height=128, columns=2)
    assert report["unique_drawings"] == 8
    with ZipFile(target) as archive:
        manifest = json.loads(archive.read("manifest.json"))
        assert len(manifest["frames"]) == 8
        assert "frames/frame_000007.png" in archive.namelist()
        assert "boards/board_0000.png" in archive.namelist()

def test_failed_generation_leaves_no_partial_output(tmp_path):
    target = tmp_path / "story.zip"
    with pytest.raises(ValueError, match="Repeated drawing"):
        produce_storyboard_to_file(
            Image.new("RGB", (64, 64)), "A bird flies.",
            lambda req: Image.new("RGB", (128, 128), "white"),
            target, duration_seconds=1, fps=3, width=128, height=128)
    assert not target.exists()
    assert not list(tmp_path.glob("*.partial"))
