extends SceneTree

func _initialize() -> void:
    var planner: RefCounted = load("res://scripts/board_generation_plan.gd").new()
    var story: String = "Une banane anthropomorphe court, trébuche et tombe."
    var actions: Array[String] = []
    var instructions: Array[String] = []
    for index in range(6):
        var brief: Dictionary = planner.remote_frame(story, 4.0, 6, index)
        assert(brief["ok"])
        actions.append(brief["action"])
        instructions.append(brief["instruction"])
        assert(not str(brief["instruction"]).contains("Full story:"))
    assert(actions == ["course", "course", "trebuche", "trebuche", "chute", "chute"])
    assert(instructions[0] != instructions[1])
    assert(instructions[3].contains("balance"))
    assert(instructions[5].contains("lying still on the ground"))
    # Rejected drawings must keep their original action even in a partial board.
    assert(planner.remote_frame(story, 4.0, 6, 3)["instruction"] == instructions[3])
    assert(not planner.remote_frame(story, 4.0, 2, 0)["ok"])
    var short_step: Array[String] = []
    for index in range(3):
        short_step.append(planner.remote_frame(story, 4.0, 3, index)["action"])
    assert(short_step == ["course", "trebuche", "chute"])
    var ball_story: String = "Une balle roule puis rebondit."
    var ball_actions: Array[String] = []
    for index in range(8):
        var brief: Dictionary = planner.remote_frame(ball_story, 4.0, 8, index)
        assert(brief["ok"])
        ball_actions.append(brief["action"])
        assert(not brief["instruction"].contains("freinage"))
        assert(not brief["instruction"].contains("limb"))
    assert(ball_actions == ["roule", "roule", "roule", "roule", "rebond", "rebond", "rebond", "rebond"])
    assert(planner.remote_frame(ball_story, 4.0, 8, 5)["pose"].contains("contacts the surface"))
    assert(planner.remote_frame(ball_story, 4.0, 8, 6)["pose"].contains("rising"))
    var interaction: Dictionary = planner.remote_frame("Deux personnages se serrent la main.", 3.0, 3, 1)
    assert(interaction["action"] == "interaction")
    assert(interaction["instruction"].contains("each other"))
    assert(interaction["instruction"].contains("ALL existing subjects"))
    assert(interaction["instruction"].contains("No duplicate subjects"))
    print("REMOTE_POSE_BRIEFS_OK: course, stumble, fall; no skipped action; same brief on retry")
    quit(0)
