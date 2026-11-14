extends Control
# V50 : planche / validation offline. Corrections : bornes d'index,
# double refresh supprime. Export AVI/MJPEG conserve, MP4 via plugin separe.
var root_box: VBoxContainer
var preview: TextureRect
var contact_sheet: TextureRect
var contact_caption: Label
var skeleton_preview: TextureRect
var ai_endpoint: LineEdit
var ai_http: HTTPRequest
var ai_running: bool = false
var pose_http: HTTPRequest
var pose_running: bool = false
var detected_landmarks: Array = []
var status: Label
var action_input: TextEdit
var duration_input: SpinBox
var frame_index: int = 0
var accepted: Array[bool] = []
var sources: Array[Texture2D] = []
var paths: Array[String] = []
var plan: Array[int] = []
var parent_studio: Control
var picker: FileDialog
var video_picker: FileDialog
var v5_sheet_loaded: bool = false
var pose_sheet_picker: FileDialog
var exporting_video: bool = false
var imported_path: String = ""
const SAVE: String = "user://mobilei2v_storyboard_v23.json"

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var backdrop := ColorRect.new()
    backdrop.color = Color("101923")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var sc := ScrollContainer.new()
    sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(sc)
    root_box = VBoxContainer.new()
    root_box.custom_minimum_size = Vector2(0, 0)
    root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root_box.add_theme_constant_override("separation", 12)
    sc.add_child(root_box)
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _label("MOBILEI2V | STUDIO DE CREATION", 28)
    _label("1. Importe ton personnage. 2. Decris son mouvement. 3. Cree et controle les dessins.", 18)
    _label("Important : le mode photo actuel anime un detourage 2D. Il ne redessine pas encore chaque posture avec une IA.", 16)
    _button("1. CHOISIR MA PHOTO", _choose_image)
    status = _label("Choisis une photo pour creer une planche locale approximative.", 23)
    preview = TextureRect.new()
    preview.custom_minimum_size = Vector2(0, 210)
    preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    root_box.add_child(preview)
    skeleton_preview = TextureRect.new()
    skeleton_preview.custom_minimum_size = Vector2(0, 360)
    skeleton_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    skeleton_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    skeleton_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    skeleton_preview.visible = false
    root_box.add_child(skeleton_preview)
    action_input = TextEdit.new()
    action_input.custom_minimum_size = Vector2(0, 125)
    action_input.placeholder_text = "Exemple : Le personnage danse, saute puis tombe et se releve."
    root_box.add_child(action_input)
    var line := HBoxContainer.new()
    root_box.add_child(line)
    var lbl := Label.new()
    lbl.text = "Duree (secondes) : "
    line.add_child(lbl)
    duration_input = SpinBox.new()
    duration_input.min_value = 1
    duration_input.max_value = 60
    duration_input.step = 1
    duration_input.value = 6
    line.add_child(duration_input)
    _button("CREER DES POSES 2D A PARTIR DE MA PHOTO", _automatic_local_movie)
    contact_caption = _label("Les poses generees apparaitront ici.", 20)
    contact_sheet = TextureRect.new()
    contact_sheet.custom_minimum_size = Vector2(0, 220)
    contact_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    contact_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    contact_sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    root_box.add_child(contact_sheet)
    _button("IMPORTER 18 DESSINS DEJA CREES (V5)", _choose_pose_sheet)
    _button("EXPORTER LE FILM MP4 (APRES VERIFICATION)", _export_board_mp4)
    var advanced_box := VBoxContainer.new()
    root_box.add_child(advanced_box)
    advanced_box.visible = false
    _button("OPTIONS AVANCEES : AFFICHER / MASQUER", func() -> void: advanced_box.visible = not advanced_box.visible)
    var advanced_title := Label.new()
    advanced_title.text = "OPTIONS AVANCEES (facultatives)"
    advanced_box.add_child(advanced_title)
    var endpoint_label := Label.new()
    endpoint_label.text = "Serveur IA externe (facultatif)"
    advanced_box.add_child(endpoint_label)
    ai_endpoint = LineEdit.new()
    ai_endpoint.placeholder_text = "https://ton-serveur/generate/storyboard"
    advanced_box.add_child(ai_endpoint)
    _button("Detecter le squelette (serveur externe)", _request_pose, advanced_box)
    _button("Poses avec articulations detectees", _generate_detected_board, advanced_box)
    _button("IA externe (secours facultatif)", _request_ai_board, advanced_box)
    _button("Generer images successives (moteur HTTPS)", _generate_image_sequence, advanced_box)
    _button("Mouvement de camera sur photo (sans IA)", _generate_from_photo, advanced_box)
    _button("Dessiner un personnage generique (sans photo)", _generate_text_cartoon, advanced_box)
    _button("DEMO : planches personnage articule", _generate_layered_demo, advanced_box)
    _button("Animation articulee approximative", _generate_articulated_board, advanced_box)
    _button("Exporter AVI (secours)", _export_video_direct, advanced_box)
    _button("Planche de demonstration", _prepare, advanced_box)
    _button("Exporter les images PNG", _export_png_sequence, advanced_box)
    _button("Tout valider", _approve_all, advanced_box)
    _button("Tout retirer", _reject_all, advanced_box)
    _button("Pose precedente", _previous, advanced_box)
    _button("Valider ou retirer la pose", _toggle_approval, advanced_box)
    _button("Pose suivante", _next, advanced_box)
    _button("Enregistrer la planche", _save, advanced_box)
    _button("Recharger la planche", _load_saved, advanced_box)
    _button("FERMER LE STUDIO (ANCIEN LECTEUR)", _close)
    picker = FileDialog.new()
    picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    picker.access = FileDialog.ACCESS_FILESYSTEM
    # Start in shared pictures rather than Android filesystem root.
    if OS.get_name() == "Android":
        picker.current_dir = "/storage/emulated/0/Pictures"
    picker.use_native_dialog = true
    picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Images;image/png,image/jpeg,image/webp"])
    picker.file_selected.connect(_image_chosen)
    add_child(picker)
    pose_sheet_picker = FileDialog.new()
    pose_sheet_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    pose_sheet_picker.access = FileDialog.ACCESS_FILESYSTEM
    pose_sheet_picker.use_native_dialog = true
    pose_sheet_picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg;Planche de poses"])
    pose_sheet_picker.file_selected.connect(_pose_sheet_selected)
    add_child(pose_sheet_picker)
    video_picker = FileDialog.new()
    video_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    video_picker.access = FileDialog.ACCESS_FILESYSTEM
    video_picker.use_native_dialog = true
    video_picker.filters = PackedStringArray(["*.avi ; Video AVI Motion JPEG"])
    video_picker.file_selected.connect(_export_video)
    add_child(video_picker)
    ai_http = HTTPRequest.new()
    ai_http.timeout = 240.0
    add_child(ai_http)
    ai_http.request_completed.connect(_ai_completed)
    pose_http = HTTPRequest.new()
    pose_http.timeout = 45.0
    add_child(pose_http)
    pose_http.request_completed.connect(_pose_completed)
    _load_saved()
    if not sources.is_empty():
        _build_contact_sheet()

func _label(t: String, size: int) -> Label:
    var l := Label.new()
    l.text = t
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", size)
    root_box.add_child(l)
    return l

func _button(t: String, cb: Callable, target: Node = null) -> void:
    var b := Button.new()
    b.text = t
    b.custom_minimum_size = Vector2(0, 62)
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(cb)
    if target == null: root_box.add_child(b)
    else: target.add_child(b)

func _avi_u16(v: int) -> PackedByteArray:
    var b := PackedByteArray()
    b.resize(2)
    b.encode_u16(0, v)
    return b

func _avi_u32(v: int) -> PackedByteArray:
    var b := PackedByteArray()
    b.resize(4)
    b.encode_u32(0, v)
    return b

func _avi_fourcc(s: String) -> PackedByteArray:
    return s.to_ascii_buffer()

func _avi_chunk(tag: String, payload: PackedByteArray) -> PackedByteArray:
    var b := _avi_fourcc(tag)
    b.append_array(_avi_u32(payload.size()))
    b.append_array(payload)
    if payload.size() % 2 != 0:
        b.append(0)
    return b

