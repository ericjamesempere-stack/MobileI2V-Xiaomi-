extends SceneTree

func _initialize() -> void:
    var path: String = "user://autopilot_memory_test_%d/journal.jsonl" % Time.get_ticks_usec()
    var memory: RefCounted = load("res://scripts/karma_technical_memory.gd").new()
    memory.journal = path
    var key: String = "synthetic-input".sha256_text()
    for i in range(2):
        var ticket: Dictionary = memory.begin(key)
        assert(ticket["ok"])
        assert(memory.finish(ticket, {"ok": false, "stage": "analysis", "detail": {"error": "synthetic provider refusal"}}))
        assert(not memory.finish(ticket, {"ok": true}))
        # Reloading an independent object cannot reset the failure budget.
        memory = load("res://scripts/karma_technical_memory.gd").new()
        memory.journal = path
    assert(not memory.begin(key)["ok"])
    var other: String = "changed-input".sha256_text()
    var first: Dictionary = memory.begin(other)
    assert(first["ok"] and memory.finish(first, {"ok": true}))
    assert(memory.begin(other)["ok"])
    assert(memory.begin(other)["ok"])
    assert(not memory.begin(other)["ok"], "Two interrupted reservations must block")
    var raw: String = FileAccess.get_file_as_string(path)
    assert(not raw.contains("synthetic provider") and not raw.contains("changed-input"))
    var file := FileAccess.open(path, FileAccess.READ_WRITE)
    file.seek_end()
    file.store_string("truncated")
    file.close()
    assert(not memory.begin("new-input".sha256_text())["ok"])
    DirAccess.remove_absolute(path)
    print("AUTOPILOT_TECHNICAL_MEMORY_OK: persistent retry budget, interrupted calls, integrity, private hashes")
    quit(0)
