extends RefCounted
class_name ReferenceKeyframePlan

# A model-agnostic generation contract. Does not claim to generate images.
# Each frame has the same identity, style, scene and reference constraints.
static func build(project: Dictionary, fps: int = 12) -> Dictionary:
    var reference := str(project.get("styled_reference_path", ""))
    var profile_path := str(project.get("scene_reference_profile", ""))
    if reference.is_empty() or not FileAccess.file_exists(reference):
        return {"ok": false, "error": "styled_reference_missing"}
    if profile_path.is_empty() or not FileAccess.file_exists(profile_path):
        return {"ok": false, "error": "scene_profile_missing"}
    var profile_file := FileAccess.open(profile_path, FileAccess.READ)
    if profile_file == null:
        return {"ok": false, "error": "profile_unreadable"}
    var parsed = JSON.parse_string(profile_file.get_as_text())
    if not parsed is Dictionary:
        return {"ok": false, "error": "invalid_profile"}
    var profile: Dictionary = parsed
    var trajectory := MotionContinuityPlanner.timeline(project, fps)
    if not trajectory.get("ok", false):
        return trajectory
    var original := str(profile.get("reference_image", ""))
    if not FileAccess.file_exists(original):
        return {"ok": false, "error": "original_reference_missing"}
    var frames: Array = []
    var scenes: Array = project.get("scenes", [])
    for state in trajectory["frames"]:
        var scene_index := int(state["scene"])
        var scene: Dictionary = scenes[scene_index]
        frames.append({
            "frame_index": frames.size(),
            "scene_index": scene_index,
            "action": state["action"],
            "action_progress": state["progress"],
            "position": {"x": state["x"], "y": state["y"], "altitude": state["altitude"]},
            "pose_phase": state["phase"],
            "reference_original": original,
            "reference_styled": reference,
            "style": str(project.get("style", "cartoon")),
            "description": str(scene.get("description", "")),
            "preserve_identity": true,
            "preserve_clothing": true,
            "preserve_scene_objects": true,
            "preserve_background_layout": true,
            "generation_status": "awaiting_image_generation"
        })
    return {
        "ok": true,
        "fps": fps,
        "frames": frames,
        "reference_profile": profile_path,
        "image_generation_available": false,
        "model_required": true
    }

static func save(plan: Dictionary, path: String) -> Dictionary:
    if not plan.get("ok", false) or not path.begins_with("user://"):
        return {"ok": false, "error": "invalid_plan_or_path"}
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "error": "cannot_write_plan"}
    file.store_string(JSON.stringify(plan, "  "))
    file.close()
    return {"ok": true, "path": path, "frames": plan["frames"].size()}