func _avi_list(kind: String, payload: PackedByteArray) -> PackedByteArray:
    var body := _avi_fourcc(kind)
    body.append_array(payload)
    return _avi_chunk("LIST", body)

func _avi_headers(width: int, height: int, fps: int, count: int, max_jpg: int) -> PackedByteArray:
    var avih := PackedByteArray()
    for v in [int(1000000.0 / fps), max_jpg * fps, 0, 0x10, count, 0, 1, max_jpg, width, height, 0, 0, 0, 0]:
        avih.append_array(_avi_u32(v))
    var strh := PackedByteArray()
    strh.append_array(_avi_fourcc("vids"))
    strh.append_array(_avi_fourcc("MJPG"))
    strh.append_array(_avi_u32(0))
    strh.append_array(_avi_u16(0))
    strh.append_array(_avi_u16(0))
    strh.append_array(_avi_u32(0))
    for v in [1, fps, 0, count, max_jpg, 0xFFFFFFFF, 0]:
        strh.append_array(_avi_u32(v))
    for v in [0, 0, width, height]:
        strh.append_array(_avi_u16(v))
    var strf := PackedByteArray()
    strf.append_array(_avi_u32(40))
    strf.append_array(_avi_u32(width))
    strf.append_array(_avi_u32(height))
    strf.append_array(_avi_u16(1))
    strf.append_array(_avi_u16(24))
    strf.append_array(_avi_fourcc("MJPG"))
    for v in [width * height * 3, 0, 0, 0, 0]:
        strf.append_array(_avi_u32(v))
    var stream := _avi_chunk("strh", strh)
    stream.append_array(_avi_chunk("strf", strf))
    var hdrl := _avi_chunk("avih", avih)
    hdrl.append_array(_avi_list("strl", stream))
    return _avi_list("hdrl", hdrl)

func _choose_pose_sheet() -> void:
    pose_sheet_picker.popup_centered_ratio(0.9)

func _pose_sheet_selected(path: String) -> void:
    var sheet: Image = load("res://scripts/android_image_reader.gd").read_image(path)
    if sheet == null or sheet.is_empty():
        status.text = "Impossible de lire la planche V5."
        return
    var w: int = sheet.get_width()
    var h: int = sheet.get_height()
    if w < 600 or h < 450:
        status.text = "Planche V5 trop petite."
        return
    var x0: int = int(float(w) * 0.245)
    var y_edges: Array[int] = [0, int(float(h) * 0.325), int(float(h) * 0.655), h]
    var imported: Array[Texture2D] = []
    for row in range(3):
        for col in range(6):
            var x1: int = x0 + roundi(float(col) * float(w - x0) / 6.0) + 5
            var x2: int = x0 + roundi(float(col + 1) * float(w - x0) / 6.0) - 5
            var y1: int = y_edges[row] + 40
            var y2: int = y_edges[row + 1] - 38
            if x2 <= x1 or y2 <= y1:
                status.text = "Planche V5 : dimensions incompatibles."
                return
            var part: Image = sheet.get_region(Rect2i(x1, y1, x2 - x1, y2 - y1))
            part.resize(540, 960, Image.INTERPOLATE_LANCZOS)
            imported.append(ImageTexture.create_from_image(part))
    sources = imported
    v5_sheet_loaded = true
    accepted.clear()
    paths.clear()
    plan.clear()
    for i in range(sources.size()):
        accepted.append(true)
        plan.append(i)
    frame_index = 0
    _refresh()
    _build_contact_sheet()
    status.text = "18 poses V5 importees localement. Export MP4 disponible. ATTENTION : poses maintenues, pas de redessin IA."

func _export_board_mp4() -> void:
    if not Engine.has_singleton("MP4Exporter"):
        status.text = "MP4 indisponible : plugin Android absent. Utilise EXPORTER AVI."
        return
    if sources.is_empty():
        status.text = "Cree d'abord une planche."
        return
    var selected: int = 0
    for accepted_flag in accepted:
        if accepted_flag:
            selected += 1
    if selected == 0:
        status.text = "Valide les dessins avant l'export MP4."
        return
    var exporter: Node = Node.new()
    exporter.set_script(load("res://scripts/export_mp4.gd"))
    exporter.set("status_label", status)
    exporter.set("hold_keyframes", v5_sheet_loaded)
    add_child(exporter)
    var indices: Array = []
    for item in plan:
        indices.append(int(item))
    if indices.is_empty():
        for i in range(sources.size()):
            indices.append(i)
    await exporter.call("export_board_mp4", sources, indices, float(duration_input.value))
    exporter.queue_free()

func _export_video_direct() -> void:
    if sources.is_empty():
        status.text = "Genere d'abord les poses avec le bouton 2."
        return
    var output_dir: String = "user://exports"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
    _export_video(output_dir.path_join("animation.avi"))

func _choose_video_export() -> void:
    if sources.is_empty():
        status.text = "Prepare une planche avant l'export video."
        return
    var selected: int = 0
    for a in accepted:
        if a: selected += 1
    if selected == 0:
        status.text = "Valide au moins un dessin."
        return
    video_picker.current_file = "MobileI2V_animation.avi"
    video_picker.popup_centered_ratio(0.9)

