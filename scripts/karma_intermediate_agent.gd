extends RefCounted
# KARMA ONE orchestration contract: schedules genuine in-between drawings.
# This agent never claims to have rendered pixels or verified optical flow.
const REVISION := "v54-intermediate-agent-1"

func schedule(plan: Dictionary) -> Dictionary:
    if not plan.get("ok", false):
        return {"ok": false, "error": "invalid_plan"}
    var boards: Array = plan.get("boards", [])
    var steps: Array = plan.get("steps", [])
    var tasks: Array = []
    var unfillable: Array = []
    var used_frames: Dictionary = {}
    var requested_total: int = 0
    for step in steps:
        var step_id: String = str(step.get("id", ""))
        var count: int = int(step.get("intermediate_drawings", 0))
        requested_total += maxi(0, count)
        if count <= 0:
            continue
        var poses: Array = []
        for board in boards:
            if str(board.get("step_id", "")) == step_id:
                poses.append(board)
        if poses.size() < 2:
            unfillable.append({"step_id": step_id, "requested": count, "reason": "requires_two_distinct_keyposes"})
            continue
        # Divide intermediate requests across actual neighboring keyposes, not
        # unrelated actions or scene cuts. Deterministic and quota-free.
        for i in range(count):
            var position: float = float(i + 1) * float(poses.size() - 1) / float(count + 1)
            var left: int = mini(poses.size() - 2, int(floor(position)))
            var alpha: float = position - float(left)
            # A boundary-aligned request would duplicate an existing keypose.
            # Place it strictly inside the preceding adjacent interval instead.
            if alpha <= 0.00001:
                left = maxi(0, left - 1)
                alpha = 0.9
            var a: Dictionary = poses[left]
            var b: Dictionary = poses[left + 1]
            var start_frame: int = int(a.get("video_frame", 0))
            var end_frame: int = int(b.get("video_frame", 0))
            if end_frame <= start_frame + 1:
                unfillable.append({"step_id": step_id, "reason": "no_video_frame_between_keyposes", "from_pose": str(a.get("id", "")), "to_pose": str(b.get("id", ""))})
                continue
            var target_frame: int = clampi(roundi(lerpf(float(start_frame), float(end_frame), alpha)), start_frame + 1, end_frame - 1)
            if used_frames.has(target_frame):
                unfillable.append({"step_id": step_id, "reason": "duplicate_intermediate_frame", "target_frame": target_frame})
                continue
            used_frames[target_frame] = true
            tasks.append({
                "id": "between_%04d" % tasks.size(),
                "step_id": step_id,
                "from_pose": str(a.get("id", "")),
                "to_pose": str(b.get("id", "")),
                "from_frame": start_frame,
                "to_frame": end_frame,
                "target_frame": target_frame,
                "fraction": alpha,
                "actor_ids": a.get("actor_ids", []).duplicate(true),
                "object_ids": a.get("object_ids", []).duplicate(true),
                "instruction": "Draw one new physically plausible intermediate state between the two approved adjacent keyposes. Preserve all entity identities, counts, anatomy or object structure, background, perspective and unaffected scene elements. Advance the action, not camera zoom or image warping.",
                "status": "pending_generation",
                "image_path": "",
                "identity_verified": false,
                "human_approved": false
            })
    tasks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["target_frame"]) < int(b["target_frame"]))
    if requested_total != int(plan.get("intermediate_drawings", 0)):
        unfillable.append({"reason": "intermediate_count_mismatch", "steps_requested": requested_total, "plan_requested": int(plan.get("intermediate_drawings", 0))})
    return {"ok": unfillable.is_empty(), "revision": REVISION, "tasks": tasks, "unfillable": unfillable, "requested": int(plan.get("intermediate_drawings", 0)), "scheduled": tasks.size(), "generated": 0, "verified": false, "ready_for_animation": false}

