extends SceneTree
func _initialize() -> void:
    var separator: RefCounted = load("res://scripts/character_separator.gd").new()
    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    for y in range(8, 24):
        for x in range(10, 22):
            image.set_pixel(x, y, Color.RED)
    var result: Dictionary = separator.separate(image)
    assert(result.get("ok", false), "Flat-background cartoon should be isolated")
    var foreground: Image = result["foreground"]
    assert(foreground.get_pixel(0, 0).a < 0.01)
    assert(foreground.get_pixel(16, 16).a > 0.99)
    var complex := image.duplicate()
    complex.set_pixel(31, 31, Color.BLUE)
    assert(not separator.separate(complex).get("ok", true), "Complex borders must be rejected")
    print("CHARACTER_SEPARATOR_TESTS_OK")
    quit(0)
