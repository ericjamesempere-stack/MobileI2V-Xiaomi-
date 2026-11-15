extends RefCounted
class_name ReferenceSequenceAssembler

# Imports only fully generated frame PNGs. No duplicate-frame padding,
# no image warping, and no false claim of model-generated movement.
static func assemble(plan: Dictionary, source_folder: String, output_folder: String) -> Dictionary:
    if not plan.get("ok", false) or not source_folder.begins_with("user://") or not output_folder.begins_with("user://"):
        return {"ok": false, "error": "invalid_input"}
    var requested: Array = plan.get("frames", [])
    if requested.is_empty():
        return {"ok": false, "error": "empty_plan"}
    var paths: Array[String] = []
    for i in range(requested.size()):
        paths.append("%s/frame_%06d.png" % [source_folder, i])
    var checked := GeneratedFrameValidator.inspect(plan, paths)
    if not checked.get("ok", false):
        return checked
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_folder)) != OK:
        return {"ok": false, "error": "output_directory_failed"}
    var copied: Array[String] = []
    for i in range(paths.size()):
        var destination := "%s/frame_%06d.png" % [output_folder, i]
        var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(paths[i]), ProjectSettings.globalize_path(destination))
        if error != OK:
            return {"ok": false, "error": "copy_failed", "index": i}
        copied.append(destination)
    return {
        "ok": true,
        "paths": copied,
        "frame_count": copied.size(),
        "fps": int(plan.get("fps", 12)),
        "identity_verified": false,
        "pose_verified": false,
        "review_required": true,
        "mp4_encoded": false
    }
