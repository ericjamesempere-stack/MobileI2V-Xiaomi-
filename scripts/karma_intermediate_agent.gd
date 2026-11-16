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
            if alpha <= 0.00001:
                alpha = 0.5
            var a: Dictionary = poses[left]
            var b: Dictionary = poses[left + 1]
            tasks.append({
                "id": "between_%04d" % tasks.size(),
                "step_id": step_id,
                "from_pose": str(a.get("id", "")),
                "to_pose": str(b.get("id", "")),
                "from_frame": int(a.get("video_frame", 0)),
                "to_frame": int(b.get("video_frame", 0)),
                "fraction": alpha,
                "actor_ids": a.get("actor_ids", []).duplicate(true),
                "object_ids": a.get("object_ids", []).duplicate(true),
                "instruction": "Draw one new physically plausible intermediate state between the two approved adjacent keyposes. Preserve all entity identities, counts, anatomy or object structure, background, perspective and unaffected scene elements. Advance the action, not camera zoom or image warping.",
                "status": "pending_generation",
                "image_path": "",
                "identity_verified": false,
                "human_approved": false
            })
    return {"ok": unfillable.is_empty(), "revision": REVISION, "tasks": tasks, "unfillable": unfillable, "requested": int(plan.get("intermediate_drawings", 0)), "scheduled": tasks.size(), "generated": 0, "verified": false, "ready_for_animation": false}
