extends RefCounted
# Explicitly checks whether a native offline diffusion installation is actually present.
# A loopback API or a model name alone is NOT an embedded Android runtime.
const REQUIRED_COMPONENTS := ["tokenizer", "text_encoder", "unet", "vae_decoder"]
const MAX_MANIFEST_BYTES := 65536

func inspect_embedded_model(manifest_path: String = "user://models/sd15/manifest.json") -> Dictionary:
    if not FileAccess.file_exists(manifest_path):
        return {"ok": false, "embedded": false, "reason": "model_manifest_missing", "missing": REQUIRED_COMPONENTS.duplicate()}
    var manifest_text: String = FileAccess.get_file_as_string(manifest_path)
    if manifest_text.to_utf8_buffer().size() > MAX_MANIFEST_BYTES:
        return {"ok": false, "embedded": false, "reason": "manifest_too_large"}
    var parsed: Variant = JSON.parse_string(manifest_text)
    if not parsed is Dictionary or not parsed.get("components") is Dictionary:
        return {"ok": false, "embedded": false, "reason": "invalid_model_manifest"}
    var missing: Array[String] = []
    var invalid: Array[String] = []
    var model_dir: String = manifest_path.get_base_dir()
    var files: Dictionary = parsed["components"]
    for name in REQUIRED_COMPONENTS:
        var spec: Variant = files.get(name)
        if not spec is Dictionary:
            missing.append(name)
            continue
        var filename: String = str(spec.get("file", ""))
        var expected_sha: String = str(spec.get("sha256", "")).to_lower()
        if filename.is_empty() or filename.contains("/") or filename.contains("\\") or filename.begins_with(".") or expected_sha.length() != 64 or not expected_sha.is_valid_hex_number():
            invalid.append(name)
            continue
        var path: String = model_dir.path_join(filename)
        if not FileAccess.file_exists(path):
            missing.append(name)
            continue
        var actual_sha: String = FileAccess.get_sha256(path).to_lower()
        if actual_sha != expected_sha:
            invalid.append(name)
    var verified: bool = missing.is_empty() and invalid.is_empty()
    return {"ok": verified, "embedded": verified, "weights_verified": verified, "native_runtime_verified": false, "inference_verified": false, "missing": missing, "invalid": invalid, "reason": "native_runtime_not_verified" if verified else "model_files_missing_or_invalid"}
