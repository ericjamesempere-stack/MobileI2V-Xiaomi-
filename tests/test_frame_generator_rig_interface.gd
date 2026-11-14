extends SceneTree

func _initialize() -> void:
    var rig: Control = load("res://scripts/rig_character.gd").new()
    assert(rig.has_method("update_pose"))
    assert(rig.has_method("update_expression"))
    rig.update_pose(0.2, "marche")
    rig.update_expression(0.2, "happy")
    assert(rig.facial_expression == "happy")
    rig.update_expression(0.3, "surprised")
    assert(rig.facial_expression == "surprised")
    rig.update_expression(0.4, "neutral")
    assert(rig.facial_expression == "neutral")
    rig.free()
    print("FRAME_GENERATOR_RIG_INTERFACE_TESTS_OK")
    quit(0)
