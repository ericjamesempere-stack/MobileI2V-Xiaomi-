extends RefCounted
class_name AnimationContactSheet

# Generates an inspectable storyboard contact sheet from actual rendered frames.
static func build(frame_paths: Array[String], output_path: String, columns: int = 4, thumb_width: int = 160) -> Dictionary:
    if frame_paths.is_empty() or not output_path.begins_with("user://"):
        return {"ok": false, "error": "invalid_input"}
    if columns < 1 or columns > 8 or thumb_width < 32 or thumb_width > 512:
        return {"ok": false, "error": "invalid_layout"}
    var sample := Image.new()
    if sample.load(frame_paths[0]) != OK or sample.is_empty():
        return {"ok": false, "error": "invalid_first_frame"}
    var thumb_height := maxi(1, roundi(float(thumb_width) * float(sample.get_height()) / float(sample.get_width())))
    var rows := ceili(float(frame_paths.size()) / float(columns))
    var sheet := Image.create_empty(columns * thumb_width, rows * thumb_height, false, Image.FORMAT_RGBA8)
    sheet.fill(Color("#e5e7eb"))
    for i in range(frame_paths.size()):
        var frame := Image.new()
        if frame.load(frame_paths[i]) != OK:
            return {"ok": false, "error": "missing_frame", "index": i}
        frame.resize(thumb_width, thumb_height, Image.INTERPOLATE_LANCZOS)
        sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(i % columns * thumb_width, i / columns * thumb_height))
    if sheet.save_png(output_path) != OK:
        return {"ok": false, "error": "save_failed"}
    return {"ok": true, "path": output_path, "frames": frame_paths.size(), "columns": columns, "rows": rows}
