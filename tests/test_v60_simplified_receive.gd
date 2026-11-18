extends SceneTree
class ShareBoard extends "res://scripts/storyboard.gd":
    var kinds: Array[String] = []
    func _send_chatgpt_request(kind: String = "board") -> void:
        kinds.append(kind) # Android share simulated; preparation fallback is production.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var board := ShareBoard.new()
    root.add_child(board)
    assert(board.wizard_tabs[0].text == "1. Créer")
    assert(board.wizard_tabs[1].text == "2. Mes dessins")
    assert(board.wizard_tabs[2].text == "3. Ma vidéo")
    assert(board.wizard_pages[0].is_ancestor_of(board.action_input))
    assert(board.advanced_panel.is_ancestor_of(board.local_mode))
    # The V60 primary generate action lives on the Create page, not in advanced settings.
    var generate_button: Button = null
    for item in board.wizard_buttons:
        if item.text == "Générer mes dessins avec les agents":
            generate_button = item
            break
    assert(generate_button != null and board.wizard_pages[0].is_ancestor_of(generate_button))
    assert(board.wizard_pages[1].is_ancestor_of(board.contact_sheet))
    assert(board.wizard_pages[2].is_ancestor_of(board.friendly_export))
    assert(not board.advanced_panel.visible)
    board.action_input.text = ""
    board.character_description.text = "Une voiture dérape sur une piste."
    board._send_chatgpt_board()
    assert(board.action_input.text == board.character_description.text and board.kinds == ["board"])
    var image:=Image.create(512,512,false,Image.FORMAT_RGB8)
    image.fill(Color.WHITE);image.fill_rect(Rect2i(50,50,250,300),Color.RED)
    var path: String="user://v60_received.png"
    image.save_png(path)
    var previous_reference: String=board.imported_path
    board._offer_shared_image(JSON.stringify({"id":"test-pending","state":"selected","value":path}))
    assert(is_instance_valid(board.shared_image_dialog))
    assert(board.imported_path == previous_reference, "Receiving alone cannot change a project")
    board._close_shared_dialog()
    await process_frame
    assert(board.shared_image_deferred and board.imported_path == previous_reference)
    await board._apply_shared_image(path,"reference")
    assert(board.imported_path != previous_reference and FileAccess.file_exists(board.imported_path))
    var reference: String = board.imported_path
    var sheet:=Image.create(1024,512,false,Image.FORMAT_RGB8)
    sheet.fill(Color.WHITE)
    for i in range(8):
        sheet.fill_rect(Rect2i((i%4)*256+10+i*3,(i/4)*256+20,90,150),Color.from_hsv(float(i)/8,0.9,0.7))
    var sheet_path: String="user://v60_received_board.png"
    sheet.save_png(sheet_path)
    await board._apply_shared_image(sheet_path,"board")
    assert(board.paths.size()==8 and board.imported_path==reference)
    assert(board.wizard_step==1, "Imported drawings open review, not export")
    assert(not board._has_current_review())
    var paths: Array[String]=board.paths.duplicate()
    board.chatgpt_pending=board._chatgpt_context()
    board.chatgpt_pending.merge({"kind":"replacement","index":2,"old_path":paths[2],"old_hash":FileAccess.get_sha256(paths[2])})
    await board._apply_shared_image(path,"replacement")
    assert(board.paths[2]!=paths[2] and not board.accepted[2])
    for i in range(8):
        if i!=2: assert(board.paths[i]==paths[i])
    board._save();board._load_saved()
    assert(board.paths.size()==8 and board.chatgpt_board_origin)
    board.queue_free()
    await process_frame
    print("V60_SIMPLIFIED_RECEIVE_OK: three steps, hidden engines, idea fallback, explicit shared-image choice, targeted replacement, approval and restore; Android share SIMULATED")
    quit(0)
