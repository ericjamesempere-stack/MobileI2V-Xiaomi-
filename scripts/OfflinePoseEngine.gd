extends RefCounted
class_name OfflinePoseEngine

# A single entry point for a real, on-device reference-conditioned image model.
# Requires an installed Android native plugin exposing the declared methods.
# No network calls, subscription, placeholder images or false success.
const SINGLETON := "ReferencePoseGenerator"

static func availability() -> Dictionary:
    var manifest := PoseModelManifest.inspect("user://pose_model/manifest.json")
    if not manifest.get("ok", false):
        return {"available": false, "reason": manifest.get("error", "model_manifest_invalid")}
    if not Engine.has_singleton(SINGLETON):
        return {"available": false, "reason": "native_reference_pose_model_not_installed"}
    var engine := Engine.get_singleton(SINGLETON)
    if not engine.has_method("is_model_ready") or not engine.has_method("generate_pose_png"):
        return {"available": false, "reason": "native_plugin_interface_incomplete"}
    if not bool(engine.call("is_model_ready")):
        return {"available": false, "reason": "offline_model_not_ready"}
    return {"available": true}

static func generate(schedule_data: Dictionary, output_folder: String) -> Dictionary:
    var available := availability()
    if not available["available"]:
        return {"ok": false, "error": available["reason"]}
    if not schedule_data.get("ok", false) or not output_folder.begins_with("user://"):
        return {"ok": false, "error": "invalid_generation_request"}
    var keys: Array = schedule_data.get("keyframes", [])
    if keys.is_empty():
        return {"ok": false, "error": "no_keyframes"}
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_folder)) != OK:
        return {"ok": false, "error": "output_directory_failed"}
    var engine := Engine.get_singleton(SINGLETON)
    var previous_index := -1
    for key in keys:
        var index := int(key.get("frame_index", -1))
        var reference := str(key.get("reference_original", ""))
        if index <= previous_index or not FileAccess.file_exists(reference):
            return {"ok": false, "error": "reference_missing", "index": index}
        previous_index = index
        var path := "%s/keyframe_%06d.png" % [output_folder, index]
        # Never accept a PNG left behind by a previous failed run.
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
        var request_data: Dictionary = key.duplicate(true)
        request_data["reference_original"] = ProjectSettings.globalize_path(reference)
        var styled := str(key.get("reference_styled", ""))
        if not styled.is_empty():
            if not FileAccess.file_exists(styled):
                return {"ok": false, "error": "styled_reference_missing", "index": index}
            request_data["reference_styled"] = ProjectSettings.globalize_path(styled)
        var manifest := PoseModelManifest.inspect("user://pose_model/manifest.json")
        if not manifest.get("ok", false):
            return {"ok": false, "error": "model_manifest_invalid"}
        request_data["model_path"] = ProjectSettings.globalize_path(str(manifest["model_path"]))
        # Native plugin receives absolute filesystem paths, not Godot user:// URIs.
        var request := JSON.stringify(request_data)
        var success := bool(engine.call("generate_pose_png", request, ProjectSettings.globalize_path(path)))
        if not success:
            return {"ok": false, "error": "model_generation_failed", "index": index}
    var imported := ReferenceKeyframeImporter.inspect(schedule_data, output_folder)
    if not imported.get("ok", false):
        return imported
    return {"ok": true, "keyframes": imported["count"], "folder": output_folder, "review_required": true}

# Generate every planned frame using the installed native image model.
# This is intentionally not interpolation by duplicating existing PNGs.
static func generate_full_sequence(plan: Dictionary, output_folder: String, keyframe_folder: String = "") -> Dictionary:
    var available := availability()
    if not available.get("available", false):
        return {"ok": false, "error": available.get("reason", "model_unavailable")}
    if not plan.get("ok", false) or not output_folder.begins_with("user://"):
        return {"ok": false, "error": "invalid_generation_request"}
    var instructions: Array = plan.get("frames", [])
    if instructions.is_empty():
        return {"ok": false, "error": "empty_frame_plan"}
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_folder)) != OK:
        return {"ok": false, "error": "output_directory_failed"}
    var manifest := PoseModelManifest.inspect("user://pose_model/manifest.json")
    if not manifest.get("ok", false):
        return {"ok": false, "error": "model_manifest_invalid"}
    var model_path := ProjectSettings.globalize_path(str(manifest["model_path"]))
    var engine := Engine.get_singleton(SINGLETON)
    var paths: Array[String] = []
    var reused_keyframes := 0
    for i in range(instructions.size()):
        var instruction: Dictionary = instructions[i]
        var original := str(instruction.get("reference_original", ""))
        var styled := str(instruction.get("reference_styled", ""))
        if not FileAccess.file_exists(original) or not FileAccess.file_exists(styled):
            return {"ok": false, "error": "reference_missing", "index": i}
        var destination := "%s/frame_%06d.png" % [output_folder, i]
        if FileAccess.file_exists(destination):
            var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
            if remove_error != OK:
                return {"ok": false, "error": "stale_frame_removal_failed", "index": i}
        var used_keyframe := false
        # A keyframe already generated for exactly this frame must not be
        # regenerated. Copy only its matching index; never pad other frames.
        if not keyframe_folder.is_empty():
            if not keyframe_folder.begins_with("user://"):
                return {"ok": false, "error": "invalid_keyframe_folder"}
            var keyframe_path := "%s/keyframe_%06d.png" % [keyframe_folder, i]
            if FileAccess.file_exists(keyframe_path):
                var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path(keyframe_path), ProjectSettings.globalize_path(destination))
                if copied != OK:
                    return {"ok": false, "error": "keyframe_copy_failed", "index": i}
                reused_keyframes += 1
                used_keyframe = true
        if not used_keyframe:
            var request := instruction.duplicate(true)
            request["reference_original"] = ProjectSettings.globalize_path(original)
            request["reference_styled"] = ProjectSettings.globalize_path(styled)
            request["model_path"] = model_path
            if not bool(engine.call("generate_pose_png", JSON.stringify(request), ProjectSettings.globalize_path(destination))):
                return {"ok": false, "error": "model_generation_failed", "index": i}
        if not FileAccess.file_exists(destination):
            return {"ok": false, "error": "model_did_not_write_png", "index": i}
        paths.append(destination)
        # Yield after each image so Android can redraw the interface and
        # handle cancellation/navigation instead of freezing for minutes.
        await Engine.get_main_loop().process_frame
    var checked := GeneratedFrameValidator.inspect(plan, paths)
    if not checked.get("ok", false):
        return checked
    return {"ok": true, "paths": paths, "frames": paths.size(), "fps": int(plan.get("fps", 12)), "review_required": true, "mp4_encoded": false, "reused_keyframes": reused_keyframes}