func _export_video(destination: String) -> void:
    if exporting_video:
        return
    exporting_video = true
    var output_path: String = destination
    if not output_path.to_lower().ends_with(".avi"):
        output_path += ".avi"
    var width: int = 480
    var height: int = 640
    var fps: int = 30
    var duration: float = clampf(duration_input.value, 1.0, 60.0)
    var count: int = maxi(1, int(round(duration * fps)))
    var approved_ids: Array[int] = []
    for i in range(sources.size()):
        if i < accepted.size() and accepted[i]:
            approved_ids.append(i)
    if approved_ids.is_empty():
        status.text = "Aucun dessin valide."
        exporting_video = false
        return
    var sample: Image = sources[approved_ids[0]].get_image()
    if sample == null or sample.is_empty():
        status.text = "ERREUR : image vide, choisis une autre photo."
        exporting_video = false
        return
    var quality_gate: RefCounted = load("res://scripts/drawing_quality_gate.gd").new()
    var quality: Dictionary = quality_gate.inspect(sample)
    if not bool(quality.get("ok", false)):
        status.text = "Export bloque : dessin suspect (" + ", ".join(quality.get("issues", [])) + ")."
        exporting_video = false
        return
    var first_color: Color = sample.get_pixel(0, 0)
    var distinct: bool = false
    for yy in range(1, 9):
        for xx in range(1, 9):
            var px: Color = sample.get_pixel(int(float(xx) / 9.0 * (sample.get_width() - 1)), int(float(yy) / 9.0 * (sample.get_height() - 1)))
            if (absf(px.r - first_color.r) + absf(px.g - first_color.g) + absf(px.b - first_color.b)) > 0.20:
                distinct = true
                break
        if distinct: break
    if not distinct:
        status.text = "EXPORT BLOQUE : images uniformes/noires. Recharge une photo et regenere la planche."
        exporting_video = false
        return
    var temp_path: String = "user://mobilei2v_video_frames.tmp"
    var temp: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
    if temp == null:
        status.text = "Impossible de creer le fichier temporaire."
        exporting_video = false
        return
    var interpolator: RefCounted = load("res://scripts/frame_interpolator.gd").new()
    var motion_cache: Dictionary = {}
    var index := PackedByteArray()
    var max_jpg: int = 0
    var written: int = 0
    var movi_size: int = 4
    var offset: int = 4
    for n in range(count):
        var slot: int = mini(plan.size() - 1, int(float(n) / count * plan.size())) if not plan.is_empty() else mini(sources.size() - 1, int(float(n) / count * sources.size()))
        var requested: int = plan[slot] if not plan.is_empty() else slot
        var source_idx: int = approved_ids[0]
        var nearest: int = 999999
        for candidate in approved_ids:
            var d: int = absi(candidate - requested)
            if d < nearest:
                nearest = d
                source_idx = candidate
        var image: Image = sources[source_idx].get_image()
        if image == null or image.is_empty():
            continue
        # Motion-compensated interpolation with cached pairwise displacement.
        var next_slot: int = mini(plan.size() - 1, slot + 1) if not plan.is_empty() else mini(sources.size() - 1, slot + 1)
        var next_requested: int = plan[next_slot] if not plan.is_empty() else next_slot
        var next_source_idx: int = source_idx
        var next_distance: int = 999999
        for candidate in approved_ids:
            var distance: int = absi(candidate - next_requested)
            if distance < next_distance:
                next_distance = distance
                next_source_idx = candidate
        image.convert(Image.FORMAT_RGB8)
        image.resize(width, height, Image.INTERPOLATE_BILINEAR)
        if next_source_idx != source_idx:
            var next_image: Image = sources[next_source_idx].get_image()
            if next_image != null and not next_image.is_empty():
                next_image.convert(Image.FORMAT_RGB8)
                next_image.resize(width, height, Image.INTERPOLATE_BILINEAR)
                var progress: float = fposmod(float(n) / float(count) * float(plan.size() if not plan.is_empty() else sources.size()), 1.0)
                var eased: float = progress * progress * (3.0 - 2.0 * progress)
                var pair_key: String = "%d_%d" % [source_idx, next_source_idx]
                if not motion_cache.has(pair_key):
                    motion_cache[pair_key] = interpolator.estimate_blocks(image, next_image, 40, 8)
                image = interpolator.blend_blocks(image, next_image, eased, motion_cache[pair_key])
        var jpg: PackedByteArray = image.save_jpg_to_buffer(0.94)
        if jpg.is_empty():
            continue
        temp.store_buffer(_avi_chunk("00dc", jpg))
        index.append_array(_avi_fourcc("00dc"))
        index.append_array(_avi_u32(0x10))
        index.append_array(_avi_u32(offset))
        index.append_array(_avi_u32(jpg.size()))
        var padded: int = jpg.size() + (jpg.size() % 2)
        movi_size += 8 + padded
        offset += 8 + padded
        max_jpg = maxi(max_jpg, jpg.size())
        written += 1
        if n % 12 == 0:
            status.text = "Preparation video : %d / %d" % [n + 1, count]
            await get_tree().process_frame
    temp.close()
    if written == 0:
        status.text = "Impossible de preparer les images video."
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
        exporting_video = false
        return
    var headers: PackedByteArray = _avi_headers(width, height, fps, written, max_jpg)
    var index_chunk: PackedByteArray = _avi_chunk("idx1", index)
    var riff_size: int = 4 + headers.size() + 8 + movi_size + index_chunk.size()
    var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
    var temp_read: FileAccess = FileAccess.open(temp_path, FileAccess.READ)
    if file == null or temp_read == null:
        status.text = "Ecriture impossible. Choisis un dossier local accessible."
        exporting_video = false
        return
    file.store_buffer(_avi_fourcc("RIFF"))
    file.store_buffer(_avi_u32(riff_size))
    file.store_buffer(_avi_fourcc("AVI "))
    file.store_buffer(headers)
    file.store_buffer(_avi_fourcc("LIST"))
    file.store_buffer(_avi_u32(movi_size))
    file.store_buffer(_avi_fourcc("movi"))
    while not temp_read.eof_reached():
        var chunk: PackedByteArray = temp_read.get_buffer(262144)
        if chunk.is_empty():
            break
        file.store_buffer(chunk)
    temp_read.close()
    file.store_buffer(index_chunk)
    file.flush()
    file.close()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
    exporting_video = false
    status.text = "Video AVI exportee : %d images, %d fps. Pas encore MP4." % [written, fps]

func _choose_image() -> void:
    if OS.get_name() == "Android":
        OS.request_permissions()
    picker.popup_centered_ratio(0.9)

