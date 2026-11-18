extends RefCounted
const SCENE_SCHEMA := 1
func reference_sha(source: Image) -> String:
    if source == null or source.is_empty():
        return ""
    var copy: Image = source.duplicate()
    copy.convert(Image.FORMAT_RGBA8)
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(str(copy.get_size()).to_utf8_buffer())
    hash.update(copy.get_data())
    return hash.finish().hex_encode()
# Deterministic visual measurements from the actual selected image.
# Not a semantic vision model: never invents subject identity or clothing.
func analyze(source: Image) -> Dictionary:
    if source == null or source.is_empty():
        return {"ok": false, "error": "empty_reference"}
    var img: Image = source.duplicate()
    img.convert(Image.FORMAT_RGBA8)
    var w: int = img.get_width()
    var h: int = img.get_height()
    var stride: int = maxi(1, maxi(w, h) / 256)
    var visible: int = 0
    var total: int = 0
    var min_x: int = w
    var min_y: int = h
    var max_x: int = -1
    var max_y: int = -1
    for y in range(0, h, stride):
        for x in range(0, w, stride):
            total += 1
            if img.get_pixel(x, y).a < 0.5:
                continue
            visible += 1
            min_x = mini(min_x, x)
            min_y = mini(min_y, y)
            max_x = maxi(max_x, x)
            max_y = maxi(max_y, y)
    if visible < 16:
        return {"ok": false, "error": "reference_has_no_visible_subject"}
    var palette: Dictionary = load("res://scripts/reference_appearance_palette.gd").new().extract(source)
    if not palette.get("ok", false):
        return {"ok": false, "error": "reference_palette_failed"}
    var hex_colors: Array[String] = []
    for color in palette.get("palette", []):
        hex_colors.append("#" + (color as Color).to_html(false))
    # Alpha bounding box only identifies a subject on a transparent image.
    # For opaque photos the whole image is visible: never mislabel it as subject segmentation.
    var has_alpha_subject: bool = visible < total
    var bbox: Rect2 = Rect2(float(min_x) / w, float(min_y) / h, float(max_x - min_x + stride) / w, float(max_y - min_y + stride) / h)
    return {
        "ok": true,
        "width": w,
        "height": h,
        "aspect_ratio": float(w) / float(h),
        "visible_fraction": float(visible) / float(maxi(1, total)),
        "bounds_normalized": bbox,
        "bounds_are_subject": has_alpha_subject,
        "palette_hex": hex_colors,
        "semantic_analysis": false,
        "reference_required": true
    }

func drawing_guidance(profile: Dictionary) -> String:
    if not profile.get("ok", false):
        return ""
    var bounds: Rect2 = profile["bounds_normalized"]
    var bounds_kind: String = "alpha-visible subject bounds" if profile.get("bounds_are_subject", false) else "full opaque photo bounds (NOT subject detection)"
    return "IMAGE-LOCKED REFERENCE: the actual user-selected image is authoritative, not a generic text character. Reference dimensions %d x %d, aspect %.3f, visible coverage %.2f, %s normalized x=%.2f y=%.2f width=%.2f height=%.2f, dominant colors %s. Preserve the reference subject's distinctive silhouette, face if present, hair if present, outfit if present, materials, visual style and palette. Do not invent a human body, new clothing or unrelated subject. Create distinct action keyframes while keeping the same subject recognizable. These are pixel measurements, not semantic AI recognition." % [
        int(profile["width"]), int(profile["height"]), float(profile["aspect_ratio"]), float(profile["visible_fraction"]),
        bounds_kind, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y, ", ".join(profile["palette_hex"])
    ]

