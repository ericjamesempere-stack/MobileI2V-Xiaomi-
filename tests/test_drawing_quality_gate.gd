extends SceneTree
func _initialize() -> void:
    var gate: RefCounted = load("res://scripts/drawing_quality_gate.gd").new()
    var blank := Image.create(48, 48, false, Image.FORMAT_RGBA8)
    blank.fill(Color.WHITE)
    assert(not gate.inspect(blank)["ok"])
    var artwork := Image.create(48, 48, false, Image.FORMAT_RGBA8)
    artwork.fill(Color.WHITE)
    for y in range(12, 36):
        for x in range(12, 36):
            artwork.set_pixel(x, y, Color.RED)
    assert(gate.inspect(artwork)["ok"])
    var same := artwork.duplicate()
    var duplicate_check: Dictionary = gate.inspect(same, artwork)
    assert(not duplicate_check["ok"])
    assert(duplicate_check["issues"].has("near_duplicate_keyframe"))
    var changed := artwork.duplicate()
    for y in range(12, 36):
        for x in range(12, 36):
            changed.set_pixel(x, y, Color.BLUE)
    var motion_check: Dictionary = gate.inspect(changed, artwork)
    assert(motion_check["ok"])
    assert(float(motion_check["average_change"]) > 0.002)
    print("DRAWING_QUALITY_GATE_TESTS_OK")
    quit(0)
