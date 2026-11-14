extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var planner = load("res://scripts/MotionPlanner.gd")
    var generator = load("res://scripts/frame_generator.gd")
    var rig_script = load("res://scripts/rig_character.gd")
    assert(planner != null, "MotionPlanner missing")
    assert(generator != null, "FrameGenerator missing")
    assert(rig_script != null, "Rig missing")
    assert(planner.action_from_text("il court puis tombe") == "run_fall")
    assert(planner.action_from_text("il saute") == "jump")
    assert(planner.timeline("il danse", 1.0, 30).size() == 30)
    var rig := Control.new()
    rig.set_script(rig_script)
    root.add_child(rig)
    var standing: Dictionary = rig._compute_pose(0.0)
    rig.motion_name = "chute"
    var fallen: Dictionary = rig._compute_pose(2.0)
    assert(standing["chest"].distance_to(fallen["chest"]) > 50.0, "Fall pose unchanged")
    rig.motion_name = "saut"
    var jumping: Dictionary = rig._compute_pose(1.0)
    assert(jumping["hip"].y < standing["hip"].y - 80.0, "Jump pose unchanged")
    print("MOBILEI2V_SMOKE_OK")
    quit(0)
