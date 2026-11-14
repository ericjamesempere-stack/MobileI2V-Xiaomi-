import importlib.util
import unittest
from pathlib import Path

path=Path(__file__).resolve().parents[1]/"scripts"/"karma_one_body_landmarks.py"
spec=importlib.util.spec_from_file_location("landmarks",path)
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def skeleton():
    return {
      "left_shoulder":[.4,.25],"right_shoulder":[.6,.25],
      "left_hip":[.44,.50],"right_hip":[.56,.50],
      "left_knee":[.44,.70],"right_knee":[.56,.70],
      "left_ankle":[.44,.95],"right_ankle":[.56,.95],
      "left_elbow":[.33,.42],"right_elbow":[.67,.42],
      "left_wrist":[.30,.58],"right_wrist":[.70,.58]
    }

class LandmarkTests(unittest.TestCase):
    def test_ratios_within_renderer_bounds(self):
        result=m.derive(skeleton())
        self.assertTrue(all(.5<=v<=1.5 for v in result.values()))
        self.assertGreater(result["leg_length"],1)
    def test_missing_joint_rejected(self):
        data=skeleton()
        del data["left_knee"]
        with self.assertRaisesRegex(ValueError,"Missing landmark"):
            m.derive(data)
    def test_invalid_coordinate_rejected(self):
        data=skeleton()
        data["left_knee"]=[-1,.7]
        with self.assertRaisesRegex(ValueError,"Invalid normalized"):
            m.derive(data)

if __name__=="__main__":
    unittest.main()
