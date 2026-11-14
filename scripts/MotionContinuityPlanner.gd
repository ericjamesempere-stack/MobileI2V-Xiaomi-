extends RefCounted
class_name MotionContinuityPlanner

# Frame-by-frame motion state, shared across scenes. The final position
# of one scene is the starting position of the next.
static func timeline(project: Dictionary, fps: int = 12) -> Dictionary:
    if fps < 1 or fps > 60:
        return {"ok": false, "error": "invalid_fps"}
    var scenes: Array = project.get("scenes", [])
    if scenes.is_empty():
        return {"ok": false, "error": "empty_story"}
    var position := Vector2.ZERO
    var altitude := 0.0
    var frame_states: Array = []
    var scene_ranges: Array = []
    for i in range(scenes.size()):
        var scene: Dictionary = scenes[i]
        var action := str(scene.get("motion_action", "unsupported"))
        if action == "unsupported":
            return {"ok": false, "error": "unsupported_action", "scene": i}
        var count := maxi(1, roundi(float(scene.get("duration_seconds", 1.0)) * fps))
        var start := position
        var start_altitude := altitude
        var target := position
        match action:
            "walk": target.x += 45.0
            "run": target.x += 110.0
            "travel", "fly": target.x += 150.0
            "fall": target.x += 24.0
            "jump": target.x += 35.0
            "dance": pass
            "wave": pass
            "land": pass
            "stop": pass
        var first_frame := frame_states.size()
        for j in range(count):
            var t := float(j) / float(maxi(1, count - 1))
            var ease := t * t * (3.0 - 2.0 * t)
            var x := lerpf(start.x, target.x, ease)
            var y := lerpf(start.y, target.y, ease)
            var z := lerpf(start_altitude, 0.0, ease)
            var phase := t * TAU * (3.0 if action == "run" else 1.0)
            match action:
                "jump": z += 70.0 * sin(PI * t)
                "fly": z += 60.0 * sin(PI * t)
                "fall": y += 65.0 * ease
                "dance": x += 16.0 * sin(phase * 2.0)
                "walk", "run": z += 5.0 * absf(sin(phase))
            frame_states.append({
                "scene": i, "frame": j, "action": action,
                "x": x, "y": y, "altitude": z,
                "phase": phase, "progress": t
            })
        position = target
        if action == "fall":
            position.y += 65.0
        scene_ranges.append({"scene": i, "start": first_frame, "end": frame_states.size() - 1})
    return {"ok": true, "frames": frame_states, "scene_ranges": scene_ranges, "fps": fps}
