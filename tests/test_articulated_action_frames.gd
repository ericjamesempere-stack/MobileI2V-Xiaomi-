extends SceneTree
# Verify that run, fall and rise generate actual articulated drawings.
# Does not assert photo identity or photorealism.
func _initialize() -> void:
    var generator = load("res://scripts/procedural_cartoon_generator.gd").new()
    var actions := ["course", "chute", "releve"]
    var samples: Array[Image] = []
    for action in actions:
        for phase in [0.0, 0.25, 0.5, 0.75, 1.0]:
            var frame: Image = generator.render("personnage", phase, Vector2i(360, 480), action)
            if frame == null or frame.is_empty():
                push_error("Missing drawing for action " + action)
                quit(1)
                return
            samples.append(frame)
    var changed_pairs := 0
    for i in range(1, samples.size()):
        var changed := 0
        for y in range(0, 480, 8):
            for x in range(0, 360, 8):
                var a: Color = samples[i - 1].get_pixel(x, y)
                var b: Color = samples[i].get_pixel(x, y)
                if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.2:
                    changed += 1
        if changed >= 10:
            changed_pairs += 1
    if changed_pairs < 7:
        push_error("Too few articulated posture changes: %d / 14" % changed_pairs)
        quit(1)
        return
    # Fall end and rise start must describe the same physical pose.
    var fallen: Image = generator.render("personnage", 1.0, Vector2i(360, 480), "chute")
    var rising: Image = generator.render("personnage", 0.0, Vector2i(360, 480), "releve")
    var mismatched := 0
    for y in range(0, 480, 4):
        for x in range(0, 360, 4):
            if fallen.get_pixel(x, y) != rising.get_pixel(x, y):
                mismatched += 1
    if mismatched > 0:
        push_error("Fall-to-rise pose discontinuity: %d mismatched samples" % mismatched)
        quit(1)
        return
    print("ARTICULATED_ACTION_FRAMES_OK changed_pairs=", changed_pairs)
    quit(0)
