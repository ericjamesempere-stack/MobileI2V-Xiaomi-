extends SceneTree
func _initialize() -> void:
    var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/universal_a_annotation.json"))
    scene["reference_sha"] = "planning-only-fixture"
    # Longer duration asks for more keys than the three original physical phases.
    scene["steps"] = [scene["steps"][0]]
    var planner: RefCounted = load("res://scripts/board_generation_plan.gd").new()
    var plan: Dictionary = planner.calculate_density(scene, 12.0)
    assert(plan["ok"] and plan["keyposes"] > 3)
    var unique: Dictionary = {}
    var exact_phases: Array = []
    for i in range(plan["boards"].size()):
        var board: Dictionary = plan["boards"][i]
        assert(not unique.has(board["pose"]), "Extra key poses must not repeat a phase verbatim")
        unique[board["pose"]] = true
        assert(board["instruction"].contains("Sequence drawing %d of %d" % [i + 1, plan["keyposes"]]))
        assert(board["instruction"].contains('Acting entity IDs: ["e1"]'))
        assert(board["phase_progress"] >= 0.0 and board["phase_progress"] < 1.0)
        if board["phase_progress"] == 0.0:
            exact_phases.append(board["pose"])
    assert(exact_phases == scene["steps"][0]["phases"], "Every original physical phase must remain an exact key pose")
    # Exhaust interval distributions, including uneven allocations and static holds.
    for phase_count in range(2, 8):
        var phases: Array = []
        for i in range(phase_count):
            phases.append("physical state %d" % i)
        for key_count in range(phase_count, 30):
            var states: Dictionary = {}
            for i in range(key_count):
                states[planner._physical_state(phases, key_count, i)["pose"]] = true
            assert(states.size() == key_count)
            for phase in phases:
                assert(states.has(phase))
    assert(planner._physical_state(["still"], 1, 0)["pose"] == "still")
    print("UNIVERSAL_PHASE_PROGRESS_OK: distinct physical instructions, all original phases retained, actor IDs and sequence position; no generated images")
    quit(0)
