extends SceneTree

func _initialize() -> void:
    var passed := true
    # The headless CI environment has no Android singleton; export must
    # fail explicitly rather than pretending that a PNG sequence is an MP4.
    if AndroidSequenceMp4.available():
        push_error("Unexpected MP4Exporter singleton in headless test")
        passed = false
    var result := await AndroidSequenceMp4.encode([], "user://test.mp4", 12)
    if result.get("ok", false) or result.get("error", "") != "android_mp4_plugin_not_installed":
        push_error("Missing native plugin must fail explicitly: " + str(result))
        passed = false
    if passed:
        print("AndroidSequenceMp4 missing-plugin contract: PASS")
    quit(0 if passed else 1)
