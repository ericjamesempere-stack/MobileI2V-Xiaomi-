extends Control
# Minimal image-first studio. A generated sequence must be approved before export.
const FPS := 12
var selected_photo := ""
var project_root := ""
var generated := false
var approved := false
var frames: Array[String] = []
var frame_index := 0
var elapsed := 0.0
var playing := false
var preview: TextureRect
var status: Label
var prompt: LineEdit
var style: OptionButton
var duration: SpinBox
var photo_picker: FileDialog
var preview_button: Button
var approve_button: Button
var video_button: Button
var photo_button: Button
var sheet_button: Button
var contact_sheet_path := ""

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#101923")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var layout := VBoxContainer.new()
    layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_theme_constant_override("separation", 8)
    scroll.add_child(layout)
    var header := Label.new()
    header.text = "STUDIO ANIMATION"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_font_size_override("font_size", 26)
    layout.add_child(header)
    preview = TextureRect.new()
    preview.custom_minimum_size = Vector2(0, 380)
    preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    layout.add_child(preview)
    photo_button = _button(layout, "1. Ajouter une image ou une photo", _pick_photo)
    prompt = LineEdit.new()
    prompt.placeholder_text = "Ex : Le personnage court puis saute"
    layout.add_child(prompt)
    var settings := HBoxContainer.new()
    layout.add_child(settings)
    style = OptionButton.new()
    for name in ["manga", "bd", "cartoon"]:
        style.add_item(name)
    style.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    settings.add_child(style)
    duration = SpinBox.new()
    duration.min_value = 1.0
    duration.max_value = 15.0
    duration.step = 1.0
    duration.value = 5.0
    duration.suffix = " s"
    settings.add_child(duration)
    _button(layout, "2. Generer les dessins", _generate)
    preview_button = _button(layout, "3. Voir les mouvements en grand", _play)
    sheet_button = _button(layout, "Voir la planche de dessins", _show_contact_sheet)
    approve_button = _button(layout, "4. Valider cette sequence", _approve)
    video_button = _button(layout, "5. Creer la video", _export)
    status = Label.new()
    status.text = "Ajoute une image ou decris un mouvement."
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.custom_minimum_size.y = 55
    layout.add_child(status)
    _set_stage(false)
    photo_picker = FileDialog.new()
    photo_picker.access = FileDialog.ACCESS_FILESYSTEM
    photo_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    photo_picker.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Images")
    photo_picker.file_selected.connect(_photo_selected)
    add_child(photo_picker)

