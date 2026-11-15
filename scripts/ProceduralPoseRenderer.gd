extends RefCounted
class_name ProceduralPoseRenderer

# Offline 2D proof of concept. Renders new articulated stick-figure poses,
# NOT a model-generated character and NOT a user's face.
static func render(project: Dictionary, root: String, fps: int = 12) -> Dictionary:
    if not root.begins_with("user://") or fps < 1 or fps > 30:
        return {"ok": false, "error": "invalid_parameters"}
    var scenes: Array = project.get("scenes", [])
    if scenes.is_empty():
        return {"ok": false, "error": "no_scenes"}
    for scene in scenes:
        var kind := str(scene.get("subject_type", ""))
        if not ["character", "unknown", "animal", "vehicle"].has(kind):
            return {"ok": false, "error": "unsupported_demo_subject", "subject_type": kind}
        var allowed := ["run", "walk", "jump", "fall", "wave", "dance"] if kind == "character" or kind == "unknown" else ["run", "walk", "jump", "fall", "dance"] if kind == "animal" else ["travel", "fly", "jump", "fall", "land", "stop"]
        if not allowed.has(str(scene.get("motion_action", ""))):
            return {"ok": false, "error": "unsupported_demo_motion", "scene_id": scene.get("id", "")}
    var continuity := MotionContinuityPlanner.timeline(project, fps)
    if not continuity.get("ok", false):
        return {"ok": false, "error": continuity.get("error", "continuity_failed")}
    var states: Array = continuity["frames"]
    var generated := 0
    for i in range(scenes.size()):
        var scene: Dictionary = scenes[i]
        var folder := "%s/rendered/scene_%03d" % [root, i]
        if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
            return {"ok": false, "error": "cannot_create_scene_folder"}
        var count := maxi(1, roundi(float(scene.get("duration_seconds", 1.0)) * fps))
        for j in range(count):
            var progress := float(j) / float(maxi(1, count - 1))
            var kind := str(scene.get("subject_type", ""))
            var motion_state: Dictionary = states[generated]
            var svg := _pose_svg(str(scene["motion_action"]), progress, motion_state) if kind == "character" or kind == "unknown" else SubjectPoseLibrary.render_svg(kind, str(scene["motion_action"]), progress)
            var image := Image.new()
            if image.load_svg_from_buffer(svg.to_utf8_buffer(), 1.0) != OK:
                return {"ok": false, "error": "svg_render_failed", "scene": i, "frame": j}
            if image.save_png("%s/frame_%06d.png" % [folder, j]) != OK:
                return {"ok": false, "error": "png_write_failed", "scene": i, "frame": j}
            generated += 1
    return {"ok": true, "frames": generated, "mode": "offline_procedural_subject_demo", "video_encoded": false}

