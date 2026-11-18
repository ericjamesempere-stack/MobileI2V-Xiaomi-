extends SceneTree

# Offline integration test: checks the actual payload sent to image engines.
# No cloud calls and no claim that the resulting pixels match the reference.
func _initialize() -> void:
    var reference := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
    reference.fill(Color.RED)
    var gate = load("res://scripts/ReferenceFidelityGate.gd")
    var contract: Dictionary = gate.build_request_from_image(reference, "the subject turns around")
    assert(contract.get("ok", false))
    var remote = load("res://scripts/hf_studio_generator.gd").new()
    remote.reference_contract = contract
    var remote_payload: Dictionary = remote.build_edit_payload(reference, "turn around", "original")
    var remote_serialized: String = JSON.stringify(remote_payload)
    assert(remote_serialized.contains("Do not invent anatomy"))
    remote.free()
    var local = load("res://scripts/local_studio_generator.gd").new()
    local.reference_contract = contract
    var local_payload: Dictionary = local._generation_payload(reference, "turn around", "original", false)
    assert(str(local_payload.get("prompt", "")).contains("Do not invent anatomy"))
    local.free()
    print("FIDELITY_PROMPT_WIRING_OK")
    quit(0)
