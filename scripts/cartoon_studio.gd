extends Control
# Cartoon Studio: single linear flow. No demo character and no hidden fake redraw.
const FPS := 30
var source: Image
var frames: Array[Texture2D] = []
var prompt: TextEdit
var duration: SpinBox
var endpoint: LineEdit
var upload_consent: CheckBox
var status: Label
var preview: TextureRect
var action: Button
var picker: FileDialog
var generator: Node
var exporter: Node
var step := 0
var busy := false
var project_dir := "user://cartoon_studio"
var style: OptionButton
var sheet_button: Button
var play_button: Button
var approve_button: Button
var approved := false
var playing := false
var playback_clock := 0.0
var sheet_path := ""
var native_picker_pending := false
var native_picker_wait_seconds := 0.0

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(project_dir))
    var background := ColorRect.new()
    background.color = Color("#101722")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(scroll)
    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(690, 0)
    panel.add_theme_constant_override("separation", 20)
    scroll.add_child(panel)
    var heading := Label.new()
    heading.text = "CARTOON STUDIO"
    heading.add_theme_font_size_override("font_size", 36)
    panel.add_child(heading)
    var subtitle := Label.new()
    subtitle.text = "Image  >  Dessins  >  MP4"
    panel.add_child(subtitle)
    preview = TextureRect.new()
    preview.custom_minimum_size = Vector2(660, 490)
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    panel.add_child(preview)
    var import_button := Button.new()
    import_button.text = "Choisir une image"
    import_button.custom_minimum_size.y = 80
    import_button.pressed.connect(_choose_image)
    panel.add_child(import_button)
    var alternate_import := Button.new()
    alternate_import.text = "Autre methode : parcourir les fichiers"
    alternate_import.custom_minimum_size.y = 72
    alternate_import.pressed.connect(func():
        native_picker_pending = false
        status.text = "Selectionne une image via le selecteur de fichiers alternatif."
        picker.popup_centered_ratio(0.95)
    )
    panel.add_child(alternate_import)
    prompt = TextEdit.new()
    prompt.placeholder_text = "Que doit faire ton personnage ? Exemple : il se leve, marche, puis salue."
    prompt.custom_minimum_size.y = 140
    panel.add_child(prompt)
    style = OptionButton.new()
    for style_name in ["manga", "bd", "cartoon", "cinema", "naturel"]:
        style.add_item(style_name)
    panel.add_child(style)
    play_button = Button.new()
    play_button.text = "Previsualiser les mouvements"
    play_button.pressed.connect(_play_sequence)
    panel.add_child(play_button)
    sheet_button = Button.new()
    sheet_button.text = "Voir la planche de dessins"
    sheet_button.pressed.connect(_show_sheet)
    panel.add_child(sheet_button)
    approve_button = Button.new()
    approve_button.text = "Valider les dessins (optionnel)"
    approve_button.pressed.connect(_approve_sequence)
    panel.add_child(approve_button)
    var duration_row := HBoxContainer.new()
    panel.add_child(duration_row)
    var duration_title := Label.new()
    duration_title.text = "Duree (secondes)"
    duration_row.add_child(duration_title)
    duration = SpinBox.new()
    duration.min_value = 1
    duration.max_value = 60
    duration.step = 1
    duration.value = 5
    duration.value_changed.connect(_duration_changed)
    duration_row.add_child(duration)
    var engine_title := Label.new()
    engine_title.text = "Moteur de redessin HTTPS (necessaire pour de nouveaux dessins)"
    engine_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(engine_title)
    endpoint = LineEdit.new()
    endpoint.placeholder_text = "https://.../generate"
    panel.add_child(endpoint)
    upload_consent = CheckBox.new()
    upload_consent.text = "J’autorise l’envoi de mon image au moteur HTTPS indique ci-dessus"
    upload_consent.button_pressed = false
    panel.add_child(upload_consent)
    action = Button.new()
    action.text = "Generer les dessins"
    action.custom_minimum_size.y = 100
    action.pressed.connect(_advance)
    panel.add_child(action)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(status)
    picker = FileDialog.new()
    picker.access = FileDialog.ACCESS_FILESYSTEM
    picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    picker.use_native_dialog = false
    picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
    picker.file_selected.connect(_image_selected)
    picker.canceled.connect(func(): status.text = "Selection annulee. Choisis une photo dans Images ou Telechargements.")
    add_child(picker)
    generator = Node.new()
    generator.set_script(load("res://scripts/image_sequence_generator.gd"))
    add_child(generator)
    generator.connect("progress", Callable(self, "_progress"))
    exporter = Node.new()
    exporter.set_script(load("res://scripts/export_mp4.gd"))
    add_child(exporter)
    exporter.set("status_label", status)
    _restore()
    if source == null or source.is_empty():
        _duration_changed(duration.value)
    else:
        status.text = "Photo restauree et prete pour la generation."
    _refresh_review_buttons()

