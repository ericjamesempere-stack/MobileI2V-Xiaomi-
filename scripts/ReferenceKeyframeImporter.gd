extends RefCounted
class_name ReferenceKeyframeImporter

# Accepts real generated key pose PNGs from a future local model adapter.
# Never substitutes the reference photo or procedural drawings as fake results.
static func inspect(schedule_data: Dictionary, folder: String) -> Dictionary:
    if not schedule_data.get("ok", false) or not folder.begins_with("user://"):
        return {"ok": false, "error": "invalid_schedule_or_folder"}
    var keys: Array = schedule_data.get("keyframes", [])
    if keys.is_empty():
        return {"ok": false, "error": "no_keyframes"}
    var output: Array[String] = []
    var dimensions := Vector2i.ZERO
    var hashes: Dictionary = {}
    for key in keys:
        var index := int(key.get("frame_index", -1))
        if index < 0:
            return {"ok": false, "error": "invalid_frame_index"}
        var path := "%s/keyframe_%06d.png" % [folder, index]
        if not FileAccess.file_exists(path):
            return {"ok": false, "error": "keyframe_missing", "index": index, "path": path}
        var image := Image.new()
        if image.load(path) != OK or image.is_empty():
            return {"ok": false, "error": "invalid_keyframe", "index": index}
        if dimensions == Vector2i.ZERO:
            dimensions = image.get_size()
        elif image.get_size() != dimensions:
            return {"ok": false, "error": "keyframe_size_mismatch", "index": index}
        var hash := FileAccess.get_sha256(path)
        if hashes.has(hash):
            return {"ok": false, "error": "identical_keyframes", "first": hashes[hash], "second": index}
        hashes[hash] = index
        output.append(path)
    return {
        "ok": true,
        "paths": output,
        "width": dimensions.x,
        "height": dimensions.y,
        "count": output.size(),
        "identity_verified": false,
        "pose_verified": false,
        "requires_visual_review": true
    }
