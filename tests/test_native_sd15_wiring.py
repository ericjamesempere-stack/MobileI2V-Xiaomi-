"""Fail-closed wiring checks. Static only: no device/model inference claims."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
java=(ROOT/'native/mp4exporter/src/main/java/com/mobilei2v/encoder/MP4Exporter.java').read_text()
local=(ROOT/'scripts/local_studio_generator.gd').read_text()
bridge=(ROOT/'native/mnnarm64/src/KarmaMnnBridge.java').read_text()
clip=(ROOT/'native/mnnarm64/src/KarmaClipEncoder.java').read_text()
sd=(ROOT/'native/mnnarm64/src/KarmaSdInference.java').read_text()
build=(ROOT/'.github/workflows/build-apk.yml').read_text()

assert '@UsedByGodot public String native_sd15_readiness()' in java
assert 'com.mobilei2v.mnn.KarmaMnnBridge.isAvailable()' in java
assert 'new File(getContext().getFilesDir(), "models/sd15")' in java
for name in ('tokenizer.mtok','text_encoder.mnn','unet.mnn','vae_decoder.mnn'):
    assert name in java
assert 'report.put("inference_verified", false)' in java
assert 'report.put("ok", librariesLoaded && filesPresent)' in java
assert 'native.has_java_method("native_sd15_readiness")' in local
assert 'report["embedded_sd15"] = native_status' in local
assert '"inference_verified": false' in local
assert 'generatePrompt(' in sd and 'KarmaClipEncoder.encodePrompt(' in sd
assert 'KarmaMnnBridge.runGraph()' in sd
assert 'nativeTokenizeClip' in bridge and 'last_hidden_state' in clip
assert 'KarmaSdInference' in build and 'KarmaMnnBridge' in build
print('NATIVE_SD15_WIRING_STATIC_OK: native readiness, model files, CLIP-to-PNG code, fail-closed inference status')

# End-to-end static routing: main Create button -> worker -> Android JNI bridge.
board=(ROOT/'scripts/storyboard.gd').read_text()
assert 'var native_t2i: bool' in board
assert 'or native_t2i' in board
assert 'await worker.create_reference(description, _selected_drawing_style())' in board
assert 'func create_reference(description: String, style: String)' in local
assert 'await verify_native_sd15(prompt, "watermark, text, unwanted people")' in local
assert 'start_native_sd15(String prompt, String negativePrompt)' in java
assert 'KarmaSdInference.generatePrompt(cfg,' in java
assert 'new Thread(() -> {' in java
assert 'native_sd15_job_status()' in java
print('NATIVE_SD15_CREATE_BUTTON_STATIC_ROUTE_OK')

# Regression for GitHub Actions run 44522942556: the Android plugin AAR must
# compile the real MNN Java classes, not just stage them for the final APK.
gradle=(ROOT/'native/mp4exporter/build.gradle').read_text()
assert "main.java.srcDirs += ['../mnnarm64/src']" in gradle
for source in ('KarmaMnnBridge.java', 'KarmaClipEncoder.java', 'KarmaSdInference.java'):
    assert (ROOT/'native/mnnarm64/src'/source).is_file()
print('NATIVE_SD15_PLUGIN_JAVA_SOURCESET_OK')

# Model archive import must be private, user-initiated, and compile with the plugin.
installer=(ROOT/'native/mp4exporter/src/main/java/com/mobilei2v/encoder/Sd15ModelImportActivity.java').read_text()
plugin=(ROOT/'native/mp4exporter/src/main/java/com/mobilei2v/encoder/MP4Exporter.java').read_text()
manifest=(ROOT/'native/mp4exporter/src/main/AndroidManifest.xml').read_text()
assert 'ACTION_OPEN_DOCUMENT' in installer and 'ZipInputStream' in installer
assert 'missing_model_files' in installer and 'model_size_limit' in installer
assert 'pick_sd15_model_archive' in plugin and 'sd15_model_import_status' in plugin
assert 'Sd15ModelImportActivity' in manifest and 'android:exported="false"' in manifest
print('SD15_USER_SELECTED_ARCHIVE_IMPORT_WIRING_OK')

# Startup engine detection must not require the user to browse a ZIP archive.
ui=(ROOT/'scripts/studio_friendly_ui.gd').read_text()
assert 'call_deferred("_detect_sd15_engine")' in board
assert 'func _detect_sd15_engine() -> void:' in board
assert 'native.call("native_sd15_readiness")' in board
assert 'board._detect_sd15_engine' in ui
assert 'Installer les modèles IA (ZIP)' not in ui
assert 'RefreshSd15Engine' in ui
assert 'Modèles locaux absents : téléchargement vérifié en Wi-Fi demandé.' in board
assert 'auto_state in ["error", "waiting_wifi"]' in board
assert 'diagnostic non renseigné' in board
assert 'func _probe_sd15_fallbacks() -> void:' in board
assert 'await worker.inspect_local_engines(true, true)' in board
print('SD15_STARTUP_AUTO_DETECTION_UI_OK: verified public provisioning and visible failure states')

# Genuine MNN exports may have external .weight tensors; do not report ready
# or attempt inference with an incomplete converted graph.
assert 'OPTIONAL_WEIGHTS' in installer
assert 'missing_external_weights_' in installer
assert 'graph + ".weight"' in installer
assert 'sd15_external_weights_missing' in java
assert 'components.put(graph + ".weight"' in java
print('SD15_EXTERNAL_MNN_WEIGHTS_GUARD_OK')

# Public distribution requires no login, resumes only on a valid byte range,
# verifies SHA256 before atomic activation, and waits for unmetered network.
provision=(ROOT/'native/mp4exporter/src/main/java/com/mobilei2v/encoder/Sd15AutoProvision.java').read_text()
publish=(ROOT/'.github/workflows/publish-sd15-public-models.yml').read_text()
assert 'releases/download/karma-sd15-mnn-v1/' in provision
assert 'NET_CAPABILITY_NOT_METERED' in provision
assert 'Content-Range' in provision and 'Range' in provision
assert 'sha256_mismatch_' in provision and 'renameTo(target)' in provision
assert 'start_sd15_auto_provision()' in java and 'sd15_auto_provision_status()' in java
assert 'native.call("start_sd15_auto_provision")' in board
assert 'gh release create' in publish and 'catalog.json' in publish
print('SD15_PUBLIC_RESUMABLE_VERIFIED_DISTRIBUTION_STATIC_OK')

# Immutable public catalog must be authenticated independently of the files it lists.
assert 'CATALOG_SHA256 = "1d62ee46d72b02761c50e403fc66fc3a5d9ba83420155da8c43e1d2a9b64ed3e"' in provision
assert 'catalog_integrity_mismatch' in provision
assert 'getUsableSpace()' in provision
assert 'insufficient_storage_' in provision
print('SD15_PUBLIC_CATALOG_PIN_AND_STORAGE_GUARD_OK')
