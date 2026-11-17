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
