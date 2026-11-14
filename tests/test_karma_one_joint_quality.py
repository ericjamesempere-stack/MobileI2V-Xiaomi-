import importlib.util
import unittest
from pathlib import Path
p=Path(__file__).resolve().parents[1]/"scripts"/"karma_one_joint_quality.py"
spec=importlib.util.spec_from_file_location("joint_quality",p)
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def frame(offset=0):
    return {name:(x+offset,y) for name,x,y in
            [("hip",10,20),("shoulder",10,10),("head",10,0),
             ("left_foot",0,30),("right_foot",20,30),
             ("left_knee",4,25),("right_knee",16,25),
             ("left_elbow",2,14),("right_elbow",18,14),
             ("left_hand",0,19),("right_hand",20,19)]}

class JointQualityTests(unittest.TestCase):
    def test_anatomy_reports_floor_penetration(self):
        joints=frame()
        joints["left_foot"]=(0,440)
        report=m.inspect([joints])
        self.assertEqual(report["jump_count"],0)
        self.assertTrue(any(w["issue"]=="floor_penetration"
                            for w in report["anatomy_warnings"]))

    def test_anatomy_reports_collapsed_segment(self):
        joints=frame()
        joints["left_knee"]=joints["hip"]
        report=m.inspect([joints])
        self.assertTrue(any(w["issue"]=="collapsed_leg_segment"
                            for w in report["anatomy_warnings"]))

    def test_smooth_sequence(self):
        report=m.inspect([frame(0),frame(2),frame(4)],max_step=5)
        self.assertEqual(report["jump_count"],0)
        self.assertEqual(report["max_joint_step_px"],2)
    def test_jump_detected(self):
        report=m.inspect([frame(0),frame(80)],max_step=65)
        self.assertEqual(report["jump_count"],11)
    def test_missing_joint_rejected(self):
        bad=frame()
        del bad["head"]
        with self.assertRaisesRegex(ValueError,"Missing joints"):
            m.inspect([bad])

if __name__=="__main__":
    unittest.main()