# Rendering is deliberately separate from scheduling. The orchestrator calls
# this only after keypose generation; human approval remains a later gate.
func render_pending(plan: Dictionary, folder: String, worker: Node, style: String = "original", max_new: int = 4, original_reference: Image = null) -> Dictionary:
    var scheduled: Dictionary = schedule(plan)
    if not scheduled.get("ok", false):
        return {"ok": false, "error": "intermediate_schedule_invalid", "schedule": scheduled}
    if worker == null or not worker.has_method("redraw"):
        return {"ok": false, "error": "drawing_engine_missing"}
    if max_new < 1:
        return {"ok": false, "error": "invalid_render_budget"}
    var boards: Array = plan.get("boards", [])
    var lookup: Dictionary = {}
    for board in boards:
        lookup[str(board.get("id", ""))] = board
    var results: Array = []
    var generated: int = 0
    for task in scheduled["tasks"]:
        var left: Dictionary = lookup.get(str(task["from_pose"]), {})
        var right: Dictionary = lookup.get(str(task["to_pose"]), {})
        var left_path: String = folder.path_join("pose_%04d.png" % int(left.get("index", -1)))
        var right_path: String = folder.path_join("pose_%04d.png" % int(right.get("index", -1)))
        if left.is_empty() or right.is_empty() or not FileAccess.file_exists(left_path) or not FileAccess.file_exists(right_path):
            return {"ok": false, "error": "adjacent_keypose_missing", "task": task["id"], "generated": generated, "results": results}
        var left_image := Image.new()
        var right_image := Image.new()
        if left_image.load(left_path) != OK or right_image.load(right_path) != OK:
            return {"ok": false, "error": "adjacent_keypose_unreadable", "task": task["id"], "generated": generated, "results": results}
        # An image editor with only one reference cannot truly condition on two
        # images. The right pose is a semantic target, not falsely sent as pixels.
        var prompt: String = str(task["instruction"]) + " Earlier physical pose: " + str(left.get("pose", "")) + ". Later physical pose: " + str(right.get("pose", "")) + ". Intermediate fraction: %.3f. Keep all subjects and environmental landmarks." % float(task["fraction"])
        var output_path: String = folder.path_join(str(task["id"]) + ".png")
        var meta_path: String = folder.path_join(str(task["id"]) + ".json")
        var has_original: bool = original_reference != null and not original_reference.is_empty()
        var original_hash: String = original_reference.save_png_to_buffer().hex_encode().sha256_text() if has_original else "legacy-left-pose-only"
        var binding: String = (REVISION + original_hash + FileAccess.get_sha256(left_path) + FileAccess.get_sha256(right_path) + prompt + style).sha256_text()
        if FileAccess.file_exists(output_path) and FileAccess.file_exists(meta_path):
            var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
            if meta is Dictionary and meta.get("binding", "") == binding and meta.get("image_sha", "") == FileAccess.get_sha256(output_path):
                var cached_task: Dictionary = task.duplicate(true)
                cached_task["status"] = "candidate_cached"
                cached_task["image_path"] = output_path
                results.append(cached_task)
                continue
        if generated >= max_new:
            break
        # Original image is the identity anchor; left pose is temporal context.
        # Do not turn a previous generated drawing into the permanent identity.
        var identity_source: Image = original_reference if has_original else left_image
        var response: Dictionary = await worker.redraw(identity_source, prompt, style, left_image)
        if not response.get("ok", false) or not response.get("image") is Image:
            return {"ok": false, "error": "intermediate_generation_failed", "detail": response.get("error", ""), "task": task["id"], "generated": generated, "results": results}
        var candidate: Image = response["image"]
        if candidate.is_empty() or candidate.save_png(output_path + ".part") != OK:
            return {"ok": false, "error": "intermediate_save_failed", "task": task["id"], "generated": generated, "results": results}
        if FileAccess.file_exists(output_path):
            # Do not silently overwrite a previously reviewed drawing.
            DirAccess.remove_absolute(output_path + ".part")
            return {"ok": false, "error": "existing_candidate_requires_explicit_repair", "task": task["id"], "generated": generated, "results": results}
        if DirAccess.rename_absolute(output_path + ".part", output_path) != OK:
            return {"ok": false, "error": "intermediate_rename_failed", "task": task["id"], "generated": generated, "results": results}
        var record: Dictionary = {"binding": binding, "image_sha": FileAccess.get_sha256(output_path), "from_pose": task["from_pose"], "to_pose": task["to_pose"], "target_frame": task["target_frame"], "identity_verified": false, "human_approved": false, "status": "candidate_requires_review"}
        var file := FileAccess.open(meta_path, FileAccess.WRITE)
        if file == null:
            return {"ok": false, "error": "intermediate_metadata_save_failed", "task": task["id"], "generated": generated, "results": results}
        file.store_string(JSON.stringify(record))
        file.close()
        var completed: Dictionary = task.duplicate(true)
        completed["status"] = "candidate_requires_review"
        completed["image_path"] = output_path
        results.append(completed)
        generated += 1
    return {"ok": true, "generated": generated, "results": results, "scheduled": scheduled["scheduled"], "human_approved": false, "ready_for_animation": false}

