extends SceneTree

func _initialize() -> void:
    var storyboard = load("res://scripts/storyboard.gd")
    assert(storyboard != null)
    assert(storyboard._validated_export_timeline([0, 1, 1, 2], 3, [true, true, true]) == [0, 1, 1, 2])
    assert(storyboard._validated_export_timeline([], 2, [true, true]).is_empty())
    assert(storyboard._validated_export_timeline([0, 2], 2, [true, true]).is_empty())
    assert(storyboard._validated_export_timeline([-1, 0], 2, [true, true]).is_empty())
    assert(storyboard._validated_export_timeline([0, 1], 2, [true, false]).is_empty())
    assert(storyboard._validated_export_timeline([0, 1], 2, [true]).is_empty())
    assert(storyboard._validated_export_timeline(["invalid", 1], 2, [true, true]).is_empty())
    print("MP4_APPROVED_TIMELINE_OK")
    quit(0)
