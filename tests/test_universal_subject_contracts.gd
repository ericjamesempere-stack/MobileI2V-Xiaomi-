extends SceneTree

# Deterministic contracts for arbitrary subjects; does not claim semantic
# recognition or invoke paid models. Live vision remains a separate test.
func _initialize() -> void:
    var gate = load("res://scripts/ReferenceFidelityGate.gd")
    var reference := Image.create(64, 48, false, Image.FORMAT_RGBA8)
    reference.fill(Color(0.4, 0.6, 0.2))
    var scenarios := [
        {"kind": "human", "action": "the person raises one hand"},
        {"kind": "animal", "action": "the cat turns and jumps"},
        {"kind": "vehicle", "action": "the car transforms into a robot"},
        {"kind": "object", "action": "the banana grows eyes and dances"},
        {"kind": "creature", "action": "the dragon folds its wings"},
        {"kind": "plant", "action": "the tree bends in the wind"},
        {"kind": "unknown", "action": "the unusual shape rotates"}
    ]
    for scenario in scenarios:
        var result: Dictionary = gate.build_request_from_image(reference, scenario["action"], scenario["kind"])
        assert(result.get("ok", false), scenario["kind"])
        assert(result["action"] == scenario["action"])
        assert(result["subject_type"] == scenario["kind"])
        assert(result["reference_width"] == 64 and result["reference_height"] == 48)
        assert(result["requires_human_review"] and not result["identity_verified"])
        var prompt: String = " ".join(result["constraints"])
        assert(prompt.contains("unless the user explicitly requests them"))
        if scenario["kind"] in ["vehicle", "object", "plant"]:
            assert(prompt.contains("Do not anthropomorphize unless explicitly requested"))
    assert(not gate.build_request_from_image(reference, "", "animal").get("ok", false))
    assert(not gate.build_request_from_image(reference, "move", "invalid_kind").get("ok", false))
    print("UNIVERSAL_SUBJECT_CONTRACTS_OK")
    quit(0)
