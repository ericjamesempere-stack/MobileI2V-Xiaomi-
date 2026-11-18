extends RefCounted
# KARMA LYRICS SYNC V6: additive adapter, no alternate storyboard/export path.
func load_manifest(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "error": "manifest_missing"}
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary or not data.get("scenes") is Array:
        return {"ok": false, "error": "invalid_manifest"}
    var scenes: Array = data["scenes"]
    var duration: float = float(data.get("duration", 0))
    if scenes.is_empty() or duration <= 0:
        return {"ok": false, "error": "invalid_duration_or_scenes"}
    var cursor: float = 0
    for scene in scenes:
        if not scene is Dictionary:
            return {"ok": false, "error": "invalid_scene"}
        var start: float = float(scene.get("start", -1))
        var finish: float = float(scene.get("end", -1))
        if absf(start - cursor) > 0.005 or finish <= start:
            return {"ok": false, "error": "timeline_gap_or_overlap"}
        if not scene.get("lyrics_reviewed", false):
            return {"ok": false, "error": "lyrics_review_required"}
        if scene.get("semantic_status", "") != "director_approved":
            return {"ok": false, "error": "director_approval_required"}
        if str(scene.get("action_prompt", "")).strip_edges().is_empty():
            return {"ok": false, "error": "action_prompt_missing"}
        cursor = finish
    if absf(cursor - duration) > 0.005:
        return {"ok": false, "error": "duration_mismatch"}
    return {"ok": true, "scenes": scenes, "duration": duration}

func prepare_existing_pipeline_job(manifest_path: String, scene_index: int, reference: Image, style: String, folder: String) -> Dictionary:
    var doc: Dictionary = load_manifest(manifest_path)
    if not doc.get("ok", false):
        return doc
    if reference == null or reference.is_empty():
        return {"ok": false, "error": "reference_image_required"}
    var scenes: Array = doc["scenes"]
    if scene_index < 0 or scene_index >= scenes.size():
        return {"ok": false, "error": "scene_index_invalid"}
    var scene: Dictionary = scenes[scene_index]
    return {"ok": true, "reference": reference, "story": (str(scene["action_prompt"]) + "\n" + str(scene.get("setting_prompt", ""))).strip_edges(), "seconds": float(scene["end"]) - float(scene["start"]), "style": style, "folder": folder.path_join("scene_%03d" % (scene_index + 1)), "method": "build_boards", "ready_for_export": false, "human_storyboard_approval_required": true}
