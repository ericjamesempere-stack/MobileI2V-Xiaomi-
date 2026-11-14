extends RefCounted
class_name StoryStudio

# Universal storyboard data model. No assumption that the subject is human.
const STYLES := ["manga", "bd", "cartoon"]
const SUBJECT_HINTS := {
    "moto": "vehicle", "voiture": "vehicle", "avion": "vehicle",
    "chat": "animal", "chien": "animal", "oiseau": "animal",
    "maison": "place", "ville": "place", "forêt": "place", "foret": "place",
    "arbre": "object", "robot": "character", "personne": "character",
    "personnage": "character"
}

static func classify_subject(description: String) -> String:
    var lowered := description.to_lower()
    for hint in SUBJECT_HINTS:
        if lowered.contains(hint):
            return SUBJECT_HINTS[hint]
    return "unknown"

static func storyboard(prompt: String, duration: float = 15.0, style: String = "manga", references: Array = []) -> Dictionary:
    var selected_style: String = style if STYLES.has(style) else "manga"
    var normalized := prompt.strip_edges()
    duration = clampf(duration, 0.1, 300.0)
    # Case-insensitive sentence segmentation while keeping the original text.
    # The former exact-string replacement missed "Puis", "THEN" and newlines.
    var splitter := RegEx.new()
    splitter.compile("(?i)\\s+(?:et\\s+puis|puis|ensuite|apr[eè]s|then|and\\s+then)\\s+|[,;\\n]+")
    var parts := splitter.sub(normalized, "|", true)
    var descriptions: PackedStringArray = parts.split("|", false)
    if descriptions.is_empty():
        descriptions.append("scene immobile")
    var scenes: Array[Dictionary] = []
    var count := descriptions.size()
    var scene_length := duration / float(count)
    var subject_type: String = classify_subject(normalized)
    var entity_id := "subject_000"
    var reference_ids: Array[String] = []
    for index in range(references.size()):
        reference_ids.append("reference_%d" % index)
    for i in range(count):
        var scene_text := descriptions[i].strip_edges()
        scenes.append({
            "id": "scene_%03d" % i,
            "description": scene_text,
            "start_seconds": float(i) * scene_length,
            "duration_seconds": scene_length,
            "style": selected_style,
            "subject_type": subject_type,
            "reference_ids": reference_ids.duplicate(),
            "entity_ids": [entity_id],
            "generation_prompt": "%s illustration, consistent subject (%s), %s" % [selected_style, subject_type, scene_text],
            "reference_previous_frame": "",
            "continuity_from": "scene_%03d" % (i - 1) if i > 0 else "",
            "entry_state": {},
            "exit_state": {},
            "last_frame_path": "",
            "status": "planned"
        })
    return {
        "version": 1,
        "prompt": normalized,
        "duration_seconds": duration,
        "style": selected_style,
        "subject_type": subject_type,
        "reference_count": references.size(),
        "entities": [{"id": entity_id, "kind": subject_type, "description": normalized, "reference_ids": reference_ids.duplicate()}],
        "scenes": scenes,
        "render_status": "not_rendered",
        "capability": "storyboard_only"
    }

static func carry_forward(project: Dictionary, scene_index: int, final_frame: String, final_state: Dictionary) -> Dictionary:
    var scenes: Array = project.get("scenes", [])
    if scene_index < 0 or scene_index >= scenes.size():
        return project
    var current: Dictionary = scenes[scene_index]
    if final_frame.strip_edges().is_empty():
        return project
    current["last_frame_path"] = final_frame
    current["exit_state"] = final_state.duplicate(true)
    current["status"] = "rendered"
    scenes[scene_index] = current
    if scene_index + 1 < scenes.size():
        var following: Dictionary = scenes[scene_index + 1]
        following["entry_state"] = final_state.duplicate(true)
        following["reference_previous_frame"] = final_frame
        scenes[scene_index + 1] = following
    project["scenes"] = scenes
    return project

# Generate a reproducible image-generation request. An external or local
# image model must actually process this request; this is not an image renderer.
static func image_request(project: Dictionary, scene_index: int) -> Dictionary:
    var scenes: Array = project.get("scenes", [])
    if scene_index < 0 or scene_index >= scenes.size():
        return {"error": "invalid_scene_index"}
    var scene: Dictionary = scenes[scene_index]
    var refs: Array = project.get("reference_paths", [])
    var previous: String = str(scene.get("reference_previous_frame", ""))
    var images: Array = refs.duplicate()
    if not previous.is_empty():
        images.append(previous)
    return {
        "scene_id": scene.get("id", ""),
        "prompt": scene.get("generation_prompt", ""),
        "style": project.get("style", "manga"),
        "entity_ids": scene.get("entity_ids", []),
        "reference_images": images,
        "previous_frame": previous,
        "output_type": "image",
        "status": "requires_image_model"
    }

# Persist one machine-readable generation request per scene. A model can
# consume these files without re-parsing the original story.
static func export_requests(project: Dictionary, directory: String) -> Dictionary:
    if not directory.begins_with("user://"):
        return {"ok": false, "error": "output_must_be_user_directory"}
    var err: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if err != OK:
        return {"ok": false, "error": "cannot_create_directory"}
    var scenes: Array = project.get("scenes", [])
    var paths: Array[String] = []
    for i in range(scenes.size()):
        var request: Dictionary = image_request(project, i)
        if request.has("error"):
            return {"ok": false, "error": request["error"]}
        var path := "%s/scene_%03d_request.json" % [directory, i]
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file == null:
            return {"ok": false, "error": "cannot_write_request", "scene": i}
        file.store_string(JSON.stringify(request, "  "))
        file.close()
        paths.append(path)
    return {"ok": true, "requests": paths, "count": paths.size()}
