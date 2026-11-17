extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var bridge: RefCounted = load("res://scripts/chatgpt_board_bridge.gd").new()
    var prompt: String = bridge.request_prompt("Une banane danse puis tombe", "Une banane", "cartoon")
    assert(prompt.contains("4 colonnes") and prompt.contains("banane reste une banane"))
    assert(not prompt.contains("hf.space"))
    var sheet := Image.create(1024, 512, false, Image.FORMAT_RGB8)
    sheet.fill(Color.WHITE)
    for i in range(8):
        sheet.fill_rect(Rect2i((i % 4)*256+10+i*3, (i / 4)*256+20, 90, 150), Color.from_hsv(float(i)/8, 0.9, 0.7))
    var split: Dictionary = bridge.split_board(sheet)
    assert(split["ok"] and split["images"].size() == 8)
    assert(not split["layout_verified"] and not split["identity_verified"])
    assert(split["images"][0].get_size() == Vector2i(256,256))
    var duplicate := Image.create(1024,512,false,Image.FORMAT_RGB8)
    duplicate.fill(Color.WHITE)
    assert(not bridge.split_board(duplicate)["ok"])
    assert(not bridge.split_board(sheet, 0, 2)["ok"])
    assert(not bridge.split_board(sheet, 6, 2)["ok"])
    var board: Node = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    var source := Image.create(512,512,false,Image.FORMAT_RGB8)
    source.fill(Color.YELLOW)
    source.fill_rect(Rect2i(0,0,100,100),Color.RED)
    var source_path: String = "user://v59_source.png"
    source.save_png(source_path)
    await board._image_chosen(source_path)
    board.action_input.text = "Une banane danse puis tombe"
    board.chatgpt_pending = board._chatgpt_context()
    board.chatgpt_pending["columns"] = 4
    board.chatgpt_pending["rows"] = 2
    var path: String = "user://v59_sheet.png"
    sheet.save_png(path)
    await board._import_chatgpt_result(path, "board")
    assert(board.paths.size() == 8 and board.chatgpt_board_origin)
    for keep in board.accepted: assert(not keep)
    assert(not board._has_current_review())
    var old_paths: Array[String] = board.paths.duplicate()
    var old_hashes: Array[String] = []
    for p in old_paths: old_hashes.append(FileAccess.get_sha256(p))
    var index: int = 3
    board.chatgpt_pending = board._chatgpt_context()
    board.chatgpt_pending.merge({"kind":"replacement", "index":index, "old_path":old_paths[index], "old_hash":old_hashes[index]})
    var pending: Dictionary = board.chatgpt_pending.duplicate(true)
    var replacement: String = "user://v59_redo.png"
    source.save_png(replacement)
    await board._import_chatgpt_result(replacement, "replacement")
    assert(board.paths[index] != old_paths[index] and not board.accepted[index])
    for i in range(8):
        if i != index:
            assert(board.paths[i] == old_paths[i] and FileAccess.get_sha256(board.paths[i]) == old_hashes[i])
    # Reusing a consumed replacement cannot alter a drawing again.
    board.chatgpt_pending = pending
    var replaced: String = board.paths[index]
    await board._import_chatgpt_result(replacement, "replacement")
    assert(board.paths[index] == replaced)
    board._save()
    board._load_saved()
    assert(board.chatgpt_board_origin and board.v5_sheet_loaded and board.paths.size() == 8)
    board.chatgpt_pending = board._chatgpt_context()
    board.chatgpt_pending["story"] = "OLD STORY"
    await board._import_chatgpt_result(path,"board")
    assert(board.paths[index] == replaced)
    board.queue_free()
    await process_frame
    print("CHATGPT_BRIDGE_OK: production import, grid, duplicate guard, targeted replacement, stale guards, approval gate, restore; synthetic test art, NO AI inference or Android claim")
    quit(0)
