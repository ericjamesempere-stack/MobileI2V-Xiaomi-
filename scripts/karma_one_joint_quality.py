#!/usr/bin/env python3
"""Inspect consecutive articulated 2D joint samples before video assembly."""
import math

def joint_angle(a, pivot, b):
    """Interior angle in degrees, 0 folded and 180 straight."""
    ax,ay=float(a[0])-float(pivot[0]),float(a[1])-float(pivot[1])
    bx,by=float(b[0])-float(pivot[0]),float(b[1])-float(pivot[1])
    la=math.hypot(ax,ay)
    lb=math.hypot(bx,by)
    if min(la,lb)<1e-8:
        return None
    cosine=max(-1.0,min(1.0,(ax*bx+ay*by)/(la*lb)))
    return math.degrees(math.acos(cosine))

def tracked_angles(joints):
    result={}
    for side in ("left","right"):
        result[side+"_knee"]=joint_angle(joints["hip"],joints[side+"_knee"],joints[side+"_foot"])
        result[side+"_elbow"]=joint_angle(joints["shoulder"],joints[side+"_elbow"],joints[side+"_hand"])
    return result

def angle_motion_report(samples, max_angle_step=65.0):
    if max_angle_step<=0:
        raise ValueError("max_angle_step must be positive")
    angles=[tracked_angles(sample) for sample in samples]
    warnings=[]
    maximum=0.0
    for frame in range(1,len(angles)):
        for name in sorted(angles[frame]):
            before,after=angles[frame-1][name],angles[frame][name]
            if before is None or after is None:
                continue
            delta=abs(after-before)
            maximum=max(maximum,delta)
            if delta>max_angle_step:
                warnings.append({"frame":frame,"joint":name,
                                 "issue":"abrupt_joint_rotation","degrees":round(delta,1)})
    return {"max_angle_change_deg":round(maximum,1),
            "max_allowed_angle_change_deg":max_angle_step,
            "angle_warning_count":len(warnings),
            "angle_warnings":warnings[:100]}

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
            knee_angle=joint_angle(hip,knee,foot)
            if knee_angle is not None and knee_angle < 15:
                warnings.append({"frame":i,"joint":side+"_knee",
                                 "issue":"extreme_knee_flexion",
                                 "degrees":round(knee_angle,1)})
            elbow=joints[side+"_elbow"]
            hand=joints[side+"_hand"]
            if math.dist(joints["shoulder"],elbow)<5 or math.dist(elbow,hand)<5:
                warnings.append({"frame":i,"joint":side+"_elbow",
                                 "issue":"collapsed_arm_segment"})
            elbow_angle=joint_angle(joints["shoulder"],elbow,hand)
            if elbow_angle is not None and elbow_angle < 15:
                warnings.append({"frame":i,"joint":side+"_elbow",
                                 "issue":"extreme_elbow_flexion",
                                 "degrees":round(elbow_angle,1)})
    return {"anatomy_warning_count":len(warnings),
            "anatomy_warnings":warnings[:100]}

def trajectory_report(samples, max_acceleration=45.0):
    """Flag sudden changes in hand/foot velocity (pixels per frame squared)."""
    if max_acceleration<=0:
        raise ValueError("max_acceleration must be positive")
    tracked=("left_hand","right_hand","left_foot","right_foot")
    warnings=[]
    maximum=0.0
    for i in range(2,len(samples)):
        for name in tracked:
            before,current,after=(samples[i-2][name],samples[i-1][name],samples[i][name])
            ax=float(after[0])-2*float(current[0])+float(before[0])
            ay=float(after[1])-2*float(current[1])+float(before[1])
            acceleration=math.hypot(ax,ay)
            maximum=max(maximum,acceleration)
            if acceleration>max_acceleration:
                warnings.append({"frame":i,"joint":name,
                                 "issue":"abrupt_trajectory_acceleration",
                                 "pixels_per_frame_squared":round(acceleration,2)})
    return {"max_extremity_acceleration":round(maximum,2),
            "max_allowed_extremity_acceleration":max_acceleration,
            "trajectory_warning_count":len(warnings),
            "trajectory_warnings":warnings[:100]}

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
    angles=angle_motion_report(samples)
    trajectories=trajectory_report(samples)
    return {"checked_frames":len(samples),**anatomy,**angles,**trajectories,"max_joint_step_px":round(maximum,2),
            "max_allowed_step_px":max_step,"jump_count":len(jumps),"jumps":jumps[:100]}
