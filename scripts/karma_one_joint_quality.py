#!/usr/bin/env python3
"""Inspect consecutive articulated 2D joint samples before video assembly."""
import math

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
    return {"checked_frames":len(samples),"max_joint_step_px":round(maximum,2),
            "max_allowed_step_px":max_step,"jump_count":len(jumps),"jumps":jumps[:100]}
