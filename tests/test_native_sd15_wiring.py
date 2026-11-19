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
