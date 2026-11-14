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
    var previous_scene_id: String = ""
    var previous_action: String = ""
    for index in range(steps.size()):
        var step: Dictionary = steps[index]
        var action: String = str(step.get("action", "repos"))
        var supported_motion: bool = ACTIONS.has(action)
        var spec: Dictionary = ACTIONS.get(action, ACTIONS["repos"])
        if not supported_motion:
            warnings.append("Scene %d : action %s reconnue, mais aucun mouvement 2D correspondant n est implemente." % [index + 1, action])
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
            "rig_motion": spec["rig"] if bool(visual["implemented"]) and supported_motion else "none",
            "visual_engine": visual["engine"],
            "visual_engine_status": visual["status"],
            "requires_visual_generation": not supported_motion or not bool(visual["implemented"]) or needs_reference_redraw,
            "keyframes": frames,
            "background": "preserve",
            "character_id": "main",
            "continuity": {"from_scene": previous_scene_id, "previous_action": previous_action, "same_character": true, "preserve_last_pose": index > 0, "transition_frames": mini(6, maxi(0, end_frame - start_frame - 1)) if index > 0 else 0},
            "status": "needs_motion_implementation" if not supported_motion else ("needs_reference_redraw" if needs_reference_redraw else "pending_draw")
        })
        previous_scene_id = "scene_%03d" % (index + 1)
        previous_action = action
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
            if str(pose.get("image_path", "")).is_empty():
                problems.append(str(pose.get("asset_id", "unknown")) + " image manquante")
            if str(pose.get("pixel_sha256", "")).is_empty():
                problems.append(str(pose.get("asset_id", "unknown")) + " empreinte visuelle manquante")
        if bool(scene.get("requires_visual_generation", false)):
            var hashes: Dictionary = {}
            for pose in scene.get("keyframes", []):
                var digest: String = str(pose.get("pixel_sha256", ""))
                if not digest.is_empty():
                    hashes[digest] = true
            if hashes.size() < 2:
                problems.append(str(scene.get("id", "scene")) + " : aucun changement de posture visuel prouve")
    if project.get("scenes", []).is_empty():
        problems.append("Aucune scene.")
    return {"ok": problems.is_empty(), "errors": problems}

# Connect the planner's scene boundary to the articulated pose interpolator.
# The caller supplies actual detected/approved landmark arrays for each scene.
# Missing poses are reported; no fabricated human detection is performed.
func build_pose_transitions(project: Dictionary, scene_landmarks: Dictionary) -> Dictionary:
    var scenes: Array = project.get("scenes", [])
    var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
    var transitions: Array = []
    var errors: Array[String] = []
    for i in range(1, scenes.size()):
        var previous_scene: Dictionary = scenes[i - 1]
        var current_scene: Dictionary = scenes[i]
        var previous_id: String = str(previous_scene.get("id", ""))
        var current_id: String = str(current_scene.get("id", ""))
        var previous_data: Dictionary = scene_landmarks.get(previous_id, {})
        var current_data: Dictionary = scene_landmarks.get(current_id, {})
        var ending: Array = previous_data.get("end", [])
        var starting: Array = current_data.get("start", [])
        var continuity: Dictionary = current_scene.get("continuity", {})
        if str(continuity.get("from_scene", "")) != previous_id:
            errors.append("Scene %s: continuity link missing" % current_id)
            continue
        var count: int = int(continuity.get("transition_frames", 0))
        var result: Dictionary = rig.transition_between_actions(ending, starting, count)
        if not bool(result.get("ok", false)):
            errors.append("Scene %s: %s" % [current_id, str(result.get("error", "invalid pose"))])
            continue
        transitions.append({"from_scene": previous_id, "to_scene": current_id,
            "start_frame": int(current_scene.get("start_frame", 0)),
            "poses": result["frames"], "count": result["count"],
            "status": "ready_for_skeleton_render"})
    return {"ok": errors.is_empty(), "transitions": transitions, "errors": errors}

# Render actual articulated transition images ready for a frame encoder.
# These frames depict a skeleton; painting the original photographed character
# requires a separate character-layer/rig mapping step.
func render_pose_transitions(transition_plan: Dictionary, width: int = 360, height: int = 480) -> Dictionary:
    if not bool(transition_plan.get("ok", false)):
        return {"ok": false, "error": "Invalid transition plan", "frames": []}
    if width < 64 or height < 64 or width > 2048 or height > 2048:
        return {"ok": false, "error": "Invalid render dimensions", "frames": []}
    var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
    var rendered: Array = []
    for transition in transition_plan.get("transitions", []):
        var images: Array[Image] = []
        for pose in transition.get("poses", []):
            var frame := Image.create(width, height, false, Image.FORMAT_RGBA8)
            frame.fill(Color("#172033"))
            var result: Dictionary = rig.draw_skeleton(frame, pose)
            if not bool(result.get("ok", false)):
                return {"ok": false, "error": "Invalid landmark frame", "frames": []}
            images.append(frame)
        rendered.append({"from_scene": transition.get("from_scene", ""),
            "to_scene": transition.get("to_scene", ""), "images": images,
            "count": images.size(), "status": "rendered_skeleton"})
    return {"ok": true, "frames": rendered, "format": "rgba8"}
