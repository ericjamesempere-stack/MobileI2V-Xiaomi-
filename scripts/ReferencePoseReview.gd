extends RefCounted
class_name ReferencePoseReview

# Build an honest review sheet from actual model-generated keyframes only.
# Never treats source-image stylization as generated motion.
static func prepare(schedule_data: Dictionary, folder: String, output_path: String) -> Dictionary:
    var checked := ReferenceKeyframeImporter.inspect(schedule_data, folder)
    if not checked.get("ok", false):
        return checked
    var paths: Array[String] = checked["paths"]
    var result := AnimationContactSheet.build(paths, output_path, 4, 160)
    if not result.get("ok", false):
        return result
    return {
        "ok": true,
        "sheet_path": result["path"],
        "keyframes": paths.size(),
        "shown_keyframes": result["shown_frames"],
        "identity_verified": false,
        "motion_verified": false,
        "requires_user_approval": true,
        "video_ready": false
    }
