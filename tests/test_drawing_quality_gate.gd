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
    print("DRAWING_QUALITY_GATE_TESTS_OK")
    quit(0)