func validate_scene(scene: Dictionary, reference_sha: String) -> Dictionary:
    # A schema check is NOT visual recognition. Provenance remains explicit.
    if scene.get("reference_sha", "") != reference_sha or reference_sha.is_empty():
        return {"ok": false, "error": "scene_reference_mismatch"}
    if not scene.get("entities") is Array or scene["entities"].is_empty() or not scene.get("steps") is Array or scene["steps"].is_empty():
        return {"ok": false, "error": "missing_entities_or_actions"}
    var ids: Dictionary = {}
    for entity in scene["entities"]:
        if not entity is Dictionary:
            return {"ok": false, "error": "invalid_entity"}
        var id: String = str(entity.get("id", ""))
        if not entity.get("id") is String or id.is_empty() or ids.has(id) or not entity.get("kind") is String or str(entity.get("kind", "")).is_empty() or not entity.get("appearance") is String or str(entity.get("appearance", "")).is_empty() or not entity.get("invariants") is Array or not entity.get("allowed_changes") is Array:
            return {"ok": false, "error": "invalid_entity_identity_or_policy"}
        if entity.get("origin", "") not in ["visible", "requested"]:
            return {"ok": false, "error": "entity_origin_required"}
        if entity["origin"] == "visible":
            var box: Variant = entity.get("bbox")
            if not box is Array or box.size() != 4:
                return {"ok": false, "error": "visible_entity_bounds_required"}
            # Vision models may round normalized coordinates slightly outside [0, 1].
            # Repair only edge-rounding drift; never silently accept pixel coordinates
            # or fabricated boxes. Preserve the original model response as evidence.
            var normalized_box: Array = []
            for coordinate in box:
                if not (coordinate is float or coordinate is int):
                    return {"ok": false, "error": "invalid_entity_bounds"}
                var value: float = float(coordinate)
                if not is_finite(value) or value < -0.01 or value > 1.01:
                    return {"ok": false, "error": "invalid_entity_bounds"}
                normalized_box.append(clampf(value, 0.0, 1.0))
            if float(normalized_box[2]) <= 0.0 or float(normalized_box[3]) <= 0.0 or float(normalized_box[0]) + float(normalized_box[2]) > 1.001 or float(normalized_box[1]) + float(normalized_box[3]) > 1.001:
                return {"ok": false, "error": "entity_bounds_outside_reference"}
            entity["bbox"] = normalized_box
        ids[id] = entity
    var step_ids: Dictionary = {}
    for step in scene["steps"]:
        if not step is Dictionary or not step.get("id") is String or str(step.get("id", "")).is_empty() or step_ids.has(str(step.get("id", ""))):
            return {"ok": false, "error": "invalid_action_identity"}
        step_ids[step["id"]] = true
        if not step.get("actor_ids") is Array or not step.get("object_ids") is Array or not step.get("phases") is Array or step["phases"].is_empty() or str(step.get("instruction", "")).is_empty():
            return {"ok": false, "error": "action_roles_and_phases_required"}
        for key in ["actor_ids", "object_ids"]:
            for id in step[key]:
                if not id is String or not ids.has(id):
                    return {"ok": false, "error": "unresolved_entity_id: " + str(id)}
        if step["actor_ids"].is_empty() and float(step.get("camera", 0.0)) <= 0.0 and not step.get("static", false):
            return {"ok": false, "error": "moving_action_has_no_actor"}
        for feature in ["speed", "amplitude", "interaction", "occlusion", "camera"]:
            var value: Variant = step.get(feature)
            if not (value is float or value is int) or not (float(value) >= 0.0 and float(value) <= 1.0):
                return {"ok": false, "error": "missing_or_invalid_motion_feature: " + feature}
        if not (step.get("weight") is float or step.get("weight") is int) or not (float(step.get("weight", 0.0)) > 0.0 and float(step.get("weight", 0.0)) < 1000000000.0):
            return {"ok": false, "error": "positive_duration_weight_required"}
        if not step.get("static") is bool:
            return {"ok": false, "error": "static_flag_must_be_boolean"}
        if not step.get("static", false) and step["phases"].size() < 2:
            return {"ok": false, "error": "moving_action_requires_multiple_physical_phases"}
        for phase in step["phases"]:
            if not phase is String or phase.strip_edges().is_empty():
                return {"ok": false, "error": "empty_physical_phase"}
        if step.get("static", false) and (float(step["speed"]) + float(step["amplitude"]) + float(step["camera"])) > 0.0:
            return {"ok": false, "error": "static_motion_contradiction"}
    if not scene.get("relations", []) is Array:
        return {"ok": false, "error": "invalid_spatial_relations"}
    for relation in scene.get("relations", []):
        if not relation is Dictionary or not ids.has(str(relation.get("from", ""))) or not ids.has(str(relation.get("to", ""))):
            return {"ok": false, "error": "unresolved_spatial_relation"}
    if not scene.get("unresolved", []) is Array or not scene.get("unresolved", []).is_empty():
        return {"ok": false, "error": "scene_has_unresolved_instructions"}
    var origin: String = str(scene.get("analysis_origin", "unknown"))
    if origin == "live_vision_model" and (str(scene.get("provider", "")).is_empty() or str(scene.get("raw_model_output", "")).is_empty()):
        return {"ok": false, "error": "missing_model_execution_evidence"}
    return {"ok": true, "entities": ids, "semantic_analysis": origin == "live_vision_model", "analysis_origin": origin, "identity_verified": false}
