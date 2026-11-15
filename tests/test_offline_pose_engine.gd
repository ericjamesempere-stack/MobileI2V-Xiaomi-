extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var engine = load("res://scripts/OfflinePoseEngine.gd")
    var availability: Dictionary = engine.availability()
    assert(availability.has("available"))
    if not availability["available"]:
        var result: Dictionary = engine.generate({"ok": true, "keyframes": [{"frame_index": 0}]}, "user://offline_pose_test")
        assert(not result.get("ok", true))
        assert(result.has("error"))
    print("MOBILEI2V_OFFLINE_POSE_ENGINE_CONTRACT_OK")
    quit(0)
