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
    var parts := normalized.to_lower()
    for sep in [" et puis ", " puis ", " ensuite ", " après ", " apres ", " then ", " and then ", " et ", ","]:
        parts = parts.replace(sep, "|")
    var descriptions: PackedStringArray = parts.split("|", false)
    if descriptions.is_empty():
        descriptions.append("scene immobile")
    var scenes: Array[Dictionary] = []
    var count := descriptions.size()
    var scene_length := maxf(duration, 0.1) / float(count)
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
        "duration_seconds": maxf(duration, 0.1),
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
