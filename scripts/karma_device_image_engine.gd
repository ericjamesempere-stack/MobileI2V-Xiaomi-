extends RefCounted
# Native Godot Image CPU renderer. No server, model download, or fabricated AI.
# Supports only camera movement on an existing still; never claims new anatomy.
const REVISION := "cpu-camera-v1"
func render_camera_frame(reference: Image, fraction: float, motion: String = "pan_right", travel: float = 0.08) -> Dictionary:
    if reference == null or reference.is_empty() or reference.get_width() < 2 or reference.get_height() < 2:
        return {"ok": false, "error": "invalid_reference"}
    if not is_finite(fraction) or fraction < 0.0 or fraction > 1.0 or not is_finite(travel) or travel < 0.0 or travel > 0.2:
        return {"ok": false, "error": "invalid_camera_parameters"}
    if motion not in ["pan_right", "pan_left", "pan_up", "pan_down", "zoom_in"]:
        return {"ok": false, "error": "unsupported_local_motion", "requires_semantic_generation": true}
    var width: int = reference.get_width()
    var height: int = reference.get_height()
    var source: Image = reference.duplicate()
    source.convert(Image.FORMAT_RGBA8)
    var crop_w: int = maxi(1, roundi(float(width) * (1.0 - travel)))
    var crop_h: int = maxi(1, roundi(float(height) * (1.0 - travel)))
    var x: int = (width - crop_w) / 2
    var y: int = (height - crop_h) / 2
    if motion == "pan_right":
        x = roundi(float(width - crop_w) * fraction)
    elif motion == "pan_left":
        x = roundi(float(width - crop_w) * (1.0 - fraction))
    elif motion == "pan_down":
        y = roundi(float(height - crop_h) * fraction)
    elif motion == "pan_up":
        y = roundi(float(height - crop_h) * (1.0 - fraction))
    elif motion == "zoom_in":
        crop_w = maxi(1, roundi(float(width) * (1.0 - travel * fraction)))
        crop_h = maxi(1, roundi(float(height) * (1.0 - travel * fraction)))
        x = (width - crop_w) / 2
        y = (height - crop_h) / 2
    var output: Image = source.get_region(Rect2i(x, y, crop_w, crop_h))
    output.resize(width, height, Image.INTERPOLATE_LANCZOS)
    return {"ok": true, "image": output, "engine": "godot_cpu_camera", "on_device": true, "semantic_generation": false, "identity_verified": false, "motion": motion}
