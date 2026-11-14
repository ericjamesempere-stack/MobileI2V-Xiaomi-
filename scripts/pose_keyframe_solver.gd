extends RefCounted
# Generic 2D pose-keyframe sequencer for arbitrary action names.
# Caller supplies real or artist-approved 33-point landmarks. No model inference.
const Rig = preload("res://scripts/continuous_rig.gd")

func generate(keyframes: Array, frame_count: int = 60) -> Dictionary:
    if keyframes.size() < 2 or frame_count < 2 or frame_count > 9000:
        return {"ok": false, "error": "Need at least two keyframes and 2-9000 frames"}
    var rig: RefCounted = Rig.new()
    var ordered: Array = keyframes.duplicate(true)
    ordered.sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))
    var previous_time: float = -1.0
    for item in ordered:
        if not item is Dictionary:
            return {"ok": false, "error": "Invalid keyframe"}
        var time: float = float(item.get("time", -1.0))
        if time < 0.0 or time > 1.0 or time <= previous_time:
            return {"ok": false, "error": "Keyframe times must be unique and ordered within 0..1"}
        var check: Dictionary = rig.validate_landmarks(item.get("pose", []))
        if not bool(check.get("ok", false)):
            return {"ok": false, "error": "Invalid keyframe pose: " + str(check.get("error", ""))}
        previous_time = time
    if float(ordered[0]["time"]) > 0.0 or float(ordered[-1]["time"]) < 1.0:
        return {"ok": false, "error": "Keyframes must cover time 0 and 1"}
    var frames: Array = []
    var segment: int = 0
    for frame_id in range(frame_count):
        var t: float = float(frame_id) / float(frame_count - 1)
        while segment + 2 < ordered.size() and t > float(ordered[segment + 1]["time"]):
            segment += 1
        var a: Dictionary = ordered[segment]
        var z: Dictionary = ordered[segment + 1]
        var span: float = float(z["time"]) - float(a["time"])
        var fraction: float = clampf((t - float(a["time"])) / span, 0.0, 1.0)
        frames.append(rig.interpolate_pose(a["pose"], z["pose"], fraction))
    return {"ok": true, "frames": frames, "count": frames.size(),
        "status": "articulated_keyframe_interpolation",
        "limitations": ["requires supplied poses", "no automatic action understanding",
            "no inverse kinematics, collision or physics"]}

# Check 2D bone lengths between adjacent poses. This flags implausible
# stretching before artwork is warped, without claiming full-body physics.
func validate_bone_lengths(frames: Array, max_relative_change: float = 0.20) -> Dictionary:
    if frames.size() < 2:
        return {"ok": false, "error": "At least two poses required"}
    var rig: RefCounted = Rig.new()
    var violations: Array = []
    var baseline: Dictionary = {}
    for frame_id in range(frames.size()):
        var pose: Array = frames[frame_id]
        var check: Dictionary = rig.validate_landmarks(pose)
        if not bool(check.get("ok", false)):
            return {"ok": false, "error": "Invalid pose at frame %d" % frame_id}
        for bone in rig.BONES:
            var a: Dictionary = pose[bone[0]]
            var z: Dictionary = pose[bone[1]]
            var dx: float = float(a["x"]) - float(z["x"])
            var dy: float = float(a["y"]) - float(z["y"])
            var length: float = sqrt(dx * dx + dy * dy)
            var key: String = "%d_%d" % [bone[0], bone[1]]
            if not baseline.has(key):
                baseline[key] = length
            elif float(baseline[key]) > 0.001:
                var relative_change: float = absf(length - float(baseline[key])) / float(baseline[key])
                if relative_change > max_relative_change:
                    violations.append({"frame": frame_id, "bone": key, "change": relative_change})
    return {"ok": violations.is_empty(), "violations": violations,
        "status": "bone_length_checked",
        "limitations": ["2D projection can change apparent bone length",
            "does not enforce collisions, joint angles or dynamics"]}

