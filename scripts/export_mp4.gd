extends Node
# V50 : export MP4 H.264 via plugin Android natif. Repli PNG explicite sinon.
var status_label: Label = null
var exporting: bool = false
var last_output: String = ""
var hold_keyframes: bool = false

const FPS: int = 30
const WIDTH: int = 720
const HEIGHT: int = 1280

func _set_status(text: String) -> void:
    if status_label != null and is_instance_valid(status_label):
        status_label.text = text
    print("MobileI2V export: " + text)

func export_rig_mp4(rig: Control, current_scene: int, start_clock: float) -> void:
    if exporting:
        return
    exporting = true
    var motion_name: String = "danse"
    var duration: float = 5.0
    var viewport := SubViewport.new()
    viewport.size = Vector2i(WIDTH, HEIGHT)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.transparent_bg = false
    var holder: Control = Control.new()
    holder.set_script(load("res://scripts/rig_character.gd"))
    holder.position = Vector2(0, 105)
    holder.size = Vector2(720, 900)
    viewport.add_child(holder)
    add_child(viewport)
    var frames_dir: String = "user://exports/mp4_frames"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_dir))
    var frame_count: int = duration * FPS
    var plugin_ok: bool = Engine.has_singleton("MP4Exporter")
    var exporter: Object = null
    if plugin_ok:
        exporter = Engine.get_singleton("MP4Exporter")
        var out: String = "/storage/emulated/0/Movies/MobileI2V_%d.mp4" % (Time.get_unix_time_from_system() as int)
        exporter.call("begin", out, WIDTH, HEIGHT, FPS)
    var written: int = 0
    for n in range(frame_count):
        var t: float = float(n) / float(FPS)
        holder.call("update_pose", t, motion_name)
        RenderingServer.force_draw()
        var img: Image = viewport.get_texture().get_image()
        if img == null or img.is_empty():
            continue
        img.convert(Image.FORMAT_RGBA8)
        if plugin_ok and exporter != null:
            exporter.call("push_frame_rgba", img.get_data())
        else:
            img.save_png("%s/frame_%04d.png" % [frames_dir, n])
        written += 1
        if n % 15 == 0:
            _set_status("Export video : %d / %d frames" % [n + 1, frame_count])
            await get_tree().process_frame
    var result_text: String
    if plugin_ok and exporter != null:
        var out_path: String = str(exporter.call("finish"))
        result_text = "MP4 H.264 exporte : " + out_path if out_path != "" else "Echec encodage MP4 (voir logcat)."
    else:
        result_text = "%d PNG exportes dans %s (plugin MP4 indisponible sur cette plateforme)." % [written, frames_dir]
    _set_status(result_text)
    viewport.queue_free()
    exporting = false
func export_board_mp4(board_images: Array, timeline: Array, duration: float) -> void:
    last_output = ""
    if exporting:
        return
    if board_images.is_empty() or timeline.is_empty():
        _set_status("MP4 impossible : planche vide.")
        return
    var native_encoder: Object = _get_encoder()
    if native_encoder == null:
        _set_status("Encodeur MP4 Android indisponible. Utilise l'export AVI local.")
        return
    exporting = true
    var encoder: Object = native_encoder
    var output: String = "/storage/emulated/0/Movies/MobileI2V_Board_%d.mp4" % int(Time.get_unix_time_from_system())
    var begin_result: Variant = encoder.call("begin", output, WIDTH, HEIGHT, FPS)
    if begin_result is bool and not begin_result:
        _set_status("Echec initialisation de l'encodeur H.264.")
        exporting = false
        return
    var total: int = maxi(1, roundi(clampf(duration, 0.5, 300.0) * float(FPS)))
    var written: int = 0
    var previous_pair: String = ""
    var image_a: Image = null
    var image_b: Image = null
    for n in range(total):
        var position: float = float(n) / float(total) * float(timeline.size())
        var slot: int = mini(timeline.size() - 1, n if timeline.size() == total else floori(position))
        var next_slot: int = mini(timeline.size() - 1, slot + 1)
        var index: int = int(timeline[slot])
        var next_index: int = int(timeline[next_slot])
        if index < 0 or index >= board_images.size() or next_index < 0 or next_index >= board_images.size():
            _set_status("Index de pose invalide : export MP4 annule.")
            encoder.call("abort")
            exporting = false
            return
        var pair: String = "%d:%d" % [index, next_index]
        if pair != previous_pair:
            image_a = _read_drawing(board_images[index])
            image_b = image_a if index == next_index else _read_drawing(board_images[next_index])
            if image_a == null or image_a.is_empty() or image_b == null or image_b.is_empty():
                _set_status("Dessin vide : export MP4 annule.")
                encoder.call("abort")
                exporting = false
                return
            previous_pair = pair
        var progress: float = position - float(slot)
        var eased: float = progress * progress * (3.0 - 2.0 * progress)
        # Pixel crossfades create translucent double bodies rather than genuine
        # in-between poses. Keep each validated drawing intact until a real
        # articulated interpolation backend is available.
        var img: Image = image_a.duplicate() if hold_keyframes or index == next_index or eased < 0.5 else image_b.duplicate()
        img = _fit_canvas(img)
        img.convert(Image.FORMAT_RGBA8)
        var frame_ok: Variant = encoder.call("push_frame_rgba", img.get_data())
        if frame_ok is bool and not frame_ok:
            var reason: String = str(encoder.call("get_last_error"))
            encoder.call("abort")
            exporting = false
            _set_status("Encodage H.264 interrompu a l image %d : %s" % [n + 1, reason])
            return
        written += 1
        if n % 8 == 0:
            _set_status("MP4 poses distinctes : %d / %d" % [n + 1, total])
            await get_tree().process_frame
    var result: String = str(encoder.call("finish"))
    exporting = false
    if not result.is_empty() and written == total:
        last_output = result
    _set_status("MP4 : " + result if not result.is_empty() and written == total else "MP4 incomplet : %d/%d images." % [written, total])



func _read_drawing(value: Variant) -> Image:
    if value is String:
        var image := Image.new()
        return image if image.load(str(value)) == OK else null
    if value is Texture2D:
        return value.get_image()
    return null

func _fit_canvas(source: Image) -> Image:
    var image: Image = source.duplicate()
    var ratio: float = minf(float(WIDTH) / image.get_width(), float(HEIGHT) / image.get_height())
    image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_BILINEAR)
    image.convert(Image.FORMAT_RGBA8)
    var canvas := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
    canvas.fill(Color.BLACK)
    canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((WIDTH - image.get_width()) / 2, (HEIGHT - image.get_height()) / 2))
    return canvas

func _get_encoder() -> Object:
    return Engine.get_singleton("MP4Exporter") if Engine.has_singleton("MP4Exporter") else null
