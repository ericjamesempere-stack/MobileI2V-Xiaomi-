import pytest
from PIL import Image, ImageDraw
from ai_redraw.storyboard_plan import plan_storyboard
from ai_redraw.drawing_generator import generate_drawings

def test_reference_and_previous_are_passed_for_every_drawing():
    plan = plan_storyboard("The castle rises. The clouds scatter.", 2, 4, 128, 128)
    reference = Image.new("RGB", (80, 60), "green")
    calls = []
    def renderer(request):
        assert request.reference.size == (80, 60)
        assert request.previous is None if request.frame_index == 0 else request.previous is not None
        calls.append((request.scene_index, request.phase))
        image = Image.new("RGB", (128, 128), "navy")
        ImageDraw.Draw(image).rectangle((request.frame_index * 3, 20, 15 + request.frame_index * 3, 40), fill="white")
        return image
    frames = generate_drawings(plan, reference, renderer)
    assert len(frames) == 8
    assert calls[0][0] == 0 and calls[-1][0] == 1
    assert calls[0][1] == 0 and calls[-1][1] == 1

def test_reject_static_frames():
    plan = plan_storyboard("Move a vehicle.", 1, 3, 128, 128)
    with pytest.raises(ValueError, match="Duplicate drawing"):
        generate_drawings(plan, Image.new("RGB", (128, 128)),
                          lambda req: Image.new("RGB", (128, 128), "blue"))

def test_reject_abrupt_changes():
    plan = plan_storyboard("Move a vehicle.", 1, 2, 128, 128)
    with pytest.raises(ValueError, match="Visual discontinuity"):
        generate_drawings(plan, Image.new("RGB", (128, 128)),
                          lambda req: Image.new("RGB", (128, 128),
                                                "white" if req.frame_index else "black"),
                          max_mean_change=50)

def test_reject_invalid_size():
    plan = plan_storyboard("Move a vehicle.", 1, 2, 128, 128)
    with pytest.raises(ValueError, match="Incorrect drawing size"):
        generate_drawings(plan, Image.new("RGB", (128, 128)),
                          lambda req: Image.new("RGB", (64, 64)))
