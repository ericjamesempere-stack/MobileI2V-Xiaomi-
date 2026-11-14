import io
import json
import zipfile
import pytest
from PIL import Image, ImageDraw
from ai_redraw.storyboard_plan import plan_storyboard
from ai_redraw.storyboard_sheets import create_storyboard_archive

def test_storyboard_full_pipeline():
    plan = plan_storyboard("A train leaves. Rain starts. The bridge lights up.", 2, 12, 128, 128)
    assert plan.total_frames == 24
    assert sum(scene.frame_count for scene in plan.scenes) == 24
    assert [scene.start_frame for scene in plan.scenes] == [0, 8, 16]
    def draw(index, instruction, local_index):
        frame = Image.new("RGB", (128, 128), (index * 9 % 256, 20, 60))
        ImageDraw.Draw(frame).ellipse((local_index, 10, local_index + 20, 30), fill="yellow")
        return frame
    data = create_storyboard_archive(plan, draw)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        names = z.namelist()
        assert len([n for n in names if n.startswith("frames/")]) == 24
        assert len([n for n in names if n.startswith("boards/")]) == 2
        manifest = json.loads(z.read("manifest.json"))
        assert manifest["total_frames"] == 24
        assert manifest["frames"][-1]["index"] == 23
        assert Image.open(io.BytesIO(z.read("frames/frame_000023.png"))).size == (128, 128)

def test_refuse_wrong_proportions():
    plan = plan_storyboard("Make a tree dance.", 1, 2, 128, 128)
    with pytest.raises(ValueError, match="Wrong proportions"):
        create_storyboard_archive(plan, lambda *_: Image.new("RGB", (64, 64)))

def test_refuse_missing_frame():
    plan = plan_storyboard("Make a tree dance.", 1, 2, 128, 128)
    with pytest.raises(ValueError, match="returned no image"):
        create_storyboard_archive(plan, lambda *_: None)

def test_storyboard_can_target_5_minutes():
    plan = plan_storyboard("An entire landscape comes alive.", 300, 24)
    assert plan.total_frames == 7200
    assert plan.scenes[0].frame_count == 7200
