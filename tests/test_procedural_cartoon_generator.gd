extends SceneTree
func _initialize() -> void:
    var generator: RefCounted = load("res://scripts/procedural_cartoon_generator.gd").new()
    var a: Image = generator.render("Personnage qui danse", 0.0)
    var b: Image = generator.render("Personnage qui danse", 0.25)
    assert(a.get_width() == 360 and a.get_height() == 480)
    assert(b.get_width() == 360 and b.get_height() == 480)
    var difference: float = 0.0
    for y in range(0, 480, 12):
        for x in range(0, 360, 12):
            difference += a.get_pixel(x, y).distance_to(b.get_pixel(x, y))
    assert(difference > 0.5, "Animation phases should draw distinct keyframes")
    var c: Image = generator.render("Personnage qui danse", 0.0)
    assert(a.get_pixel(180, 220).is_equal_approx(c.get_pixel(180, 220)), "Character colors should be deterministic")
    print("PROCEDURAL_CARTOON_GENERATOR_TESTS_OK")
    quit(0)
