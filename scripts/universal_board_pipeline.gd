extends Node
# Strict engine API. No UI, video encoding or procedural stand-in.
var worker: Node
const REVISION := "v54-registry-density-1"

func _ready() -> void:
    worker = load("res://scripts/hf_studio_generator.gd").new()
    add_child(worker)

func build_boards(reference: Image, story: String, seconds: float, style: String, folder: String) -> Dictionary:
    var plan: Dictionary = await prepare(reference, story, seconds, folder)
    if not plan.get("ok", false):
        return {"ok": false, "stage": "analysis", "detail": plan, "drawings_unchanged": true, "ready_for_animation": false}
    var generation: Dictionary = await generate_keyposes(reference, plan, style, folder)
    if not generation.get("ok", false):
        return {"ok": false, "stage": "generation", "plan": plan, "detail": generation, "ready_for_animation": false}
    var review: Dictionary = await review_and_correct(reference, plan, style, folder)
    return {"ok": review.get("fidelity_verified", false) and plan.get("semantic_analysis", false), "stage": "fidelity_review", "plan": plan, "generation": generation, "quality": review, "human_approved": false, "ready_for_animation": false, "intermediates_generated": 0}

func _write(path: String, value: Dictionary) -> bool:
    var file := FileAccess.open(path + ".part", FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(value, "  "))
    file.close()
    return DirAccess.rename_absolute(path + ".part", path) == OK

func prepare(reference: Image, story: String, seconds: float, folder: String) -> Dictionary:
    if reference == null or reference.is_empty() or story.strip_edges().is_empty():
        return {"ok": false, "error": "invalid_reference_or_story", "semantic_analysis": false}
    var analyzer: RefCounted = load("res://scripts/reference_visual_analysis.gd").new()
    var digest: String = analyzer.reference_sha(reference)
    var cache: String = folder.path_join("scene.json")
    if FileAccess.file_exists(cache):
        var scene: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache))
        if scene is Dictionary and scene.get("story", "") == story and scene.get("analysis_origin", "") == "live_vision_model" and analyzer.validate_scene(scene, digest).get("ok", false):
            return prepare_from_scene(reference, scene, seconds, folder)
    var response: Dictionary = await worker.analyze_scene(reference, story)
    if not response.get("ok", false):
        return {"ok": false, "error": response.get("error", "vision_unavailable"), "semantic_analysis": false, "drawings_unchanged": true}
    var scene: Dictionary = response["scene"]
    scene["story"] = story
    return prepare_from_scene(reference, scene, seconds, folder)

func prepare_from_scene(reference: Image, scene: Dictionary, seconds: float, folder: String, allow_annotation: bool = false) -> Dictionary:
    if reference == null or reference.is_empty():
        return {"ok": false, "error": "invalid_reference"}
    var analyzer: RefCounted = load("res://scripts/reference_visual_analysis.gd").new()
    var checked: Dictionary = analyzer.validate_scene(scene, analyzer.reference_sha(reference))
    if not checked.get("ok", false):
        return checked
    if not checked["semantic_analysis"] and not allow_annotation:
        return {"ok": false, "error": "automatic_vision_not_executed", "semantic_analysis": false}
    var plan: Dictionary = load("res://scripts/board_generation_plan.gd").new().calculate_density(scene, seconds)
    if not plan.get("ok", false):
        return plan
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        return {"ok": false, "error": "project_directory_failed"}
    if FileAccess.file_exists(folder.path_join("plan.json")):
        var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("plan.json")))
        if existing is Dictionary and (existing.get("reference_sha", "") != scene["reference_sha"] or existing.get("story", "") != scene.get("story", "")):
            return {"ok": false, "error": "new_project_directory_required_existing_drawings_kept"}
    plan["story"] = scene.get("story", "")
    plan["revision"] = REVISION
    plan["scene"] = scene
    plan["reference_measurements"] = analyzer.analyze(reference)
    if not _write(folder.path_join("scene.json"), scene) or not _write(folder.path_join("plan.json"), plan):
        return {"ok": false, "error": "plan_save_failed"}
    return plan

