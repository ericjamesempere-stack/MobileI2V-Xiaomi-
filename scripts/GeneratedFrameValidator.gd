extends RefCounted
class_name GeneratedFrameValidator

# Validates model output before admitting it to a storyboard.
# Pixel differences alone do NOT prove pose correctness or identity.
static func inspect(plan: Dictionary, frame_paths: Array[String]) -> Dictionary:
    if not plan.get("ok", false):
        return {"ok": false, "error": "invalid_plan"}
    var instructions: Array = plan.get("frames", [])
    if instructions.is_empty() or frame_paths.size() != instructions.size():
        return {"ok": false, "error": "frame_count_mismatch", "expected": instructions.size(), "actual": frame_paths.size()}
    var expected_size := Vector2i.ZERO
    var previous_hash := ""
    var identical_adjacent := 0
    var scene_breaks: Array = []
    var last_scene := -1
    for i in range(frame_paths.size()):
        var path := frame_paths[i]
        if not path.begins_with("user://") or not FileAccess.file_exists(path):
            return {"ok": false, "error": "missing_generated_frame", "index": i}
        var img := Image.new()
        if img.load(path) != OK or img.is_empty():
            return {"ok": false, "error": "unreadable_generated_frame", "index": i}
        if expected_size == Vector2i.ZERO:
            expected_size = img.get_size()
        elif img.get_size() != expected_size:
            return {"ok": false, "error": "inconsistent_dimensions", "index": i}
        var current_hash := FileAccess.get_sha256(path)
        if current_hash == previous_hash:
            identical_adjacent += 1
        previous_hash = current_hash
        var scene := int(instructions[i].get("scene_index", -1))
        if scene != last_scene:
            scene_breaks.append(i)
            last_scene = scene
    if identical_adjacent > 0:
        return {"ok": false, "error": "duplicate_adjacent_frames", "duplicates": identical_adjacent}
    return {
        "ok": true, "frames": frame_paths.size(),
        "width": expected_size.x, "height": expected_size.y,
        "scene_starts": scene_breaks,
        "identity_verified": false,
        "pose_verified": false,
        "review_required": true
    }

# Adapter for the current universal storyboard schema (boards + intermediates).
# Unlike inspect(), this accepts resumable partial generations and does not
# reject identical adjacent poses: held animation frames may be intentional.
static func inspect_storyboard_entries(entries: Array) -> Dictionary:
    if entries.is_empty():
        return {"ok": false, "error": "no_generated_drawings"}
    var inspected: int = 0
    var dimensions: Array[Vector2i] = []
    for entry in entries:
        if not entry is Dictionary:
            return {"ok": false, "error": "invalid_drawing_entry", "index": inspected}
        var path: String = str(entry.get("path", ""))
        if not path.begins_with("user://") or not FileAccess.file_exists(path):
            return {"ok": false, "error": "missing_generated_drawing", "index": inspected}
        var picture := Image.new()
        if picture.load(path) != OK or picture.is_empty():
            return {"ok": false, "error": "unreadable_generated_drawing", "index": inspected}
        dimensions.append(picture.get_size())
        inspected += 1
    return {"ok": true, "drawings": inspected, "dimensions": dimensions, "identity_verified": false, "pose_verified": false, "review_required": true}
