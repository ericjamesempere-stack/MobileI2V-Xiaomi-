extends RefCounted
# Image-first storyboard production contract for KARMA ONE.
# Generates precise drawing briefs; does not falsely claim to generate AI images.
const MAX_BOARDS := 240
const ACTION_PHASES := {
    "course": ["contact gauche", "propulsion", "suspension", "contact droit"],
    "marche": ["appui gauche", "passage", "appui droit", "passage"],
    "danse": ["pose initiale", "transfert poids gauche", "extension", "transfert poids droit", "retour"],
    "chute": ["perte equilibre", "inclinaison", "bascule", "impact", "immobilisation"],
    "trebuche": ["obstacle", "deséquilibre", "rattrapage"],
    "saut": ["preparation", "impulsion", "envol", "sommet", "reception"],
    "releve": ["au sol", "appui mains", "genoux", "debout"],
    "salut": ["bras bas", "bras leve", "main oscillante", "bras bas"],
    "repos": ["pose stable"]
}

func make_plan(story: String, reference_images: Array, seconds: float, target_fps: int = 30) -> Dictionary:
    var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
    var parsed: Dictionary = planner.plan(story, seconds)
    var steps: Array = parsed.get("steps", [])
    var boards: Array = []
    var warnings: Array[String] = []
    if steps.is_empty():
        warnings.append("Aucune action connue : utiliser un generateur de scenario avant de dessiner.")
    var character_ids: Array = []
    for i in range(reference_images.size()):
        character_ids.append({"id": "character_%02d" % (i + 1), "reference": str(reference_images[i]), "appearance_locked": true})
    if character_ids.is_empty():
        warnings.append("Aucune image de reference : la creation du personnage necessite un dessinateur generatif.")
    for step_index in range(steps.size()):
        var step: Dictionary = steps[step_index]
        var action: String = str(step.get("action", "repos"))
        var phases: Array = ACTION_PHASES.get(action, ACTION_PHASES["repos"])
        # More key drawings for longer action sequences, capped for mobile memory.
        var step_duration: float = maxf(0.1, float(step.get("end", seconds)) - float(step.get("start", 0.0)))
        var desired: int = clampi(ceili(step_duration * 3.0), phases.size(), 48)
        for k in range(desired):
            if boards.size() >= MAX_BOARDS:
                warnings.append("Limite de planches atteinte : diviser le film en sequences.")
                break
            var t: float = float(k) / float(maxi(1, desired - 1))
            var phase_index: int = mini(phases.size() - 1, int(floor(t * phases.size())))
            var moment: float = float(step.get("start", 0.0)) + t * step_duration
            boards.append({
                "id": "board_%04d" % (boards.size() + 1),
                "scene": step_index + 1,
                "time_seconds": moment,
                "action": action,
                "phase": phases[phase_index],
                "story_context": str(step.get("description", story)),
                "characters": character_ids.duplicate(true),
                "background_policy": "preserve_across_scene",
                "camera_policy": "preserve_unless_scripted",
                "drawing_instruction": "Dessiner l'action '%s' a la phase '%s'. Respecter exactement les references de personnages, les couleurs, les proportions, les accessoires et le decor des planches adjacentes." % [action, phases[phase_index]],
                "status": "needs_drawing",
                "image_path": ""
            })
    return {
        "schema_version": 1,
        "story": story,
        "fps": maxi(1, target_fps),
        "duration_seconds": maxf(0.1, seconds),
        "characters": character_ids,
        "boards": boards,
        "warnings": warnings,
        "intermediate_frames": {"method": "optical_flow_or_motion_interpolation", "target_fps": maxi(1, target_fps), "requires_real_keyframe_images": true},
        "ready_for_animation": false
    }

func validate_drawings(plan: Dictionary) -> Dictionary:
    var missing: Array[String] = []
    for board in plan.get("boards", []):
        if str(board.get("image_path", "")).is_empty() or str(board.get("status", "")) != "approved":
            missing.append(str(board.get("id", "unknown")))
    return {"ok": not plan.get("boards", []).is_empty() and missing.is_empty(), "missing": missing}
