extends SceneTree
class OfflineOnly extends "res://scripts/hf_studio_generator.gd":
    var attempted_calls: int = 0
    func _redraw_qwen(_ref: Image, _story: String, _style: String, _previous: Image, _variation: bool) -> Dictionary:
        attempted_calls += 1
        return {"ok": false, "error": "No GPU call allowed in cache test"}
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var folder: String = "res://validation/v54-universal-a"
    var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("plan.json")))
    var reference := Image.new()
    assert(reference.load("res://validation/v54-poses/reference.png") == OK)
    var pipeline: Node = load("res://scripts/universal_board_pipeline.gd").new()
    root.add_child(pipeline)
    pipeline.worker.free()
    var offline := OfflineOnly.new()
    pipeline.worker = offline
    pipeline.add_child(offline)
    var hashes: Array[String] = []
    for i in range(8):
        var path: String = folder.path_join("pose_%04d.png" % i)
        assert(FileAccess.file_exists(path))
        hashes.append(FileAccess.get_sha256(path))
    var result: Dictionary = await pipeline.generate_keyposes(reference, plan, "original", folder)
    assert(result["ok"] and result["reused"] == 8 and offline.attempted_calls == 0)
    assert(not result["fidelity_verified"] and not result["ready_for_animation"])
    for i in range(8):
        assert(FileAccess.get_sha256(folder.path_join("pose_%04d.png" % i)) == hashes[i])
    pipeline.queue_free()
    await process_frame
    print("ACTUAL_CANDIDATE_CACHE_OK: 8 real candidate PNGs reused, identical SHA256, zero inference; fidelity remains unverified")
    quit(0)
