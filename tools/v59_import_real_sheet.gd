extends SceneTree
# Real generated artwork supplied separately. No inference is performed by this importer.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var sheet_path: String = OS.get_environment("KARMA_REAL_SHEET")
    var out: String = OS.get_environment("KARMA_REAL_PROOF")
    assert(not sheet_path.is_empty() and not out.is_empty())
    var board: Node = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    board.action_input.text = "Une banane vivante danse, saute, tombe sur le côté puis se redresse. Aucun bras ni jambe."
    board.chatgpt_pending = board._chatgpt_context()
    board.chatgpt_pending["columns"] = 4
    board.chatgpt_pending["rows"] = 2
    await board._import_chatgpt_result(sheet_path,"board")
    assert(board.paths.size() == 8 and board.chatgpt_board_origin)
    assert(not board._has_current_review())
    var files: Array[String] = []
    DirAccess.make_dir_recursive_absolute(out)
    for i in range(8):
        var path: String = out.path_join("frame_%04d.png" % i)
        var source: Image = load("res://scripts/android_image_reader.gd").read_image(board.paths[i])
        assert(source != null)
        assert(source.save_png(path) == OK)
        files.append(path)
    # Simulated test clicks, never approvals of a user-owned project.
    for i in range(8):
        board.review_index = i
        board._review_choose(true)
    board.review_check.set_pressed(true)
    assert(board._has_current_review())
    var result: Dictionary = {"source_sheet": sheet_path.get_file(), "source_sha256": FileAccess.get_sha256(sheet_path), "real_ai_artwork": true, "inference_inside_android": false, "android_share_tested": false, "human_approval_clicks": "simulated in isolated test project", "count":8, "paths":files, "all_unapproved_on_import":true, "export_gate_passed_only_after_test_clicks":true}
    var f:= FileAccess.open(out.path_join("real_import.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(result,"  "));f.close()
    print("REAL_AI_SHEET_IMPORT_OK ",JSON.stringify(result))
    board.queue_free()
    await process_frame
    quit(0)
