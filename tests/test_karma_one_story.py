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
    def test_wave_and_jump_are_articulated_and_parsed(self):
        story=load("karma_one_story_sequence")
        draw=load("karma_one_pose_drawings")
        self.assertEqual([step["action"] for step in
                          story.plan("marche puis salue puis saute")],
                         ["walk","wave","jump"])
        standing=draw.joint_positions(6,24,action="stand",phase_index=6)
        waving=draw.joint_positions(6,24,action="wave",phase_index=6)
        jumping=draw.joint_positions(6,24,action="jump",phase_index=6)
        self.assertLess(waving["right_hand"][1],standing["right_hand"][1])
        self.assertLess(jumping["hip"][1],standing["hip"][1])
        self.assertLess(jumping["left_foot"][1],standing["left_foot"][1])
        self.assertNotEqual(draw.draw_pose(6,24,action="wave").tobytes(),
                            draw.draw_pose(6,24,action="stand").tobytes())

    def test_repeated_story_generation_clears_old_frames(self):
        import tempfile
        story=load("karma_one_story_sequence")
        with tempfile.TemporaryDirectory() as tmp:
            output=Path(tmp)/"story.mp4"
            drawings=Path(tmp)/"story_drawings"
            drawings.mkdir()
            stale=drawings/"frame_999999.png"
            Image.new("RGB",(360,480)).save(stale)
            # The real pipeline is exercised by CI; here verify the cleanup
            # through the complete short render when ffmpeg is installed.
            import shutil
            if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
                self.skipTest("ffmpeg unavailable")
            report=story.produce("marche",output,seconds=1,fps=24)
            self.assertFalse(stale.exists())
            self.assertEqual(len(list(drawings.glob("frame_*.png"))),24)
            self.assertEqual(report["frame_count"],24)

    def test_quintic_transition_has_gentle_endpoints(self):
        draw=load("karma_one_pose_drawings")
        def hip(blend):
            return draw.joint_positions(0,24,action="crouch",
                     previous_action="stand",blend=blend,phase_index=0)["hip"][1]
        first,early,mid,late,last=[hip(t) for t in (0,0.1,0.5,0.9,1)]
        self.assertLessEqual(abs(first-early),1)
        self.assertLess(first,mid)
        self.assertLess(mid,late)
        self.assertLessEqual(abs(late-last),1)

    def test_tracked_joints_are_identical_to_rendered_frame_geometry(self):
        draw=load("karma_one_pose_drawings")
        image, joints=draw.draw_pose(3,24,action="run",phase_index=3,
                                     proportions={"leg_length":1.2},
                                     return_joints=True)
        measured=draw.joint_positions(3,24,action="run",phase_index=3,
                                      proportions={"leg_length":1.2})
        self.assertEqual(joints,measured)
        self.assertEqual(image.size,(360,480))
        self.assertEqual(set(joints),{"hip","shoulder","head","left_foot","right_foot",
                         "left_knee","right_knee","left_elbow","right_elbow",
                         "left_hand","right_hand"})

    def test_transition_reaches_target_even_for_two_frame_action(self):
        story=load("karma_one_story_sequence")
        self.assertEqual(story.transition_blend(0,2),0.0)
        self.assertEqual(story.transition_blend(1,2),1.0)
        with self.assertRaisesRegex(ValueError,"at least two"):
            story.transition_blend(0,1)

    def test_transition_starts_at_old_pose_and_finishes_at_new_pose(self):
        story=load("karma_one_story_sequence")
        self.assertEqual(story.transition_blend(0,6),0.0)
        self.assertAlmostEqual(story.transition_blend(2,6),0.4)
        self.assertEqual(story.transition_blend(5,6),1.0)
        self.assertEqual(story.transition_blend(9,6),1.0)
        self.assertEqual(story.transition_blend(0,6,first_action=True),1.0)

    def test_ordered_actions(self):
        m=load("karma_one_story_sequence")
        self.assertEqual([s["action"] for s in m.plan("marche puis court puis danse")],
                         ["walk","run","dance"])
    def test_running_pelvis_and_knees_change_across_stride(self):
        draw=load("karma_one_pose_drawings")
        a=draw.draw_pose(0,24,action="run",phase_index=0)
        b=draw.draw_pose(3,24,action="run",phase_index=3)
        c=draw.draw_pose(6,24,action="run",phase_index=6)
        self.assertNotEqual(a.tobytes(),b.tobytes())
        self.assertNotEqual(b.tobytes(),c.tobytes())
        self.assertEqual(a.size,b.size)

    def test_gait_alternates_support_and_swing_foot(self):
        draw=load("karma_one_pose_drawings")
        a=draw.joint_positions(3,24,action="run",phase_index=3)
        b=draw.joint_positions(9,24,action="run",phase_index=9)
        # Test the actual articulated foot landmarks, not ambiguous pixel colors
        # where limbs can cross from one half of the image into the other.
        self.assertLess(a["left_foot"][1],a["right_foot"][1])
        self.assertGreater(b["left_foot"][1],b["right_foot"][1])

    def test_stumble_between_run_and_fall(self):
        story=load("karma_one_story_sequence")
        draw=load("karma_one_pose_drawings")
        self.assertEqual([x["action"] for x in story.plan("court puis trébuche puis tombe puis se relève")],
                         ["run","stumble","fall","stand"])
        standing=draw.draw_pose(0,24,action="stand",phase_index=0)
        stumbling=draw.draw_pose(0,24,action="stumble",phase_index=0)
        fallen=draw.draw_pose(0,24,action="fall",phase_index=0)
        self.assertNotEqual(standing.tobytes(),stumbling.tobytes())
        self.assertNotEqual(stumbling.tobytes(),fallen.tobytes())

    def test_getting_up_after_fall_in_both_languages(self):
        story=load("karma_one_story_sequence")
        self.assertEqual([x["action"] for x in story.plan("tombe puis se relève")],
                         ["fall","stand"])
        self.assertEqual([x["action"] for x in story.plan("falls then gets up")],
                         ["fall","stand"])

    def test_fall_ground_contact_keeps_hands_above_floor(self):
        draw=load("karma_one_pose_drawings")
        image=draw.draw_pose(0,24,action="fall",phase_index=0)
        floor=int(image.height*.86)
        skin=(185,135,102)
        pixels=image.load()
        self.assertFalse(any(pixels[x,y]==skin for y in range(floor+1,image.height)
                             for x in range(image.width)))

    def test_fall_is_recognized_and_joint_geometry_transitions(self):
        story=load("karma_one_story_sequence")
        draw=load("karma_one_pose_drawings")
        self.assertEqual([x["action"] for x in story.plan("court puis tombe puis debout")],
                         ["run","fall","stand"])
        start=draw.draw_pose(0,24,action="fall",previous_action="stand",blend=0,phase_index=0)
        middle=draw.draw_pose(0,24,action="fall",previous_action="stand",blend=.5,phase_index=0)
        end=draw.draw_pose(0,24,action="fall",previous_action="stand",blend=1,phase_index=0)
        self.assertNotEqual(start.tobytes(),middle.tobytes())
        self.assertNotEqual(middle.tobytes(),end.tobytes())
        self.assertEqual(start.tobytes(),draw.draw_pose(0,24,action="stand",phase_index=0).tobytes())

    def test_crouch_transition_interpolates_geometry(self):
        draw=load("karma_one_pose_drawings")
        first=draw.draw_pose(0,24,action="crouch",previous_action="stand",blend=0,phase_index=0)
        middle=draw.draw_pose(0,24,action="crouch",previous_action="stand",blend=.5,phase_index=0)
        last=draw.draw_pose(0,24,action="crouch",previous_action="stand",blend=1,phase_index=0)
        self.assertNotEqual(first.tobytes(),middle.tobytes())
        self.assertNotEqual(middle.tobytes(),last.tobytes())
        standing=draw.draw_pose(0,24,action="stand",phase_index=0)
        self.assertEqual(first.tobytes(),standing.tobytes())

    def test_crouch_transition_reverses(self):
        draw=load("karma_one_pose_drawings")
        start=draw.draw_pose(0,24,action="stand",previous_action="crouch",blend=0,phase_index=0)
        end=draw.draw_pose(0,24,action="stand",previous_action="crouch",blend=1,phase_index=0)
        crouch=draw.draw_pose(0,24,action="crouch",phase_index=0)
        standing=draw.draw_pose(0,24,action="stand",phase_index=0)
        self.assertEqual(start.tobytes(),crouch.tobytes())
        self.assertEqual(end.tobytes(),standing.tobytes())

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
