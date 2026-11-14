import io
import zipfile
import pytest
from PIL import Image, ImageDraw
from ai_redraw.storyboard_pipeline import produce_storyboard

def test_pipeline_creates_complete_verified_boards():
    source = Image.new("RGB", (90, 60), "forestgreen")
    def renderer(req):
        assert req.reference.size == source.size
        assert req.previous is None if req.frame_index == 0 else req.previous is not None
        im = Image.new("RGB", (128, 128), "lightblue")
        ImageDraw.Draw(im).rectangle((req.frame_index * 8, 20, req.frame_index * 8 + 12, 50), fill="red")
        return im
    archive, report = produce_storyboard(
        source, "A car drives. A cloud passes.", renderer,
        duration_seconds=2, fps=4, width=128, height=128)
    assert report["valid"] and report["total_frames"] == 8
    assert report["unique_drawings"] == 8
    assert report["identity_verified"] is False
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        assert "manifest.json" in z.namelist()
        assert "boards/board_0000.png" in z.namelist()
        assert "frames/frame_000007.png" in z.namelist()

def test_pipeline_fails_when_renderer_repeats_frames():
    with pytest.raises(ValueError, match="drawing"):
        produce_storyboard(
            Image.new("RGB", (128, 128)), "Make a flower grow.",
            lambda req: Image.new("RGB", (128, 128), "white"),
            duration_seconds=1, fps=3, width=128, height=128)
