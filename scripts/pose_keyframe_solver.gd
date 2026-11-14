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
