extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var worker: Node = load("res://scripts/hf_studio_generator.gd").new()
    root.add_child(worker)
    worker.job_folder = OS.get_environment("KARMA_JOB_CACHE")
    worker.hf_token = "synthetic-test-token"
    var base: String = OS.get_environment("KARMA_JOB_SERVER")
    assert(base.begins_with("http://127.0.0.1:"))
    var first: Dictionary = await worker._call_api(base, "resume", [])
    assert(first["ok"] and first["data"][0]["get"] == 1)
    var cached: Dictionary = await worker._call_api(base, "resume", [])
    assert(cached["cached_job"] and cached["data"][0]["get"] == 1)
    var files: PackedStringArray = DirAccess.get_files_at(worker.job_folder)
    assert(files.size() == 1)
    var path: String = worker.job_folder.path_join(files[0])
    var raw: String = FileAccess.get_file_as_string(path)
    assert(not raw.contains("synthetic-test-token"))
    var record: Dictionary = JSON.parse_string(raw)
    record["state"] = "pending"
    record.erase("result")
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(record))
    file.close()
    var resumed: Dictionary = await worker._call_api(base, "resume", [])
    assert(resumed["ok"] and resumed["data"][0]["get"] == 2)
    # Refaire must not reuse a completed randomized drawing request.
    var data: Array = ["fixture", "pose", "style", 1234, true, 1.0, 4]
    assert((await worker._call_api(base, "edit_image", data))["ok"])
    assert((await worker._call_api(base, "edit_image", data))["ok"])
    worker.queue_free()
    await process_frame
    print("GENERATION_JOB_RESUME_OK: local HTTP fixture; completed cache, pending GET without POST, fresh randomized requests; no GPU")
    quit(0)
