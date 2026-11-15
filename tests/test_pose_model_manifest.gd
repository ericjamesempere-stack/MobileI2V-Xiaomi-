extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var validator = load("res://scripts/PoseModelManifest.gd")
    var folder := "user://pose_model_manifest_test"
    assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
    var path := folder + "/manifest.json"
    var absent: Dictionary = validator.inspect(path)
    assert(absent.get("error") == "manifest_missing")
    var weights := folder + "/weights.onnx"
    var file := FileAccess.open(weights, FileAccess.WRITE)
    assert(file != null)
    file.store_8(1)
    file.close()
    var manifest := {
        "model_name": "test_only",
        "model_path": weights,
        "license": "test",
        "backend": "onnxruntime",
        "reference_conditioning": true,
        "pose_conditioning": true
    }
    var output := FileAccess.open(path, FileAccess.WRITE)
    assert(output != null)
    output.store_string(JSON.stringify(manifest))
    output.close()
    var accepted: Dictionary = validator.inspect(path)
    assert(accepted.get("ok", false), str(accepted))
    assert(not accepted["inference_verified"])
    manifest["pose_conditioning"] = false
    output = FileAccess.open(path, FileAccess.WRITE)
    output.store_string(JSON.stringify(manifest))
    output.close()
    var rejected: Dictionary = validator.inspect(path)
    assert(rejected.get("error") == "model_lacks_required_conditioning")
    print("MOBILEI2V_POSE_MODEL_MANIFEST_OK")
    quit(0)
