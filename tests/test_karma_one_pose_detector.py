import importlib.util
import unittest
from pathlib import Path
from types import SimpleNamespace

p=Path(__file__).resolve().parents[1]/"scripts"/"karma_one_pose_detector.py"
spec=importlib.util.spec_from_file_location("pose_detector",p)
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def points():
    return [SimpleNamespace(x=.5,y=.5,visibility=.95) for _ in range(33)]

class PoseDetectionTests(unittest.TestCase):
    def test_extracts_twelve_joint_names(self):
        found=m.from_pose_landmarks(points())
        self.assertEqual(len(found),12)
        self.assertEqual(found["left_shoulder"],[.5,.5])
    def test_low_visibility_rejected(self):
        pts=points()
        pts[25].visibility=.1
        with self.assertRaisesRegex(ValueError,"left_knee"):
            m.from_pose_landmarks(pts)
    def test_outside_photo_rejected(self):
        pts=points()
        pts[16].x=1.4
        with self.assertRaisesRegex(ValueError,"right_wrist"):
            m.from_pose_landmarks(pts)
    def test_incomplete_pose_rejected(self):
        with self.assertRaisesRegex(ValueError,"fewer than"):
            m.from_pose_landmarks(points()[:15])

if __name__=="__main__":
    unittest.main()
