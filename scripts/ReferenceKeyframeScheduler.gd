extends RefCounted
class_name ReferenceKeyframeScheduler

# Reduces expensive image generation to selected key poses, while preserving
# the full per-frame motion plan. Interpolation is a separate future stage.
static func schedule(plan: Dictionary, interval: int = 6) -> Dictionary:
    if not plan.get("ok", false) or interval < 1 or interval > 120:
        return {"ok": false, "error": "invalid_schedule"}
    var frames: Array = plan.get("frames", [])
    if frames.is_empty():
        return {"ok": false, "error": "empty_plan"}
    var keys: Array = []
    var selected: Dictionary = {}
    for i in range(frames.size()):
        var current: Dictionary = frames[i]
        var scene_start := i == 0 or int(current.get("scene_index", -1)) != int(frames[i - 1].get("scene_index", -1))
        var scene_end := i == frames.size() - 1 or int(current.get("scene_index", -1)) != int(frames[i + 1].get("scene_index", -1))
        if scene_start or scene_end or i % interval == 0:
            selected[i] = true
    var indices := selected.keys()
    indices.sort()
    for index in indices:
        var i := int(index)
        var frame: Dictionary = frames[i]
        keys.append({
            "frame_index": i,
            "scene_index": frame.get("scene_index", -1),
            "reference_original": frame.get("reference_original", ""),
            "reference_styled": frame.get("reference_styled", ""),
            "style": frame.get("style", ""),
            "description": frame.get("description", ""),
            "action": frame.get("action", ""),
            "action_progress": frame.get("action_progress", 0.0),
            "position": frame.get("position", {}),
            "pose_phase": frame.get("pose_phase", 0.0),
            "constraints": {
                "identity": frame.get("preserve_identity", true),
                "clothing": frame.get("preserve_clothing", true),
                "objects": frame.get("preserve_scene_objects", true),
                "background": frame.get("preserve_background_layout", true)
            },
            "generation_status": "pending"
        })
    return {
        "ok": true,
        "total_frames": frames.size(),
        "keyframe_count": keys.size(),
        "keyframes": keys,
        "interpolation_status": "not_implemented",
        "image_generation_status": "not_connected"
    }

static func save(schedule_data: Dictionary, path: String) -> Dictionary:
    if not schedule_data.get("ok", false) or not path.begins_with("user://"):
        return {"ok": false, "error": "invalid_schedule_or_path"}
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "error": "cannot_save_schedule"}
    file.store_string(JSON.stringify(schedule_data, "  "))
    file.close()
    return {"ok": true, "path": path, "keyframes": schedule_data["keyframe_count"]}
