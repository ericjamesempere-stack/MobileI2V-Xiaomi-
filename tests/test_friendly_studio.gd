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
    board.review_check.set_pressed_no_signal(true)
    board._sync_friendly_ui()
    assert(not board.friendly_export.disabled)
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
        var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
        image.fill(Color.SKY_BLUE)
        return {"ok": true, "image": image, "model": "SIMULATED"}
class IdeaBoard extends "res://scripts/storyboard.gd":
    var requested_ideas: Array[String] = []
    var received_stories: Array[String] = []
    var fail_creation: bool = false
    func _make_drawing_worker() -> Node:
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
    board.queue_free()
    await process_frame
    print("UNIVERSAL_IDEA_ENTRY_WIRING_OK: SIMULATED image creation; idea-only, optional subject, reference reuse, import guard and failure preservation")
