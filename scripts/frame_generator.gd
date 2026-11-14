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
    var directory := "user://generated/sequence_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
    var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if error != OK:
        busy = false
        failed.emit("Impossible de creer le dossier : %d" % error)
        return ""
    var metadata := {"prompt": prompt, "duration_seconds": duration, "fps": FPS, "width": SIZE.x, "height": SIZE.y, "frames": count, "format": "png", "renderer": "articulated_2d", "reference_photo_applied": false, "identity_preserved": false, "actions": MotionPlanner.story_actions(prompt)}
    var metadata_file := FileAccess.open(directory + "/sequence.json", FileAccess.WRITE)
    if metadata_file == null:
        busy = false
        failed.emit("Impossible de sauvegarder les metadonnees")
        return ""
    metadata_file.store_string(JSON.stringify(metadata, "  "))
    metadata_file.close()
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
    var rig := load("res://scripts/rig_character.gd").new()
    rig.position = Vector2(0, 170)
    rig.size = Vector2(720, 900)
    viewport.add_child(rig)
    # A raw photo cannot be treated as a generated full-body model sheet.
    # Keep the procedural illustrated character until a genuine model-sheet
    # conversion is available; do not paste the photo onto its head.
    if face != null:
        push_warning("Photo importee, mais conversion en personnage BD non disponible : avatar provisoire.")
    for i in range(count):
        var t := float(i) / float(FPS)
        var instruction: Dictionary = MotionPlanner.story_action_at(prompt, t, duration)
        var action: String = instruction["action"]
        var local_time: float = instruction["local_time"]
        var segment_duration: float = instruction["segment_duration"]
        var frame_action := "danse"
        var pose_time := local_time
        match action:
            "run":
                frame_action = "marche"
            "wave":
                frame_action = "salut"
            "dance":
                frame_action = "danse"
            "fall":
                frame_action = "chute"
                pose_time = local_time * 2.0 / segment_duration
            "jump":
                frame_action = "saut"
                pose_time = local_time * 2.0 / segment_duration
            "idle":
                frame_action = "salut"
                pose_time = 0.0
        rig.update_pose(pose_time, frame_action)
        var expression := "neutral"
        if action == "fall":
            expression = "surprised"
        elif action == "dance" or action == "jump":
            expression = "happy"
        rig.update_expression(t, expression)
        await get_tree().process_frame
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
        # Keep one frame in memory at a time; avoid accumulating images.
    viewport.queue_free()
    busy = false
    finished.emit(directory, count)
    return directory