func _button(parent: Node, title: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size.y = 48
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(action)
    parent.add_child(b)
    return b

func _set_stage(has_frames: bool) -> void:
    preview_button.disabled = not has_frames
    sheet_button.disabled = not has_frames
    approve_button.disabled = not has_frames
    video_button.disabled = not approved

func _pick_photo() -> void:
    photo_picker.popup_centered_ratio(0.9)

func _photo_selected(path: String) -> void:
    var img := Image.new()
    if img.load(path) != OK:
        status.text = "Image illisible"
        return
    selected_photo = path
    preview.texture = ImageTexture.create_from_image(img)
    generated = false
    approved = false
    playing = false
    _set_stage(false)
    status.text = "Image chargee. Decris maintenant le mouvement."

func _generate() -> void:
    playing = false
    generated = false
    approved = false
    frames.clear()
    contact_sheet_path = ""
    _set_stage(false)
    var story := prompt.text.strip_edges()
    if story.is_empty():
        status.text = "Decris le mouvement a generer."
        return
    var refs: Array = []
    if not selected_photo.is_empty():
        refs.append(selected_photo)
    var project := StoryStudio.storyboard(story, duration.value, style.get_item_text(style.selected), refs)
    project["reference_paths"] = refs
    var plan := StoryActionPlanner.plan(project, FPS)
    if not plan.get("ok", false):
        status.text = "Erreur de planification"
        return
    project = plan["project"]
    project_root = "user://storyboards/quick_%d" % Time.get_ticks_msec()
    if not selected_photo.is_empty():
        var inspected := ReferenceSceneAnalyzer.analyze(selected_photo, project_root)
        if not inspected.get("ok", false):
            status.text = "Analyse de la photo impossible : " + str(inspected.get("error", "inconnue"))
            return
        project["scene_reference_profile"] = inspected["profile_path"]
        var style_path := project_root + "/reference_styled.png"
        var stylized := ReferenceStyleRenderer.render(selected_photo, style_path, style.get_item_text(style.selected))
        if not stylized.get("ok", false):
            status.text = "Transformation de l'image impossible : " + str(stylized.get("error", "inconnue"))
            return
        var styled_image := Image.new()
        if styled_image.load(style_path) == OK:
            preview.texture = ImageTexture.create_from_image(styled_image)
        project["styled_reference_path"] = style_path
        var keyframe_plan := ReferenceKeyframePlan.build(project, FPS)
        if not keyframe_plan.get("ok", false):
            status.text = "Plan de poses impossible : " + str(keyframe_plan.get("error", "inconnu"))
            return
        var keyframes := ReferenceKeyframeScheduler.schedule(keyframe_plan, 6)
        if not keyframes.get("ok", false):
            status.text = "Selection des poses impossible"
            return
        var keyframes_saved := ReferenceKeyframeScheduler.save(keyframes, project_root + "/poses_cles.json")
        if not keyframes_saved.get("ok", false):
            status.text = "Sauvegarde des poses cles impossible"
            return
        var plan_saved := ReferenceKeyframePlan.save(keyframe_plan, project_root + "/poses_a_generer.json")
        if not plan_saved.get("ok", false):
            status.text = "Impossible de sauvegarder les poses"
            return
        var file := FileAccess.open(project_root + "/storyboard.json", FileAccess.WRITE)
        if file != null:
            file.store_string(JSON.stringify(project, "  "))
            file.close()
        status.text = "%d images prevues, dont %d poses cles. Dessin fidele et interpolation encore non connectes." % [int(plan_saved["frames"]), int(keyframes_saved["keyframes"])]
        return
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(project_root)) != OK:
        status.text = "Impossible de creer le dossier."
        return
    var result := ProceduralPoseRenderer.render(project, project_root, FPS)
    if not result.get("ok", false):
        status.text = "Mouvement non disponible : " + str(result.get("error", "inconnu"))
        return
    var imported := StoryFramePipeline.import_rendered_scenes(project, project_root)
    if not imported.get("ok", false):
        status.text = "Erreur images : " + str(imported.get("error", "inconnue"))
        return
    var exported := StoryFramePipeline.export_png_sequence(imported["project"], project_root + "/sequence", FPS)
    if not exported.get("ok", false):
        status.text = "Erreur sequence : " + str(exported.get("error", "inconnue"))
        return
    for i in range(int(exported["frame_count"])):
        frames.append("%s/sequence/frame_%06d.png" % [project_root, i])
    var sheet_result := AnimationContactSheet.build(frames, project_root + "/planche.png")
    if sheet_result.get("ok", false):
        contact_sheet_path = str(sheet_result["path"])
    generated = true
    _set_stage(true)
    _show_frame(0)
    status.text = "%d dessins crees. Regarde les gestes, puis valide." % frames.size()

func _show_frame(index: int) -> void:
    if index < 0 or index >= frames.size():
        return
    var img := Image.new()
    if img.load(frames[index]) == OK:
        preview.texture = ImageTexture.create_from_image(img)

func _show_contact_sheet() -> void:
    if contact_sheet_path.is_empty():
        status.text = "Planche indisponible"
        return
    playing = false
    var img := Image.new()
    if img.load(contact_sheet_path) == OK:
        preview.texture = ImageTexture.create_from_image(img)
        status.text = "Planche des poses generees. Valide apres inspection."

func _play() -> void:
    if not generated:
        return
    frame_index = 0
    elapsed = 0.0
    playing = true
    _show_frame(0)
    status.text = "Lecture des vrais dessins successifs."

func _process(delta: float) -> void:
    if not playing or frames.is_empty():
        return
    elapsed += delta
    while elapsed >= 1.0 / float(FPS):
        elapsed -= 1.0 / float(FPS)
        frame_index += 1
        if frame_index >= frames.size():
            playing = false
            frame_index = frames.size() - 1
            break
    _show_frame(frame_index)

func _approve() -> void:
    if not generated:
        return
    approved = true
    _set_stage(true)
    status.text = "Sequence validee. La video peut etre creee."

func _export() -> void:
    if not approved:
        return
    # The Android MP4 encoder is not connected to storyboard frames yet.
    # Keep the validated PNG sequence rather than falsely naming it MP4.
    status.text = "Dessins valides dans le projet. Encodage MP4 de cette sequence non disponible dans cette version."
