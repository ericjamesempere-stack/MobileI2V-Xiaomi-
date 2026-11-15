extends Node
class_name OfflineModelInstaller

# Download a user-approved, legally redistributable model to app-private
# storage, verify its SHA-256 and install it atomically. This installs WEIGHTS
# only; it does not install or impersonate the required Android inference plugin.
signal progress(downloaded: int, total: int)
signal completed(result: Dictionary)

var _request: HTTPRequest
var _target := ""
var _temporary := ""
var _expected_hash := ""
var _metadata: Dictionary = {}

func install(url: String, sha256: String, metadata: Dictionary) -> void:
    if _request != null:
        completed.emit({"ok": false, "error": "download_already_running"})
        return
    if not url.begins_with("https://") or sha256.length() != 64 or not sha256.is_valid_hex_number():
        completed.emit({"ok": false, "error": "invalid_url_or_sha256"})
        return
    for field in ["model_name", "license", "backend", "reference_conditioning", "pose_conditioning"]:
        if not metadata.has(field):
            completed.emit({"ok": false, "error": "missing_metadata", "field": field})
            return
    if not bool(metadata["reference_conditioning"]) or not bool(metadata["pose_conditioning"]):
        completed.emit({"ok": false, "error": "model_missing_required_conditioning"})
        return
    var directory := "user://pose_model"
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
        completed.emit({"ok": false, "error": "storage_unavailable"})
        return
    _target = directory + "/model.bin"
    _temporary = directory + "/model.part"
    _expected_hash = sha256.to_lower()
    _metadata = metadata.duplicate(true)
    if FileAccess.file_exists(_temporary):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(_temporary))
    _request = HTTPRequest.new()
    add_child(_request)
    _request.download_file = ProjectSettings.globalize_path(_temporary)
    _request.request_completed.connect(_finished)
    var error := _request.request(url)
    if error != OK:
        _cleanup()
        completed.emit({"ok": false, "error": "download_start_failed", "code": error})

func _process(_delta: float) -> void:
    if _request != null:
        progress.emit(_request.get_downloaded_bytes(), _request.get_body_size())

func _finished(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        _cleanup()
        completed.emit({"ok": false, "error": "download_failed", "http_status": response_code})
        return
    var digest := FileAccess.get_sha256(_temporary).to_lower()
    if digest != _expected_hash:
        _cleanup()
        completed.emit({"ok": false, "error": "sha256_mismatch"})
        return
    var source := ProjectSettings.globalize_path(_temporary)
    var destination := ProjectSettings.globalize_path(_target)
    if FileAccess.file_exists(_target):
        DirAccess.remove_absolute(destination)
    var moved := DirAccess.rename_absolute(source, destination)
    if moved != OK:
        _cleanup()
        completed.emit({"ok": false, "error": "model_install_failed"})
        return
    var manifest := _metadata.duplicate(true)
    manifest["model_path"] = _target
    manifest["sha256"] = _expected_hash
    var manifest_path := "user://pose_model/manifest.json"
    var file := FileAccess.open(manifest_path, FileAccess.WRITE)
    if file == null:
        _cleanup()
        completed.emit({"ok": false, "error": "manifest_write_failed"})
        return
    file.store_string(JSON.stringify(manifest, "  "))
    file.close()
    _cleanup()
    completed.emit({"ok": true, "model_path": _target, "inference_verified": false})

func _cleanup() -> void:
    if _request != null:
        _request.queue_free()
        _request = null
    if FileAccess.file_exists(_temporary):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(_temporary))
