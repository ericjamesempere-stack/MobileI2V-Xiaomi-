extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var save: String = "user://mobilei2v_storyboard_v23.json"
    var existed: bool = FileAccess.file_exists(save)
    var backup: PackedByteArray = FileAccess.get_file_as_bytes(save) if existed else PackedByteArray()
    var folder: String = "user://individual_import_%d" % Time.get_ticks_usec()
    assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
    var image := Image.create(512,512,false,Image.FORMAT_RGB8)
    image.fill(Color.WHITE)
    for i in range(2):
        image.fill_rect(Rect2i(50+i*50,50,100,150),Color.RED)
        assert(image.save_png(folder.path_join("drawing_%02d.png" % i)) == OK)
    var board: Control = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    await board._drawings_folder_selected(folder)
    assert(board.sources.size()==2 and board.accepted==[false,false])
    board.review_check.set_pressed(true)
    assert(not board._has_current_review() and not board.review_check.button_pressed)
    board._show_drawing_review()
    board.review_index=0
    board._review_choose(true)
    board.review_check.set_pressed(true)
    assert(not board._has_current_review(),"A single kept drawing cannot approve its neighbour")
    board.review_index=1
    board._review_choose(true)
    board.review_check.set_pressed(true)
    assert(board._has_current_review())
    # Importing a new batch cannot inherit acceptance of the preceding batch.
    await board._drawings_folder_selected(folder)
    assert(board.accepted==[false,false] and not board._has_current_review())
    board.review_check.set_pressed(true)
    assert(not board._has_current_review())
    var numbered: String=folder.path_join("numbered")
    assert(DirAccess.make_dir_recursive_absolute(numbered)==OK)
    for i in range(2):
        assert(image.save_png(numbered.path_join("frame_%04d.png" % i))==OK)
    await board._drawings_folder_selected(numbered)
    for keep in board.accepted:
        assert(not keep,"Numbered merge import must also require individual review")
    board.review_check.set_pressed(true)
    assert(not board._has_current_review())
    board.queue_free()
    await process_frame
    if existed:
        var f:=FileAccess.open(save,FileAccess.WRITE)
        f.store_buffer(backup)
        f.close()
    else:
        DirAccess.remove_absolute(save)
    print("IMPORTED_DRAWINGS_INDIVIDUAL_REVIEW_OK: plain and numbered batches need Keep per image; global confirmation cannot auto-accept")
    quit(0)
