extends SceneTree
func _color_delta(a: Color, b: Color) -> float:
    return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _initialize() -> void:
    var generator: RefCounted = load("res://scripts/procedural_cartoon_generator.gd").new()
    var a: Image = generator.render("Personnage qui danse", 0.0)
    var b: Image = generator.render("Personnage qui danse", 0.25)
    assert(a.get_width() == 360 and a.get_height() == 480)
    assert(b.get_width() == 360 and b.get_height() == 480)
    var difference: float = 0.0
    for y in range(0, 480, 12):
        for x in range(0, 360, 12):
            difference += _color_delta(a.get_pixel(x, y), b.get_pixel(x, y))
    assert(difference > 0.5, "Animation phases should draw distinct keyframes")
    var c: Image = generator.render("Personnage qui danse", 0.0)
    assert(a.get_pixel(180, 220).is_equal_approx(c.get_pixel(180, 220)), "Character colors should be deterministic")
    var run: Image = generator.render("Le personnage court", 0.25, Vector2i(360, 480), "course")
    var jump: Image = generator.render("Le personnage saute", 0.25, Vector2i(360, 480), "saut")
    var action_delta: float = 0.0
    for y in range(0, 480, 12):
        for x in range(0, 360, 12):
            action_delta += _color_delta(run.get_pixel(x, y), jump.get_pixel(x, y))
    assert(action_delta > 1.0, "Different actions must produce different drawings")
    # Regression: falling must change the drawn posture and getting up
    # must reverse it, not merely translate an unchanged standing image.
    var start_fall: Image = generator.render("same character", 0.0, Vector2i(360, 480), "chute")
    var end_fall: Image = generator.render("same character", 1.0, Vector2i(360, 480), "chute")
    var start_rise: Image = generator.render("same character", 0.0, Vector2i(360, 480), "releve")
    var end_rise: Image = generator.render("same character", 1.0, Vector2i(360, 480), "releve")
    var fall_delta: float = 0.0
    var reverse_delta: float = 0.0
    for y in range(0, 480, 8):
        for x in range(0, 360, 8):
            fall_delta += _color_delta(start_fall.get_pixel(x, y), end_fall.get_pixel(x, y))
            reverse_delta += _color_delta(end_fall.get_pixel(x, y), start_rise.get_pixel(x, y))
    assert(fall_delta > 5.0, "Fall must draw visibly distinct standing and grounded poses")
    assert(reverse_delta > 5.0, "Stand-up sequence must begin near the grounded pose")
    print("PROCEDURAL_CARTOON_GENERATOR_TESTS_OK")
    quit(0)