func _image_chosen(path: String) -> void:
    var img: Image = load("res://scripts/android_image_reader.gd").read_image(path)
    if img == null or img.is_empty():
        status.text = "ERREUR PHOTO : impossible de lire le fichier. Essaie JPG ou PNG."
        return
    var max_side: int = maxi(img.get_width(), img.get_height())
    if max_side > 1200:
        var factor: float = 1200.0 / float(max_side)
        img.resize(maxi(1, int(img.get_width() * factor)), maxi(1, int(img.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
    # Keep every imported reference in a distinct local project folder.
    # Previously each new image silently overwrote the previous project's photo.
    var project_id: String = "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
    var project_dir: String = "user://projects/" + project_id
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(project_dir)) != OK:
        status.text = "ERREUR : impossible de creer le dossier du projet."
        return
    var saved_path: String = project_dir + "/reference.png"
    if img.save_png(saved_path) != OK:
        status.text = "ERREUR : impossible de copier la photo."
        return
    v5_sheet_loaded = false
    imported_path = saved_path
    detected_landmarks.clear()
    skeleton_preview.visible = false
    skeleton_preview.texture = null
    sources.clear()
    paths.clear()
    plan.clear()
    accepted.clear()
    contact_sheet.texture = null
    contact_caption.text = "Planche en preparation"
    preview.texture = ImageTexture.create_from_image(img)
    status.text = "PHOTO CHARGEE (%d x %d) : preparation..." % [img.get_width(), img.get_height()]
    await get_tree().process_frame
    status.text = "Photo importee. Decris une action. Le mode 2D conserve des morceaux de la photo; pas de redessin IA."

func _texture_for_path(path: String) -> Texture2D:
    if path.begins_with("user://") or path.begins_with("/"):
        var img := Image.new()
        if img.load(path) == OK:
            return ImageTexture.create_from_image(img)
        return null
    if ResourceLoader.exists(path):
        return load(path)
    return null

func _joint_mask(x: float, y: float, ax: Vector2, bx: Vector2, radius: float) -> float:
    var d: Vector2 = bx - ax
    var t: float = clampf((Vector2(x,y) - ax).dot(d) / maxf(d.length_squared(), 0.01), 0.0, 1.0)
    return clampf((radius - (Vector2(x,y) - (ax + d*t)).length()) / 4.0, 0.0, 1.0)

func _erase_limb(dst: Image, a: Vector2, b: Vector2, radius: float, background: Color) -> void:
    # Clear the original limb footprint before drawing its new position.
    # Do not erase the shoulder/hip joint itself: keep a small connection
    # to the stationary torso to avoid visible gaps at the attachment.
    var x0: int = maxi(0, floori(minf(a.x, b.x) - radius - 4.0))
    var x1: int = mini(dst.get_width() - 1, ceili(maxf(a.x, b.x) + radius + 4.0))
    var y0: int = maxi(0, floori(minf(a.y, b.y) - radius - 4.0))
    var y1: int = mini(dst.get_height() - 1, ceili(maxf(a.y, b.y) + radius + 4.0))
    var axis: Vector2 = b - a
    var axis_len_sq: float = maxf(axis.length_squared(), 0.01)
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            var point := Vector2(float(xx), float(yy))
            var along: float = clampf((point - a).dot(axis) / axis_len_sq, 0.0, 1.0)
            if along < 0.18:
                continue
            var amount: float = _joint_mask(float(xx), float(yy), a, b, radius)
            if amount > 0.0:
                dst.set_pixel(xx, yy, dst.get_pixel(xx, yy).lerp(background, amount))

func _limb_copy(dst: Image, src: Image, a: Vector2, b: Vector2, angle: float, radius: float) -> void:
    var ca: float = cos(angle)
    var sa: float = sin(angle)
    var out_b: Vector2 = a + Vector2((b.x-a.x)*ca-(b.y-a.y)*sa, (b.x-a.x)*sa+(b.y-a.y)*ca)
    var lo_x: int = maxi(0, int(minf(a.x,out_b.x)-radius-4))
    var hi_x: int = mini(src.get_width()-1, int(maxf(a.x,out_b.x)+radius+4))
    var lo_y: int = maxi(0, int(minf(a.y,out_b.y)-radius-4))
    var hi_y: int = mini(src.get_height()-1, int(maxf(a.y,out_b.y)+radius+4))
    for yy in range(lo_y,hi_y+1):
        for xx in range(lo_x,hi_x+1):
            var mask: float = _joint_mask(float(xx),float(yy),a,out_b,radius)
            if mask <= 0.0: continue
            var rx: float = xx-a.x
            var ry: float = yy-a.y
            var sx: int = roundi(a.x+rx*ca+ry*sa)
            var sy: int = roundi(a.y-rx*sa+ry*ca)
            if sx < 0 or sy < 0 or sx >= src.get_width() or sy >= src.get_height(): continue
            # Clip pixels to the ORIGINAL limb capsule as well as the
            # destination capsule. Otherwise the rotated sampling window
            # picks up torso, neighboring limbs and head pixels.
            var source_mask: float = _joint_mask(float(sx), float(sy), a, b, radius)
            if source_mask <= 0.0: continue
            var pix: Color = src.get_pixel(sx,sy)
            var strength: float = mask * source_mask * pix.a
            if strength <= 0.0: continue
            pix.a = 1.0
            dst.set_pixel(xx, yy, dst.get_pixel(xx, yy).lerp(pix, strength))

func _request_pose() -> void:
    if pose_running: return
    if imported_path.is_empty() or not FileAccess.file_exists(imported_path):
        status.text = "Choisis une photo d'abord."
        return
    var endpoint: String = ai_endpoint.text.strip_edges()
    if not endpoint.begins_with("https://") and not endpoint.begins_with("http://"):
        status.text = "Il faut une adresse de serveur MediaPipe. Aucun moteur natif n'est installe."
        return
    var photo: PackedByteArray = FileAccess.get_file_as_bytes(imported_path)
    if photo.is_empty(): return
    var base_url: String = endpoint.trim_suffix("/")
    if base_url.ends_with("/generate/storyboard"):
        base_url = base_url.trim_suffix("/generate/storyboard")
    elif base_url.ends_with("/generate"):
        base_url = base_url.trim_suffix("/generate")
    var url: String = base_url + "/pose"
    var payload: String = JSON.stringify({"image_base64":Marshalls.raw_to_base64(photo)})
    pose_running = true
    detected_landmarks.clear()
    status.text = "Detection MediaPipe en cours..."
    var error: Error = pose_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
    if error != OK:
        pose_running = false
        status.text = "Serveur MediaPipe inaccessible (code %d)." % error

func _pose_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    pose_running = false
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        status.text = "Detection echouee : erreur reseau %d, HTTP %d." % [result, code]
        return
    var response: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not response is Dictionary:
        status.text = "Reponse MediaPipe invalide."
        return
    if not bool(response.get("detected", false)):
        status.text = "Aucun corps detecte. Utilise une photo en pied."
        return
    var points: Array = response.get("landmarks", [])
    if points.size() < 33:
        status.text = "MediaPipe : points incomplets (%d)." % points.size()
        return
    detected_landmarks = points.duplicate(true)
    _show_skeleton_preview()
    status.text = "MediaPipe : 33 points detectes. Squelette affiche ci-dessus. Verifie puis lance les poses."

func _generate_image_sequence() -> void:
    if ai_running:
        status.text = "Generation deja en cours."
        return
    if imported_path.is_empty() or not FileAccess.file_exists(imported_path):
        status.text = "Importe d'abord l'image de depart."
        return
    var original := Image.new()
    if original.load(imported_path) != OK or original.is_empty():
        status.text = "Image source illisible."
        return
    var endpoint: String = ai_endpoint.text.strip_edges()
    var generator := Node.new()
    generator.set_script(load("res://scripts/image_sequence_generator.gd"))
    add_child(generator)
    generator.progress.connect(func(index: int, total: int) -> void:
        status.text = "Images generees : %d / %d" % [index, total]
    )
    ai_running = true
    var count: int = clampi(ceili(float(duration_input.value) * 4.0), 2, 120)
    var result: Dictionary = await generator.call("generate", original, action_input.text, endpoint, count, false)
    ai_running = false
    generator.queue_free()
    if not bool(result.get("ok", false)):
        status.text = "Generation impossible : " + str(result.get("error", "erreur inconnue"))
        return
    var images: Array = result["frames"]
    var continuity = load("res://scripts/frame_continuity_check.gd")
    var report: Dictionary = continuity.inspect(images)
    if not bool(report.get("ok", false)) or float(report.get("average_difference", 0.0)) < 0.003:
        status.text = "Images refusees : sequence immobile ou invalide."
        return
    var folder := "user://generated_image_sequence"
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        status.text = "Impossible de creer le dossier des images."
        return
    var new_sources: Array[Texture2D] = []
    var new_paths: Array[String] = []
    for i in range(images.size()):
        var img: Image = images[i]
        var file_path: String = "%s/frame_%04d.png" % [folder, i]
        if img.save_png(file_path) != OK:
            status.text = "Sauvegarde impossible a l'image %d." % i
            return
        new_sources.append(ImageTexture.create_from_image(img))
        new_paths.append(file_path)
    sources = new_sources
    paths = new_paths
    plan.clear()
    accepted.clear()
    for i in range(sources.size()):
        plan.append(i)
        accepted.append(false)
    frame_index = 0
    _refresh()
    _build_contact_sheet()
    _save()
    status.text = "%d images produites. Verifie la planche avant export MP4." % sources.size()

func _request_ai_board() -> void:
    if ai_running: return
    if imported_path.is_empty() or not FileAccess.file_exists(imported_path):
        status.text = "Choisis d'abord une photo."
        return
    var url: String = ai_endpoint.text.strip_edges()
    if not (url.begins_with("https://") or url.begins_with("http://")):
        status.text = "Renseigne l'adresse de ton moteur IA personnel. Aucun moteur IA Android n'est installe."
        return
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(imported_path)
    if bytes.is_empty():
        status.text = "Impossible de lire la photo."
        return
    var payload := {"image_base64": Marshalls.raw_to_base64(bytes), "prompt": action_input.text, "frames": 4, "num_images": 4, "seed": 42}
    ai_running = true
    status.text = "Generation SDXL avec reference en cours (serveur GPU requis)..."
    var err: Error = ai_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        ai_running = false
        status.text = "Connexion IA impossible : code %d" % err

func _ai_completed(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    ai_running = false
    if _result != HTTPRequest.RESULT_SUCCESS or code != 200:
        status.text = "Moteur IA indisponible (reseau %d, HTTP %d). Ancienne planche conservee." % [_result, code]
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not data is Dictionary or not data.has("images") or not data["images"] is Array:
        status.text = "Reponse IA invalide : tableau images manquant."
        return
    var imgs: Array[Image] = []
    if data["images"].size() > 24:
        status.text = "Reponse IA trop grande : 24 images maximum."
        return
    for item in data["images"]:
        var b: PackedByteArray = Marshalls.base64_to_raw(str(item))
        var img := Image.new()
        if img.load_png_from_buffer(b) != OK or img.is_empty():
            status.text = "Image IA invalide. Ancienne planche conservee."
            return
        if img.get_width() > 1024 or img.get_height() > 1024:
            status.text = "Image IA trop grande (1024 pixels max)."
            return
        imgs.append(img)
    if imgs.is_empty():
        status.text = "Le moteur IA n'a genere aucune image."
        return
    var folder: String = "user://ai_board"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var new_paths: Array[String] = []
    var new_sources: Array[Texture2D] = []
    for i in range(imgs.size()):
        var path: String = "%s/pose_%02d.png" % [folder, i]
        if imgs[i].save_png(path) != OK:
            status.text = "Sauvegarde IA impossible. Ancienne planche conservee."
            return
        new_paths.append(path)
        new_sources.append(ImageTexture.create_from_image(imgs[i]))
    sources = new_sources
    paths = new_paths
    plan.clear()
    accepted.clear()
    for i in range(sources.size()):
        plan.append(i)
        accepted.append(false)
    frame_index = 0
    _refresh()
    _build_contact_sheet()
    _save()
    status.text = "%d images IA recues. Verifie la planche puis valide les poses." % sources.size()

func _show_skeleton_preview() -> void:
    if detected_landmarks.size() < 33 or imported_path.is_empty():
        return
    var img := Image.new()
    if img.load(imported_path) != OK or img.is_empty():
        return
    img.convert(Image.FORMAT_RGBA8)
    var edges: Array = [[11,12],[11,13],[13,15],[12,14],[14,16],
        [11,23],[12,24],[23,24],[23,25],[25,27],[24,26],[26,28]]
    for edge in edges:
        var a: Dictionary = detected_landmarks[edge[0]]
        var b: Dictionary = detected_landmarks[edge[1]]
        if float(a.get("visibility",0)) < 0.35 or float(b.get("visibility",0)) < 0.35:
            continue
        var x0: int = roundi(float(a.get("x",0))*float(img.get_width()-1))
        var y0: int = roundi(float(a.get("y",0))*float(img.get_height()-1))
        var x1: int = roundi(float(b.get("x",0))*float(img.get_width()-1))
        var y1: int = roundi(float(b.get("y",0))*float(img.get_height()-1))
        var steps: int = maxi(1, maxi(absi(x1-x0), absi(y1-y0)))
        for t in range(steps+1):
            var xx: int = roundi(lerpf(float(x0),float(x1),float(t)/steps))
            var yy: int = roundi(lerpf(float(y0),float(y1),float(t)/steps))
            for dx in range(-2,3):
                for dy in range(-2,3):
                    var px: int = xx+dx
                    var py: int = yy+dy
                    if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
                        img.set_pixel(px,py,Color(0.12,1.0,0.42))
    for index in [11,12,13,14,15,16,23,24,25,26,27,28]:
        var pt: Dictionary = detected_landmarks[index]
        if float(pt.get("visibility",0)) < 0.35:
            continue
        var cx: int = roundi(float(pt.get("x",0))*float(img.get_width()-1))
        var cy: int = roundi(float(pt.get("y",0))*float(img.get_height()-1))
        for dy in range(-5,6):
            for dx in range(-5,6):
                var px: int = cx+dx
                var py: int = cy+dy
                if dx*dx+dy*dy <= 25 and px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
                    img.set_pixel(px,py,Color(1.0,0.45,0.05))
    skeleton_preview.texture = ImageTexture.create_from_image(img)
    skeleton_preview.visible = true

func _joint_point(index: int, width: int, height: int, fw: int, fh: int) -> Vector2:
    var p: Dictionary = detected_landmarks[index]
    return Vector2((width-fw)*0.5 + clampf(float(p.get("x",0.5)),0.0,1.0)*fw,
        (height-fh)*0.5 + clampf(float(p.get("y",0.5)),0.0,1.0)*fh)

func _generate_detected_board() -> void:
    if detected_landmarks.size() != 33:
        status.text = "Detecte d'abord les articulations MediaPipe."
        return
    await _generate_articulated_board(true)

func _automatic_local_movie() -> void:
    if exporting_video:
        status.text = "Export deja en cours."
        return
    if action_input.text.strip_edges().is_empty():
        status.text = "Decris les mouvements avant de lancer."
        return
    # Reset only the in-memory result of the previous generation.
    # Previously, a failed generation could export an old storyboard as
    # though it were the newly requested video. Saved projects are untouched.
    v5_sheet_loaded = false
    sources.clear()
    paths.clear()
    plan.clear()
    accepted.clear()
    frame_index = 0
    # Preserve the reference photo preview until actual pose frames exist.
    if not imported_path.is_empty() and FileAccess.file_exists(imported_path):
        var reference_image := Image.new()
        if reference_image.load(imported_path) == OK:
            preview.texture = ImageTexture.create_from_image(reference_image)
    else:
        preview.texture = null
    contact_sheet.texture = null
    contact_caption.text = "Nouvelle planche en cours de generation."
    status.text = "Etape 1/3 : creation automatique de la planche."
    if not imported_path.is_empty():
        if not FileAccess.file_exists(imported_path):
            status.text = "Photo introuvable. Reimporte-la avant de generer."
            return
        # Prefer the articulated reference-image pipeline instead of moving
        # the whole photograph regardless of the requested movement.
        var request: String = action_input.text.to_lower()
        var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
        var motion_plan: Dictionary = planner.plan(request, float(duration_input.value))
        if bool(motion_plan.get("ok", false)):
            await _generate_articulated_board()
        elif request.contains("tete") or request.contains("tête") or request.contains("head") or request.contains("visage"):
            status.text = "Mouvement de tete : articulation du visage non disponible sur une photo seule. Photo conservee; aucune animation generique creee."
            return
        else:
            status.text = "Action non reconnue. Precise marcher, courir, danser, sauter, tomber ou se relever."
            return
    else:
        await _generate_text_cartoon()
    if sources.is_empty():
        status.text = "Aucun dessin genere. Export annule."
        return
    # Check image-to-image continuity before accepting the generated sequence.
    var continuity = load("res://scripts/frame_continuity_check.gd")
    var continuity_report: Dictionary = continuity.inspect(sources)
    if not bool(continuity_report.get("ok", false)):
        status.text = "Sequence invalide : " + str(continuity_report.get("reason", "images absentes"))
        return
    var average_change: float = float(continuity_report.get("average_difference", 0.0))
    if average_change < 0.003:
        status.text = "Animation refusee : les dessins sont quasiment identiques. Aucun mouvement reel detecte."
        return
    # Never export stale frames when a generation was rejected or failed.
    status.text = "Etape 2/3 : validation de %d dessins." % sources.size()
    _approve_all()
    if accepted.is_empty():
        status.text = "Planche non validee. Export annule."
        return
    status.text = "Etape 3/3 : calcul de %d images a 30 fps." % maxi(1, roundi(float(duration_input.value) * 30.0))
    var export_dir: String = "user://exports"
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(export_dir)) != OK:
        status.text = "Impossible de creer le dossier video."
        return
    if Engine.has_singleton("MP4Exporter"):
        await _export_board_mp4()
    else:
        status.text = "Encodeur MP4 absent : export AVI local de secours."
        await _export_video(export_dir.path_join("animation_auto.avi"))

func _generate_text_cartoon() -> void:
    var story: String = action_input.text.strip_edges()
    if story.is_empty():
        status.text = "Decris le personnage et ses mouvements."
        return
    var project_dir: String = "user://projects/cartoon_%d" % Time.get_ticks_usec()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(project_dir)) != OK:
        status.text = "Impossible de creer le dossier des dessins."
        return
    var generator: RefCounted = load("res://scripts/procedural_cartoon_generator.gd").new()
    var planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
    var motion: Dictionary = planner.plan(story, float(duration_input.value))
    var count: int = clampi(ceili(float(duration_input.value) * 4.0), 12, 120)
    sources.clear()
    paths.clear()
    plan.clear()
    accepted.clear()
    # Generated cartoon art is not a user-imported photograph.
    # Never overwrite the original photo reference with procedural artwork.
    var cartoon_reference: String = project_dir.path_join("reference.png")
    var initial: Image = generator.render(story, 0.0)
    if initial.save_png(cartoon_reference) != OK:
        status.text = "Impossible de sauvegarder le personnage."
        return
    preview.texture = ImageTexture.create_from_image(initial)
    for i in range(count):
        var seconds: float = float(i) / float(count) * float(duration_input.value)
        var action: String = planner.action_at(motion, seconds) if bool(motion.get("ok", false)) else "danse"
        var speed: float = 1.8 if action == "course" else 1.0
        var phase: float = seconds * speed
        var image: Image = generator.render(story, phase, Vector2i(360, 480), action)
        var path: String = project_dir.path_join("drawing_%03d.png" % i)
        if image.save_png(path) != OK:
            status.text = "Erreur de sauvegarde du dessin %d." % i
            return
        sources.append(ImageTexture.create_from_image(image))
        paths.append(path)
        plan.append(i)
        accepted.append(true)
        if i % 4 == 0:
            status.text = "Dessins en cours : %d/%d" % [i + 1, count]
            await get_tree().process_frame
    frame_index = 0
    _refresh()
    _save()
    _build_contact_sheet()
    status.text = "%d dessins 2D generes hors ligne. Style cartoon simple; IA detaillee non installee." % count

func _generate_layered_demo() -> void:
    # Non-destructive standalone preview: existing imported photos and
    # previously saved projects remain untouched.
    var folder: String = "user://projects/layered_%d" % Time.get_ticks_usec()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        status.text = "Impossible de creer le projet de demonstration."
        return
    var renderer: RefCounted = load("res://scripts/articulated_preview.gd").new()
    # Keep a bounded number of key poses in RAM. The MP4 exporter
    # interpolates them to 30 fps; storing 240 full-size textures on
    # a mobile phone wastes memory without increasing output frame rate.
    var count: int = clampi(ceili(float(duration_input.value) * 6.0), 12, 72)
    var new_sources: Array[Texture2D] = []
    var new_paths: Array[String] = []
    for i in range(count):
        var seconds: float = float(i) / float(count) * float(duration_input.value)
        var drawing: Image = renderer.draw_frame(360, 480, seconds)
        var path: String = folder.path_join("drawing_%03d.png" % i)
        if drawing.save_png(path) != OK:
            status.text = "Echec sauvegarde du dessin %d." % i
            return
        new_sources.append(ImageTexture.create_from_image(drawing))
        new_paths.append(path)
        if i % 12 == 0:
            status.text = "Dessin articule : %d/%d" % [i + 1, count]
            await get_tree().process_frame
    sources = new_sources
    paths.clear()
    paths.append_array(new_paths)
    plan.clear()
    accepted.clear()
    for i in range(count):
        plan.append(i)
        accepted.append(true)
    frame_index = 0
    _refresh()
    _save()
    _build_contact_sheet()
    status.text = "%d dessins articules generes. Demo sans photo : utilise EXPORTER MP4." % count

func _generate_articulated_board(use_detected: bool = false) -> void:
    if imported_path.is_empty():
        status.text = "Choisis une photo pour creer les poses."
        return
    var original := Image.new()
    if original.load(imported_path) != OK or original.is_empty():
        status.text = "Photo introuvable."
        return
    var width: int = 360
    var height: int = 480
    var factor: float = minf(340.0/original.get_width(),460.0/original.get_height())
    var fw: int = maxi(1,int(original.get_width()*factor))
    var fh: int = maxi(1,int(original.get_height()*factor))
    original.resize(fw,fh,Image.INTERPOLATE_LANCZOS)
    original.convert(Image.FORMAT_RGBA8)
    var base := Image.create(width,height,false,Image.FORMAT_RGBA8)
    base.fill(Color("25364a"))
    # Segment BEFORE adding the studio backdrop. Segmenting the padded
    # canvas previously made every photo appear to have a uniform background.
    var separator: RefCounted = load("res://scripts/character_separator.gd").new()
    var separated: Dictionary = separator.separate(original)
    if not bool(separated.get("ok", false)):
        status.text = "Personnage non isole : " + str(separated.get("reason", "fond complexe")) + ". Utilise une image PNG detouree ou un fond uni."
        return
    var cutout: Image = separated["foreground"]
    # Composite ONLY the segmented character; never paste the original
    # photo's rectangular background over the animation backdrop.
    var foreground := Image.create(width, height, false, Image.FORMAT_RGBA8)
    foreground.fill(Color(0, 0, 0, 0))
    var offset := Vector2i(int((width-fw)/2), int((height-fh)/2))
    foreground.blend_rect(cutout, Rect2i(0, 0, fw, fh), offset)
    base.blend_rect(foreground, Rect2i(0, 0, width, height), Vector2i.ZERO)

    # Infer approximate rig placement from the actual alpha silhouette,
    # rather than assuming the character fills the entire canvas.
    var min_x: int = width
    var min_y: int = height
    var max_x: int = -1
    var max_y: int = -1
    for py in range(height):
        for px in range(width):
            if foreground.get_pixel(px, py).a > 0.5:
                min_x = mini(min_x, px)
                min_y = mini(min_y, py)
                max_x = maxi(max_x, px)
                max_y = maxi(max_y, py)
    if max_x <= min_x or max_y <= min_y:
        status.text = "Silhouette du personnage vide : animation annulee."
        return
    var left: float = float(min_x)
    var top: float = float(min_y)
    var sw: float = float(max_x - min_x)
    var sh: float = float(max_y - min_y)
    var shoulder_l := Vector2(left + sw * 0.35, top + sh * 0.31)
    var shoulder_r := Vector2(left + sw * 0.65, top + sh * 0.31)
    var hip_l := Vector2(left + sw * 0.43, top + sh * 0.60)
    var hip_r := Vector2(left + sw * 0.57, top + sh * 0.60)
    var arm_l := Vector2(left + sw * 0.26, top + sh * 0.54)
    var arm_r := Vector2(left + sw * 0.74, top + sh * 0.54)
    var leg_l := Vector2(left + sw * 0.39, top + sh * 0.91)
    var leg_r := Vector2(left + sw * 0.61, top + sh * 0.91)
    # Approximate elbows and knees only when pose landmarks are unavailable.
    var elbow_l: Vector2 = shoulder_l.lerp(arm_l, 0.5)
    var elbow_r: Vector2 = shoulder_r.lerp(arm_r, 0.5)
    var knee_l: Vector2 = hip_l.lerp(leg_l, 0.5)
    var knee_r: Vector2 = hip_r.lerp(leg_r, 0.5)
    if use_detected:
        var rig: RefCounted = load("res://scripts/continuous_rig.gd").new()
        var rig_check: Dictionary = rig.validate_landmarks(detected_landmarks)
        if not bool(rig_check.get("ok", false)):
            status.text = "Squelette incomplet : " + str(rig_check.get("error", ""))
            return
        for joint in [11,12,13,14,15,16,23,24,25,26,27,28]:
            if not detected_landmarks[joint] is Dictionary or float(detected_landmarks[joint].get("visibility",0.0)) < 0.35:
                status.text = "Articulation %d peu visible. Utilise une photo du corps entier." % joint
                return
        shoulder_l = _joint_point(11,width,height,fw,fh)
        shoulder_r = _joint_point(12,width,height,fw,fh)
        arm_l = _joint_point(15,width,height,fw,fh)
        arm_r = _joint_point(16,width,height,fw,fh)
        hip_l = _joint_point(23,width,height,fw,fh)
        hip_r = _joint_point(24,width,height,fw,fh)
        leg_l = _joint_point(27,width,height,fw,fh)
        leg_r = _joint_point(28,width,height,fw,fh)
        elbow_l = _joint_point(13,width,height,fw,fh)
        elbow_r = _joint_point(14,width,height,fw,fh)
        knee_l = _joint_point(25,width,height,fw,fh)
        knee_r = _joint_point(26,width,height,fw,fh)
    if action_input.text.strip_edges().is_empty():
        status.text = "Ecris une action avant de generer la planche."
        return
    var count: int = _adaptive_pose_count(action_input.text, float(duration_input.value))
    var story_planner: RefCounted = load("res://scripts/story_motion_planner.gd").new()
    var story_plan: Dictionary = story_planner.plan(action_input.text, float(duration_input.value))
    # KARMA ONE production manifest: one contract for storyboard and animation.
    var director: RefCounted = load("res://scripts/story_director.gd").new()
    var production: Dictionary = director.build(action_input.text, float(duration_input.value), imported_path)
    # Image-first contract: drawing briefs precede any rig or video rendering.
    var board_planner: RefCounted = load("res://scripts/board_generation_plan.gd").new()
    var drawing_plan: Dictionary = board_planner.make_plan(action_input.text, [imported_path], float(duration_input.value))
    var drawing_file: FileAccess = FileAccess.open(imported_path.get_base_dir().path_join("drawing_plan.json"), FileAccess.WRITE)
    if drawing_file != null:
        drawing_file.store_string(JSON.stringify(drawing_plan, "  "))
        drawing_file.close()

    if production.get("scenes", []).is_empty():
        status.text = "Aucune scene exploitable : precise les mouvements."
        return
    var manifest_path: String = imported_path.get_base_dir().path_join("production_manifest.json")
    var manifest_file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
    if manifest_file != null:
        manifest_file.store_string(JSON.stringify(production, "  "))
        manifest_file.close()

    if not bool(story_plan.get("ok", false)):
        status.text = "Action non reconnue : essaie courir, tomber, danser, marcher..."
        return
    # Keep the previous approved board until the new request has been validated.
    sources.clear()
    paths.clear()
    plan.clear()
    accepted.clear()
    var folder: String = imported_path.get_base_dir() + ("/mediapipe_board" if use_detected else "/articulated_board")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    # Reuse rigging engines across frames to avoid repeated script loads and allocations.
    var ik_solver: RefCounted = load("res://scripts/two_bone_ik.gd").new()
    var pixel_warp: RefCounted = load("res://scripts/painted_limb_warp.gd").new()
    for i in range(count):
        var seconds: float = float(i) / float(count) * float(duration_input.value)
        var action: String = story_planner.action_at(story_plan, seconds) if bool(story_plan.get("ok", false)) else "marche"
        var phase: float = seconds * TAU * 1.6
        var arm_angle: float = 0.22
        var leg_angle: float = 0.15
        var lean: float = 0.0
        match action:
            "course":
                arm_angle = 0.65
                leg_angle = 0.52
            "danse":
                arm_angle = 0.7
                leg_angle = 0.3
            "saut":
                arm_angle = 0.8
                leg_angle = 0.55
            "trebuche":
                arm_angle = 1.0
                leg_angle = 0.65
                lean = 0.25
            "chute":
                arm_angle = 1.1
                leg_angle = 0.8
                lean = 0.6
            "releve":
                arm_angle = 0.45
                leg_angle = 0.4
            "salut":
                arm_angle = 0.8
                leg_angle = 0.02
            "repos":
                arm_angle = 0.03
                leg_angle = 0.02
        var result: Image = base.duplicate()
        # Clear all original limb locations first, then composite rotated
        # patches. Otherwise the old arms and legs remain as ghost limbs.
        var studio_color := Color("25364a")
        # Scale limb thickness with the detected silhouette rather than
        # applying fixed 18/22 px brushes to small and large characters.
        var arm_radius: float = clampf(sw * 0.085, 4.0, 24.0)
        var leg_radius: float = clampf(sw * 0.105, 5.0, 30.0)
        _erase_limb(result, shoulder_l, elbow_l, arm_radius, studio_color)
        _erase_limb(result, elbow_l, arm_l, arm_radius, studio_color)
        _erase_limb(result, shoulder_r, elbow_r, arm_radius, studio_color)
        _erase_limb(result, elbow_r, arm_r, arm_radius, studio_color)
        _erase_limb(result, hip_l, knee_l, leg_radius, studio_color)
        _erase_limb(result, knee_l, leg_l, leg_radius, studio_color)
        _erase_limb(result, hip_r, knee_r, leg_radius, studio_color)
        _erase_limb(result, knee_r, leg_r, leg_radius, studio_color)
        # Animate the original imported drawing with two articulated bones
        # per limb. The artwork pixels are sampled from the transparent
        # source image, not replaced with procedural colored capsules.
        for limb in [
            {"root": shoulder_l, "middle": elbow_l, "end": arm_l, "angle": arm_angle * sin(phase) + lean, "radius": arm_radius, "bend": -1.0},
            {"root": shoulder_r, "middle": elbow_r, "end": arm_r, "angle": -arm_angle * sin(phase) + lean, "radius": 18.0, "bend": 1.0},
            {"root": hip_l, "middle": knee_l, "end": leg_l, "angle": -leg_angle * sin(phase) + lean, "radius": leg_radius, "bend": -1.0},
            {"root": hip_r, "middle": knee_r, "end": leg_r, "angle": leg_angle * sin(phase) + lean, "radius": 22.0, "bend": 1.0}
        ]:
            var root_point: Vector2 = limb["root"]
            var rest_end: Vector2 = limb["end"]
            var rest_middle: Vector2 = limb["middle"]
            var upper_length: float = root_point.distance_to(rest_middle)
            var lower_length: float = rest_middle.distance_to(rest_end)
            var theta: float = limb["angle"]
            var target: Vector2 = root_point + (rest_end - root_point).rotated(theta) * 0.94
            var solution: Dictionary = ik_solver.solve_two_bone(root_point, target, upper_length, lower_length, limb["bend"])
            if not bool(solution.get("ok", false)):
                continue
            var radius: float = limb["radius"]
            pixel_warp.draw_segment(result, foreground, root_point, rest_middle, root_point, solution["middle"], radius)
            pixel_warp.draw_segment(result, foreground, rest_middle, rest_end, solution["middle"], solution["end"], radius * 0.82)
            # Blend the original painted elbow/knee over the two segment ends.
            pixel_warp.draw_joint(result, foreground, rest_middle, solution["middle"], radius * 0.78)
            # Restore shoulder/hip paint where the moving segment meets the torso.
            pixel_warp.draw_joint(result, foreground, root_point, root_point, radius * 0.66)
        var path: String = "%s/pose_%02d.png" % [folder,i]
        if result.save_png(path) != OK:
            status.text = "Erreur sauvegarde pose."
            return
        paths.append(path)
        sources.append(ImageTexture.create_from_image(result))
        plan.append(i)
        accepted.append(true)
        if i % 2 == 0:
            status.text = "Calcul des poses : %d / %d" % [i+1, count]
            await get_tree().process_frame
    frame_index = 0
    _refresh()
    _save()
    _build_contact_sheet()
    status.text = ("%d poses approx. Squelette detecte." % count if use_detected else "%d poses approx. Squelette estime." % count) + (" Fond uni isole." if bool(separated.get("ok", false)) else " Fond complexe : isolation non garantie.")

func _adaptive_pose_count(description: String, duration: float) -> int:
    # More keyframes for transitions and rapid actions, within mobile memory limits.
    var story: String = description.to_lower()
    var complexity: int = 0
    for word in ["cour", "run", "saut", "jump", "tomb", "fall", "trebuch", "chut", "tourne", "rotate", "danse", "dance", "relev", "stand", "puis", "ensuite"]:
        if story.contains(word):
            complexity += 1
    return clampi(8 + int(ceil(duration * 0.75)) + complexity * 3, 12, 48)

func _build_contact_sheet() -> void:
    if sources.is_empty():
        contact_sheet.texture = null
        contact_caption.text = "Aucune image disponible."
        return
    # Preview a representative subset, not every full-resolution pose.
    # Keeps the atlas below 384 x 1536 on Android even for long sequences.
    var thumb_w: int = 96
    var thumb_h: int = 128
    var cols: int = 4
    var shown: int = mini(sources.size(), 48)
    var rows: int = ceili(float(shown) / float(cols))
    var board := Image.create(thumb_w * cols, thumb_h * rows, false, Image.FORMAT_RGBA8)
    board.fill(Color("1a2530"))
    for slot in range(shown):
        var source_index: int = roundi(float(slot) * float(sources.size() - 1) / float(maxi(shown - 1, 1)))
        var img: Image = sources[source_index].get_image()
        if img == null or img.is_empty():
            continue
        img.resize(thumb_w - 8, thumb_h - 8, Image.INTERPOLATE_BILINEAR)
        board.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i((slot % cols) * thumb_w + 4, int(slot / cols) * thumb_h + 4))
    contact_sheet.texture = ImageTexture.create_from_image(board)
    contact_caption.text = ("PLANCHE : apercu de %d / %d dessins (verifier avant validation)" % [shown, sources.size()] if shown < sources.size() else "PLANCHE : %d dessins (verifier avant validation)" % shown)