func _binding(plan: Dictionary, index: int, style: String) -> String:
    var style_hash: String = ""
    if worker.style_reference != null:
        style_hash = load("res://scripts/reference_visual_analysis.gd").new().reference_sha(worker.style_reference)
    var context: Dictionary = {"entities": plan["scene"]["entities"], "relations": plan["scene"].get("relations", [])}
    # Godot JSON reloads integer numbers as floats. Canonicalize before hashing
    # so simply reopening a project does not invalidate every cached drawing.
    var canonical_context: String = JSON.stringify(JSON.parse_string(JSON.stringify(context)))
    var canonical_pose: String = JSON.stringify(JSON.parse_string(JSON.stringify(plan["boards"][index])))
    return (REVISION + str(plan["reference_sha"]) + canonical_context + canonical_pose + style + style_hash).sha256_text()

func _cached(plan: Dictionary, index: int, style: String, folder: String) -> bool:
    var path: String = folder.path_join("pose_%04d.png" % index)
    var meta_path: String = folder.path_join("pose_%04d.json" % index)
    if not FileAccess.file_exists(path) or not FileAccess.file_exists(meta_path):
        return false
    var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
    if not meta is Dictionary or meta.get("image_sha", "") != FileAccess.get_sha256(path):
        return false
    var wanted: String = _binding(plan, index, style)
    if meta.get("binding", "") == wanted:
        return true
    # Migrate the diagnostic cache written earlier in this development session.
    # Old pixels still require review; this only avoids recomputing candidates.
    var style_hash: String = ""
    if worker.style_reference != null:
        style_hash = load("res://scripts/reference_visual_analysis.gd").new().reference_sha(worker.style_reference)
    var old_pose: Dictionary = plan["boards"][index].duplicate(true)
    old_pose["index"] = int(old_pose["index"])
    old_pose["video_frame"] = int(old_pose["video_frame"])
    var old: String = (REVISION + str(plan["reference_sha"]) + JSON.stringify(plan["scene"]) + JSON.stringify(old_pose) + style + style_hash).sha256_text()
    if meta.get("binding", "") == old:
        meta["binding"] = wanted
        meta["binding_migrated_without_generation"] = true
        return _write(meta_path, meta)
    return false

func _trusted_previous(folder: String, index: int, plan: Dictionary = {}, style: String = "original") -> Image:
    if index <= 0:
        return null
    if plan.is_empty() or not _cached(plan, index - 1, style, folder):
        return null
    var path: String = folder.path_join("pose_%04d.png" % (index - 1))
    var meta_path: String = folder.path_join("pose_%04d.json" % (index - 1))
    if not FileAccess.file_exists(meta_path) or not FileAccess.file_exists(path):
        return null
    var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
    if not meta is Dictionary or not (meta.get("fidelity_verified", false) or meta.get("human_approved", false)) or meta.get("image_sha", "") != FileAccess.get_sha256(path):
        return null
    var image := Image.new()
    return image if image.load(path) == OK else null

func batch_limit(plan: Dictionary, index: int, style: String) -> int:
    # Mixed actions in one model call leaked the stumbling prop into later
    # phases. Complex contacts/occlusions get an entire generated image.
    var id: String = plan["boards"][index]["step_id"]
    for step in plan["steps"]:
        if step["id"] == id:
            var features: Dictionary = step["requested_features"]
            if step["mobile_subjects"] > 1 or float(features["interaction"]) > 0.5 or float(features["occlusion"]) > 0.3 or float(features["camera"]) > 0.0:
                return 1
            return worker.max_batch_size(style)
    return 1

func _save_drawing(image: Image, plan: Dictionary, index: int, style: String, folder: String, quality: Dictionary, repair_reason: String = "") -> bool:
    var path: String = folder.path_join("pose_%04d.png" % index)
    if not _store_image(image, path):
        return false
    return _write(folder.path_join("pose_%04d.json" % index), {"pose_id": plan["boards"][index]["id"], "binding": _binding(plan, index, style), "image_sha": FileAccess.get_sha256(path), "technical_quality": quality, "repair_reason": repair_reason, "fidelity_verified": false, "human_approved": false})

func _store_image(image: Image, path: String) -> bool:
    if image.save_png(path + ".part") != OK:
        return false
    if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != FileAccess.get_sha256(path + ".part"):
        var history: String = path.get_base_dir().path_join("history")
        if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(history)) != OK:
            return false
        var previous: String = history.path_join(path.get_file().get_basename() + "_" + FileAccess.get_sha256(path).substr(0, 16) + ".png")
        if not FileAccess.file_exists(previous) and DirAccess.copy_absolute(path, previous) != OK:
            return false
    return DirAccess.rename_absolute(path + ".part", path) == OK

