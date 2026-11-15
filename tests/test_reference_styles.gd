extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stylizer = load("res://scripts/ReferenceStyleRenderer.gd")
    var analyzer = load("res://scripts/ReferenceSceneAnalyzer.gd")
    var source := "user://test_reference_source.png"
    var img := Image.create_empty(120, 80, false, Image.FORMAT_RGBA8)
    for y in range(80):
        for x in range(120):
            img.set_pixel(x, y, Color(0.9, 0.2, 0.1) if x < 60 else Color(0.2, 0.5, 0.9))
    assert(img.save_png(source) == OK)
    var inspected: Dictionary = analyzer.analyze(source, "user://test_reference_profile")
    assert(inspected.get("ok", false), str(inspected))
    assert(int(inspected["profile"]["width"]) == 120)
    assert(int(inspected["profile"]["height"]) == 80)
    assert(inspected["profile"]["palette"].size() > 0)
    for style in ["manga", "bd", "cartoon"]:
        var output := "user://test_reference_%s.png" % style
        var result: Dictionary = stylizer.render(source, output, style)
        assert(result.get("ok", false), str(result))
        var rendered := Image.new()
        assert(rendered.load(output) == OK)
        assert(rendered.get_width() == 120)
        assert(rendered.get_height() == 80)
        assert(FileAccess.get_sha256(source) != FileAccess.get_sha256(output))
    print("MOBILEI2V_REFERENCE_STYLES_OK")
    quit(0)
