extends SceneTree

func _initialize() -> void:
    var exporter = load("res://scripts/export_mp4.gd")
    assert(exporter != null)
    var good := "user://mp4_header_good.mp4"
    var file := FileAccess.open(good, FileAccess.WRITE)
    assert(file != null)
    # Minimal ISO BMFF header for container preflight; not a playable movie.
    file.store_buffer(PackedByteArray([0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109, 0, 0, 0, 0, 105, 115, 111, 109, 109, 112, 52, 50]))
    file.store_buffer(PackedByteArray([0, 0, 0, 8, 109, 100, 97, 116]))
    file.close()
    assert(exporter._verify_mp4_file(good, 30, 30).get("ok", false))
    assert(exporter._verify_mp4_file(good, 29, 30).get("error", "") == "frame_count_incomplete")
    assert(exporter._verify_mp4_file("", 30, 30).get("error", "") == "missing_output_path")
    assert(exporter._verify_mp4_file("user://missing.mp4", 30, 30).get("error", "") == "output_not_readable")
    var bad := "user://mp4_header_bad.mp4"
    var invalid := FileAccess.open(bad, FileAccess.WRITE)
    assert(invalid != null)
    invalid.store_buffer(PackedByteArray([0, 0, 0, 24, 98, 97, 100, 33, 105, 115, 111, 109, 0, 0, 0, 0, 105, 115, 111, 109, 109, 112, 52, 50]))
    invalid.store_buffer(PackedByteArray([0, 0, 0, 8, 109, 100, 97, 116]))
    invalid.close()
    assert(exporter._verify_mp4_file(bad, 30, 30).get("error", "") == "missing_mp4_ftyp")
    print("MP4_OUTPUT_CONTAINER_CHECK_OK")
    quit(0)