func _choose_image() -> void:
    if busy:
        return
    if Engine.has_singleton("MP4Exporter"):
        var native: Object = Engine.get_singleton("MP4Exporter")
        if native.has_method("pick_image") and bool(native.call("pick_image")):
            native_picker_pending = true
            native_picker_wait_seconds = 0.0
            status.text = "Selectionne une photo dans la galerie Android..."
            return
    status.text = "Selecteur Android natif indisponible : ouverture du selecteur Godot (diagnostic)."
    picker.popup_centered_ratio(0.95)

func _image_selected(path: String) -> void:
    # Android's native document picker can return a content:// URI rather
    # than an ordinary filesystem path. Do not claim a successful import
    # until a readable PNG has been persisted and loaded back.
    status.text = "Import de l'image en cours..."
    # Reuse the existing Android-aware image reader rather than duplicating
    # the import implementation in this screen.
    var img: Image = load("res://scripts/android_image_reader.gd").read_image(path)
    print("Cartoon Studio image import: ", path, " decoded=", img != null and not img.is_empty())
    if img == null or img.is_empty():
        if path.begins_with("content://"):
            status.text = "Acces Android refuse pour content://. Le lecteur existant ne peut pas ouvrir ce document; un pont ContentResolver est requis."
        else:
            status.text = "Impossible de lire cette image. Essaie un fichier JPG ou PNG."
        return
    var saved_path := project_dir + "/reference.png"
    var save_error := img.save_png(saved_path)
    if save_error != OK:
        status.text = "Erreur d'enregistrement de la photo (code %d)." % save_error
        return
    var persisted := Image.new()
    if persisted.load(saved_path) != OK or persisted.is_empty():
        status.text = "Verification de sauvegarde echouee. L'ancienne image est conservee."
        return
    source = persisted
    preview.texture = ImageTexture.create_from_image(source)
    preview.show()
    frames.clear()
    approved = false
    playing = false
    sheet_path = ""
    _clear_saved_frames()
    step = 0
    action.text = "Generer les dessins"
    status.text = "Image importee et sauvegardee : %d x %d pixels." % [source.get_width(), source.get_height()]
    _save()
    _refresh_review_buttons()

func _duration_changed(value: float) -> void:
    if status != null and step == 0 and not busy:
        var drawings: int = mini(240, maxi(2, roundi(value * 12.0)))
        status.text = "%d dessins demandes (%.1f/s), export %d images/s. Limite : 240 dessins." % [drawings, float(drawings) / maxf(value, 1.0), FPS]

func _save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("project", "story", prompt.text)
    cfg.set_value("project", "seconds", duration.value)
    cfg.set_value("project", "endpoint", endpoint.text)
    cfg.set_value("project", "style", style.selected)
    cfg.save(project_dir + "/project.cfg")

func _restore() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(project_dir + "/project.cfg") == OK:
        prompt.text = str(cfg.get_value("project", "story", ""))
        duration.value = float(cfg.get_value("project", "seconds", 5.0))
        endpoint.text = str(cfg.get_value("project", "endpoint", ""))
        style.select(clampi(int(cfg.get_value("project", "style", 0)), 0, style.item_count - 1))
    if FileAccess.file_exists(project_dir + "/reference.png"):
        var img := Image.new()
        if img.load(project_dir + "/reference.png") == OK:
            source = img
            preview.texture = ImageTexture.create_from_image(img)
    _restore_saved_frames()

func _clear_saved_frames() -> void:
    var folder: String = project_dir + "/generated_frames"
    var dir := DirAccess.open(folder)
    if dir == null:
        return
    for filename in dir.get_files():
        if filename.begins_with("frame_") and filename.ends_with(".png"):
            dir.remove(filename)
    if FileAccess.file_exists(project_dir + "/frames.cfg"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(project_dir + "/frames.cfg"))

