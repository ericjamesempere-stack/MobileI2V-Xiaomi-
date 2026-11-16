extends SceneTree

class RoutedEditor extends "res://scripts/hf_studio_generator.gd":
    var calls: Array[String] = []
    var first_failure: String = "quota"
    var second_fails: bool = false
    func _redraw_qwen(_ref: Image, _story: String, _style: String, _previous: Image, _variation: bool) -> Dictionary:
        calls.append("qwen")
        return {"ok": false, "error_kind": first_failure, "error": "simulated GPU refusal"}
    func _redraw_anypose(ref: Image, _story: String, _style: String, _previous: Image, _variation: bool) -> Dictionary:
        calls.append("anypose")
        if second_fails:
            return {"ok": false, "error_kind": "hidden_server_error", "error": "simulated error/null"}
        return {"ok": true, "image": ref.duplicate(), "model": "SIMULATED"}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var reference := Image.create(1024, 1024, false, Image.FORMAT_RGB8)
    reference.fill(Color.RED)
    var router := RoutedEditor.new()
    root.add_child(router)
    assert(router.engine_status.is_empty())
    var result: Dictionary = await router.redraw(reference, "falls", "original")
    assert(result["ok"] and result["engine"] == "anypose")
    assert(router.calls == ["qwen", "anypose"])
    assert(router.engine_status["qwen"]["status"] == "unavailable")
    assert(not router.engine_status["anypose"]["identity_verified"])
    assert((await router.redraw(reference, "lies on ground", "original"))["ok"])
    assert(router.calls == ["qwen", "anypose", "anypose"])
    router.free()
    router = RoutedEditor.new()
    router.second_fails = true
    root.add_child(router)
    assert(not (await router.redraw(reference, "falls", "original"))["ok"])
    assert(not (await router.redraw(reference, "falls", "original"))["ok"])
    assert(router.calls == ["qwen", "anypose"])
    assert(reference.get_pixel(0, 0) == Color.RED)
    router.free()
    router = RoutedEditor.new()
    router.first_failure = "safety"
    root.add_child(router)
    assert(not (await router.redraw(reference, "blocked", "original"))["ok"])
    assert(router.calls == ["qwen"])
    router.free()
    var worker: Node = load("res://scripts/hf_studio_generator.gd").new()
    var sheet := Image.create(1024, 1024, false, Image.FORMAT_RGB8)
    var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
    for index in range(4):
        sheet.fill_rect(Rect2i((index % 2) * 512, (index / 2) * 512, 512, 512), colors[index])
    var split: Dictionary = worker.split_batch(sheet, 4)
    assert(split["ok"] and not split["layout_verified"])
    for index in range(4):
        assert(split["images"][index].get_size() == Vector2i(512, 512))
        assert(split["images"][index].get_pixel(0, 0) == colors[index])
    assert(not worker.split_batch(Image.create(512, 512, false, Image.FORMAT_RGB8), 4)["ok"])
    assert(worker.decode_event_stream("event: error\ndata: null\n\n")["error_kind"] == "hidden_server_error")
    assert(worker.decode_event_stream("event: error\ndata: \"GPU quota exceeded (60s requested vs. 20s left)\"\n\n")["error_kind"] == "quota")
    assert(worker._http_failure(429, 0)["error_kind"] == "quota")
    assert(worker._http_failure(503, 0)["error_kind"] == "transport")
    var plan: RefCounted = load("res://scripts/board_generation_plan.gd").new()
    var last: Dictionary = plan.remote_frame("Une banane court, trébuche et tombe", 4.0, 4, 3)
    assert(last["action"] == "chute" and last["pose"].contains("lying still"))
    worker.free()
    print("HF_BATCH_FALLBACK_OK: SIMULATED routing, bounded retries, safety stop, exact crops and quota classification")
    quit(0)
