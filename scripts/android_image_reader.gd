extends RefCounted
# Supports Android SAF content:// URIs as well as ordinary file paths.
static func read_image(path: String) -> Image:
    var result := Image.new()
    if not path.begins_with("content://"):
        if result.load(path) == OK:
            return result
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var bytes: PackedByteArray = file.get_buffer(file.get_length())
    file.close()
    if bytes.is_empty():
        return null
    var ext: String = path.get_extension().to_lower()
    var attempts: Array[String] = [ext, "png", "jpg", "webp"]
    for kind in attempts:
        var err: Error = ERR_FILE_UNRECOGNIZED
        match kind:
            "png":
                err = result.load_png_from_buffer(bytes)
            "jpg", "jpeg":
                err = result.load_jpg_from_buffer(bytes)
            "webp":
                err = result.load_webp_from_buffer(bytes)
        if err == OK and not result.is_empty():
            return result
    return null
