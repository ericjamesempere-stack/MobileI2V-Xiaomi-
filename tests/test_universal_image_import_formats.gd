extends SceneTree

# Offline regression: the same reader used by Android storyboard must accept
# common drawings/photos and reject corrupt input without altering a project.
func _initialize() -> void:
    var reader = load("res://scripts/android_image_reader.gd")
    var img := Image.create(47, 29, false, Image.FORMAT_RGB8)
    img.fill(Color(0.2, 0.5, 0.8))
    var folder := "user://image_import_regression"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
    var png := folder.path_join("source.png")
    var jpg := folder.path_join("source.jpg")
    var webp := folder.path_join("source.webp")
    assert(img.save_png(png) == OK)
    assert(img.save_jpg(jpg) == OK)
    assert(img.save_webp(webp) == OK)
    for path in [png, jpg, webp]:
        var decoded: Image = reader.read_image(path)
        assert(decoded != null and not decoded.is_empty(), path)
        assert(decoded.get_width() == 47 and decoded.get_height() == 29, path)
    var corrupt := folder.path_join("broken.png")
    var file := FileAccess.open(corrupt, FileAccess.WRITE)
    assert(file != null)
    file.store_string("not an image")
    file.close()
    assert(reader.read_image(corrupt) == null)
    assert(reader.read_image(folder.path_join("missing.png")) == null)
    print("UNIVERSAL_IMAGE_IMPORT_FORMATS_OK")
    quit(0)
