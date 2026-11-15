extends RefCounted
class_name AndroidSequenceMp4

# Exports the approved storyboard PNG sequence, not the legacy rig.
static func available() -> bool:
    if not Engine.has_singleton("MP4Exporter"):
        return false
    var encoder := Engine.get_singleton("MP4Exporter")
    return encoder.has_method("begin") and encoder.has_method("push_frame_rgba") and encoder.has_method("finish")

static func encode(paths: Array[String], output: String, fps: int = 12) -> Dictionary:
    if not available():
        return {"ok": false, "error": "android_mp4_plugin_not_installed"}
    if paths.is_empty() or fps < 1 or not output.begins_with("user://"):
        return {"ok": false, "error": "invalid_mp4_request"}
    var first := Image.new()
    if first.load(paths[0]) != OK or first.is_empty():
        return {"ok": false, "error": "first_frame_unreadable"}
    var dimensions := first.get_size()
    if dimensions.x % 2 != 0 or dimensions.y % 2 != 0:
        return {"ok": false, "error": "mp4_requires_even_dimensions"}
    var encoder := Engine.get_singleton("MP4Exporter")
    var absolute_output := ProjectSettings.globalize_path(output)
    if not bool(encoder.call("begin", absolute_output, dimensions.x, dimensions.y, fps)):
        return {"ok": false, "error": "encoder_start_failed"}
    for i in range(paths.size()):
        var frame := Image.new()
        if frame.load(paths[i]) != OK or frame.get_size() != dimensions:
            encoder.call("abort")
            return {"ok": false, "error": "frame_missing_or_size_mismatch", "index": i}
        frame.convert(Image.FORMAT_RGBA8)
        if not bool(encoder.call("push_frame_rgba", frame.get_data())):
            encoder.call("abort")
            return {"ok": false, "error": "encoder_frame_failed", "index": i}
        await Engine.get_main_loop().process_frame
    var saved := str(encoder.call("finish"))
    if saved.is_empty() or not FileAccess.file_exists(saved):
        return {"ok": false, "error": "mp4_output_missing"}
    var file := FileAccess.open(saved, FileAccess.READ)
    if file == null or file.get_length() <= 0:
        return {"ok": false, "error": "mp4_output_empty"}
    return {"ok": true, "path": saved, "frames": paths.size(), "fps": fps}
