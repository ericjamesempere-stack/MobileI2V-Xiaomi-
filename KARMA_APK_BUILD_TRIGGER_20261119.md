# KARMA ONE — controlled APK build

Validated source before this build: `32ef7fedda2060a76bae4f18beb0aba3c7012f35`.

- Native SD15 wiring and Android plugin compilation: passed in GitHub Actions run `44618513829`.
- Godot script parsing and navigation validations: passed on `90e87208` in run `44618498941`.
- Real MNN ARM64 native libraries artifact: present, unexpired in run `44459460832`.
- Preserved SD15 models archive: present in run `44534183813`; not bundled inside the APK.
- On-device inference and archive installation are **not yet verified**.

This is a controlled build request, not a claim of working on-device inference.