func _generate_from_photo() -> void:
    if imported_path.is_empty():
        status.text = "Choisis d'abord une photo."
        return
    var source := Image.new()
    if source.load(imported_path) != OK or source.is_empty():
        status.text = "ERREUR : photo inaccessible. Reimporte-la."
        return
    var width: int = 480
    var height: int = 640
    var scale_factor: float = minf(float(width - 32) / float(source.get_width()), float(height - 32) / float(source.get_height()))
    var fit_w: int = maxi(1, int(source.get_width() * scale_factor))
    var fit_h: int = maxi(1, int(source.get_height() * scale_factor))
    source.resize(fit_w, fit_h, Image.INTERPOLATE_LANCZOS)
    source.convert(Image.FORMAT_RGBA8)
    var folder: String = "user://generated_board"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    sources.clear()
    paths.clear()
    plan.clear()
    accepted.clear()
    var count: int = clampi(int(duration_input.value * 2.0), 6, 24)
    for i in range(count):
        var phase: float = float(i) / float(count)
        var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
        result.fill(Color("25364a"))
        var x: int = int((width - fit_w) / 2.0 + 9.0 * sin(phase * TAU))
        var y: int = int((height - fit_h) / 2.0 + 7.0 * sin(phase * TAU * 2.0))
        result.blit_rect(source, Rect2i(0, 0, fit_w, fit_h), Vector2i(x, y))
        var image_path: String = "%s/frame_%04d.png" % [folder, i]
        if result.save_png(image_path) != OK:
            status.text = "ERREUR : impossible d'enregistrer la planche."
            return
        paths.append(image_path)
        sources.append(ImageTexture.create_from_image(result))
        plan.append(i)
        accepted.append(true)
        if i % 4 == 0:
            preview.texture = sources[i]
            status.text = "Creation de la planche : %d / %d" % [i + 1, count]
            await get_tree().process_frame
    frame_index = 0
    _refresh()
    _save()
    preview.texture = sources[0]
    status.text = "PHOTO VISIBLE : %d images creees et validees. Bouton 2 pour animer." % count

