extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var script = load("res://scripts/StorySequencePlayer.gd")
    var root := "user://test_story_player"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) == OK)
    var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    for i in range(3):
        img.fill(Color(float(i) / 3.0, 0.3, 0.7))
        assert(img.save_png("%s/frame_%06d.png" % [root, i]) == OK)
    var manifest := FileAccess.open(root + "/manifest.json", FileAccess.WRITE)
    assert(manifest != null)
    manifest.store_string(JSON.stringify({"fps": 12, "frame_count": 3, "video_encoded": false}))
    manifest.close()
    var player: Control = script.new()
    root_node.add_child(player)
    assert(player.open_sequence(root))
    assert(player.running)
    assert(player.frame_paths.size() == 3)
    player._process(1.0 / 12.0)
    assert(player.index == 1)
    player._process(1.0 / 12.0)
    assert(player.index == 2)
    player._process(1.0 / 12.0)
    assert(player.index == 0)
    player.queue_free()
    for i in range(3):
        assert(DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/frame_%06d.png" % [root, i])) == OK)
    assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(root + "/manifest.json")) == OK)
    assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(root)) == OK)
    print("MOBILEI2V_STORY_PLAYER_OK")
    quit(0)
