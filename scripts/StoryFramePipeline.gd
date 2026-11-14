extends RefCounted
class_name StoryFramePipeline

# Validates actual, independently generated scene frames and links them into
# a single timeline. Does NOT fabricate frames or claim to run an image model.
static func attach_scene_frames(project: Dictionary, scene_index: int, paths: Array) -> Dictionary:
    var scenes: Array = project.get("scenes", [])
    if scene_index < 0 or scene_index >= scenes.size():
        return {"ok": false, "error": "invalid_scene"}
    if paths.is_empty():
        return {"ok": false, "error": "no_frames"}
    var validated: Array[String] = []
    var expected_size := Vector2i.ZERO
    for item in paths:
        var path := str(item)
        if not FileAccess.file_exists(path):
            return {"ok": false, "error": "missing_file", "path": path}
        var img := Image.new()
        if img.load(path) != OK or img.is_empty():
            return {"ok": false, "error": "invalid_image", "path": path}
        if expected_size == Vector2i.ZERO:
            expected_size = img.get_size()
        elif img.get_size() != expected_size:
            return {"ok": false, "error": "inconsistent_dimensions", "path": path}
        validated.append(path)
    var scene: Dictionary = scenes[scene_index]
    scene["frame_paths"] = validated
    scene["frame_dimensions"] = [expected_size.x, expected_size.y]
    scene["last_frame_path"] = validated[validated.size() - 1]
    scene["status"] = "frames_ready"
    scenes[scene_index] = scene
    project["scenes"] = scenes
    if scene_index + 1 < scenes.size():
        var next_scene: Dictionary = scenes[scene_index + 1]
        next_scene["reference_previous_frame"] = scene["last_frame_path"]
        scenes[scene_index + 1] = next_scene
    return {"ok": true, "project": project, "frames": validated.size()}

static func timeline(project: Dictionary, fps: int = 12) -> Dictionary:
    if fps < 1 or fps > 60:
        return {"ok": false, "error": "invalid_fps"}
    var scenes: Array = project.get("scenes", [])
    var result: Array[String] = []
    var expected_size: Array = []
    for scene in scenes:
        if not scene.has("frame_paths"):
            return {"ok": false, "error": "scene_missing_frames", "scene_id": scene.get("id", "")}
        var frames: Array = scene["frame_paths"]
        if frames.is_empty():
            return {"ok": false, "error": "empty_scene"}
        var dims: Array = scene.get("frame_dimensions", [])
        if expected_size.is_empty():
            expected_size = dims.duplicate()
        elif dims != expected_size:
            return {"ok": false, "error": "inconsistent_scene_dimensions"}
        var count := maxi(1, roundi(float(scene["duration_seconds"]) * float(fps)))
        for i in range(count):
            var source_index := mini(frames.size() - 1, int(float(i) * float(frames.size()) / float(count)))
            result.append(str(frames[source_index]))
    return {"ok": true, "fps": fps, "frames": result, "frame_count": result.size(), "dimensions": expected_size}
