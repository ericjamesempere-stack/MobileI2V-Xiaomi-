extends RefCounted
# Offline narrative-to-image prompt adapter for the EXISTING story_motion_planner.
# Does not claim to perform Stable Diffusion inference or to identify a person.
const VERSION := 1
const MAX_SCENES := 24
const MAX_STORY_CHARS := 12000

func compose(story: String, style: String, reference_path: String = "", duration_seconds: float = 5.0) -> Dictionary:
    var clean_story: String = story.strip_edges()
    if clean_story.is_empty() or clean_story.length() > MAX_STORY_CHARS:
        return {"ok": false, "error": "invalid_story_length", "scenes": []}
    if not is_finite(duration_seconds) or duration_seconds <= 0.0 or duration_seconds > 180.0:
        return {"ok": false, "error": "invalid_duration", "scenes": []}
    var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
    var plan: Dictionary = planner.plan(clean_story, duration_seconds)
    var steps: Array = plan.get("steps", [])
    if not plan.get("ok", false) or steps.is_empty() or steps.size() > MAX_SCENES:
        return {"ok": false, "error": "narrative_scene_limit_or_empty", "scenes": []}
    var safe_style: String = style.strip_edges()
    if safe_style.is_empty():
        safe_style = "style original coherent"
    var scenes: Array[Dictionary] = []
    var previous_id: String = ""
    for i in range(steps.size()):
        var step: Dictionary = steps[i]
        var scene_id: String = "scene_%03d" % (i + 1)
        var action_text: String = str(step.get("description", "")).strip_edges()
        var prompt: String = "Scene %d/%d. %s. Style: %s. Preserve subject morphology, clothes, colors, accessories, environment and camera continuity. No unrelated subjects." % [i + 1, steps.size(), action_text, safe_style]
        if not reference_path.is_empty():
            prompt += " Use the provided reference image as identity and composition anchor."
        if i > 0:
            prompt += " Continue from the actual final approved image of the previous scene; do not invent continuity."
        scenes.append({
            "id": scene_id,
            "action": str(step.get("action", "inconnu")),
            "source_text": action_text,
            "prompt": prompt,
            "negative_prompt": "identity drift, changed clothing, altered anatomy, extra limbs, unrelated objects, inconsistent background",
            "start_seconds": float(step.get("start", 0.0)),
            "end_seconds": float(step.get("end", duration_seconds)),
            "reference_image": reference_path if i == 0 else "",
            "previous_scene_id": previous_id,
            "previous_final_image_required": i > 0,
            "status": "pending_real_inference",
            "image_path": "",
            "pixel_sha256": ""
        })
        previous_id = scene_id
    return {"ok": true, "version": VERSION, "source": "existing_story_motion_planner", "duration_seconds": duration_seconds, "scenes": scenes, "inference_verified": false, "images_generated": 0}

func ready_for_next_scene(scenes: Array, index: int) -> Dictionary:
    if index < 0 or index >= scenes.size():
        return {"ok": false, "error": "invalid_scene_index"}
    if index == 0:
        return {"ok": true, "reference_image": str(scenes[0].get("reference_image", ""))}
    var previous: Dictionary = scenes[index - 1]
    var image_path: String = str(previous.get("image_path", ""))
    var expected_hash: String = str(previous.get("pixel_sha256", "")).to_lower()
    if previous.get("status", "") != "approved" or image_path.is_empty() or expected_hash.length() != 64 or not expected_hash.is_valid_hex_number():
        return {"ok": false, "error": "previous_scene_not_approved"}
    if not FileAccess.file_exists(image_path) or FileAccess.get_sha256(image_path).to_lower() != expected_hash:
        return {"ok": false, "error": "previous_scene_image_missing_or_changed"}
    return {"ok": true, "reference_image": image_path}
