extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var board: Control = load("res://scripts/storyboard.gd").new()
    root.add_child(board)
    assert(board.wizard_pages.size() == 3)
    assert(board.wizard_pages[0].visible)
    assert(not board.wizard_pages[1].visible and not board.wizard_pages[2].visible)
    assert(not board.advanced_panel.visible, "Technical options must start closed")
    assert(not board.invent_box.visible)
    board.find_child("InventCharacter", true, false).pressed.emit()
    assert(board.invent_box.visible)
    board.style_tiles[4].pressed.emit()
    assert(board.drawing_style.selected == 4)
    board.find_child("NextStory", true, false).pressed.emit()
    assert(board.wizard_step == 1 and board.wizard_pages[1].visible)
    board.action_input.text = ""
    await board._friendly_generate()
    assert(board.status.text.contains("Raconte"))
    board.imported_path = ""
    board.character_description.text = ""
    board.action_input.text = ""
    await board._friendly_generate()
    assert(board.status.text.contains("Raconte"))
    board._go_step(2)
    board._sync_friendly_ui()
    assert(board.friendly_export.disabled, "An empty or unreviewed film cannot be exported")
    board.ai_running = true
    board._sync_friendly_ui()
    assert(board.busy_bar.visible)
    for item in board.wizard_buttons:
        assert(item.disabled, "Prevent duplicate actions while busy")
    board._go_step(0)
    assert(board.wizard_step == 2, "Do not switch steps while a generation is running")
    board.ai_running = false
    board._sync_friendly_ui()
    assert(not board.busy_bar.visible)
    board.find_child("AdvancedToggle", true, false).pressed.emit()
    assert(board.advanced_panel.visible)
    var frame := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    frame.fill(Color.RED)
    var texture: Texture2D = ImageTexture.create_from_image(frame)
    board.sources.assign([texture, texture])
    board.paths.assign(["demo_0.png", "demo_1.png"])
    board.accepted.assign([true, true])
    board.plan.assign([0, 1])
    board._sync_friendly_ui()
    assert(not board.review_check.button_pressed)
    assert(not board.friendly_export.disabled)
    assert(board._confirm_export_review())
    board._reject_all()
    board._sync_friendly_ui()
    assert(not board.review_check.button_pressed and board.friendly_export.disabled)
    board._toggle_drawing_preview()
    assert(board.drawing_preview_playing)
    board._toggle_drawing_preview()
    assert(not board.drawing_preview_playing)
    board.free()
    await test_idea_entry()
    print("FRIENDLY_STUDIO_NAVIGATION_AND_GUARDS_OK")
    quit(0)

# SIMULATED inference: tests wiring and preservation, not image quality.
class FakeImageWorker extends Node:
    var hf_token: String = ""
    var observer: Node
    func create_reference(description: String, _style: String) -> Dictionary:
        observer.requested_ideas.append(description)
        if observer.fail_creation:
            return {"ok": false, "error": "SIMULATED unavailable"}
        if observer.image_mode == "missing":
            return {"ok": true, "model": "SIMULATED missing pixels"}
        var side: int = 64 if observer.image_mode == "tiny" else 512
        var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
        image.fill(Color.SKY_BLUE)
        return {"ok": true, "image": image, "model": "SIMULATED"}
class ProbeImageWorker extends FakeImageWorker:
    func inspect_local_engines(_vision: bool, _drawing: bool) -> Dictionary:
        return {"ok": false, "message": "SIMULATED local probe failure", "drawing": {"http_status": observer.probe_status}}
class IdeaBoard extends "res://scripts/storyboard.gd":
    var requested_ideas: Array[String] = []
    var received_stories: Array[String] = []
    var fail_creation: bool = false
    var image_mode: String = "valid"
    var probe_status: int = -1
    func _make_drawing_worker() -> Node:
        if probe_status == -1:
            return _make_remote_drawing_worker()
        var worker := ProbeImageWorker.new()
        worker.observer = self
        return worker
    func _make_remote_drawing_worker() -> Node:
        var worker := FakeImageWorker.new()
        worker.observer = self
        return worker
    func _draw_remote_story() -> void:
        assert(not imported_path.is_empty() and FileAccess.file_exists(imported_path))
        received_stories.append(action_input.text)
func test_idea_entry() -> void:
    var board := IdeaBoard.new()
    root.add_child(board)
    board.imported_path = ""
    board.character_description.text = ""
    var idea: String = "Un paysage de montagne se transforme au lever du soleil."
    board.action_input.text = idea
    board.photo_importing = true
    await board._friendly_generate()
    await board._create_remote_reference("Do not generate during import")
    assert(board.requested_ideas.is_empty() and board.received_stories.is_empty())
    board.photo_importing = false
    await board._friendly_generate()
    assert(board.requested_ideas == [idea], "Story alone must create the initial scene")
    assert(board.received_stories == [idea], "Full idea must reach the existing board pipeline")
    assert(board.character_description.text.is_empty(), "Do not overwrite the optional description")
    var saved: String = board.imported_path
    var digest: String = FileAccess.get_sha256(saved)
    board.action_input.text = "La neige fond."
    await board._friendly_generate()
    assert(board.requested_ideas.size() == 1, "Reuse an imported or created reference")
    assert(board.imported_path == saved and FileAccess.get_sha256(saved) == digest)
    for invalid_mode in ["missing", "tiny"]:
        board.image_mode = invalid_mode
        var routed_before: int = board.received_stories.size()
        await board._create_remote_reference("Invalid fixture must preserve original")
        assert(board.imported_path == saved and FileAccess.get_sha256(saved) == digest)
        assert(board.received_stories.size() == routed_before)
        assert(board.status.text.contains("conservé"))
    board.image_mode = "valid"
    board.fail_creation = true
    await board._create_remote_reference("Un bateau")
    assert(board.imported_path == saved and FileAccess.get_sha256(saved) == digest)
    assert(board.status.text.contains("SIMULATED unavailable"))
    board.imported_path = ""
    board.fail_creation = false
    board.character_description.text = "Deux véhicules dans un désert"
    board.action_input.text = "Ils se croisent."
    await board._friendly_generate()
    assert(board.requested_ideas.back() == "Deux véhicules dans un désert")
    assert(board.received_stories.back() == "Ils se croisent.")
    assert(board.remote_fallback.button_pressed, "V61 enables online fallback by default")
    board.remote_fallback.button_pressed = false
    var before_fallback: int = board.requested_ideas.size()
    board.probe_status = 503
    await board._create_remote_reference("Moteur local indisponible")
    assert(board.requested_ideas.size() == before_fallback, "No remote upload without session consent")
    board.remote_fallback.button_pressed = true
    board.probe_status = 401
    await board._create_remote_reference("Authentification locale refusée")
    assert(board.requested_ideas.size() == before_fallback, "Authentication failure must stop")
    board.probe_status = 503
    await board._create_remote_reference("Secours distant autorisé")
    assert(board.requested_ideas.size() == before_fallback + 1)
    assert(board.requested_ideas.back() == "Secours distant autorisé")
    board.queue_free()
    await process_frame
    print("UNIVERSAL_IDEA_ENTRY_WIRING_OK: SIMULATED image creation; idea-only, optional subject, reference reuse, import guard and failure preservation")
    quit(0)
