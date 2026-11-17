extends SceneTree
# Model/tokenizer fixtures only. No AI inference or device claim.
class Compiler extends "res://scripts/local_studio_generator.gd":
    var scenario: String = "ready"
    var compilations: int = 0
    var tokenizations: int = 0
    var generations: int = 0
    var received_instruction: String = ""
    var received_image: Image
    func _vision_request(images: Array[Image], prompt: String) -> Dictionary:
        compilations += 1
        received_instruction = prompt
        if not images.is_empty():
            received_image = images[0]
        if scenario == "vision_down":
            return {"ok": false, "error": "SIMULATED engine unavailable"}
        var raw: String = "not JSON" if scenario == "malformed" else JSON.stringify({"prompt": "A yellow banana lying horizontally on the floor, curved fruit body, cartoon"})
        return {"ok": true, "data": [{"role": "assistant", "content": [{"type": "text", "content": raw}]}]}
    func _local_request(_base: String, path: String, payload: Dictionary = {}, _get: bool = false, _timeout: float = 900.0) -> Dictionary:
        if path == "/health":
            return {"ok": true, "body": ""}
        if path == "/tokenize":
            tokenizations += 1
            if scenario == "tokenizer_down":
                return {"ok": false, "error": "SIMULATED tokenizer unavailable"}
            var count: float = 23
            if scenario == "long" or (scenario == "shorten" and tokenizations == 1):
                count = 120
            elif scenario == "fractional":
                count = 2.5
            elif scenario == "negative":
                count = -1
            elif scenario == "small_budget":
                count = 24
            return {"ok": true, "body": JSON.stringify({"count": count, "max_length": 20 if scenario == "small_budget" else 77})}
        assert(path == "/generate")
        generations += 1
        assert(payload["prompt"].begins_with("A yellow banana lying"))
        assert(not payload["prompt"].contains("entity_1"))
        var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
        image.fill(Color.YELLOW)
        return {"ok": true, "body": "data: " + JSON.stringify({"type": "complete", "format": "png", "width": 512, "height": 512, "channels": 3, "image": Marshalls.raw_to_base64(image.save_png_to_buffer())}) + "\n\n"}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var reference := Image.create(512, 512, false, Image.FORMAT_RGB8)
    reference.fill(Color.YELLOW)
    for scenario in ["ready", "shorten", "long", "malformed", "vision_down", "tokenizer_down", "fractional", "negative", "small_budget"]:
        var worker := Compiler.new()
        worker.scenario = scenario
        worker.scene_registry = {"entities": [{"id": "entity_1", "kind": "banana"}]}
        root.add_child(worker)
        var result: Dictionary = await worker.redraw(reference, "entity_1 tombe puis finit couché au sol. Évite toute anatomie humaine.", "cartoon")
        var success: bool = scenario in ["ready", "shorten"]
        assert(result["ok"] == success, scenario)
        assert(worker.generations == (1 if success else 0), "Oversized/unverified prompts must never start diffusion: " + scenario)
        assert(worker.compilations <= 2, "No infinite compilation retry")
        if scenario == "shorten":
            assert(worker.compilations == 2 and worker.tokenizations == 2)
        if success:
            assert(worker.received_image == reference)
            assert(worker.received_instruction.contains("entity_1 tombe") and worker.received_instruction.contains("Évite"))
            assert(not result["identity_verified"])
        worker.free()
    var subject := Compiler.new()
    root.add_child(subject)
    assert((await subject.create_reference("Une banane vivante", "cartoon"))["ok"])
    assert(subject.received_image == null and subject.received_instruction.contains("Une banane vivante"))
    assert(subject.generations == 1 and subject.tokenizations == 1)
    subject.free()
    print("LOCAL_PROMPT_BUDGET_OK: ten simulated cases; French/scene/reference retained, tokenizer budget enforced before diffusion, bounded shortening, no automatic approval")
    quit(0)
