extends RefCounted
# Recolors the procedural cartoon with colors sampled from a private reference.
# This is palette transfer, NOT reference-faithful generative redrawing.
const Generator = preload("res://scripts/procedural_cartoon_generator.gd")
const Extractor = preload("res://scripts/reference_appearance_palette.gd")

func render_with_reference(reference: Image, description: String, phase: float = 0.0, size: Vector2i = Vector2i(360, 480), action: String = "danse") -> Dictionary:
    if reference == null or reference.is_empty():
        return {"ok": false, "reason": "empty_reference"}
    var appearance: Dictionary = Extractor.new().extract(reference)
    if not appearance.get("ok", false):
        return {"ok": false, "reason": appearance.get("reason", "appearance_failed")}
    var frame: Image = Generator.new().render(description, phase, size, action)
    var palette: Array = appearance["palette"]
    if palette.is_empty():
        return {"ok": false, "reason": "no_colors"}
    # Replace only known procedural clothing colors. Do not recolor face, eyes,
    # outlines or background; arbitrary palette transfer would destroy them.
    var shirt_a := Color("#306caa")
    var shirt_b := Color("#c34e59")
    var shirt_color: Color = palette[0]
    for y in range(frame.get_height()):
        for x in range(frame.get_width()):
            var pixel: Color = frame.get_pixel(x, y)
            if pixel.is_equal_approx(shirt_a) or pixel.is_equal_approx(shirt_b):
                frame.set_pixel(x, y, shirt_color)
    return {"ok": true, "image": frame, "method": "procedural_pose_with_reference_palette", "generative_redraw": false, "identity_verified": false}
