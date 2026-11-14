#!/usr/bin/env python3
"""Inspect consecutive articulated 2D joint samples before video assembly."""
import math

def anatomy_report(samples, floor=412, tolerance=12):
    """Diagnostic only: report suspect floor penetration and joint bending.

    Procedural cartoon limbs are not constrained by a biomechanical solver.
    Do not treat these warnings as a medical or physical validity verdict.
    """
    warnings=[]
    for i, joints in enumerate(samples):
        for side in ("left", "right"):
            foot=joints[side+"_foot"]
            if foot[1] > floor+tolerance:
                warnings.append({"frame":i,"joint":side+"_foot",
                                 "issue":"floor_penetration","pixels":foot[1]-floor})
            knee=joints[side+"_knee"]
            hip=joints["hip"]
            upper=math.dist(hip,knee)
            lower=math.dist(knee,foot)
            if upper < 5 or lower < 5:
                warnings.append({"frame":i,"joint":side+"_knee",
                                 "issue":"collapsed_leg_segment"})
            elbow=joints[side+"_elbow"]
            hand=joints[side+"_hand"]
            if math.dist(joints["shoulder"],elbow)<5 or math.dist(elbow,hand)<5:
                warnings.append({"frame":i,"joint":side+"_elbow",
                                 "issue":"collapsed_arm_segment"})
    return {"anatomy_warning_count":len(warnings),
            "anatomy_warnings":warnings[:100]}

def inspect(samples, max_step=65.0):
    if max_step <= 0:
        raise ValueError("max_step must be positive")
    if not samples:
        raise ValueError("No joint samples")
    required={"hip","shoulder","head","left_foot","right_foot",
              "left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"}
    for i, sample in enumerate(samples):
        if not required.issubset(sample):
            raise ValueError(f"Missing joints in frame {i}: {sorted(required-set(sample))}")
        for name in required:
            xy=sample[name]
            if len(xy)!=2 or not all(math.isfinite(float(v)) for v in xy):
                raise ValueError(f"Invalid joint {name} at frame {i}")
    jumps=[]
    maximum=0.0
    for i in range(1,len(samples)):
        for name in sorted(required):
            step=math.dist(samples[i-1][name],samples[i][name])
            maximum=max(maximum,step)
            if step>max_step:
                jumps.append({"frame":i,"joint":name,"pixels":round(step,2)})
    anatomy=anatomy_report(samples)
    return {"checked_frames":len(samples),**anatomy,"max_joint_step_px":round(maximum,2),
            "max_allowed_step_px":max_step,"jump_count":len(jumps),"jumps":jumps[:100]}
