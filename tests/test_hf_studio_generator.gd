extends SceneTree
func _initialize() -> void:
    var client: Node = load("res://scripts/hf_studio_generator.gd").new()
    var result: Dictionary = client.decode_event_stream("event: heartbeat\n\nevent: complete\ndata: [{\"status\":\"success\",\"image\":\"abc\"}]\n\n")
    assert(result.get("ok", false))
    assert(result["data"][0]["image"] == "abc")
    assert(client.decode_event_stream("event: complete\r\ndata: [1]\r\n\r\n")["ok"])
    assert(not client.decode_event_stream("event: error\ndata: \"quota exceeded\"\n\n")["ok"])
    assert(not client.decode_event_stream("event: complete\ndata: null\n\n")["ok"])
    client.free()
    print("HF_STUDIO_PROTOCOL_TESTS_OK")
    quit(0)
