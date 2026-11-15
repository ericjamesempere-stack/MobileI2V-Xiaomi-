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
    for key in keys:
        var index := int(key.get("frame_index", -1))
        var reference := str(key.get("reference_original", ""))
        if index < 0 or not FileAccess.file_exists(reference):
            return {"ok": false, "error": "reference_missing", "index": index}
        var path := "%s/keyframe_%06d.png" % [output_folder, index]
        # Native plugin must produce the PNG; success is verified by importer.
        var request := JSON.stringify(key)
        var success := bool(engine.call("generate_pose_png", request, ProjectSettings.globalize_path(path)))
        if not success:
            return {"ok": false, "error": "model_generation_failed", "index": index}
    var imported := ReferenceKeyframeImporter.inspect(schedule_data, output_folder)
    if not imported.get("ok", false):
        return imported
    return {"ok": true, "keyframes": imported["count"], "folder": output_folder, "review_required": true}
