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
    var scene_starts: Dictionary = {}
    var scene_ends: Dictionary = {}
    for i in range(frames.size()):
        var current: Dictionary = frames[i]
        var scene_id := int(current.get("scene_index", -1))
        if not scene_starts.has(scene_id):
            scene_starts[scene_id] = i
        scene_ends[scene_id] = i
        if i % interval == 0:
            selected[i] = true
    # Always retain boundaries AND the semantic movement beats within scenes.
    # A fall needs upright/imbalance/descent/impact, not just regular samples.
    for scene_id in scene_starts.keys():
        var start := int(scene_starts[scene_id])
        var finish := int(scene_ends[scene_id])
        selected[start] = true
        selected[finish] = true
        var action := str(frames[start].get("action", ""))
        var beats := StoryActionPlanner.beats_for(action)
        if beats.size() > 0:
            for beat_index in range(beats.size()):
                var frame_index := start + roundi(float(finish - start) * float(beat_index) / float(maxi(1, beats.size() - 1)))
                selected[frame_index] = true
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
            "motion_beat": _beat_at(frame),
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

# The beat label is an instruction to a future pose generator, not a drawn pose.
static func _beat_at(frame: Dictionary) -> String:
    var beats := StoryActionPlanner.beats_for(str(frame.get("action", "")))
    if beats.is_empty():
        return "unknown"
    var t := clampf(float(frame.get("action_progress", 0.0)), 0.0, 1.0)
    var index := mini(beats.size() - 1, int(floor(t * float(beats.size()))))
    return str(beats[index])
