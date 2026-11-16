extends RefCounted
# Image-first storyboard production contract for KARMA ONE.
# Generates precise drawing briefs; does not falsely claim to generate AI images.
const MAX_BOARDS := 240
const REMOTE_BRIEF_VERSION := "v54-batch-5"
# Physical states, restricted to the current action. Sending the entire story
# to every edit encouraged multiple simultaneous poses and duplicate subjects.
const REMOTE_POSES := {
    # A continuous dance phrase, sampled across the whole action rather than
    # restarting the same few vague poses in every remote batch.
    "danse": [
        "dance begins with weight over the left support, knees softly bent, torso slightly left, existing arms low",
        "weight stays left, right heel lifts, torso begins shifting toward center",
        "right knee lifts slightly forward, left support stays planted, arms counterbalance",
        "right support steps to the right, torso follows, knees remain soft",
        "weight transfers right, left heel lifts, left arm begins extending outward",
        "left support draws inward, torso turns slightly left, right arm extends forward",
        "both supports grounded, knees bend, existing arms open halfway to the sides",
        "weight shifts left, torso rises, existing arms open farther to the sides",
        "right heel lifts, torso turns slightly right, open arms counterbalance",
        "right support crosses slightly in front of left, torso follows the crossing step",
        "left support steps outward to uncross, knees bend, arms start lowering",
        "both supports planted apart, body lowers into a shallow crouch, arms lowered for balance",
        "weight shifts right while crouched, torso leans slightly right, head follows torso",
        "body lowers farther with knees flexed, existing arms stay beside the body without touching ground",
        "body starts rising, weight transfers left, arms begin opening again",
        "dance phrase ends with weight over the right support, left heel lifted, knees softly bent and arms partly open"
    ],
    "course": ["forward lean, left support contacting ground, right limb trailing", "push off the ground, rear limb extended", "airborne stride, supports separated", "right support contacting ground, left limb trailing"],
    "trebuche": ["leading support catches on the ground while momentum continues forward", "support blocked, body pitching forward, existing limbs spread to recover balance", "balance lost, body tipping farther forward, no stable support"],
    "roule": ["initial position, existing object touching its support", "existing object rotates while translating along the requested path", "existing object farther along the same path, rotation continues"],
    "rebond": ["existing object descending toward the existing surface", "existing object contacts the surface", "existing object rising away from the surface after impact", "existing object at the apex of its rebound"],
    "interaction": ["existing participants preparing the requested interaction", "existing participants carrying out the requested interaction with each other", "existing participants completing the requested interaction"],
    "chute": ["balance lost, body tilting forward above the ground", "body halfway down, descending toward ground", "body nearly horizontal, just above ground", "impact with ground, body horizontal", "lying still on the ground after the fall, no standing pose"]
}

func remote_frame(story: String, seconds: float, count: int, index: int) -> Dictionary:
    var motion: Dictionary = load("res://scripts/story_motion_planner.gd").new().plan(story, seconds)
    var steps: Array = motion.get("steps", [])
    if not motion.get("ok", false) or count < 2 or index < 0 or index >= count:
        return {"ok": false, "error": "Plan de dessins invalide."}
    if count < steps.size():
        return {"ok": false, "error": "Choisis au moins %d dessins pour couvrir les %d actions." % [steps.size(), steps.size()]}
    # Reserve a drawing for every action, even for a brief stumble between
    # longer actions. Remaining drawings follow their relative durations.
    var allocation: Array[int] = []
    for step in steps:
        allocation.append(1)
    for unused in range(count - steps.size()):
        var best: int = 0
        var score: float = -1.0
        for s in range(steps.size()):
            var weight: float = (float(steps[s]["end"]) - float(steps[s]["start"])) / float(allocation[s])
            if weight > score:
                score = weight
                best = s
        allocation[best] += 1
    var offset: int = 0
    for s in range(steps.size()):
        if index >= offset + allocation[s]:
            offset += allocation[s]
            continue
        var action: String = str(steps[s]["action"])
        var phase: float = float(index - offset) / float(allocation[s] - 1) if allocation[s] > 1 else (1.0 if s == steps.size() - 1 else 0.5)
        var pose: String = phase_at(action, phase)
        if REMOTE_POSES.has(action):
            var poses: Array = REMOTE_POSES[action]
            pose = str(poses[mini(poses.size() - 1, int(floor(phase * poses.size())))])
        var instruction: String = "Create exactly one full-frame drawing of the scene from image 1, retaining ALL existing subjects, characters, animals, vehicles, objects, and environmental landmarks unless this action explicitly changes them. Current action only: %s. Required physical state: %s. Move only the subjects and objects involved in this action, keeping other scene elements stable. Preserve each subject's identity, existing anatomy or object structure, proportions, materials, markings, colors, and spatial relationships. Preserve the background and perspective unless the action explicitly requires a change. Do not add human anatomy to a non-human subject or change its species or object type. Show the requested physical action, not merely camera motion, zoom, or image deformation. No duplicate subjects, invented objects, motion trails, collage, grid, captions, or extra panels." % [str(steps[s]["description"]), pose]
        return {"ok": true, "action": action, "phase": phase, "description": str(steps[s]["description"]), "pose": pose, "instruction": instruction, "sequence_index": index, "sequence_count": count, "action_index": index - offset, "action_count": allocation[s]}
    return {"ok": false, "error": "Action du dessin introuvable."}
