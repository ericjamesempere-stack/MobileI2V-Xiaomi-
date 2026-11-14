extends SceneTree

func _initialize() -> void:
    var renderer: RefCounted = load("res://scripts/reference_guided_cartoon_renderer.gd").new()
    var reference: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    reference.fill(Color(0, 0, 0, 0))
    for y in range(8, 56):
        for x in range(8, 56):
            reference.set_pixel(x, y, Color("#22bb66"))
    var standing: Dictionary = renderer.render_with_reference(reference, "character", 0.0, Vector2i(120, 160), "repos")
    var falling: Dictionary = renderer.render_with_reference(reference, "character", 1.0, Vector2i(120, 160), "chute")
    assert(standing.get("ok", false) and falling.get("ok", false))
    assert(standing["generative_redraw"] == false)
    assert(standing["identity_verified"] == false)
    assert(standing["image"].get_size() == Vector2i(120, 160))
    var difference: float = 0.0
    for y in range(0, 160, 4):
        for x in range(0, 120, 4):
            var a: Color = standing["image"].get_pixel(x, y)
            var b: Color = falling["image"].get_pixel(x, y)
            difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
    assert(difference > 1.0, "poses must produce different frames")
    print("REFERENCE_GUIDED_CARTOON_RENDERER_TESTS_OK")
    quit(0)
