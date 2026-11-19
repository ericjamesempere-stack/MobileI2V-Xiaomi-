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
assert 'native.has_method("native_sd15_readiness")' in local
assert 'report["embedded_sd15"] = native_status' in local
assert '"inference_verified": false' in local
assert 'generatePrompt(' in sd and 'KarmaClipEncoder.encodePrompt(' in sd
assert 'KarmaMnnBridge.runGraph()' in sd
assert 'nativeTokenizeClip' in bridge and 'last_hidden_state' in clip
assert 'KarmaSdInference' in build and 'KarmaMnnBridge' in build
print('NATIVE_SD15_WIRING_STATIC_OK: native readiness, model files, CLIP-to-PNG code, fail-closed inference status')
