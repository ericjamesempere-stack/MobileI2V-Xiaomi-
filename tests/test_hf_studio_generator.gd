extends SceneTree
class FakeEditor extends "res://scripts/hf_studio_generator.gd":
    var edit_calls: Array = []
    func _call_api(_base: String, api: String, data: Array) -> Dictionary:
        if api == "check_safety":
            return {"ok": true, "data": [{"status": "ok"}]}
        edit_calls.append(data)
        var image := Image.create(8, 8, false, Image.FORMAT_RGB8)
        image.fill(Color.YELLOW)
        return {"ok": true, "data": [{"status": "success", "image": Marshalls.raw_to_base64(image.save_png_to_buffer())}]}

class VisionTransport extends "res://scripts/hf_studio_generator.gd":
    var upload_statuses: Array[int] = []
    var jobs: int = 0
    var upload_count: int = 0

    func _upload_images(_base: String, _images: Array[Image]) -> Dictionary:
        upload_count += 1
        var code: int = upload_statuses.pop_front()
        if code == 200:
            return {"ok": true, "files": []}
        return _http_failure(code, 0)

    func _call_api(_base: String, _api: String, _data: Array) -> Dictionary:
        jobs += 1
        return {"ok": false, "error_kind": "hidden_server_error"}

class VisionFailover extends "res://scripts/hf_studio_generator.gd":
    var called: Array[String] = []
    func _vision_request_at(endpoint: String, _images: Array[Image], _prompt: String) -> Dictionary:
        called.append(endpoint)
        if endpoint == VISION_URL:
            return {"ok": false, "error_kind": "hidden_server_error", "error": "server unavailable"}
        return {"ok": false, "error_kind": "transport", "http_status": 503, "error": "backup unavailable"}

