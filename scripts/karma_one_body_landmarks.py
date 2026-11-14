#!/usr/bin/env python3
"""Convert manually annotated 2D body landmarks to stable cartoon proportions.

Input is a JSON object with normalized image points [x,y] for:
left_shoulder,right_shoulder,left_hip,right_hip,left_knee,right_knee,
left_ankle,right_ankle,left_wrist,right_wrist,left_elbow,right_elbow.
These ratios are relative, not medical measurements or 3D reconstruction.
"""
import argparse
import json
import math
from pathlib import Path

REQUIRED = ("left_shoulder","right_shoulder","left_hip","right_hip",
            "left_knee","right_knee","left_ankle","right_ankle",
            "left_elbow","right_elbow","left_wrist","right_wrist")

def distance(a,b):
    return math.dist(a,b)

def midpoint(a,b):
    return [(a[0]+b[0])/2,(a[1]+b[1])/2]

def derive(landmarks):
    for name in REQUIRED:
        if name not in landmarks:
            raise ValueError(f"Missing landmark: {name}")
        point = landmarks[name]
        if len(point)!=2 or not all(isinstance(v,(int,float)) and 0<=v<=1 for v in point):
            raise ValueError(f"Invalid normalized landmark: {name}")
    shoulder=midpoint(landmarks["left_shoulder"],landmarks["right_shoulder"])
    hip=midpoint(landmarks["left_hip"],landmarks["right_hip"])
    torso=distance(shoulder,hip)
    if torso < 0.025:
        raise ValueError("Torso is too short for reliable estimation")
    leg_lengths=[]
    arm_lengths=[]
    for side in ("left","right"):
        leg_lengths.append(distance(landmarks[f"{side}_hip"],landmarks[f"{side}_knee"])+
                           distance(landmarks[f"{side}_knee"],landmarks[f"{side}_ankle"]))
        arm_lengths.append(distance(landmarks[f"{side}_shoulder"],landmarks[f"{side}_elbow"])+
                           distance(landmarks[f"{side}_elbow"],landmarks[f"{side}_wrist"]))
    # Calibrate to renderer default lengths (legs ~100, torso ~105, arms ~85)
    def safe_ratio(value, reference):
        return round(max(0.5,min(1.5,value/reference)),3)
    return {
        "torso_length":1.0,
        "leg_length":safe_ratio(sum(leg_lengths)/2,torso*(100/105)),
        "arm_length":safe_ratio(sum(arm_lengths)/2,torso*(85/105)),
        "head_size":1.0,
    }

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("landmarks",type=Path)
    p.add_argument("output",type=Path)
    a=p.parse_args()
    result=derive(json.loads(a.landmarks.read_text(encoding="utf-8")))
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,indent=2),encoding="utf-8")
    print(json.dumps(result,indent=2))
