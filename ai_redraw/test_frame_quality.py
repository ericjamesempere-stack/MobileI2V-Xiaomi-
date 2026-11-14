from PIL import Image, ImageDraw
import pytest
from ai_redraw.frame_quality import assess_pair

def test_identical():
    im = Image.new("RGB", (256, 128), "white")
    result = assess_pair(im, im.copy())
    assert result.identical and result.likely_static and result.mean_difference == 0

def test_moving_object_detected():
    def make(x):
        im = Image.new("RGB", (256, 128), "white")
        ImageDraw.Draw(im).rectangle((x, 20, x + 40, 60), fill="black")
        return im
    result = assess_pair(make(20), make(65))
    assert not result.identical and result.changed_pixel_fraction > 0.02
    assert result.edge_difference > 0

def test_cut_detected():
    result = assess_pair(Image.new("RGB", (128, 128), "black"),
                         Image.new("RGB", (128, 128), "white"))
    assert result.abrupt_change

def test_dimensions():
    with pytest.raises(ValueError, match="dimensions"):
        assess_pair(Image.new("RGB", (128, 128)), Image.new("RGB", (64, 64)))
