extends SceneTree
# Real Godot production screen/file persistence; no Android/gallery claim.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    for script_path in ["storyboard.gd", "android_image_reader.gd", "local_studio_generator.gd"]:
        var source_code: String = FileAccess.get_file_as_string("res://scripts/" + script_path)
        assert(not source_code.is_empty())
        assert(not source_code.contains("native.has_method("), "Android plugin methods bypass Object.has_method: " + script_path)
    var board: Node = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    await process_frame
    assert(board.advanced_panel.is_ancestor_of(board.local_mode), "V60 keeps technical engine selection in advanced options")
    var source: String = "user://v58_fixture.webp"
    var image := Image.create(320, 256, false, Image.FORMAT_RGB8)
    image.fill(Color.YELLOW)
    image.fill_rect(Rect2i(10, 20, 30, 40), Color.RED)
    assert(image.save_webp(source, true) == OK)
    # Recover a mailbox result even when Android recreated the Godot screen.
    board.photo_importing = false
    board._consume_photo_result(JSON.stringify({"state": "selected", "role": "reference", "value": source}), true)
    await process_frame
    assert(board.preview.texture != null)
    assert(board.preview.texture.get_width() == 320)
    var original: String = board.imported_path
    assert(FileAccess.file_exists(original))
    # Simulate a native selector whose return callback is lost after focus returns.
    board.photo_importing = true
    board.photo_app_focused = false
    board._update_photo_import_progress("selecting", board.PHOTO_IMPORT_TIMEOUT + 1.0)
    assert(board.photo_importing and board.photo_import_clock == 0.0)
    board.photo_app_focused = true
    board._update_photo_import_progress("selecting", board.PHOTO_IMPORT_TIMEOUT + 1.0)
    assert(not board.photo_importing and board.status.text.contains("selecting"))
    assert(not board.find_child("ChoosePhoto", true, false).disabled)
    assert(board.imported_path == original and board.preview.texture != null)
    board.action_input.text = "Une banane danse."
    board._save()
    var snapshot: String = original.get_base_dir().path_join("project.json")
    assert(FileAccess.file_exists(snapshot))
    board.photo_importing = true
    board._consume_photo_result(JSON.stringify({"state": "cancelled", "value": ""}))
    assert(board.imported_path == original)
    board.photo_importing = true
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
    reopened._restore_project(snapshot)
    assert(reopened.imported_path == original)
    assert(reopened.action_input.text == "Une banane danse.")
    assert(FileAccess.file_exists(current))
    reopened.queue_free()
    await process_frame
    print("V58_PHOTO_RECOVERY_OK: WebP pixels, preview, recovery, cancellation, errors, successive projects, reopen. Android NOT tested.")
    quit(0)