func _restore_saved_frames() -> void:
    var manifest := ConfigFile.new()
    if manifest.load(project_dir + "/frames.cfg") != OK:
        return
    var count: int = int(manifest.get_value("frames", "count", 0))
    if count < 2 or count > 240:
        return
    var loaded: Array[Texture2D] = []
    for index in range(count):
        var image := Image.new()
        var filename: String = "%s/generated_frames/frame_%04d.png" % [project_dir, index]
        if image.load(filename) != OK or image.is_empty():
            return
        loaded.append(ImageTexture.create_from_image(image))
    frames = loaded
    _build_sheet()
    preview.texture = frames[0]
    step = 1
    action.text = "Exporter MP4"
    status.text = "%d dessins retrouves. Export MP4 disponible." % frames.size()

func _progress(index: int, total: int) -> void:
    status.text = "Dessin %d / %d" % [index, total]

func _advance() -> void:
    if busy:
        return
    if step == 1:
        if frames.is_empty():
            status.text = "Aucun dessin valide : assemblage interdit."
            return
        busy = true
        action.disabled = true
        await _export_generated_mp4()
        action.disabled = false
        busy = false
        return
    if source == null or source.is_empty():
        status.text = "Choisis une image avant de generer."
        return
    if prompt.text.strip_edges().is_empty():
        status.text = "Decris les gestes du personnage."
        return
    var online_mode: bool = endpoint.text.begins_with("https://")
    if online_mode and not upload_consent.button_pressed:
        status.text = "Autorise l'envoi de la photo au moteur HTTPS ou vide son adresse pour le mode local."
        return
    _save()
    busy = true
    action.disabled = true
    # 12 genuinely requested drawings per second, capped at 240 to keep
    # inference and RAM bounded; the MP4 encoder still writes 30 fps.
    var count := mini(240, maxi(2, roundi(duration.value * 12.0)))
    status.text = "Creation de %d dessins distincts pour %.0f secondes..." % [count, duration.value]
    var styled_story: String = "%s, style %s" % [prompt.text, style.get_item_text(style.selected)]
    var result: Dictionary
    if online_mode:
        result = await generator.call("generate", source, styled_story, endpoint.text, count, false, "", duration.value)
    else:
        result = await _generate_local_drawings(count)
    if not bool(result.get("ok", false)):
        status.text = "Generation arretee : " + str(result.get("error", "Erreur inconnue"))
    else:
        frames.clear()
        approved = false
        _clear_saved_frames()
        var saved_dir: String = project_dir + "/generated_frames"
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saved_dir))
        var frame_index: int = 0
        for img in result.get("frames", []):
            if img is Image and not img.is_empty():
                img.save_png("%s/frame_%04d.png" % [saved_dir, frame_index])
                frames.append(ImageTexture.create_from_image(img))
                frame_index += 1
        if frames.is_empty():
            status.text = "Le moteur n'a retourne aucun dessin."
        else:
            var manifest := ConfigFile.new()
            manifest.set_value("frames", "count", frames.size())
            manifest.save(project_dir + "/frames.cfg")
            preview.texture = frames[0]
            step = 1
            action.text = "Exporter MP4"
            _build_sheet()
            status.text = "%d dessins sauvegardes (%s). Creation du MP4..." % [frames.size(), "IA externe" if online_mode else "animation locale stylisee, visage non reproduit"]
            await _export_generated_mp4()
    busy = false
    action.disabled = false
    _refresh_review_buttons()

func _refresh_review_buttons() -> void:
    if play_button == null:
        return
    play_button.disabled = frames.is_empty() or busy
    sheet_button.disabled = sheet_path.is_empty() or busy
    approve_button.disabled = frames.is_empty() or busy
    if action != null:
        action.text = "Exporter MP4" if step == 1 else "Generer les dessins"

func _build_sheet() -> void:
    sheet_path = ""
    if frames.is_empty():
        return
    var folder := project_dir + "/generated_frames"
    var paths: Array[String] = []
    for i in range(frames.size()):
        paths.append("%s/frame_%04d.png" % [folder, i])
    var output := project_dir + "/planche.png"
    var result: Dictionary = AnimationContactSheet.build(paths, output)
    if bool(result.get("ok", false)):
        sheet_path = output

