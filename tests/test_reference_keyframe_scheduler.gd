extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scheduler = load("res://scripts/ReferenceKeyframeScheduler.gd")
    var frames: Array = []
    for i in range(30):
        frames.append({
            "scene_index": 0 if i < 12 else 1,
            "action": "run" if i < 12 else "jump",
            "position": {"x": i * 2, "y": 0},
            "reference_original": "user://reference.png",
            "reference_styled": "user://styled.png",
            "preserve_identity": true
        })
    var plan := {"ok": true, "frames": frames}
    var result: Dictionary = scheduler.schedule(plan, 6)
    assert(result.get("ok", false), str(result))
    var keys: Array = result["keyframes"]
    assert(keys.size() < frames.size())
    assert(int(keys[0]["frame_index"]) == 0)
    assert(int(keys[keys.size() - 1]["frame_index"]) == 29)
    var selected: Dictionary = {}
    for item in keys:
        selected[int(item["frame_index"])] = true
        assert(item["constraints"]["identity"])
    assert(selected.has(11) and selected.has(12), "Scene boundary keyframes required")
    var saved: Dictionary = scheduler.save(result, "user://test_keyframes.json")
    assert(saved.get("ok", false))
    assert(FileAccess.file_exists("user://test_keyframes.json"))
    assert(not scheduler.schedule(plan, 0).get("ok", true))
    print("MOBILEI2V_KEYFRAME_SCHEDULER_OK")
    quit(0)
