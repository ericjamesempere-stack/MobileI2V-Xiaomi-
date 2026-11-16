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
                alpha = 0.5
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