func _show_sheet() -> void:
    if sheet_path.is_empty() or busy:
        return
    playing = false
    var image := Image.new()
    if image.load(sheet_path) == OK:
        preview.texture = ImageTexture.create_from_image(image)
        status.text = "Planche de controle des dessins generes."

func _play_sequence() -> void:
    if frames.is_empty() or busy:
        return
    playing = true
    playback_clock = 0.0
    preview.texture = frames[0]
    status.text = "Lecture des dessins successifs."

func _process(delta: float) -> void:
    if native_picker_pending and Engine.has_singleton("MP4Exporter"):
        native_picker_wait_seconds += delta
        if native_picker_wait_seconds > 15.0:
            native_picker_pending = false
            status.text = "Le selecteur Android ne renvoie pas la photo. Utilise Autre methode : parcourir les fichiers."
            return
        var native: Object = Engine.get_singleton("MP4Exporter")
        var path: String = str(native.call("take_selected_image_path"))
        if not path.is_empty():
            native_picker_pending = false
            _image_selected(path)
        else:
            var failure: String = str(native.call("take_image_picker_error"))
            if not failure.is_empty():
                native_picker_pending = false
                status.text = "Import Android : " + failure
    if not playing or frames.is_empty():
        return
    playback_clock += delta
    var index := floori(playback_clock * float(frames.size()) / maxf(duration.value, 0.1))
    if index >= frames.size():
        playing = false
        index = frames.size() - 1
    preview.texture = frames[index]

func _approve_sequence() -> void:
    if frames.is_empty() or busy:
        return
    playing = false
    approved = true
    status.text = "%d dessins valides. Export MP4 disponible." % frames.size()

func _export_generated_mp4() -> void:
    if frames.is_empty():
        status.text = "Aucun dessin a encoder."
        return
    var timeline: Array = []
    var total: int = maxi(1, roundi(duration.value * FPS))
    for i in range(total):
        timeline.append(mini(frames.size() - 1, floori(float(i) * float(frames.size()) / float(total))))
    await exporter.call("export_board_mp4", frames, timeline, duration.value)

func _generate_local_drawings(count: int) -> Dictionary:
    # Genuine distinct pose drawings, but not AI identity-preserving redrawing.
    # The reference supplies a color palette; it does not reproduce the face.
    var motion_script: Script = load("res://scripts/story_motion_planner.gd")
    var renderer_script: Script = load("res://scripts/reference_guided_cartoon_renderer.gd")
    var planner: RefCounted = motion_script.new()
    var renderer: RefCounted = renderer_script.new()
    var plan: Dictionary = planner.plan(prompt.text, duration.value)
    if not bool(plan.get("ok", false)):
        return {"ok": false, "error": "Histoire non comprise : " + str(plan.get("error", "action inconnue"))}
    var drawings: Array[Image] = []
    for i in range(count):
        var seconds: float = float(i) / float(maxi(1, count - 1)) * duration.value
        var action_name: String = str(planner.action_at(plan, seconds))
        var supported: Array[String] = ["repos", "marche", "course", "saut", "chute", "trebuche", "releve", "danse", "salut"]
        if not supported.has(action_name):
            return {"ok": false, "error": "Mouvement local non disponible : " + action_name}
        var phase: float = 0.0
        for step_data in plan.get("steps", []):
            if seconds < float(step_data.get("end", 0.0)) or step_data == plan.get("steps", []).back():
                var start_time: float = float(step_data.get("start", 0.0))
                var end_time: float = float(step_data.get("end", start_time + 1.0))
                phase = clampf((seconds - start_time) / maxf(0.001, end_time - start_time), 0.0, 1.0)
                break
        if action_name in ["marche", "course", "danse"]:
            phase = seconds * (1.8 if action_name == "course" else 1.0)
        var rendered: Dictionary = renderer.render_with_reference(source, prompt.text, phase, Vector2i(360, 480), action_name)
        if not bool(rendered.get("ok", false)):
            return {"ok": false, "error": str(rendered.get("reason", "Dessin local impossible"))}
        drawings.append(rendered["image"])
        if i % 4 == 0:
            _progress(i + 1, count)
            await get_tree().process_frame
    return {"ok": true, "frames": drawings, "method": "procedural_pose_reference_palette", "identity_verified": false}