const ACTION_PHASES := {
    "course": ["contact gauche", "propulsion", "suspension", "contact droit"],
    "marche": ["appui gauche", "passage", "appui droit", "passage"],
    "danse": ["appui gauche flechi", "talon droit leve", "genou droit leve", "pas lateral droit", "transfert droit", "rotation et bras avant", "ouverture des bras", "extension laterale", "rotation droite", "pas croise", "decroisement", "flexion", "transfert bas", "accroupissement", "remontee", "appui droit final"],
    "chute": ["perte equilibre", "inclinaison", "bascule", "impact", "immobilisation"],
    "trebuche": ["obstacle", "deséquilibre", "rattrapage"],
    "saut": ["preparation", "impulsion", "envol", "sommet", "reception"],
    "releve": ["au sol", "appui mains", "genoux", "debout"],
    "salut": ["bras bas", "bras leve", "main oscillante", "bras bas"],
    "repos": ["pose stable"],
    "transformation": ["forme initiale", "premiers changements visibles", "transformation a mi-parcours", "forme finale"],
    "metro": ["approche du quai", "arrivee du train", "portes ouvertes", "depart du train"],
    "football": ["approche du ballon", "preparation du tir", "contact", "trajectoire du ballon"],
    "vol": ["preparation", "decollage", "ascension", "vol stabilise", "atterrissage"],
    "roule": ["position initiale", "rotation et translation", "roulement en cours", "position plus loin sur le trajet"],
    "rebond": ["descente", "contact avec la surface", "remontee apres impact", "sommet du rebond"],
    "interaction": ["preparation de l interaction demandee", "interaction en cours entre les participants existants", "fin de l interaction demandee"],
    "nage": ["entree dans l eau", "propulsion", "glisse", "nouvelle propulsion", "sortie"],
    "rotation": ["orientation initiale", "quart de tour", "demi-tour", "trois quarts", "orientation finale"],
    "apparition": ["etat initial", "premiers signes", "transition visible", "apparition ou disparition complete"],
    "inconnu": ["etat initial", "debut du changement demande", "action en cours", "fin de l action", "etat final"]
}

func phase_at(action: String, progress: float) -> String:
    # Universal phase labels: unknown actions remain meaningful and never
    # silently become a human standing still.
    var phases: Array = ACTION_PHASES.get(action, [])
    if phases.is_empty():
        phases = ["initial state", "begin requested change", "mid-action", "complete requested change", "final state"]
    var index: int = mini(phases.size() - 1, int(floor(clampf(progress, 0.0, 1.0) * phases.size())))
    return str(phases[index])

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
        var phases: Array = ACTION_PHASES.get(action, ACTION_PHASES["inconnu"])
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
    # Stable continuity keys make it possible for an image generator to reuse
    # approved character sheets and backgrounds instead of reinventing them.
    var continuity: Dictionary = {
        "character_reference_images": reference_images.duplicate(),
        "identity_policy": "strict_reference_match",
        "palette_policy": "locked_across_scene",
        "line_art_policy": "consistent_line_width_and_style",
        "background_policy": "reuse_approved_background",
        "negative_constraints": ["subject identity drift", "unrequested human anatomy", "unrequested shape changes", "flicker", "color shift", "background jump"]
    }
    for board in boards:
        board["continuity"] = continuity.duplicate(true)
        board["required_outputs"] = ["color_image", "foreground_alpha", "character_ids", "approval_status"]
        board["quality_checks"] = ["character_consistency", "anatomy", "palette", "background", "adjacent_frame_motion"]
    return {
        "schema_version": 1,
        "story": story,
        "fps": maxi(1, target_fps),
        "duration_seconds": maxf(0.1, seconds),
        "characters": character_ids,
        "continuity": continuity,
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
