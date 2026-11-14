extends RefCounted
# Shared production contract for story planning, drawing and animation.
# No generative model is claimed: this deterministic planner creates actionable
# timelines from supported verbs and records unknown directives for review.
const FPS := 30
const SCHEMA_VERSION := 1
const ACTIONS := {
    "course": {"keyframes": ["contact", "flight", "contact"], "rig": "run"},
    "marche": {"keyframes": ["contact", "passing", "contact"], "rig": "walk"},
    "danse": {"keyframes": ["neutral", "left", "right", "neutral"], "rig": "dance"},
    "saut": {"keyframes": ["anticipation", "takeoff", "airborne", "landing"], "rig": "jump"},
    "trebuche": {"keyframes": ["balance", "stumble", "recover"], "rig": "stumble"},
    "chute": {"keyframes": ["standing", "falling", "ground"], "rig": "fall"},
    "releve": {"keyframes": ["crouched", "half_standing", "standing"], "rig": "stand"},
    "salut": {"keyframes": ["neutral", "wave", "neutral"], "rig": "wave"},
    "repos": {"keyframes": ["neutral"], "rig": "idle"}
}

func build(story: String, duration_seconds: float, reference_image: String = "") -> Dictionary:
    var duration: float = clampf(duration_seconds, 1.0, 180.0)
    var parser: RefCounted = load("res://scripts/story_motion_planner.gd").new()
    var parsed: Dictionary = parser.plan(story, duration)
    var steps: Array = parsed.get("steps", [])
    var router: RefCounted = load("res://scripts/visual_engine_router.gd").new()
    var scenes: Array = []
    var warnings: Array[String] = []
    var total_frames: int = maxi(1, roundi(duration * FPS))
    if steps.is_empty():
        warnings.append("Aucune action reconnue : le dessin et les mouvements demandent une interpretation humaine ou un modele de langage.")
    for index in range(steps.size()):
        var step: Dictionary = steps[index]
        var action: String = str(step.get("action", "repos"))
        var spec: Dictionary = ACTIONS.get(action, ACTIONS["repos"])
        var visual: Dictionary = router.select_engine(action, not reference_image.is_empty())
        var needs_reference_redraw: bool = not reference_image.is_empty() and str(visual["engine"]) == "rig_2d"
        if needs_reference_redraw:
            warnings.append("Scene %d : rig 2D disponible mais redessin du personnage de reference non valide." % [index + 1])
        if not bool(visual["implemented"]):
            warnings.append("Scene %d : moteur %s non disponible." % [index + 1, visual["engine"]])
        var start_frame: int = clampi(roundi(float(step.get("start", 0.0)) * FPS), 0, total_frames - 1)
        var end_frame: int = clampi(roundi(float(step.get("end", duration)) * FPS), start_frame + 1, total_frames)
        var phases: Array = spec["keyframes"]
        var frames: Array = []
        for k in range(phases.size()):
            var frame_number: int = start_frame + roundi(float(k) / float(maxi(1, phases.size() - 1)) * float(end_frame - start_frame - 1))
            frames.append({"frame": frame_number, "phase": phases[k], "asset_id": "scene_%03d_pose_%02d" % [index + 1, k + 1], "status": "pending"})
        scenes.append({
            "id": "scene_%03d" % (index + 1),
            "source_text": str(step.get("description", story)),
            "action": action,
            "start_frame": start_frame,
            "end_frame": end_frame,
            "rig_motion": spec["rig"] if bool(visual["implemented"]) else "none",
            "visual_engine": visual["engine"],
            "visual_engine_status": visual["status"],
            "requires_visual_generation": not bool(visual["implemented"]) or needs_reference_redraw,
            "keyframes": frames,
            "background": "preserve",
            "character_id": "main",
            "status": "needs_reference_redraw" if needs_reference_redraw else "pending_draw"
        })
    return {
        "schema_version": SCHEMA_VERSION,
        "fps": FPS,
        "duration_seconds": duration,
        "total_frames": total_frames,
        "story": story,
        "characters": [{"id": "main", "reference_image": reference_image, "appearance_lock": true, "segmentation_status": "pending"}],
        "scenes": scenes,
        "warnings": warnings,
        "drawing_contract": {"layers": ["background", "character"], "transparent_character": true, "preserve_character_identity": true, "output_format": "png"},
        "animation_contract": {"fps": FPS, "interpolation": "required", "validate_missing_frames": true, "validate_layer_dimensions": true},
        "status": "needs_drawings"
    }

func validate_for_animation(project: Dictionary) -> Dictionary:
    var problems: Array[String] = []
    for scene in project.get("scenes", []):
        for pose in scene.get("keyframes", []):
            if str(pose.get("status", "")) != "approved":
                problems.append(str(pose.get("asset_id", "unknown")) + " non validee")
    if project.get("scenes", []).is_empty():
        problems.append("Aucune scene.")
    return {"ok": problems.is_empty(), "errors": problems}