# Turn approved keyframes into painted RGBA frames for the existing MP4 encoder.
# This is a usable bridge, not a text-to-motion generator.
func render_artwork_sequence(artwork: Image, source_pose: Array, keyframes: Array,
        frame_count: int = 60, limb_half_width: float = 9.0) -> Dictionary:
    var plan: Dictionary = generate(keyframes, frame_count)
    if not bool(plan.get("ok", false)):
        return plan
    var painter: RefCounted = load("res://scripts/painted_limb_warp.gd").new()
    var rendered: Array = []
    for pose in plan["frames"]:
        var result: Dictionary = painter.render_composite_preview(artwork, source_pose, pose, limb_half_width)
        if not bool(result.get("ok", false)):
            return {"ok": false, "error": "Character render failed at frame %d: %s" %
                [rendered.size(), str(result.get("error", "unknown"))]}
        rendered.append(result["image"])
    return {"ok": true, "frames": rendered, "count": rendered.size(),
        "status": "articulated_artwork_frames",
        "limitations": ["requires transparent artwork and approved source/keyframe poses",
            "not automatic photo segmentation or free-text motion generation"]}

# Detect implausible single-frame joint teleportation in normalized coordinates.
# This is a conservative diagnostic, not a physics solver.
func validate_joint_velocity(frames: Array, max_step: float = 0.15) -> Dictionary:
    if frames.size() < 2 or max_step <= 0.0:
        return {"ok": false, "error": "Invalid sequence or velocity threshold"}
    var rig: RefCounted = Rig.new()
    var violations: Array = []
    for i in range(frames.size()):
        var check: Dictionary = rig.validate_landmarks(frames[i])
        if not bool(check.get("ok", false)):
            return {"ok": false, "error": "Invalid pose at frame %d" % i}
        if i == 0:
            continue
        for joint in rig.REQUIRED:
            var previous: Dictionary = frames[i - 1][joint]
            var current: Dictionary = frames[i][joint]
            var dx: float = float(current["x"]) - float(previous["x"])
            var dy: float = float(current["y"]) - float(previous["y"])
            var distance: float = sqrt(dx * dx + dy * dy)
            if distance > max_step:
                violations.append({"frame": i, "joint": joint, "step": distance})
    return {"ok": violations.is_empty(), "violations": violations,
        "status": "joint_velocity_checked",
        "limitations": ["threshold is in normalized image coordinates per frame",
            "does not distinguish fast intentional motion from tracking errors"]}

# Repair isolated joint-tracking spikes by replacing the bad sample with the
# midpoint of its two neighbors. Deliberate sustained fast motion is retained.
# Original frames are never mutated; every repair is reported.
func repair_isolated_spikes(frames: Array, max_step: float = 0.15,
        neighbor_tolerance: float = 0.05) -> Dictionary:
    if frames.size() < 3 or max_step <= 0.0 or neighbor_tolerance < 0.0:
        return {"ok": false, "error": "Need 3+ frames and valid thresholds"}
    var rig: RefCounted = Rig.new()
    for i in range(frames.size()):
        var check: Dictionary = rig.validate_landmarks(frames[i])
        if not bool(check.get("ok", false)):
            return {"ok": false, "error": "Invalid pose at frame %d" % i}
    var output: Array = frames.duplicate(true)
    var repairs: Array = []
    for i in range(1, frames.size() - 1):
        for joint in rig.REQUIRED:
            var a: Dictionary = frames[i - 1][joint]
            var p: Dictionary = frames[i][joint]
            var z: Dictionary = frames[i + 1][joint]
            var va := Vector2(float(a["x"]), float(a["y"]))
            var vp := Vector2(float(p["x"]), float(p["y"]))
            var vz := Vector2(float(z["x"]), float(z["y"]))
            if vp.distance_to(va) > max_step and vp.distance_to(vz) > max_step and va.distance_to(vz) <= neighbor_tolerance:
                var midpoint: Vector2 = va.lerp(vz, 0.5)
                output[i][joint]["x"] = midpoint.x
                output[i][joint]["y"] = midpoint.y
                repairs.append({"frame": i, "joint": joint, "type": "isolated_spike"})
    return {"ok": true, "frames": output, "repairs": repairs,
        "repair_count": repairs.size(), "status": "isolated_spikes_repaired",
        "limitations": ["only isolated spikes, not arbitrary bad motion",
            "no biomechanical constraints or full-body physics"]}
