extends SceneTree
# One bounded real inference attempt through the production screen.
# Only the synthetic reference already public in this repository is used.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var evidence_dir: String = OS.get_environment("KARMA_LIVE_EVIDENCE_DIR")
    if evidence_dir.is_empty():
        push_error("KARMA_LIVE_EVIDENCE_DIR is required")
        quit(2)
        return
    DirAccess.make_dir_recursive_absolute(evidence_dir)
    var board: Control = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    board.local_mode.set_pressed_no_signal(false)
    board.style_reference_path = ""
    board.character_description.text = ""
    board.custom_style_input.text = ""
    board.drawing_style.select(6)
    board.action_input.text = "La banane vivante se baisse, puis se redresse. Conserver son apparence, ses membres existants et le fond."
    board.duration_input.value = 3
    board.ai_drawings_count.value = 24
    await board._image_chosen("res://validation/v54-poses/reference.png")
    await board._friendly_generate()
    var files: Array = []
    for index in range(board.paths.size()):
        var path: String = board.paths[index]
        # The imported reference is never counted as a generated result.
        if path == board.imported_path or board.universal_folder.is_empty():
            continue
        var image := Image.new()
        if image.load(path) != OK:
            continue
        var destination: String = evidence_dir.path_join("pose_%04d.png" % index)
        if image.save_png(destination) == OK:
            files.append({"file": destination.get_file(), "sha256": FileAccess.get_sha256(destination), "width": image.get_width(), "height": image.get_height()})
    if not files.is_empty() and board.contact_sheet.texture != null:
        board.contact_sheet.texture.get_image().save_png(evidence_dir.path_join("contact_sheet.png"))
    if not board.universal_folder.is_empty():
        for name in ["scene.json", "plan.json", "generation.json", "fidelity_review.json"]:
            var source: String = board.universal_folder.path_join(name)
            if FileAccess.file_exists(source):
                DirAccess.copy_absolute(source, evidence_dir.path_join(name))
    var result: Dictionary = {
        "simulated": false,
        "entry": "production storyboard screen",
        "reference": "public synthetic validation/v54-poses/reference.png",
        "story": board.action_input.text,
        "status": board.status.text,
        "generated_pngs": files,
        "complete": board.last_ai_sequence_ok,
        "fidelity_verified": board.universal_quality.get("fidelity_verified", false),
        "human_approved": false,
        "device_test": false,
        "universal_quality": board.universal_quality
    }
    var report := FileAccess.open(evidence_dir.path_join("result.json"), FileAccess.WRITE)
    report.store_string(JSON.stringify(result, "  "))
    report.close()
    print("UNIVERSAL_LIVE_BOARD_RESULT " + JSON.stringify(result))
    var success: bool = result["complete"] and result["fidelity_verified"] and not files.is_empty()
    board.queue_free()
    await process_frame
    quit(0 if success else 1)