func _export_png_sequence() -> void:
    if sources.is_empty():
        status.text = "Prepare et valide d'abord la planche."
        return
    var folder: String = "user://exports/mobilei2v_frames"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var saved: int = 0
    var exported_paths: Array[String] = []
    for i in range(sources.size()):
        if i >= accepted.size() or not accepted[i]:
            continue
        var img: Image = sources[i].get_image()
        if img == null: continue
        var path: String = "%s/frame_%04d.png" % [folder, saved]
        if img.save_png(path) == OK:
            exported_paths.append(path)
            saved += 1
    var manifest: Dictionary = {"format": "PNG sequence", "count": saved, "duration_seconds": duration_input.value, "description": action_input.text, "files": exported_paths, "note": "No MP4 encoder is included"}
    var file := FileAccess.open("user://exports/mobilei2v_manifest.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(manifest, "  "))
        file.close()
    status.text = "%d PNG exportes dans %s (dossier interne de l'application). Pas de MP4." % [saved, folder]

func _prepare() -> void:
    sources.clear()
    paths.clear()
    plan.clear()
    for i in range(16):
        var path := "res://assets/poses/pose_%02d.jpg" % i
        paths.append(path)
        sources.append(load(path))
    var target_count: int = maxi(1, mini(240, int(duration_input.value * 12.0)))
    for i in range(target_count):
        plan.append(mini(15, int(float(i) / float(target_count) * 16.0)))
    accepted.clear()
    for i in range(16): accepted.append(false)
    frame_index = 0
    _refresh()

func _refresh() -> void:
    if sources.is_empty():
        status.text = "Aucune planche preparee."
        return
    frame_index = clampi(frame_index, 0, sources.size() - 1)
    preview.texture = sources[frame_index]
    var total_ok: int = 0
    for a in accepted:
        if a: total_ok += 1
    status.text = "Dessin %d / %d | %s | %d valides | %d instants prevus" % [frame_index + 1, sources.size(), "VALIDE" if accepted[frame_index] else "A VERIFIER", total_ok, plan.size()]

func _previous() -> void:
    frame_index = maxi(0, frame_index - 1)
    _refresh()

func _next() -> void:
    frame_index = mini(sources.size() - 1, frame_index + 1)
    _refresh()

func _approve_all() -> void:
    if sources.is_empty():
        status.text = "Cree ou charge une planche avant de valider."
        return
    for i in range(accepted.size()):
        accepted[i] = true
    _refresh()
    _build_contact_sheet()
    _save()
    status.text = "%d dessins VALIDES et sauvegardes. Appuie sur VALIDER ET ANIMER." % accepted.size()

func _reject_all() -> void:
    for i in range(accepted.size()):
        accepted[i] = false
    _refresh()

func _toggle_approval() -> void:
    if accepted.is_empty(): return
    accepted[frame_index] = not accepted[frame_index]
    _refresh()
    _save()

func _save() -> void:
    if sources.is_empty(): return
    var flags: Array = []
    for a in accepted: flags.append(a)
    var approved_drawings: Array = []
    var old_to_new: Dictionary = {}
    for i in range(paths.size()):
        if i < accepted.size() and accepted[i]:
            old_to_new[i] = approved_drawings.size()
            approved_drawings.append(paths[i])
    var approved_timeline: Array = []
    for old_idx in plan:
        if old_to_new.has(old_idx):
            approved_timeline.append(old_to_new[old_idx])
        elif not approved_drawings.is_empty():
            var nearest: int = -1
            var nearest_distance: int = 999999
            for original_idx in old_to_new.keys():
                var distance: int = absi(int(original_idx) - old_idx)
                if distance < nearest_distance:
                    nearest_distance = distance
                    nearest = int(original_idx)
            approved_timeline.append(old_to_new[nearest])
    var data := {"version": 2, "approved_drawings": approved_drawings, "approved_timeline": approved_timeline, "reference_path": imported_path, "description": action_input.text, "ai_endpoint": ai_endpoint.text, "duration_seconds": duration_input.value, "drawings": paths, "approved": flags, "timeline_indices": plan, "warning": "Offline photo camera motion or existing poses; no AI anatomy generation"}
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    if f == null:
        status.text = "Erreur de sauvegarde"
        return
    f.store_string(JSON.stringify(data, "  "))
    f.close()
    status.text = "Planche sauvegardee dans les donnees locales de l'application."

func _load_saved() -> void:
    if not FileAccess.file_exists(SAVE): return
    var f := FileAccess.open(SAVE, FileAccess.READ)
    if f == null: return
    var data = JSON.parse_string(f.get_as_text())
    f.close()
    if not data is Dictionary: return
    action_input.text = str(data.get("description", ""))
    ai_endpoint.text = str(data.get("ai_endpoint", ""))
    duration_input.value = float(data.get("duration_seconds", 6))
    imported_path = str(data.get("reference_path", ""))
    detected_landmarks.clear()
    sources.clear()
    paths.clear()
    for p in data.get("drawings", []):
        var path: String = str(p)
        var tex: Texture2D = _texture_for_path(path)
        if tex != null:
            sources.append(tex)
            paths.append(path)
    accepted.clear()
    for flag in data.get("approved", []): accepted.append(bool(flag))
    while accepted.size() < sources.size(): accepted.append(false)
    plan.clear()
    for idx in data.get("timeline_indices", []):
        if int(idx) >= 0 and int(idx) < sources.size():
            plan.append(int(idx))
    if plan.is_empty():
        for i in range(sources.size()): plan.append(i)
    frame_index = 0
    if sources.is_empty() and not imported_path.is_empty():
        var ref_tex: Texture2D = _texture_for_path(imported_path)
        if ref_tex != null:
            preview.texture = ref_tex
            status.text = "Photo retrouvee. Appuie sur Creer planche pour preparer les images."
    else:
        _refresh()

func _close() -> void:
    queue_free()

func _validate_and_animate() -> void:
    if sources.is_empty():
        status.text = "Prepare d'abord une planche."
        return
    var count: int = 0
    for flag in accepted:
        if flag:
            count += 1
    if count == 0:
        status.text = "Valide au moins un dessin avant de lancer l'animation."
        return
    _save()
    var file: FileAccess = FileAccess.open(SAVE, FileAccess.READ)
    if file == null:
        status.text = "Impossible de lire la planche sauvegardee."
        return
    var data: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not data is Dictionary:
        status.text = "Erreur de lecture de la planche."
        return
    if parent_studio == null or not is_instance_valid(parent_studio):
        status.text = "Erreur : studio non disponible."
        return
    var approved_paths: Array = data.get("approved_drawings", [])
    var approved_indices: Array = data.get("approved_timeline", [])
    if approved_paths.is_empty() or approved_indices.is_empty():
        status.text = "ERREUR : planche vide. Clique sur CREER PLANCHE, puis TOUT VALIDER."
        return
    for image_path in approved_paths:
        if _texture_for_path(str(image_path)) == null:
            status.text = "ERREUR : dessin introuvable : " + str(image_path).get_file()
            return
    parent_studio.call("apply_approved_board", approved_paths, approved_indices, float(data.get("duration_seconds", 6.0)))
    if parent_studio.approved_frames.is_empty() or parent_studio.approved_timeline.is_empty():
        status.text = "Erreur : aucune image transmise au studio."
        return
    queue_free()