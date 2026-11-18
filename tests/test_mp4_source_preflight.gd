extends SceneTree

func _initialize() -> void:
    var exporter = load("res://scripts/export_mp4.gd").new()
    root.add_child(exporter)
    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    var path := "user://mp4_preflight_test.png"
    assert(image.save_png(path) == OK)
    assert(exporter._preflight_board_sources([path], [0, 0]).get("ok", false))
    assert(exporter._preflight_board_sources([path], [1]).get("error", "") == "timeline_out_of_range")
    assert(exporter._preflight_board_sources([path], [-1]).get("error", "") == "timeline_out_of_range")
    assert(exporter._preflight_board_sources([path], ["bad"]).get("error", "") == "invalid_timeline_index")
    assert(exporter._preflight_board_sources(["user://missing_drawing.png"], [0]).get("error", "") == "unreadable_drawing_0")
    var corrupt := FileAccess.open("user://mp4_preflight_corrupt.png", FileAccess.WRITE)
    assert(corrupt != null)
    corrupt.store_string("invalid image")
    corrupt.close()
    assert(exporter._preflight_board_sources(["user://mp4_preflight_corrupt.png"], [0]).get("error", "") == "unreadable_drawing_0")
    print("MP4_SOURCE_PREFLIGHT_OK")
    quit(0)
