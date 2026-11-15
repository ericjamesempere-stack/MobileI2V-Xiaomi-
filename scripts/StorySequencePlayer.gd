extends Control
class_name StorySequencePlayer

# Plays actual numbered PNG frames from disk. Only one decoded frame is kept
# in memory at a time; no photo warping or synthetic in-between images.
signal playback_failed(reason: String)

var frame_paths: Array[String] = []
var fps: int = 12
var index: int = 0
var accumulator: float = 0.0
var running: bool = false
var display: TextureRect
var close_button: Button

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var backdrop := ColorRect.new()
    backdrop.color = Color("101923")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    display = TextureRect.new()
    display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    display.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(display)
    close_button = Button.new()
    close_button.text = "Fermer la lecture"
    close_button.position = Vector2(16, 16)
    close_button.size = Vector2(240, 54)
    close_button.pressed.connect(queue_free)
    add_child(close_button)

func open_sequence(directory: String) -> bool:
    var manifest_file := FileAccess.open(directory + "/manifest.json", FileAccess.READ)
    if manifest_file == null:
        playback_failed.emit("manifest_missing")
        return false
    var manifest: Variant = JSON.parse_string(manifest_file.get_as_text())
    manifest_file.close()
    if not manifest is Dictionary:
        playback_failed.emit("invalid_manifest")
        return false
    var new_fps := int(manifest.get("fps", 0))
    var count := int(manifest.get("frame_count", 0))
    if new_fps < 1 or new_fps > 60 or count < 1 or count > 18000:
        playback_failed.emit("invalid_timeline")
        return false
    var found: Array[String] = []
    for i in range(count):
        var path := "%s/frame_%06d.png" % [directory, i]
        if not FileAccess.file_exists(path):
            playback_failed.emit("missing_frame_%d" % i)
            return false
        found.append(path)
    frame_paths = found
    fps = new_fps
    index = 0
    accumulator = 0.0
    running = _show_frame(0)
    return running

func _process(delta: float) -> void:
    if not running or frame_paths.is_empty():
        return
    accumulator += minf(delta, 0.25)
    var advance := int(accumulator * float(fps))
    if advance == 0:
        return
    accumulator -= float(advance) / float(fps)
    index = (index + advance) % frame_paths.size()
    if not _show_frame(index):
        running = false

func _show_frame(frame_index: int) -> bool:
    if display == null or frame_index < 0 or frame_index >= frame_paths.size():
        return false
    var img := Image.new()
    if img.load(frame_paths[frame_index]) != OK or img.is_empty():
        playback_failed.emit("corrupt_frame_%d" % frame_index)
        return false
    display.texture = ImageTexture.create_from_image(img)
    return true
