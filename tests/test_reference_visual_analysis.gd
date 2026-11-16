extends SceneTree
func _initialize() -> void:
    var analyzer: RefCounted = load("res://scripts/reference_visual_analysis.gd").new()
    var empty: Image = Image.new()
    assert(not analyzer.analyze(empty).get("ok", false))
    var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(8, 56):
        for x in range(16, 48):
            img.set_pixel(x, y, Color(0.95, 0.8, 0.1, 1))
    var result: Dictionary = analyzer.analyze(img)
    assert(result.get("ok", false))
    assert(int(result["width"]) == 64)
    assert(float(result["visible_fraction"]) > 0.3)
    assert(float(result["visible_fraction"]) < 0.5)
    assert(result["semantic_analysis"] == false)
    assert(result["bounds_are_subject"] == true)
    var opaque := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    opaque.fill(Color(0.2, 0.3, 0.4, 1.0))
    for y in range(8, 56):
        for x in range(16, 48):
            opaque.set_pixel(x, y, Color(0.9, 0.7, 0.1, 1.0))
    var opaque_profile: Dictionary = analyzer.analyze(opaque)
    assert(opaque_profile["ok"])
    assert(opaque_profile["bounds_are_subject"] == false)
    assert(analyzer.drawing_guidance(opaque_profile).contains("NOT subject detection"))
    assert(not result["palette_hex"].is_empty())
    assert(analyzer.drawing_guidance(result).contains("IMAGE-LOCKED REFERENCE"))
    print("REFERENCE_VISUAL_ANALYSIS_TESTS_OK")
    quit(0)
