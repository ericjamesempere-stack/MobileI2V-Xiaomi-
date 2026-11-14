extends Control
# V50 : workflow guide. Restauration du projet a l'ouverture, dialogue natif
# Android, messages honnetes sur les limites du mode photo.
var studio: Control
var prompt_field: LineEdit
var status: Label
var viewport: Control
var character: Control
var picker: FileDialog
var head_image: Image
var running := false
var seconds := 0.0
var duration := 5.0
var action := "danse"
var sequence: Array[String] = []
var sequence_index := 0
var loaded_path := ""
var photo_mode: CheckBox
var speed_slider: HSlider
var duration_slider: HSlider
var duration_label: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color("111c2b")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(scroll)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(680, 0)
    column.add_theme_constant_override("separation", 14)
    scroll.add_child(column)
    var heading := Label.new()
    heading.text = "MobileI2V V50 - Danse articulee"
    heading.add_theme_font_size_override("font_size", 27)
    column.add_child(heading)
    var info := Label.new()
    info.text = "Prototype hors ligne : le corps articule danse. La photo sert de reference de tete."
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(info)
    _add_button(column, "1. Choisir une photo (facultatif)", _choose_photo)
    photo_mode = CheckBox.new()
    photo_mode.text = "Mode photo corps entier (experimental)"
    photo_mode.button_pressed = true
    column.add_child(photo_mode)
    var hint := Label.new()
    hint.text = "Photo ideale : une personne debout, de face, corps entier et bras separes."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(hint)
    prompt_field = LineEdit.new()
    prompt_field.placeholder_text = "Ex. le personnage danse puis marche"
    prompt_field.text = "le personnage danse"
    column.add_child(prompt_field)
    duration_label = Label.new()
    duration_label.text = "5 secondes par mouvement"
    column.add_child(duration_label)
    duration_slider = HSlider.new()
    duration_slider.min_value = 2.0
    duration_slider.max_value = 12.0
    duration_slider.step = 1.0
    duration_slider.value = 5.0
    duration_slider.value_changed.connect(_duration_changed)
    column.add_child(duration_slider)
    _add_button(column, "2. Creer la sequence", _generate)
    var frame := PanelContainer.new()
    frame.custom_minimum_size = Vector2(660, 760)
    column.add_child(frame)
    viewport = Control.new()
    viewport.custom_minimum_size = Vector2(660, 760)
    frame.add_child(viewport)
    character = Control.new()
    character.set_script(load("res://scripts/rig_character.gd"))
    character.position = Vector2(-25, -95)
    character.size = Vector2(720, 900)
    viewport.add_child(character)
    _add_button(column, "3. Lecture / Pause", _toggle)
    _add_button(column, "Enregistrer la sequence", _save_sequence)
    _add_button(column, "Retour au studio V38", _close)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.text = "Pret. Selectionne une photo puis ecris une action."
    column.add_child(status)
    picker = FileDialog.new()
    picker.access = FileDialog.ACCESS_FILESYSTEM
    picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    picker.use_native_dialog = true
    picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
    picker.file_selected.connect(_photo_selected)
    add_child(picker)
    _restore_project()

func _restore_project() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://mobilei2v_v43_sequence.cfg") == OK:
        prompt_field.text = str(cfg.get_value("sequence", "prompt", "le personnage danse"))
        var saved_actions: Variant = cfg.get_value("sequence", "actions", [])
        if saved_actions is Array and not (saved_actions as Array).is_empty():
            sequence.clear()
            for a in saved_actions:
                sequence.append(str(a))
        duration = clampf(float(cfg.get_value("sequence", "duration", 5.0)), 2.0, 12.0)
        duration_slider.set_value_no_signal(duration)
        duration_label.text = "%d secondes par mouvement" % int(duration)
    var photo_path: String = "user://mobilei2v_v49_photo.png"
    if FileAccess.file_exists(photo_path):
        var img := Image.new()
        if img.load(photo_path) == OK and not img.is_empty():
            head_image = img
            loaded_path = photo_path
            var texture := ImageTexture.create_from_image(img)
            character.set("reference_head", texture)
            if photo_mode.button_pressed:
                character.call("set_full_body_photo", texture, Rect2(0.0, 0.0, 1.0, 1.0))
            status.text = "Projet precedent restaure (photo + sequence). Appuie sur Creer la sequence."

func _add_button(parent: Node, caption: String, handler: Callable) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 66)
    button.pressed.connect(handler)
    parent.add_child(button)

func _choose_photo() -> void:
    picker.popup_centered_ratio(0.92)

func _photo_selected(path: String) -> void:
    var img := Image.new()
    var err := img.load(path)
    if err != OK:
        status.text = "Image illisible : %s" % error_string(err)
        return
    head_image = img
    loaded_path = path
    img.save_png("user://mobilei2v_v49_photo.png")
    var texture := ImageTexture.create_from_image(img)
    character.set("reference_head", texture)
    if photo_mode.button_pressed:
        character.call("set_full_body_photo", texture, Rect2(0.0, 0.0, 1.0, 1.0))
    else:
        character.set("photo_puppet", false)
    character.queue_redraw()
    var rig_status: String = str(character.get("status_message"))
    status.text = "Photo chargee. " + rig_status

func _duration_changed(value: float) -> void:
    duration = value
    duration_label.text = "%d secondes par mouvement" % int(value)

func _generate() -> void:
    var planner = load("res://scripts/story_sequence_planner.gd")
    var steps: Array[Dictionary] = planner.plan(prompt_field.text, duration)
    sequence.clear()
    var unsupported: Array[String] = []
    for step in steps:
        if bool(step["supported"]):
            sequence.append(str(step["action"]))
        else:
            unsupported.append(str(step["action"]))
    if sequence.is_empty():
        running = false
        status.text = "Aucun mouvement pris en charge. A developper : " + ", ".join(PackedStringArray(unsupported))
        return
    if head_image != null:
        character.set("photo_puppet", photo_mode.button_pressed)
        character.queue_redraw()
    sequence_index = 0
    seconds = 0.0
    running = true
    action = sequence[0]
    status.text = "Sequence : %s. %.0f s/action. Non disponibles : %s" % [", ".join(PackedStringArray(sequence)), duration, ", ".join(PackedStringArray(unsupported))]
    character.call("update_pose", 0.0, action)

func _process(delta: float) -> void:
    if not running or sequence.is_empty():
        return
    seconds += delta
    if seconds >= duration:
        seconds = fmod(seconds, duration)
        sequence_index = (sequence_index + 1) % sequence.size()
        action = sequence[sequence_index]
    character.call("update_pose", seconds, action)

func _toggle() -> void:
    running = not running
    status.text = "Lecture" if running else "Pause"

func _save_sequence() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("sequence", "prompt", prompt_field.text)
    cfg.set_value("sequence", "actions", sequence)
    cfg.set_value("sequence", "photo_path", "user://mobilei2v_v49_photo.png" if head_image != null else "")
    cfg.set_value("sequence", "duration", duration)
    var err := cfg.save("user://mobilei2v_v43_sequence.cfg")
    status.text = "Sequence sauvegardee." if err == OK else "Echec sauvegarde : %s" % error_string(err)

func _close() -> void:
    queue_free()