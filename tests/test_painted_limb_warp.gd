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
    # Regression: alpha interpolation must keep colored edge pixels
    # without leaking RGB from fully transparent neighboring texels.
    var edge_source := Image.create(12, 12, false, Image.FORMAT_RGBA8)
    edge_source.fill(Color(0, 1, 0, 0))
    for y in range(2, 10):
        for x in range(4, 7):
            edge_source.set_pixel(x, y, Color(1, 0, 0, 1))
    var edge_output := Image.create(24, 24, false, Image.FORMAT_RGBA8)
    edge_output.fill(Color(0, 0, 0, 1))
    painter.draw_segment(edge_output, edge_source, Vector2(5, 2), Vector2(5, 9), Vector2(7.3, 4.2), Vector2(17.1, 16.4), 2.0)
    var red_edge_count: int = 0
    for yy in range(24):
        for xx in range(24):
            var pixel: Color = edge_output.get_pixel(xx, yy)
            assert(pixel.g < 0.01, "Transparent green fringe leaked into warped red artwork")
            if pixel.r > 0.15:
                red_edge_count += 1
    assert(red_edge_count > 10, "Warped semi-transparent edge was lost")
    # Produce an actual sequence of painted-limb frames, not just one pose.
    DirAccess.make_dir_recursive_absolute("user://painted_warp")
    for frame in range(60):
        var picture := Image.create(100, 100, false, Image.FORMAT_RGBA8)
        picture.fill(Color("25364a"))
        var theta: float = sin(float(frame) / 60.0 * TAU) * 0.7
        var end_point := Vector2(50.0 + 59.0 * sin(theta), 20.0 + 59.0 * cos(theta))
        painter.draw_segment(picture, source, Vector2(50, 20), Vector2(50, 79), Vector2(50, 20), end_point, 8.0)
        if picture.save_png("user://painted_warp/frame_%03d.png" % frame) != OK:
            push_error("Could not export painted frame")
            quit(1)
            return
    print("PAINTED_LIMB_WARP_OK")
    quit(0)