func generate_keyposes(reference: Image, plan: Dictionary, style: String, folder: String) -> Dictionary:
    if not plan.get("ok", false) or not plan.has("scene"):
        return {"ok": false, "error": "valid_prepared_plan_required"}
    var check: Dictionary = load("res://scripts/reference_visual_analysis.gd").new().validate_scene(plan["scene"], load("res://scripts/reference_visual_analysis.gd").new().reference_sha(reference))
    if not check.get("ok", false):
        return check
    worker.job_folder = folder.path_join("jobs")
    worker.scene_registry = plan["scene"]
    var paths: Array[String] = []
    var previous: Image = null
    var pending: Array = []
    var failure: String = ""
    var reused: int = 0
    var session: RefCounted = load("res://scripts/karma_studio_session.gd").new()
    for i in range(plan["boards"].size()):
        var path: String = folder.path_join("pose_%04d.png" % i)
        var image := Image.new()
        var cached: bool = _cached(plan, i, style, folder) and image.load(path) == OK
        if cached:
            reused += 1
        else:
            if pending.is_empty():
                var briefs: Array = []
                for j in range(i, mini(plan["boards"].size(), i + batch_limit(plan, i, style))):
                    if plan["boards"][j]["step_id"] != plan["boards"][i]["step_id"]:
                        break
                    if j > i and _cached(plan, j, style, folder):
                        break
                    briefs.append(plan["boards"][j])
                # Technical validity alone must never make an invented object
                # in one drawing the visual reference for the following batch.
                var response: Dictionary = await worker.redraw_batch(reference, briefs, style, _trusted_previous(folder, i, plan, style))
                if not response.get("ok", false):
                    failure = str(response.get("error", "generation_failed"))
                    break
                pending = response["images"].duplicate()
                if response.has("sheet"):
                    if not _store_image(response["sheet"], folder.path_join("raw_batch_%04d.png" % i)):
                        failure = "raw_sheet_save_failed"
                        break
            image = pending.pop_front()
        var quality: Dictionary = session.inspect_frame(image, previous)
        if not quality.get("ok", false):
            if not cached:
                image.save_png(folder.path_join("rejected_candidate_%04d.png" % i))
            failure = "technical_quality_failed_at_%d: %s" % [i, str(quality.get("issues", []))]
            break
        if not cached and not _save_drawing(image, plan, i, style, folder, quality):
            failure = "drawing_save_failed"
            break
        paths.append(path)
        previous = image
    var result: Dictionary = {"ok": failure.is_empty() and paths.size() == plan["keyposes"], "paths": paths, "keyposes_required": plan["keyposes"], "keyposes_generated": paths.size(), "reused": reused, "intermediates_required": plan["intermediate_drawings"], "intermediates_generated": 0, "semantic_analysis": plan["semantic_analysis"], "analysis_origin": plan["analysis_origin"], "automatic_fidelity_check": "unavailable", "fidelity_verified": false, "human_approved": false, "ready_for_animation": false, "error": failure, "engines": worker.engine_status.duplicate(true)}
    _write(folder.path_join("generation.json"), result)
    return result

