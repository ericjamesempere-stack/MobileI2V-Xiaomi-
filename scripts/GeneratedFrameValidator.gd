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

# Lightweight pixel diagnostics only. This does not establish semantic identity,
# pose correctness or aesthetic quality; a human review remains mandatory.
static func inspect_visual_change(reference: Image, candidate: Image) -> Dictionary:
    if reference == null or candidate == null or reference.is_empty() or candidate.is_empty():
        return {"ok": false, "error": "missing_visual_input", "review_required": true}
    var left: Image = reference.duplicate()
    var right: Image = candidate.duplicate()
    left.resize(32, 32, Image.INTERPOLATE_LANCZOS)
    right.resize(32, 32, Image.INTERPOLATE_LANCZOS)
    left.convert(Image.FORMAT_RGB8)
    right.convert(Image.FORMAT_RGB8)
    var difference: float = 0.0
    var min_brightness: float = 1.0
    var max_brightness: float = 0.0
    for y in range(32):
        for x in range(32):
            var a: Color = left.get_pixel(x, y)
            var b: Color = right.get_pixel(x, y)
            difference += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
            var brightness: float = (b.r + b.g + b.b) / 3.0
            min_brightness = minf(min_brightness, brightness)
            max_brightness = maxf(max_brightness, brightness)
    var mean_difference: float = difference / 1024.0
    var warnings: Array[String] = []
    if mean_difference < 0.003:
        warnings.append("near_identical_to_reference")
    if max_brightness - min_brightness < 0.015:
        warnings.append("near_uniform_candidate")
    return {
        "ok": true, "mean_pixel_difference": mean_difference,
        "warnings": warnings, "review_required": true,
        "identity_verified": false, "pose_verified": false
    }
