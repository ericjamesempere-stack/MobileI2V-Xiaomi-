extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var engine = load("res://scripts/karma_device_image_engine.gd").new()
    var source := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    source.fill(Color(0.2, 0.4, 0.6))
    for motion in ["pan_right", "pan_left", "pan_up", "pan_down", "zoom_in"]:
        for fraction in [0.0, 0.5, 1.0]:
            var result: Dictionary = engine.render_camera_frame(source, fraction, motion)
            assert(result.get("ok", false), "CPU rendering failed: " + motion)
            assert(result["image"].get_size() == source.get_size(), "CPU output dimensions changed")
            assert(result.get("on_device", false) and not result.get("semantic_generation", true), "misleading generation provenance")
    assert(not engine.render_camera_frame(source, 0.5, "grow_horns").get("ok", false), "semantic transformation must not be faked")
    assert(not engine.render_camera_frame(source, 1.5).get("ok", false), "invalid fraction accepted")
    var worker: Node = load("res://scripts/local_studio_generator.gd").new()
    root.add_child(worker)
    var routed: Dictionary = await worker.redraw(source, "camera:pan_right", "original")
    assert(routed.get("ok", false) and routed.get("on_device", false), "local generator did not route camera work offline")
    var unsupported: Dictionary = await worker.redraw(source, "camera:grow_horns", "original")
    assert(not unsupported.get("ok", false) and unsupported.get("requires_semantic_generation", false), "unsupported semantic request was silently approximated")
    worker.queue_free()
    print("KARMA_DEVICE_CPU_RENDER_OK")
    quit()