func repair_keypose(reference: Image, plan: Dictionary, style: String, folder: String, index: int, defect: String) -> Dictionary:
    if index < 0 or index >= plan.get("boards", []).size() or defect.strip_edges().is_empty():
        return {"ok": false, "error": "invalid_targeted_repair"}
    var other_hashes: Dictionary = {}
    for i in range(plan["keyposes"]):
        var p: String = folder.path_join("pose_%04d.png" % i)
        if i != index and FileAccess.file_exists(p):
            other_hashes[p] = FileAccess.get_sha256(p)
    var previous: Image = _trusted_previous(folder, index, plan, style)
    worker.job_folder = folder.path_join("jobs")
    worker.scene_registry = plan["scene"]
    var candidate := Image.new()
    var candidate_path: String = folder.path_join("pose_%04d.png" % index)
    if not FileAccess.file_exists(candidate_path) or candidate.load(candidate_path) != OK:
        return {"ok": false, "error": "repair_candidate_missing_original_kept"}
    worker.repair_target = candidate
    var response: Dictionary = await worker.redraw(reference, str(plan["boards"][index]["instruction"]) + " Correct this specific defect only: " + defect, style, previous, true)
    worker.repair_target = null
    if not response.get("ok", false):
        return response
    var image: Image = response["image"]
    var quality: Dictionary = load("res://scripts/karma_studio_session.gd").new().inspect_frame(image, previous)
    if not quality.get("ok", false):
        return {"ok": false, "error": "repair_technical_quality_failed_original_kept"}
    var path: String = folder.path_join("pose_%04d.png" % index)
    if FileAccess.file_exists(path):
        DirAccess.copy_absolute(path, folder.path_join("before_repair_%04d_%s.png" % [index, FileAccess.get_sha256(path).substr(0, 12)]))
    if not _save_drawing(image, plan, index, style, folder, quality, defect):
        return {"ok": false, "error": "repair_save_failed"}
    for p in other_hashes:
        if FileAccess.get_sha256(p) != other_hashes[p]:
            return {"ok": false, "error": "unrelated_drawing_changed"}
    return {"ok": true, "path": path, "other_drawings_unchanged": true, "fidelity_verified": false, "human_approved": false}

func review_keyposes(reference: Image, plan: Dictionary, folder: String) -> Dictionary:
    worker.scene_registry = plan["scene"]
    var failed: Array[int] = []
    for start in range(0, plan["keyposes"], 4):
        var images: Array[Image] = []
        var expected: Array = []
        for i in range(start, mini(start + 4, plan["keyposes"])):
            var image := Image.new()
            if image.load(folder.path_join("pose_%04d.png" % i)) != OK:
                return {"ok": false, "fidelity_verified": false, "error": "missing_keypose"}
            images.append(image)
            expected.append(plan["boards"][i])
        var result: Dictionary = await worker.assess_keyposes(reference, images, expected)
        _write(folder.path_join("vision_review_%04d.json" % start), result)
        if not result.get("ok", false):
            return result
        for row in result["review"]["frames"]:
            var index: int = start + int(row["index"])
            var passed: bool = row.get("uncertain", true) == false and row.get("defects", []).is_empty()
            for key in ["identity_match", "count_match", "action_match", "environment_match", "perspective_match"]:
                passed = passed and row.get(key) == true
            var meta_path: String = folder.path_join("pose_%04d.json" % index)
            var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
            if not meta is Dictionary or meta.get("image_sha", "") != FileAccess.get_sha256(folder.path_join("pose_%04d.png" % index)):
                return {"ok": false, "fidelity_verified": false, "error": "drawing_changed_during_review"}
            meta["fidelity_verified"] = passed
            meta["model_review"] = row
            meta["review_origin"] = "live_vision_model"
            _write(meta_path, meta)
            if not passed:
                failed.append(index)
    return {"ok": true, "failed_indices": failed, "fidelity_verified": failed.is_empty(), "human_approved": false}

func review_and_correct(reference: Image, plan: Dictionary, style: String, folder: String, maximum_repairs: int = 1) -> Dictionary:
    var review: Dictionary = await review_keyposes(reference, plan, folder)
    if not review.get("ok", false) or review.get("fidelity_verified", false):
        return review
    var attempts: Array = []
    for index in review["failed_indices"].slice(0, clampi(maximum_repairs, 0, 4)):
        var meta_path: String = folder.path_join("pose_%04d.json" % int(index))
        var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
        var attempt_path: String = folder.path_join("repair_attempt_%04d.json" % int(index))
        if FileAccess.file_exists(attempt_path):
            attempts.append({"index": index, "ok": false, "error": "repair_budget_already_used"})
            continue
        # Persist intent before the GPU call; a crash cannot trigger an
        # unbounded automatic correction loop on the next project resume.
        _write(attempt_path, {"index": index, "state": "started", "image_sha": meta["image_sha"]})
        var result: Dictionary = await repair_keypose(reference, plan, style, folder, int(index), JSON.stringify(meta.get("model_review", {}).get("defects", [])))
        _write(attempt_path, result)
        attempts.append({"index": index, "result": result})
    return {"ok": true, "fidelity_verified": false, "repairs": attempts, "requires_new_fidelity_review": true, "human_approved": false}
