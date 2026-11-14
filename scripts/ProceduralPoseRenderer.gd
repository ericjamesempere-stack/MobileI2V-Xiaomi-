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
        if not ["character", "unknown"].has(str(scene.get("subject_type", ""))):
            return {"ok": false, "error": "demo_only_supports_simple_humanoid"}
        if not ["run", "walk", "jump", "fall", "wave", "dance"].has(str(scene.get("motion_action", ""))):
            return {"ok": false, "error": "unsupported_demo_motion", "scene_id": scene.get("id", "")}
    var generated := 0
    for i in range(scenes.size()):
        var scene: Dictionary = scenes[i]
        var folder := "%s/rendered/scene_%03d" % [root, i]
        if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
            return {"ok": false, "error": "cannot_create_scene_folder"}
        var count := maxi(1, roundi(float(scene.get("duration_seconds", 1.0)) * fps))
        for j in range(count):
            var progress := float(j) / float(maxi(1, count - 1))
            var svg := _pose_svg(str(scene["motion_action"]), progress)
            var image := Image.new()
            if image.load_svg_from_buffer(svg.to_utf8_buffer(), 1.0) != OK:
                return {"ok": false, "error": "svg_render_failed", "scene": i, "frame": j}
            if image.save_png("%s/frame_%06d.png" % [folder, j]) != OK:
                return {"ok": false, "error": "png_write_failed", "scene": i, "frame": j}
            generated += 1
    return {"ok": true, "frames": generated, "mode": "simple_humanoid_procedural_demo", "video_encoded": false}

static func _pose_svg(action: String, t: float) -> String:
    var phase := t * TAU * 2.0
    var stride := sin(phase)
    var swing := cos(phase)
    var torso_angle := 0.0
    var hip_x := 128.0
    var hip_y := 265.0
    var left_arm := -0.35
    var right_arm := 0.35
    var left_leg := -0.25
    var right_leg := 0.25
    match action:
        "run":
            hip_x += t * 50.0
            hip_y += absf(stride) * -10.0
            left_arm = -0.7 * stride
            right_arm = 0.7 * stride
            left_leg = 0.85 * stride
            right_leg = -0.85 * stride
        "walk":
            hip_x += t * 35.0
            left_arm = -0.4 * stride
            right_arm = 0.4 * stride
            left_leg = 0.5 * stride
            right_leg = -0.5 * stride
        "jump":
            hip_y -= 85.0 * sin(PI * t)
            left_arm = -0.6
            right_arm = 0.6
            left_leg = -0.2 + 0.35 * sin(PI * t)
            right_leg = 0.2 - 0.35 * sin(PI * t)
        "fall":
            torso_angle = t * 1.35
            hip_y += 80.0 * t
            hip_x += 30.0 * t
            left_arm = -0.7 * t
            right_arm = 0.7 * t
        "wave":
            right_arm = 2.3 + 0.35 * swing
            left_arm = -0.25
        "dance":
            hip_x += 24.0 * stride
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
    var lines := ""
    for endpoints in [[shoulder, hip], [shoulder, left_hand], [shoulder, right_hand], [hip, left_foot], [hip, right_foot]]:
        var a: Vector2 = endpoints[0]
        var b: Vector2 = endpoints[1]
        lines += '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#172f52" stroke-width="11" stroke-linecap="round"/>' % [a.x, a.y, b.x, b.y]
    return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="448" viewBox="0 0 256 448"><rect width="256" height="448" fill="#f5f3ed"/><path d="M0 365H256" stroke="#b5b8bc" stroke-width="3"/>' + lines + '<circle cx="%.2f" cy="%.2f" r="23" fill="#edbc91" stroke="#172f52" stroke-width="4"/></svg>' % [head.x, head.y]
