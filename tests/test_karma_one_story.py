import importlib.util
import unittest
from unittest.mock import patch
import builtins
from pathlib import Path
from PIL import Image

def load(name):
    path = Path(__file__).resolve().parents[1] / "scripts" / (name + ".py")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

class StoryTests(unittest.TestCase):
    def test_ordered_actions(self):
        m=load("karma_one_story_sequence")
        self.assertEqual([s["action"] for s in m.plan("marche puis court puis danse")],
                         ["walk","run","dance"])
    def test_crouching_is_distinct_pose(self):
        story=load("karma_one_story_sequence")
        draw=load("karma_one_pose_drawings")
        self.assertEqual([x["action"] for x in story.plan("marche puis accroupi")],["walk","crouch"])
        self.assertNotEqual(draw.draw_pose(4,24,action="stand").tobytes(),
                            draw.draw_pose(4,24,action="crouch").tobytes())

    def test_unsupported_action_rejected(self):
        m=load("karma_one_story_sequence")
        with self.assertRaises(ValueError):
            m.plan("il nage puis vole")
    def test_transition_changes_actual_drawing(self):
        m=load("karma_one_pose_drawings")
        a=m.draw_pose(0,24,action="run",previous_action="walk",blend=0.0,phase_index=3)
        b=m.draw_pose(0,24,action="run",previous_action="walk",blend=1.0,phase_index=3)
        self.assertNotEqual(a.tobytes(), b.tobytes())
    def test_palette_applied_to_drawing(self):
        m=load("karma_one_pose_drawings")
        a=m.draw_pose(2,24,appearance={"shirt":"#ff00ff"},action="walk")
        b=m.draw_pose(2,24,appearance={"shirt":"#00ff00"},action="walk")
        self.assertNotEqual(a.tobytes(), b.tobytes())
    def test_auto_face_detector_missing_dependency_is_explicit(self):
        detector=load("karma_one_face_detector")
        original_import=builtins.__import__
        def reject_cv2(name,*args,**kwargs):
            if name=="cv2":
                raise ImportError("simulated missing optional dependency")
            return original_import(name,*args,**kwargs)
        with patch("builtins.__import__",side_effect=reject_cv2):
            with self.assertRaisesRegex(RuntimeError,"opencv-python"):
                detector.detect_face_box(Path("nonexistent.png"))

    def test_photo_face_texture_changes_articulated_drawing(self):
        m=load("karma_one_pose_drawings")
        photo=Image.new("RGB",(80,100),"#ff5500")
        plain=m.draw_pose(3,24,action="walk")
        textured=m.draw_pose(3,24,action="walk",face_image=photo)
        self.assertNotEqual(plain.tobytes(),textured.tobytes())

    def test_body_proportions_change_drawn_anatomy(self):
        m=load("karma_one_pose_drawings")
        normal=m.draw_pose(3,24,action="walk")
        altered=m.draw_pose(3,24,action="walk",
                            proportions={"leg_length":1.2,"torso_length":0.85,"arm_length":1.15})
        self.assertNotEqual(normal.tobytes(),altered.tobytes())

    def test_invalid_body_proportions_rejected(self):
        m=load("karma_one_pose_drawings")
        with self.assertRaisesRegex(ValueError,"Invalid proportion"):
            m.draw_pose(0,24,proportions={"leg_length":9})

    def test_unsupported_draw_action_rejected(self):
        m=load("karma_one_pose_drawings")
        with self.assertRaises(ValueError):
            m.draw_pose(0,24,action="fly")

if __name__ == "__main__":
    unittest.main()
