extends SceneTree
func _initialize() -> void:
    var interpolator: RefCounted = load("res://scripts/frame_interpolator.gd").new()
    var a := Image.create(64, 64, false, Image.FORMAT_RGB8)
    var b := Image.create(64, 64, false, Image.FORMAT_RGB8)
    a.fill(Color.BLACK)
    b.fill(Color.BLACK)
    for y in range(20, 32):
        for x in range(15, 27):
            a.set_pixel(x, y, Color.RED)
            b.set_pixel(x + 6, y, Color.RED)
    var shift: Vector2i = interpolator.estimate_shift(a, b, 12)
    assert(abs(shift.x - 6) <= 3, "Motion estimate should track moving subject")
    var mid: Image = interpolator.blend(a, b, 0.5, shift)
    assert(mid.get_width() == 64 and mid.get_height() == 64)
    assert(mid.get_pixel(24, 25).r > 0.8, "Intermediate should preserve moving subject color")
    var field: Dictionary = interpolator.estimate_blocks(a, b, 16, 8)
    assert(field["shifts"].size() == 16)
    var local_mid: Image = interpolator.blend_blocks(a, b, 0.5, field)
    assert(local_mid.get_width() == 64)
    assert(local_mid.get_pixel(22, 25).r > 0.3, "Local interpolation should retain the moving color")
    print("FRAME_INTERPOLATOR_TESTS_OK")
    quit(0)
