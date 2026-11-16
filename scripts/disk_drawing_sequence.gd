extends RefCounted
# Bounded-memory offline drawing pipeline. Palette guidance is NOT face identity.
const Planner = preload("res://scripts/story_motion_planner.gd")
const Palette = preload("res://scripts/reference_appearance_palette.gd")
const Generator = preload("res://scripts/procedural_cartoon_generator.gd")
const SUPPORTED = ["repos", "marche", "course", "saut", "chute", "trebuche", "releve", "danse", "salut"]
const DRAWINGS_PER_SECOND = 12
const SIZE = Vector2i(360, 640)

func prepare(story: String, reference: Image, duration: float) -> Dictionary:
    if duration < 0.5 or duration > 300.0:
        return {"ok": false, "error": "Duree hors limites (0,5 a 300 secondes)."}
    var motion: Dictionary = Planner.new().plan(story, duration)
    if not motion.get("ok", false):
        return {"ok": false, "error": "Histoire vide."}
    for step in motion["steps"]:
        if not str(step["action"]) in SUPPORTED:
            return {"ok": false, "error": "Action non prise en charge hors ligne : " + str(step["description"])}
    var shirt := Color("306caa")
    var reference_hash: String = "none"
    if reference != null and not reference.is_empty():
        var extracted: Dictionary = Palette.new().extract(reference)
        if not extracted.get("ok", false):
            return {"ok": false, "error": "Reference sans couleurs exploitables."}
        shirt = extracted["palette"][0]
        var digest := HashingContext.new()
        digest.start(HashingContext.HASH_SHA256)
        digest.update(reference.get_data())
        reference_hash = digest.finish().hex_encode()
    var key: String = (story + str(duration) + reference_hash + "disk-v1").sha256_text()
    return {"ok": true, "motion": motion, "duration": duration,
        "count": ceili(duration * DRAWINGS_PER_SECOND), "shirt": shirt, "key": key,
        "method": "offline_procedural_palette", "identity_verified": false}

func render_frame(prepared: Dictionary, index: int) -> Image:
    if not prepared.get("ok", false) or index < 0 or index >= int(prepared["count"]):
        return null
    var seconds: float = float(index) / DRAWINGS_PER_SECOND
    var action: String = "repos"
    var phase: float = 0.0
    for step in prepared["motion"]["steps"]:
        if seconds < float(step["end"]) or step == prepared["motion"]["steps"].back():
            action = str(step["action"])
            # Include the endpoints of one-shot gestures: fall ends on ground,
            # stand-up begins on ground. Cycles use seconds, never scene length.
            var first: int = ceili(float(step["start"]) * DRAWINGS_PER_SECOND)
            var last: int = ceili(float(step["end"]) * DRAWINGS_PER_SECOND) - 1
            phase = clampf(float(index - first) / maxi(1, last - first), 0.0, 1.0)
            break
    if action in ["marche", "course", "danse"]:
        phase = seconds * (1.8 if action == "course" else 1.0)
    var frame: Image = Generator.new().render("locked character", phase, SIZE, action)
    var a := Color("306caa")
    var b := Color("c34e59")
    for y in range(frame.get_height()):
        for x in range(frame.get_width()):
            var color: Color = frame.get_pixel(x, y)
            if color.is_equal_approx(a) or color.is_equal_approx(b):
                frame.set_pixel(x, y, prepared["shirt"])
    return frame

func save_frame(folder: String, index: int, image: Image) -> bool:
    if image == null or image.is_empty():
        return false
    var target: String = folder.path_join("frame_%04d.png" % index)
    var temp: String = target + ".part"
    if image.save_png(temp) != OK:
        return false
    return DirAccess.rename_absolute(temp, target) == OK

func valid_frame(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var image := Image.new()
    return image.load(path) == OK and image.get_size() == SIZE
