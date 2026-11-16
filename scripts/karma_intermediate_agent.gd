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
    for step in steps:
        var step_id: String = str(step.get("id", ""))
        var count: int = int(step.get("intermediate_drawings", 0))
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
    return {"ok": unfillable.is_empty(), "revision": REVISION, "tasks": tasks, "unfillable": unfillable, "requested": int(plan.get("intermediate_drawings", 0)), "scheduled": tasks.size(), "generated": 0, "verified": false, "ready_for_animation": false}

# Rendering is deliberately separate from scheduling. The orchestrator calls
# this only after keypose generation; human approval remains a later gate.
func render_pending(plan: Dictionary, folder: String, worker: Node, style: String = "original", max_new: int = 4) -> Dictionary:
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
        var binding: String = (REVISION + FileAccess.get_sha256(left_path) + FileAccess.get_sha256(right_path) + prompt + style).sha256_text()
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
        var response: Dictionary = await worker.redraw(left_image, prompt, style)
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
