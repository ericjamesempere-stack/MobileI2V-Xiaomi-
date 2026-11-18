extends RefCounted
# Presentation only: existing generation, persistence and export remain in storyboard.gd.
const INK = Color("26314b")
const PURPLE = Color("6955da")
const MUTED = Color("717b92")

func box(color: Color, radius: int = 22) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func text(parent: Node, value: String, size: int = 22, color: Color = INK) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func button(board: Control, parent: Node, title: String, callback: Callable, primary: bool = false) -> Button:
    var item := Button.new()
    item.text = title
    item.custom_minimum_size.y = 76
    item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item.add_theme_font_size_override("font_size", 23)
    item.add_theme_stylebox_override("normal", box(PURPLE if primary else Color("eef0fc"), 18))
    item.add_theme_stylebox_override("hover", box(Color("7866e5") if primary else Color("e1e4fa"), 18))
    item.add_theme_stylebox_override("pressed", box(Color("5141b8"), 18))
    item.add_theme_stylebox_override("disabled", box(Color("e9eaf1"), 18))
    item.add_theme_color_override("font_color", Color.WHITE if primary else INK)
    item.add_theme_color_override("font_hover_color", Color.WHITE if primary else INK)
    item.add_theme_color_override("font_pressed_color", Color.WHITE)
    item.add_theme_color_override("font_disabled_color", Color("9b9fb3"))
    var focus: StyleBoxFlat = box(Color.TRANSPARENT, 18)
    focus.set_border_width_all(3)
    focus.border_color = Color("f3ae57")
    item.add_theme_stylebox_override("focus", focus)
    item.pressed.connect(callback)
    parent.add_child(item)
    board.wizard_buttons.append(item)
    return item

func card(parent: Node, heading: String, caption: String, tint: Color = Color.WHITE) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_stylebox_override("panel", box(tint))
    parent.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 14)
    panel.add_child(content)
    if not heading.is_empty():
        text(content, heading, 30)
    if not caption.is_empty():
        text(content, caption, 20, MUTED)
    return content

