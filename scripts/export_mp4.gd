extends Node
# V50 : export MP4 H.264 via plugin Android natif. Repli PNG explicite sinon.
var status_label: Label = null
var exporting: bool = false

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
        img.convert(Image.FORMAT_RGB8)
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
    if exporting:
        return
    if board_images.is_empty() or timeline.is_empty():
        _set_status("MP4 impossible : planche vide.")
        return
    if not Engine.has_singleton("MP4Exporter"):
        _set_status("Encodeur MP4 Android indisponible. Utilise l'export AVI local.")
        return
    exporting = true
    var encoder: Object = Engine.get_singleton("MP4Exporter")
    var output: String = "/storage/emulated/0/Movies/MobileI2V_Board_%d.mp4" % int(Time.get_unix_time_from_system())
    var begin_result: Variant = encoder.call("begin", output, WIDTH, HEIGHT, FPS)
    if begin_result is bool and not begin_result:
        _set_status("Echec initialisation de l'encodeur H.264.")
        exporting = false
        return
    var total: int = maxi(1, roundi(clampf(duration, 0.5, 60.0) * float(FPS)))
    var written: int = 0
    for n in range(total):
        var slot: int = mini(timeline.size() - 1, int(float(n) / float(total) * float(timeline.size())))
        var index: int = int(timeline[slot])
        if index < 0 or index >= board_images.size():
            continue
        var texture: Texture2D = board_images[index] as Texture2D
        if texture == null:
            continue
        var img: Image = texture.get_image()
        if img == null or img.is_empty():
            continue
        img.convert(Image.FORMAT_RGBA8)
        img.resize(WIDTH, HEIGHT, Image.INTERPOLATE_LANCZOS)
        encoder.call("push_frame_rgba", img.get_data())
        written += 1
        if n % 8 == 0:
            _set_status("Encodage MP4 : %d / %d" % [n + 1, total])
            await get_tree().process_frame
    var result: String = str(encoder.call("finish"))
    exporting = false
    _set_status("MP4 : " + result if not result.is_empty() and written == total else "MP4 incomplet : %d/%d images." % [written, total])