class AdapterContract extends "res://scripts/hf_studio_generator.gd":
    var calls: Array[Dictionary] = []
    func _upload_images(_base: String, _images: Array[Image]) -> Dictionary:
        return {"ok": true, "files": [{"path": "/tmp/test.png", "meta": {"_type": "gradio.FileData"}}]}
    func _call_api(base: String, api: String, data: Array) -> Dictionary:
        calls.append({"base": base, "api": api, "data": data})
        if api == "run_vl":
            return {"ok": true, "data": ['{"entities":[],"steps":[]}']}
        if api == "chat":
            return {"ok": true, "data": ['{"entities":[],"steps":[]}']}
        return {"ok": true, "data": ["", [], [["user", '{"entities":[],"steps":[]}']], []]}

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var client: Node = load("res://scripts/hf_studio_generator.gd").new()
    var result: Dictionary = client.decode_event_stream("event: heartbeat\n\nevent: complete\ndata: [{\"status\":\"success\",\"image\":\"abc\"}]\n\n")
    assert(result.get("ok", false))
    assert(result["data"][0]["image"] == "abc")
    assert(client.decode_event_stream("event: complete\r\ndata: [1]\r\n\r\n")["ok"])
    assert(not client.decode_event_stream("event: error\ndata: \"quota exceeded\"\n\n")["ok"])
    assert(not client.decode_event_stream("event: complete\ndata: null\n\n")["ok"])
    var queue: String = 'data: {"msg":"heartbeat"}\n\ndata: {"msg":"process_completed","event_id":"other","success":true,"output":{"data":["wrong"]}}\n\ndata: {"msg":"process_completed","event_id":"target","success":true,"output":{"data":["correct"]}}\n\n'
    assert(client.decode_queue_stream(queue, "target")["data"] == ["correct"])
    assert(not client.decode_queue_stream(queue, "missing")["ok"])
    var hidden: Dictionary = client.decode_queue_stream('data: {"msg":"process_completed","event_id":"target","success":false,"output":{"error":null}}\n\n', "target")
    assert(not hidden["ok"] and hidden["error_kind"] == "hidden_server_error")
    assert(not client.decode_queue_stream('data: {"msg":"process_completed","event_id":"target","success":false,"output":{"error":"quota exceeded"}}\n\n', "target")["ok"])
    assert(not client.decode_queue_stream('data: {"msg":"process_completed","event_id":"target","success":true,"output":{"data":null}}\n\n', "target")["ok"])
    assert(client.result_stream_url(client.VISION_URL, "add_message", "event", "session") == client.VISION_URL + "/gradio_api/queue/data?session_hash=session")
    assert(client.result_stream_url(client.EDIT_URL, "edit_image", "event", "") == client.EDIT_URL + "/gradio_api/call/edit_image/event")
    client.free()
    var vision := VisionTransport.new()
    root.add_child(vision)
    vision.upload_statuses.assign([503, 200])
    var unavailable: Dictionary = await vision._vision_request([], "test")
    assert(vision.upload_count == 2 and vision.jobs == 1)
    assert(unavailable["error_kind"] == "hidden_server_error" and unavailable["error"].contains("Qwen3-VL"))
    vision.upload_statuses.assign([429])
    var quota: Dictionary = await vision._vision_request([], "test")
    assert(vision.upload_count == 3 and vision.jobs == 1)
    assert(quota["error_kind"] == "quota")
    vision.upload_statuses.assign([503, 503])
    var outage: Dictionary = await vision._vision_request([], "test")
    assert(vision.upload_count == 5 and vision.jobs == 1)
    assert(outage["http_status"] == 503 and outage["error"].contains("envoi des images"))
    vision.free()
    var failover := VisionFailover.new()
    root.add_child(failover)
    failover.remote_vision_consent = true
    failover.vision_backup_urls.assign(["https://backup-one.example", "https://backup-two.example", "https://backup-three.example", "http://unsafe.example"])
    var sample := Image.create(8, 8, false, Image.FORMAT_RGB8)
    sample.fill(Color.RED)
    var failed: Dictionary = await failover.analyze_scene(sample, "riding a motorcycle")
    assert(not failed.get("ok", false))
    assert(failover.called.size() == 4)
    assert(failover.called[0] == failover.VISION_URL)
    assert(failover.called[1] == "https://backup-one.example")
    assert(failed.get("attempts", []).size() == 4)
    failover.free()
    var adapters := AdapterContract.new()
    root.add_child(adapters)
    var test_image := Image.create(8, 8, false, Image.FORMAT_RGB8)
    test_image.fill(Color.BLUE)
    for endpoint in [adapters.SMOLVLM_URL, adapters.QWEN_VL_URL, adapters.MINICPM_URL]:
        var checked: Dictionary = await adapters._vision_request_at(endpoint, [test_image], "Return JSON")
        assert(checked.get("ok", false))
        assert(adapters.extract_vision_text(checked.get("data", [])).contains("entities"))
    assert(adapters.calls.size() == 3)
    assert(adapters.calls[0]["api"] == "chat" and adapters.calls[0]["data"].size() == 2)
    assert(adapters.calls[1]["api"] == "run_vl" and adapters.calls[1]["data"].size() == 6)
    assert(adapters.calls[2]["api"] == "handle_submit" and adapters.calls[2]["data"].size() == 8)
    adapters.free()
    var editor := FakeEditor.new()
    root.add_child(editor)
    var reference := Image.create(8, 8, false, Image.FORMAT_RGB8)
    reference.fill(Color.RED)
    var previous := Image.create(8, 8, false, Image.FORMAT_RGB8)
    previous.fill(Color.BLUE)
    assert((await editor.redraw(reference, "lying on ground", "cartoon", previous))["ok"])
    assert((await editor.redraw(reference, "lying on ground", "cartoon", previous, true))["ok"])
    assert(not editor.edit_calls[0][4])
    assert(editor.edit_calls[1][4])
    assert(editor.edit_calls[0][0] == editor.edit_calls[1][0])
    assert(editor.edit_calls[1][1].contains("not an additional subject or a target pose"))
    assert(not editor.edit_calls[1][1].contains("previous approved"))
    editor.free()
    print("HF_STUDIO_PROTOCOL_TESTS_OK")
    quit(0)
