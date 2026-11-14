extends SceneTree

func _initialize() -> void:
    var extractor: RefCounted = load("res://scripts/reference_appearance_palette.gd").new()
    var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(12, 52):
        for x in range(12, 52):
            img.set_pixel(x, y, Color("#cc3344") if x < 32 else Color("#2244cc"))
    var result: Dictionary = extractor.extract(img)
    assert(result.get("ok", false))
    assert(result["palette"].size() >= 2)
    assert(result["visible_samples"] == 1600)
    assert(result["generative_redraw"] == false)
    var empty: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    empty.fill(Color(0, 0, 0, 0))
    assert(not extractor.extract(empty).get("ok", false))
    print("REFERENCE_APPEARANCE_PALETTE_TESTS_OK")
    quit(0)
