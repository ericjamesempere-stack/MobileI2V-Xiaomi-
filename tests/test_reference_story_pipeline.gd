extends SceneTree

func _initialize() -> void:
    var pipeline: RefCounted = load("res://scripts/reference_story_pipeline.gd").new()
    var reference: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
    reference.fill(Color(0, 0, 0, 0))
    for y in range(8, 40):
        for x in range(8, 40):
            reference.set_pixel(x, y, Color("#339966"))
    var prepared: Dictionary = pipeline.prepare("Le personnage court puis tombe puis se releve.", reference, 6.0)
    assert(prepared.get("ok", false), "story planning failed")
    var boards: Array = prepared["plan"]["boards"]
    assert(boards.size() > 3)
    var rendered: Dictionary = pipeline.render_batch(prepared, reference, 0, 8, Vector2i(120, 160))
    assert(rendered.get("ok", false), "frame rendering failed")
    assert(rendered["frames"].size() == mini(8, boards.size()))
    assert(rendered["next_index"] == rendered["frames"].size())
    assert(rendered["generative_redraw"] == false)
    assert(rendered["identity_verified"] == false)
    var missing: Dictionary = pipeline.prepare("court", null, 2.0)
    assert(not missing.get("ok", false))
    print("REFERENCE_STORY_PIPELINE_TESTS_OK")
    quit(0)
