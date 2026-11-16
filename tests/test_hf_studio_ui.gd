extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var save_path: String = "user://mobilei2v_storyboard_v23.json"
    var existed: bool = FileAccess.file_exists(save_path)
    var backup: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if existed else PackedByteArray()
    var board: Control = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    var fixture := Image.create(32, 32, false, Image.FORMAT_RGB8)
    fixture.fill(Color.RED)
    assert(fixture.save_png("user://hf_ui_reference.png") == OK)
    board.imported_path = "user://hf_ui_reference.png"
    var original_hash: String = FileAccess.get_sha256(board.imported_path)
    board.character_description.text = "test fox"
    board.drawing_style.select(4)
    board.ai_drawings_count.value = 8
    board.ai_token_input.text = "never-store-this-test-token"
    board._reuse_reference_drawing()
    assert(board.sources.size() == 1)
    assert(board.paths[0] == board.imported_path)
    assert(FileAccess.get_sha256(board.paths[0]) == original_hash)
    var atlas: Image = board.contact_sheet.texture.get_image()
    assert(atlas != null and atlas.get_pixel(48, 64).is_equal_approx(Color.RED))
    var data: String = FileAccess.get_file_as_string(save_path)
    assert(not data.contains("never-store-this-test-token"))
    board.character_description.text = ""
    board.drawing_style.select(0)
    board._load_saved()
    assert(board.character_description.text == "test fox")
    assert(board.drawing_style.selected == 4)
    assert(int(board.ai_drawings_count.value) == 8)
    board.free()
    if existed:
        var file := FileAccess.open(save_path, FileAccess.WRITE)
        file.store_buffer(backup)
        file.close()
    else:
        DirAccess.remove_absolute(save_path)
    DirAccess.remove_absolute("user://hf_ui_reference.png")
    print("HF_STUDIO_UI_EXACT_REFERENCE_PERSISTENCE_OK")
    quit(0)
