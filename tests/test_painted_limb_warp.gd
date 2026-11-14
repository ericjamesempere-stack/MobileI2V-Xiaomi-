extends SceneTree

func _initialize() -> void:
    var painter = load("res://scripts/painted_limb_warp.gd").new()
    var source := Image.create(100, 100, false, Image.FORMAT_RGBA8)
    source.fill(Color(0, 0, 0, 0))
    # Draw a deliberately nonuniform red-and-blue painted sleeve.
    for y in range(20, 80):
        for x in range(43, 58):
            source.set_pixel(x, y, Color(0.9, 0.1, 0.1, 1.0) if y < 50 else Color(0.1, 0.3, 0.9, 1.0))
    var destination := Image.create(100, 100, false, Image.FORMAT_RGBA8)
    destination.fill(Color("25364a"))
    painter.draw_segment(destination, source, Vector2(50, 20), Vector2(50, 79), Vector2(20, 50), Vector2(79, 50), 8.0)
    var upper: Color = destination.get_pixel(35, 50)
    var lower: Color = destination.get_pixel(65, 50)
    assert(upper.r > upper.b, "Painted upper sleeve lost its original red pixels")
    assert(lower.b > lower.r, "Painted lower sleeve lost its original blue pixels")
    var outside: Color = destination.get_pixel(50, 10)
    assert(outside.b < 0.5, "Background outside limb was overwritten")
    print("PAINTED_LIMB_WARP_OK")
    quit(0)
