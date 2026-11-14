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
    if paths.size() > 9000:
        return {"ok": false, "error": "too_many_source_frames"}
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
    var required_frames := 0
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
        required_frames += count
        if required_frames > 18000:
            return {"ok": false, "error": "frame_limit_exceeded"}
        for i in range(count):
            var source_index := mini(frames.size() - 1, int(float(i) * float(frames.size()) / float(count)))
            result.append(str(frames[source_index]))
    return {"ok": true, "fps": fps, "frames": result, "frame_count": result.size(), "dimensions": expected_size}

# Materialize a standard numbered PNG sequence usable by a real video encoder.
# Explicitly does not label the result MP4/GIF until an encoder succeeds.
static func export_png_sequence(project: Dictionary, directory: String, fps: int = 12) -> Dictionary:
    var plan: Dictionary = timeline(project, fps)
    if not plan.get("ok", false):
        return plan
    if not directory.begins_with("user://"):
        return {"ok": false, "error": "output_must_be_user_directory"}
    if plan["frame_count"] > 18000:
        return {"ok": false, "error": "frame_limit_exceeded"}
    var error: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if error != OK:
        return {"ok": false, "error": "cannot_create_directory", "code": error}
    var frame_paths: Array = plan["frames"]
    # Prevent silently filling long scenes with repeated stills: this would
    # produce a slideshow, not the user-requested character animation.
    var scenes: Array = project.get("scenes", [])
    for scene in scenes:
        var source_paths: Array = scene.get("frame_paths", [])
        var source_count: int = source_paths.size()
        var expected_count := maxi(1, roundi(float(scene["duration_seconds"]) * float(fps)))
        if source_count < expected_count:
            return {"ok": false, "error": "insufficient_motion_frames", "scene_id": scene.get("id", ""), "available": source_count, "required": expected_count}
        # Many different filenames can contain exactly the same still image.
        # Detect this before claiming a motion sequence is ready.
        if source_count > 1:
            var first_hash := FileAccess.get_sha256(str(source_paths[0]))
            var changed := false
            for source_path in source_paths.slice(1):
                if FileAccess.get_sha256(str(source_path)) != first_hash:
                    changed = true
                    break
            if not changed:
                return {"ok": false, "error": "identical_still_frames", "scene_id": scene.get("id", "")}
    for i in range(frame_paths.size()):
        var source_path: String = str(frame_paths[i])
        if not FileAccess.file_exists(source_path):
            return {"ok": false, "error": "missing_source_frame", "frame": i}
        var target_path := "%s/frame_%06d.png" % [directory, i]
        var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
        if source_bytes.is_empty():
            return {"ok": false, "error": "cannot_read_frame", "frame": i}
        var output := FileAccess.open(target_path, FileAccess.WRITE)
        if output == null:
            return {"ok": false, "error": "cannot_write_frame", "frame": i}
        output.store_buffer(source_bytes)
        output.close()
    var manifest := {
        "format": "png_sequence",
        "fps": fps,
        "frame_count": frame_paths.size(),
        "dimensions": plan["dimensions"],
        "duration_seconds": float(frame_paths.size()) / float(fps),
        "video_encoded": false
    }
    var manifest_file := FileAccess.open(directory + "/manifest.json", FileAccess.WRITE)
    if manifest_file == null:
        return {"ok": false, "error": "cannot_write_manifest"}
    manifest_file.store_string(JSON.stringify(manifest, "  "))
    manifest_file.close()
    return {"ok": true, "directory": directory, "manifest": directory + "/manifest.json", "frame_count": frame_paths.size(), "video_encoded": false}

# Import real model-produced images from per-scene folders, without assuming
# that a request file means the image was generated.
static func import_rendered_scenes(project: Dictionary, root: String) -> Dictionary:
    if not root.begins_with("user://"):
        return {"ok": false, "error": "invalid_project_root"}
    var scenes: Array = project.get("scenes", [])
    var imported := 0
    for i in range(scenes.size()):
        var folder := "%s/rendered/scene_%03d" % [root, i]
        var dir := DirAccess.open(folder)
        if dir == null:
            return {"ok": false, "error": "missing_scene_folder", "scene": i, "imported": imported}
        var names: Array[String] = []
        dir.list_dir_begin()
        while true:
            var filename := dir.get_next()
            if filename.is_empty():
                break
            if not dir.current_is_dir() and filename.to_lower().ends_with(".png"):
                names.append(filename)
        dir.list_dir_end()
        names.sort()
        if names.is_empty():
            return {"ok": false, "error": "no_generated_images", "scene": i, "imported": imported}
        var paths: Array[String] = []
        for filename in names:
            paths.append(folder + "/" + filename)
        var outcome: Dictionary = attach_scene_frames(project, i, paths)
        if not outcome.get("ok", false):
            return {"ok": false, "error": outcome.get("error", "invalid_scene"), "scene": i, "imported": imported}
        project = outcome["project"]
        imported += 1
    project["render_status"] = "frames_imported"
    project["capability"] = "real_frames_imported"
    return {"ok": true, "project": project, "imported": imported}