static func _pose_svg(action: String, t: float, state: Dictionary = {}) -> String:
    var phase := float(state.get("phase", t * TAU * 2.0))
    var stride := sin(phase)
    var swing := cos(phase)
    var torso_angle := 0.0
    var world_x := float(state.get("x", 0.0))
    var camera_x := maxf(0.0, world_x - 55.0)
    var hip_x := 128.0 + world_x - camera_x
    var hip_y := 265.0 + float(state.get("y", 0.0)) - float(state.get("altitude", 0.0))
    var left_arm := -0.35
    var right_arm := 0.35
    var left_leg := -0.25
    var right_leg := 0.25
    match action:
        "run":
            if state.is_empty(): hip_x += t * 50.0
            hip_y += absf(stride) * -10.0
            left_arm = -0.7 * stride
            right_arm = 0.7 * stride
            left_leg = 0.85 * stride
            right_leg = -0.85 * stride
        "walk":
            if state.is_empty(): hip_x += t * 35.0
            left_arm = -0.4 * stride
            right_arm = 0.4 * stride
            left_leg = 0.5 * stride
            right_leg = -0.5 * stride
        "jump":
            if state.is_empty(): hip_y -= 85.0 * sin(PI * t)
            left_arm = -0.6
            right_arm = 0.6
            left_leg = -0.2 + 0.35 * sin(PI * t)
            right_leg = 0.2 - 0.35 * sin(PI * t)
        "fall":
            torso_angle = t * 1.35
            if state.is_empty():
                hip_y += 80.0 * t
                hip_x += 30.0 * t
            left_arm = -0.7 * t
            right_arm = 0.7 * t
        "wave":
            right_arm = 2.3 + 0.35 * swing
            left_arm = -0.25
        "dance":
            if state.is_empty(): hip_x += 24.0 * stride
            hip_y -= 9.0 * absf(swing)
            left_arm = -0.8 * swing
            right_arm = 0.8 * swing
            left_leg = 0.5 * stride
            right_leg = -0.5 * stride
    var shoulder := Vector2(hip_x + sin(torso_angle) * 82.0, hip_y - cos(torso_angle) * 82.0)
    var hip := Vector2(hip_x, hip_y)
    var head := shoulder + Vector2(sin(torso_angle) * 22.0, -cos(torso_angle) * 22.0)
    var left_hand := shoulder + Vector2(-sin(left_arm + 0.4) * 65.0 - 15.0, cos(left_arm + 0.4) * 65.0)
    var right_hand := shoulder + Vector2(sin(right_arm + 0.4) * 65.0 + 15.0, cos(right_arm + 0.4) * 65.0)
    var left_foot := hip + Vector2(-15.0 + sin(left_leg) * 75.0, cos(left_leg) * 85.0)
    var right_foot := hip + Vector2(15.0 + sin(right_leg) * 75.0, cos(right_leg) * 85.0)
    # Filled costume and articulated limbs, not the old five-line stick figure.
    var outline := "#18263c"
    var art := ""
    for endpoints in [[hip + Vector2(-10, 0), left_foot], [hip + Vector2(10, 0), right_foot]]:
        var a: Vector2 = endpoints[0]
        var b: Vector2 = endpoints[1]
        art += '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="23" stroke-linecap="round"/>' % [a.x, a.y, b.x, b.y, outline]
        art += '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#293e61" stroke-width="18" stroke-linecap="round"/>' % [a.x, a.y, b.x, b.y]
        art += '<ellipse cx="%.2f" cy="%.2f" rx="18" ry="9" fill="#202a3a"/>' % [b.x, b.y + 4.0]
    for endpoints in [[shoulder + Vector2(-12, 8), left_hand], [shoulder + Vector2(12, 8), right_hand]]:
        var a: Vector2 = endpoints[0]
        var b: Vector2 = endpoints[1]
        art += '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="20" stroke-linecap="round"/>' % [a.x, a.y, b.x, b.y, outline]
        art += '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#db554a" stroke-width="15" stroke-linecap="round"/>' % [a.x, a.y, b.x, b.y]
        art += '<circle cx="%.2f" cy="%.2f" r="10" fill="#e9b78e" stroke="%s" stroke-width="2"/>' % [b.x, b.y, outline]
    art += '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="43" stroke-linecap="round"/>' % [shoulder.x, shoulder.y + 14.0, hip.x, hip.y - 8.0, outline]
    art += '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#e76b55" stroke-width="36" stroke-linecap="round"/>' % [shoulder.x, shoulder.y + 14.0, hip.x, hip.y - 8.0]
    art += '<circle cx="%.2f" cy="%.2f" r="24" fill="#edbc91" stroke="%s" stroke-width="3"/>' % [head.x, head.y, outline]
    art += '<path d="M%.2f %.2f Q%.2f %.2f %.2f %.2f" fill="none" stroke="%s" stroke-width="9" stroke-linecap="round"/>' % [head.x - 19.0, head.y - 10.0, head.x, head.y - 38.0, head.x + 19.0, head.y - 11.0, outline]
    art += '<circle cx="%.2f" cy="%.2f" r="2.5" fill="%s"/><circle cx="%.2f" cy="%.2f" r="2.5" fill="%s"/>' % [head.x - 8.0, head.y, outline, head.x + 8.0, head.y, outline]
    art += '<path d="M%.2f %.2f Q%.2f %.2f %.2f %.2f" fill="none" stroke="%s" stroke-width="2"/>' % [head.x - 7.0, head.y + 10.0, head.x, head.y + 15.0, head.x + 7.0, head.y + 10.0, outline]
    var ground := '<path d="M0 365H256" stroke="#c1cad5" stroke-width="3"/>'
    for marker in range(-1, 7):
        var mark_x := float(marker) * 60.0 - fmod(camera_x, 60.0)
        ground += '<path d="M%.2f 366v12" stroke="#a1adbf" stroke-width="2"/>' % mark_x
    return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="448" viewBox="0 0 256 448"><rect width="256" height="448" fill="#e9edf3"/>' + ground + art + '</svg>'
