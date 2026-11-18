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
