extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    root.size = Vector2i(720, 1280)
    var board: Control = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    var generator: RefCounted = load("res://scripts/procedural_cartoon_generator.gd").new()
    var reference: Image = generator.render("sample", 0.0, Vector2i(360, 480), "repos")
    var local_reference: String = OS.get_environment("KARMA_UI_REFERENCE")
    if not local_reference.is_empty():
        var loaded := Image.new()
        if loaded.load(local_reference) == OK:
            reference = loaded
    board.preview.texture = ImageTexture.create_from_image(reference)
    board.character_description.text = "Un renard en veste bleue"
    board.action_input.text = "Il marche, puis court. Il tombe et se relève."
    board.status.text = "Ton personnage est prêt ! À toi d'inventer son aventure."
    var folder: String = OS.get_environment("KARMA_UI_RENDER_DIR")
    if folder.is_empty():
        folder = "user://interface_preview"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var run_image: Image = generator.render("sample", 0.25, Vector2i(360, 480), "course")
    var local_pose: String = OS.get_environment("KARMA_UI_POSE")
    if not local_pose.is_empty():
        var loaded := Image.new()
        if loaded.load(local_pose) == OK:
            run_image = loaded
    for index in range(3):
        board._go_step(index)
        if index == 2:
            board.sources.assign([ImageTexture.create_from_image(reference), ImageTexture.create_from_image(run_image)])
            board.paths.assign(["sample_reference.png", "sample_run.png"])
            board.accepted.assign([false, false])
            board.plan.assign([0, 1])
            board._build_contact_sheet()
            board.status.text = "Tes dessins sont prêts. Regarde-les avant de créer ton film."
        for tick in range(5):
            await process_frame
        await RenderingServer.frame_post_draw
        var image: Image = root.get_texture().get_image()
        assert(image != null and not image.is_empty())
        assert(image.save_png(folder.path_join("step_%d.png" % (index + 1))) == OK)
        assert(board.root_box.size.x <= 682.0, "No horizontal overflow on a 720 pixel screen")
    board.free()
    print("FRIENDLY_STUDIO_RENDER_OK ", folder)
    quit(0)
