extends RefCounted
class_name ReferenceStyleRenderer

# Local, deterministic photo-to-illustration base. Not generative AI.
# Preserves spatial composition while simplifying colors and emphasizing edges.
static func render(source_path: String, output_path: String, style: String) -> Dictionary:
    if not output_path.begins_with("user://"):
        return {"ok": false, "error": "invalid_output"}
    var image := Image.new()
    if image.load(source_path) != OK or image.is_empty():
        return {"ok": false, "error": "invalid_source"}
    var scale := minf(1.0, minf(512.0 / float(image.get_width()), 768.0 / float(image.get_height())))
    var width := maxi(1, roundi(float(image.get_width()) * scale))
    var height := maxi(1, roundi(float(image.get_height()) * scale))
    image.resize(width, height, Image.INTERPOLATE_LANCZOS)
    image.convert(Image.FORMAT_RGBA8)
    var original := image.duplicate()
    var steps := 6 if style == "manga" else 9 if style == "bd" else 12
    var edge_threshold := 0.17 if style == "manga" else 0.23
    for y in range(height):
        for x in range(width):
            var color := original.get_pixel(x, y)
            var next := original.get_pixel(mini(x + 1, width - 1), y)
            var below := original.get_pixel(x, mini(y + 1, height - 1))
            var contrast := color.distance_to(next) + color.distance_to(below)
            if contrast > edge_threshold:
                image.set_pixel(x, y, Color("#17202b"))
                continue
            if style == "manga":
                var luminance := color.get_luminance()
                var shade := floorf(luminance * 5.0 + 0.5) / 5.0
                image.set_pixel(x, y, Color(shade, shade, shade, color.a))
            else:
                var r := floorf(color.r * steps + 0.5) / steps
                var g := floorf(color.g * steps + 0.5) / steps
                var b := floorf(color.b * steps + 0.5) / steps
                image.set_pixel(x, y, Color(r, g, b, color.a))
    if image.save_png(output_path) != OK:
        return {"ok": false, "error": "save_failed"}
    return {"ok": true, "path": output_path, "style": style, "mode": "non_generative_stylization"}