# Dedicated visual fidelity agent: candidates are never human-approved here.
func review_candidates(reference: Image, plan: Dictionary, folder: String, worker: Node, max_review: int = 4) -> Dictionary:
    if worker == null or not worker.has_method("assess_keyposes") or not worker.has_method("vision_provider_id"):
        return {"ok": false, "error": "vision_reviewer_missing", "human_approved": false}
    var schedule_result: Dictionary = schedule(plan)
    if not schedule_result.get("ok", false):
        return {"ok": false, "error": "invalid_intermediate_schedule", "human_approved": false}
    if reference.is_empty():
        return {"ok": false, "error": "original_reference_missing", "human_approved": false}
    # Bind every review to the ORIGINAL reference pixels, not just neighbor
    # keyposes. A changed original must invalidate all previous fidelity checks.
    var original_hash: String = reference.save_png_to_buffer().hex_encode().sha256_text()
    var reviewed: int = 0
    var failed: Array = []
    var pending: Array = []
    var cached: int = 0
    for task in schedule_result["tasks"]:
        var path: String = folder.path_join(str(task["id"]) + ".png")
        var meta_path: String = folder.path_join(str(task["id"]) + ".json")
        if not FileAccess.file_exists(path) or not FileAccess.file_exists(meta_path):
            pending.append(task["id"])
            continue
        var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
        if not meta is Dictionary or meta.get("image_sha", "") != FileAccess.get_sha256(path):
            return {"ok": false, "error": "intermediate_candidate_changed", "task": task["id"], "human_approved": false}
        var neighbor_lookup: Dictionary = {}
        for board in plan.get("boards", []):
            neighbor_lookup[str(board.get("id", ""))] = board
        var from_board: Dictionary = neighbor_lookup.get(str(task["from_pose"]), {})
        var to_board: Dictionary = neighbor_lookup.get(str(task["to_pose"]), {})
        if from_board.is_empty() or to_board.is_empty():
            return {"ok": false, "error": "missing_neighbor_metadata", "human_approved": false}
        var from_path: String = folder.path_join("pose_%04d.png" % int(from_board.get("index", -1)))
        var to_path: String = folder.path_join("pose_%04d.png" % int(to_board.get("index", -1)))
        if not FileAccess.file_exists(from_path) or not FileAccess.file_exists(to_path):
            return {"ok": false, "error": "missing_neighbor_image", "human_approved": false}
        var review_binding: String = ("intermediate-review-v3-reference-locked" + original_hash + str(meta["binding"]) + str(meta["image_sha"]) + FileAccess.get_sha256(from_path) + FileAccess.get_sha256(to_path) + worker.vision_provider_id()).sha256_text()
        if meta.get("review_binding", "") == review_binding and meta.get("original_reference_hash", "") == original_hash and meta.get("review_origin", "") == "live_vision_model" and meta.get("motion_review") is Dictionary and meta.get("model_review") is Dictionary:
            cached += 1
            if not meta.get("fidelity_verified", false):
                failed.append(task["id"])
            continue
        if reviewed >= max_review:
            pending.append(task["id"])
            continue
        var image := Image.new()
        if image.load(path) != OK:
            return {"ok": false, "error": "intermediate_image_unreadable", "task": task["id"], "human_approved": false}
        var expected: Dictionary = task.duplicate(true)
        expected["pose"] = "Intermediate physical state at fraction %.3f; preserve original reference identity and appearance; ensure plausible movement between adjacent poses" % float(task["fraction"])
        var review_images: Array[Image] = [image]
        var review_expected: Array = [expected]
        # First pass: compare with ORIGINAL reference, not merely the preceding frame.
        var response: Dictionary = await worker.assess_keyposes(reference, review_images, review_expected)
        if not response.get("ok", false):
            return {"ok": false, "error": "intermediate_vision_review_failed", "detail": response.get("error", ""), "task": task["id"], "human_approved": false}
        if not response.get("review") is Dictionary or not response["review"].get("frames") is Array or response["review"]["frames"].size() != 1:
            return {"ok": false, "error": "invalid_intermediate_review", "human_approved": false}
        var row: Dictionary = response["review"]["frames"][0]
        # Second independent pass: compare with both adjacent keyposes to
        # detect jumps, swapped limbs, missing contacts and scenery drift.
        var lookup: Dictionary = {}
        for board in plan.get("boards", []):
            lookup[str(board.get("id", ""))] = board
        var left: Dictionary = lookup.get(str(task["from_pose"]), {})
        var right: Dictionary = lookup.get(str(task["to_pose"]), {})
        var left_image := Image.new()
        var right_image := Image.new()
        if left.is_empty() or right.is_empty() or left_image.load(folder.path_join("pose_%04d.png" % int(left.get("index", -1)))) != OK or right_image.load(folder.path_join("pose_%04d.png" % int(right.get("index", -1)))) != OK:
            return {"ok": false, "error": "motion_neighbor_missing", "task": task["id"], "human_approved": false}
        var motion_expected: Array = [
            {"pose": str(left.get("pose", "")), "actor_ids": task["actor_ids"], "object_ids": task["object_ids"]},
            {"pose": str(expected["pose"]), "actor_ids": task["actor_ids"], "object_ids": task["object_ids"], "instruction": "Check physical transition from first to third pose; no abrupt changes or duplicate still"},
            {"pose": str(right.get("pose", "")), "actor_ids": task["actor_ids"], "object_ids": task["object_ids"]}
        ]
        var motion_images: Array[Image] = [left_image, image, right_image]
        var motion_response: Dictionary = await worker.assess_keyposes(reference, motion_images, motion_expected)
        if not motion_response.get("ok", false) or not motion_response.get("review") is Dictionary or not motion_response["review"].get("frames") is Array or motion_response["review"]["frames"].size() != 3:
            return {"ok": false, "error": "motion_vision_review_failed", "task": task["id"], "human_approved": false}
        var motion_row: Dictionary = motion_response["review"]["frames"][1]
        var passed: bool = row.get("uncertain", true) == false and row.get("defects") is Array and row["defects"].is_empty()
        for key in ["identity_match", "count_match", "action_match", "environment_match", "perspective_match"]:
            passed = passed and row.get(key) == true
        var motion_passed: bool = motion_row.get("uncertain", true) == false and motion_row.get("defects") is Array and motion_row["defects"].is_empty()
        for key in ["identity_match", "count_match", "action_match", "environment_match", "perspective_match"]:
            motion_passed = motion_passed and motion_row.get(key) == true
        passed = passed and motion_passed
        if FileAccess.get_sha256(path) != meta["image_sha"]:
            return {"ok": false, "error": "intermediate_changed_during_review", "human_approved": false}
        meta["original_reference_hash"] = original_hash
        meta["review_binding"] = review_binding
        meta["review_origin"] = "live_vision_model"
        meta["model_review"] = row
        meta["motion_review"] = motion_row
        meta["reference_fidelity_verified"] = row.get("uncertain", true) == false and row.get("identity_match", false) == true and row.get("count_match", false) == true
        meta["motion_continuity_verified"] = motion_passed
        meta["fidelity_verified"] = passed
        meta["human_approved"] = false
        var temp_path: String = meta_path + ".part"
        var file := FileAccess.open(temp_path, FileAccess.WRITE)
        if file == null:
            return {"ok": false, "error": "review_metadata_write_failed", "human_approved": false}
        file.store_string(JSON.stringify(meta))
        file.close()
        if DirAccess.rename_absolute(temp_path, meta_path) != OK:
            return {"ok": false, "error": "review_metadata_rename_failed", "human_approved": false}
        reviewed += 1
        if not passed:
            failed.append(task["id"])
    return {"ok": true, "reviewed": reviewed, "cached_reviews": cached, "failed": failed, "pending": pending, "fidelity_verified": failed.is_empty() and pending.is_empty(), "human_approved": false, "ready_for_animation": false}
