extends SceneTree
# Real Godot production screen/file persistence; no Android/gallery claim.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var board: Node = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    await process_frame
    var source: String = "user://v58_fixture.webp"
    var image := Image.create(320, 256, false, Image.FORMAT_RGB8)
    image.fill(Color.YELLOW)
    image.fill_rect(Rect2i(10, 20, 30, 40), Color.RED)
    assert(image.save_webp(source, true) == OK)
    # Recover a mailbox result even when Android recreated the Godot screen.
    board.photo_importing = false
    board._consume_photo_result(JSON.stringify({"state": "selected", "role": "reference", "value": source}))
    await process_frame
    assert(board.preview.texture != null)
    assert(board.preview.texture.get_width() == 320)
    var original: String = board.imported_path
    assert(FileAccess.file_exists(original))
    board.action_input.text = "Une banane danse."
    board._save()
    var snapshot: String = original.get_base_dir().path_join("project.json")
    assert(FileAccess.file_exists(snapshot))
    board._consume_photo_result(JSON.stringify({"state": "cancelled", "value": ""}))
    assert(board.imported_path == original)
    board._consume_photo_result(JSON.stringify({"state": "error", "value": "SIMULATED Android decode failure"}))
    assert(board.imported_path == original)
    board._image_chosen(source)
    await process_frame
    assert(board.imported_path != original)
    assert(FileAccess.file_exists(original))
    var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(snapshot))
    assert(previous["description"] == "Une banane danse.")
    assert(previous["reference_path"] == original)
    var current: String = board.imported_path
    board.queue_free()
    await process_frame
    var reopened: Node = load("res://scripts/storyboard.gd").new()
    root.add_child(reopened)
    await process_frame
    reopened._load_saved()
    assert(reopened.imported_path == current)
    assert(reopened.preview.texture != null)
    reopened.queue_free()
    await process_frame
    print("V58_PHOTO_RECOVERY_OK: WebP pixels, preview, recovery, cancellation, errors, successive projects, reopen. Android NOT tested.")
    quit(0)
