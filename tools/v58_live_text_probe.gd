extends SceneTree
# Explicit non-private text-only inference probe. Never loads a personal photo.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var worker: Node = load("res://scripts/hf_studio_generator.gd").new()
    root.add_child(worker)
    var result: Dictionary = await worker.create_reference("A single yellow banana on a blue table, curved fruit body, no human limbs", "cartoon")
    var folder: String = "res://validation/v58"
    if result.get("ok", false):
        var image: Image = result["image"]
        result.erase("image")
        result["width"] = image.get_width()
        result["height"] = image.get_height()
        result["save_error"] = image.save_png(folder.path_join("real_text_banana.png"))
    var file := FileAccess.open(folder.path_join("live_text_result.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(result, "  "))
    file.close()
    print("V58_LIVE_TEXT_RESULT ", JSON.stringify(result))
    worker.queue_free()
    quit(0 if result.get("ok", false) else 2)
