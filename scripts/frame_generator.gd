extends Node
class_name FrameGenerator

# Offline frame renderer: renders a real articulated 2D rig, not a zoomed photo.
# Usage: add_child(generator); await generator.generate("il court puis tombe", 5.0)
signal progress(done: int, total: int)
signal finished(directory: String, frames: int)
signal failed(reason: String)

const SIZE := Vector2i(720, 1280)
const FPS := 30
var busy := false

func generate(prompt: String, duration: float = 5.0, face: Texture2D = null) -> String:
    if busy:
        failed.emit("Generation deja en cours")
        return ""
    if duration <= 0.0 or duration > 300.0:
        failed.emit("Duree autorisee : 0 a 300 secondes")
        return ""
    busy = true
    var count := ceili(duration * FPS)
    var directory := "user://generated/sequence_%d" % Time.get_unix_time_from_system()
    var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if error != OK:
        busy = false
        failed.emit("Impossible de creer le dossier : %d" % error)
        return ""
    var viewport := SubViewport.new()
    viewport.size = SIZE
    viewport.transparent_bg = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.disable_3d = true
    add_child(viewport)
    var background := ColorRect.new()
    background.color = Color("101923")
    background.size = Vector2(SIZE)
    viewport.add_child(background)
    var rig := Control.new()
    rig.set_script(load("res://scripts/rig_character.gd"))
    rig.position = Vector2(0, 170)
    rig.size = Vector2(720, 900)
    viewport.add_child(rig)
    if face != null:
        rig.reference_head = face
    var action := MotionPlanner.action_from_text(prompt)
    for i in range(count):
        var t := float(i) / float(FPS)
        var frame_action := action
        if action == "run_fall":
            frame_action = "marche" if t < duration * 0.65 else "chute"
        elif action == "run":
            frame_action = "marche"
        elif action == "wave":
            frame_action = "salut"
        elif action == "dance":
            frame_action = "danse"
        elif action == "fall":
            frame_action = "chute"
        elif action == "jump":
            frame_action = "saut"
        rig.update_pose(t, frame_action)
        await RenderingServer.frame_post_draw
        var img := viewport.get_texture().get_image()
        if img == null or img.is_empty():
            viewport.queue_free()
            busy = false
            failed.emit("Capture de frame impossible")
            return ""
        var path := "%s/frame_%06d.png" % [directory, i]
        error = img.save_png(path)
        if error != OK:
            viewport.queue_free()
            busy = false
            failed.emit("Ecriture PNG impossible : %d" % error)
            return ""
        if i % 30 == 0 or i == count - 1:
            progress.emit(i + 1, count)
        # Yield each frame so Android can process input and redraw.
        await get_tree().process_frame
    viewport.queue_free()
    busy = false
    finished.emit(directory, count)
    return directory