func build(board: Control) -> void:
    var theme := Theme.new()
    theme.default_font_size = 22
    theme.set_color("font_color", "Label", INK)
    theme.set_color("font_color", "CheckBox", INK)
    theme.set_color("font_color", "TextEdit", INK)
    theme.set_color("font_placeholder_color", "TextEdit", MUTED)
    theme.set_color("caret_color", "TextEdit", PURPLE)
    theme.set_color("font_color", "LineEdit", INK)
    theme.set_color("font_color", "SpinBox", INK)
    theme.set_color("font_color", "OptionButton", INK)
    var field: StyleBoxFlat = box(Color("f4f5fb"), 14)
    field.set_border_width_all(1)
    field.border_color = Color("daddec")
    for kind in ["TextEdit", "LineEdit"]:
        theme.set_stylebox("normal", kind, field)
        theme.set_stylebox("focus", kind, field)
    board.theme = theme
    var backdrop := ColorRect.new()
    backdrop.color = Color("f3f4fb")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    board.add_child(backdrop)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    board.add_child(margin)
    var shell := VBoxContainer.new()
    shell.add_theme_constant_override("separation", 12)
    margin.add_child(shell)
    text(shell, "KARMA ONE", 36, PURPLE)
    text(shell, "Imagine. Dessine. Anime. · V60 · 1.6.2", 21, MUTED)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    shell.add_child(tabs)
    for index in range(3):
        var tab: Button = button(board, tabs, ["1. Créer", "2. Mes dessins", "3. Ma vidéo"][index], func() -> void: board._go_step(index))
        tab.name = "Step%d" % index
        tab.custom_minimum_size.y = 58
        tab.add_theme_font_size_override("font_size", 19)
        board.wizard_tabs.append(tab)
    var status_panel := PanelContainer.new()
    status_panel.add_theme_stylebox_override("panel", box(Color("e8e4ff"), 16))
    shell.add_child(status_panel)
    board.status = text(status_panel, "Commence par une image ou une idée. À toi de jouer !", 20)
    board.busy_bar = ProgressBar.new()
    board.busy_bar.custom_minimum_size.y = 8
    board.busy_bar.show_percentage = false
    board.busy_bar.visible = false
    shell.add_child(board.busy_bar)
    board.wizard_scroll = ScrollContainer.new()
    board.wizard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board.wizard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    board.wizard_scroll.follow_focus = true
    shell.add_child(board.wizard_scroll)
    board.root_box = VBoxContainer.new()
    board.root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board.root_box.add_theme_constant_override("separation", 14)
    board.wizard_scroll.add_child(board.root_box)
    for index in range(3):
        var page := VBoxContainer.new()
        page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        page.add_theme_constant_override("separation", 14)
        page.visible = index == 0
        board.root_box.add_child(page)
        board.wizard_pages.append(page)

    var person: VBoxContainer = card(board.wizard_pages[0], "Que veux-tu créer ?", "Choisis une photo ou décris librement ton idée ci-dessous.")
    button(board, person, "Choisir une photo", board._choose_image, true).name = "ChoosePhoto"
    board.local_mode = CheckBox.new()
    board.local_mode.text = "Moteurs du téléphone — installation et modèles requis"
    board.local_mode.button_pressed = true
    board.invent_box = VBoxContainer.new()
    board.invent_box.add_theme_constant_override("separation", 12)
    button(board, person, "Décrire mon image de départ", func() -> void: board.invent_box.visible = not board.invent_box.visible).name = "InventCharacter"
    person.add_child(board.invent_box)
    board.character_description = TextEdit.new()
    board.character_description.custom_minimum_size.y = 120
    board.character_description.placeholder_text = "Un renard, un paysage, un véhicule, plusieurs sujets…"
    board.invent_box.add_child(board.character_description)
    text(board.invent_box, "Le moteur image configuré crée la référence ; aucun compte ChatGPT requis.", 18, MUTED)
    button(board, board.invent_box, "Générer mon image avec les agents", board._create_remote_reference, true).name = "AgentReference"

    board.invent_box.visible = false
    board.preview = TextureRect.new()
    board.preview.custom_minimum_size.y = 190
    board.preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    board.preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    person.add_child(board.preview)
    board.reference_hint = Label.new()
    board.reference_hint.text = "Ton image de départ apparaîtra ici"
    board.reference_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    board.reference_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    board.reference_hint.add_theme_color_override("font_color", MUTED)
    board.reference_hint.add_theme_font_size_override("font_size", 20)
    board.reference_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    board.preview.add_child(board.reference_hint)
    text(person, "Choisis son univers", 24)
    board.drawing_style = OptionButton.new()
    var names: Array[String] = ["Original", "Cartoon", "Manga", "Anime", "3D", "Cinéma", "BD détaillée"]
    for value in names:
        board.drawing_style.add_item(value)
    board.drawing_style.hide()
    person.add_child(board.drawing_style)
    var styles := GridContainer.new()
    styles.columns = 3
    styles.add_theme_constant_override("h_separation", 8)
    styles.add_theme_constant_override("v_separation", 8)
    person.add_child(styles)
    for index in range(names.size()):
        var tile: Button = button(board, styles, names[index], func() -> void: board.drawing_style.select(index))
        tile.custom_minimum_size.y = 64
        tile.toggle_mode = true
        board.style_tiles.append(tile)
    board.custom_style_input = LineEdit.new()
    board.custom_style_input.placeholder_text = "Autre style libre : aquarelle, pâte à modeler, pixel art..."
    board.custom_style_input.custom_minimum_size.y = 58
    person.add_child(board.custom_style_input)
    board.style_reference_hint = text(person, "Facultatif : importe une illustration ou une planche dont tu veux retrouver le style.", 18)
    board.style_reference_preview = TextureRect.new()
    board.style_reference_preview.custom_minimum_size = Vector2(0, 180)
    board.style_reference_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    board.style_reference_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    board.style_reference_preview.hide()
    person.add_child(board.style_reference_preview)
    button(board, person, "Importer une référence de style", board._choose_style_reference).name = "ChooseStyleReference"
    button(board, person, "Retirer la référence de style", board._remove_style_reference)
    text(person, "Le style est facultatif. Original conserve le style de ta référence.", 18)
    text(person, "Photo depuis la galerie Android ou création avec le moteur image configuré.", 18, MUTED)

    var story: VBoxContainer = card(board.wizard_pages[0], "Que va-t-il se passer ?", "Raconte une petite aventure. Tu peux commencer par un exemple.")
    board.action_input = TextEdit.new()
    board.action_input.custom_minimum_size.y = 200
    board.action_input.placeholder_text = "Il marche, puis court. Il trébuche, tombe et se relève."
    story.add_child(board.action_input)
    var examples := HBoxContainer.new()
    examples.add_theme_constant_override("separation", 8)
    story.add_child(examples)
    var stories: Array[String] = ["Il marche, puis court. Il tombe et se relève.", "Elle danse, puis saute et salue.", "Il marche, puis salue et s'arrête."]
    for index in range(3):
        var sample: Button = button(board, examples, ["Une aventure", "Une danse", "Un coucou"][index], func() -> void: board.action_input.text = stories[index])
        sample.add_theme_font_size_override("font_size", 18)
        sample.custom_minimum_size.y = 60
    text(story, "Combien de temps ?", 24)
    var durations := HBoxContainer.new()
    durations.add_theme_constant_override("separation", 8)
    story.add_child(durations)
    for seconds in [6, 12, 20]:
        var preset: Button = button(board, durations, "%d secondes" % seconds, func() -> void: board.duration_input.value = seconds)
        preset.custom_minimum_size.y = 60
        preset.add_theme_font_size_override("font_size", 19)
    board.choice_summary = text(story, "", 19, MUTED)
    var chatgpt := VBoxContainer.new() # Legacy grid controls for saved projects
    chatgpt.visible = false
    board.wizard_pages[1].add_child(chatgpt)
    button(board, board.wizard_pages[0], "Générer mes dessins avec les agents", board._friendly_generate, true).name = "AgentBoard"
    button(board, board.wizard_pages[0], "Voir mes dessins", func() -> void: board._go_step(1), true).name = "NextStory"
    var grid_shape := HBoxContainer.new()
    var grid_toggle := Button.new()
    grid_toggle.text = "Corriger la grille (si nécessaire)"
    grid_toggle.custom_minimum_size.y = 52
    chatgpt.add_child(grid_toggle)
    grid_shape.visible = false
    grid_toggle.pressed.connect(func() -> void: grid_shape.visible = not grid_shape.visible)
    chatgpt.add_child(grid_shape)
    text(grid_shape, "Colonnes", 18)
    board.chatgpt_columns = SpinBox.new()
    board.chatgpt_columns.min_value = 1
    board.chatgpt_columns.max_value = 6
    board.chatgpt_columns.value = 4
    grid_shape.add_child(board.chatgpt_columns)
    text(grid_shape, "Lignes", 18)
    board.chatgpt_rows = SpinBox.new()
    board.chatgpt_rows.min_value = 1
    board.chatgpt_rows.max_value = 6
    board.chatgpt_rows.value = 2
    grid_shape.add_child(board.chatgpt_rows)
    text(chatgpt, "Grille automatique par défaut : 4 × 2. Vérifie les dessins après import.", 18, MUTED)
    button(board, board.wizard_pages[1], "Revoir mon image de départ", func() -> void: board._go_step(0))

    var film: VBoxContainer = card(board.wizard_pages[2], "Ton histoire prend forme", "Regarde les dessins avant de créer ta vidéo.")
    board.movie_preview = TextureRect.new()
    board.movie_preview.custom_minimum_size.y = 230
    board.movie_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    board.movie_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    film.add_child(board.movie_preview)
    var drawings: VBoxContainer = card(board.wizard_pages[1], "Examiner la planche", "Agrandis chaque dessin : Garder, Refuser ou Refaire.")
    board.contact_caption = text(drawings, "Tes dessins apparaîtront ici.", 20, MUTED)
    board.contact_sheet = TextureRect.new()
    board.contact_sheet.custom_minimum_size.y = 200
    board.contact_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    board.contact_sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    drawings.add_child(board.contact_sheet)
    button(board, drawings, "Agrandir et vérifier les dessins", board._show_drawing_review)
    button(board, drawings, "Continuer : ma vidéo", func() -> void: board._go_step(2), true).name = "NextVideo"
    board.preview_toggle = button(board, film, "Voir défiler mes dessins", board._toggle_drawing_preview)
    board.preview_toggle.name = "PreviewDrawings"
    board.review_check = CheckBox.new()
    board.review_check.text = "J'ai regardé et validé mes dessins"
    board.review_check.custom_minimum_size.y = 64
    board.review_check.add_theme_constant_override("h_separation", 12)
    for state in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
        var checked: bool = state.begins_with("checked")
        var image := Image.new()
        var mark: String = '<path d="M7 14l5 5 9-11" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>' if checked else ""
        var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28"><rect x="1" y="1" width="26" height="26" rx="7" fill="%s" stroke="#6955da" stroke-width="2"/>%s</svg>' % ["#6955da" if checked else "white", mark]
        if image.load_svg_from_string(svg) == OK:
            board.review_check.add_theme_icon_override(state, ImageTexture.create_from_image(image))
    board.review_check.visible = false # Legacy state only; final button provides one approval.
    film.add_child(board.review_check)
    board.friendly_export = button(board, board.wizard_pages[2], "Valider et exporter ma vidéo MP4", board._friendly_export, true)
    board.friendly_export.name = "CreateMovie"
    button(board, board.wizard_pages[2], "Valider et exporter la planche PNG", board._friendly_export_png, false)
    button(board, board.wizard_pages[2], "Lire ma dernière vidéo", board._play_last_mp4).name = "PlayMovie"
    button(board, board.wizard_pages[2], "Partager ma vidéo", board._share_last_mp4)
    button(board, board.wizard_pages[2], "Améliorer mon histoire", func() -> void: board._go_step(1))

    button(board, board.root_box, "Réglages et outils", func() -> void: board.advanced_panel.visible = not board.advanced_panel.visible).name = "AdvancedToggle"
    var advanced: VBoxContainer = card(board.root_box, "Le coin des réglages", "Facultatif : les trois étapes suffisent pour commencer.", Color("edf0f9"))
    board.advanced_panel = advanced.get_parent()
    board.advanced_panel.visible = false
    advanced.add_child(board.local_mode)
    button(board, advanced, "Tester une vraie image IA sur le téléphone (512 px)", board._test_real_local_diffusion).name = "TestLocalDiffusion"
    text(advanced, "Décoche le mode local pour envoyer tes demandes et images aux services Hugging Face de KARMA ONE. Leurs quotas s'appliquent.", 18, MUTED)
    board.remote_fallback = CheckBox.new()
    board.remote_fallback.text = "Secours IA automatique en ligne (Hugging Face)"
    board.remote_fallback.button_pressed = false # User must explicitly authorize photo upload to external AI.
    board.remote_fallback.name = "RemoteFallback"
    advanced.add_child(board.remote_fallback)
    text(advanced, "Si le moteur local échoue, les photos et consignes peuvent être envoyées à Hugging Face. Services soumis à disponibilité et quotas.", 18, MUTED)
    text(story, "Le secours en ligne peut envoyer tes photos et consignes à Hugging Face. Tu peux le désactiver dans Réglages et outils.", 18, MUTED)
    text(advanced, "Durée personnalisée (secondes)", 20)
    board.duration_input = SpinBox.new()
    board.duration_input.min_value = 1
    board.duration_input.max_value = 300
    board.duration_input.value = 6
    advanced.add_child(board.duration_input)
    text(advanced, "Limite de poses clés en ligne (sans plafond par lot en mode local)", 20)
    board.ai_drawings_count = SpinBox.new()
    board.ai_drawings_count.min_value = 2
    board.ai_drawings_count.max_value = 24
    board.ai_drawings_count.value = 24
    advanced.add_child(board.ai_drawings_count)
    text(advanced, "Installation des moteurs locaux", 20)
    text(advanced, "Pour utiliser le mode local, installe MNN Chat (vision) et Local Dream (images), charge leurs modèles puis active leurs services. Sinon, choisis le mode en ligne avec ton autorisation.", 18, MUTED)
    button(board, advanced, "Vérifier les moteurs du téléphone", board._check_local_engines).name = "CheckLocalEngines"
    board.local_engine_status = text(advanced, "Connexion locale non vérifiée. Ce contrôle ne génère aucune image.", 18, MUTED)
    button(board, advanced, "Copier le diagnostic local", board._copy_local_diagnostic).name = "CopyLocalDiagnostic"
    button(board, advanced, "Télécharger MNN Chat", func() -> void: OS.shell_open("https://github.com/alibaba/MNN/releases"))
    button(board, advanced, "Télécharger Local Dream", func() -> void: OS.shell_open("https://github.com/xororz/local-dream/releases"))
    board.local_auth_input = LineEdit.new()
    board.local_auth_input.secret = true
    board.local_auth_input.placeholder_text = "Clé locale générée dans les réglages API de MNN Chat"
    advanced.add_child(board.local_auth_input)
    text(advanced, "MNN Chat protège son API locale par une clé. Copie-la dans ce champ privé ; elle n'est pas enregistrée dans tes projets et ne sert à aucun abonnement.", 18, MUTED)
    text(advanced, "Compte Hugging Face : jeton facultatif", 20)
    board.ai_token_input = LineEdit.new()
    board.ai_token_input.secret = true
    board.ai_token_input.placeholder_text = "Ton jeton privé reste hors du projet sauvegardé"
    advanced.add_child(board.ai_token_input)
    text(advanced, "Autre moteur HTTPS (facultatif)", 20)
    board.ai_endpoint = LineEdit.new()
    board.ai_endpoint.placeholder_text = "https://…"
    advanced.add_child(board.ai_endpoint)
    board.karma_auto_export_toggle = CheckBox.new()
    board.karma_auto_export_toggle.text = "Vidéo après validation de la planche"
    board.karma_auto_export_toggle.disabled = true
    board.karma_auto_export_toggle.button_pressed = false
    board.karma_auto_export_toggle.toggled.connect(func(enabled: bool) -> void: board.karma_auto_export = enabled)
    advanced.add_child(board.karma_auto_export_toggle)
    # Keep every legacy operation accessible without burying the main workflow.
    var legacy_toggle: Button = button(board, advanced, "Outils techniques et anciens parcours (afficher)", func() -> void: pass)
    var legacy_box := VBoxContainer.new()
    legacy_box.visible = false
    advanced.add_child(legacy_box)
    legacy_toggle.pressed.connect(func() -> void:
        legacy_box.visible = not legacy_box.visible
        legacy_toggle.text = "Outils techniques (masquer)" if legacy_box.visible else "Outils techniques et anciens parcours (afficher)"
    )
    var tools: Array = [
        ["Reprendre mon dernier projet", board._friendly_restore],
        ["Enregistrer mes dessins", board._save], ["Mes images enregistrées", board._show_saved_images],
        ["Reprendre l'image à l'identique", board._reuse_reference_drawing],
        ["Importer des dessins", board._choose_drawings_folder], ["Fusionner des lots", board._choose_merge_folder],
        ["Reprendre un montage", board._restore_karma_merge], ["Importer une planche", board._choose_pose_sheet],
        ["Exporter les PNG", board._export_png_sequence], ["Exporter en AVI", board._export_video_direct],
        ["Préparer un relais IA", board._prepare_karma_relay], ["Préparer les poses", board._prepare_pose_guides],
        ["Moteur HTTPS personnalisé", board._generate_image_sequence], ["Moteur HTTPS + MP4", board._generate_and_export],
        ["Aperçu cartoon simple hors ligne", board._draw_offline_story],
        ["Articuler la photo en 2D", board._automatic_local_movie],
        ["Dessiner un personnage générique", board._generate_text_cartoon],
        ["Détecter le squelette", board._request_pose], ["Poses détectées", board._generate_detected_board],
        ["Ancien moteur IA", board._request_ai_board], ["Démo articulée", board._generate_layered_demo],
        ["Animation articulée", board._generate_articulated_board], ["Effet de caméra", board._generate_from_photo],
        ["Parcourir mes images", board._choose_gallery], ["Parcourir l'appareil photo", board._choose_camera_gallery],
        ["Pose précédente", board._previous], ["Valider / retirer cette pose", board._toggle_approval],
        ["Pose suivante", board._next], ["Tout retirer", board._reject_all], ["Ancien lecteur", board._close]
    ]
    var demo_actions: Array[Callable] = [board._draw_offline_story, board._automatic_local_movie, board._generate_text_cartoon, board._generate_layered_demo, board._generate_articulated_board, board._generate_from_photo, board._close]
    for tool in tools:
        if tool[1] in demo_actions:
            continue
        button(board, legacy_box, str(tool[0]), tool[1])
    board.skeleton_preview = TextureRect.new()
    board.skeleton_preview.custom_minimum_size.y = 260
    board.skeleton_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    board.skeleton_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    board.skeleton_preview.hide()
    advanced.add_child(board.skeleton_preview)
