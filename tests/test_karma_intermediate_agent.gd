extends SceneTree

func _initialize() -> void:
    var agent: RefCounted = load("res://scripts/karma_intermediate_agent.gd").new()
    var plan: Dictionary = {"ok": true, "intermediate_drawings": 3, "steps": [{"id": "step_a", "intermediate_drawings": 3}], "boards": [
        {"id": "pose_0", "step_id": "step_a", "video_frame": 0, "actor_ids": ["banana"], "object_ids": []},
        {"id": "pose_1", "step_id": "step_a", "video_frame": 12, "actor_ids": ["banana"], "object_ids": []},
        {"id": "pose_2", "step_id": "step_a", "video_frame": 24, "actor_ids": ["banana"], "object_ids": []}
    ]}
    var result: Dictionary = agent.schedule(plan)
    assert(result["ok"] and result["scheduled"] == 3)
    assert(result["generated"] == 0 and not result["ready_for_animation"])
    for task in result["tasks"]:
        assert(task["status"] == "pending_generation")
        assert(not task["identity_verified"] and not task["human_approved"])
        assert(task["actor_ids"] == ["banana"])
        assert(task["from_pose"] != task["to_pose"])
    var blocked: Dictionary = agent.schedule({"ok": true, "intermediate_drawings": 2, "steps": [{"id": "step_a", "intermediate_drawings": 2}], "boards": [plan["boards"][0]]})
    assert(not blocked["ok"] and blocked["unfillable"].size() == 1)
    print("V54_INTERMEDIATE_AGENT_CONTRACT_OK")
    quit(0)
