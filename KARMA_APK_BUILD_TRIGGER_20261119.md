# KARMA ONE — controlled APK build

Validated source before this build: `32ef7fedda2060a76bae4f18beb0aba3c7012f35`.

- Native SD15 wiring and Android plugin compilation: passed in GitHub Actions run `44618513829`.
- Godot script parsing and navigation validations: passed on `90e87208` in run `44618498941`.
- Real MNN ARM64 native libraries artifact: present, unexpired in run `44459460832`.
- Preserved SD15 models archive: present in run `44534183813`; not bundled inside the APK.
- On-device inference and archive installation are **not yet verified**.

This is a controlled build request, not a claim of working on-device inference.

## Build request 2026-11-20

User authorized a single ARM64 APK build with the published public SD15 models,
verified SHA256 catalog, resumable Wi-Fi download, and automatic provisioning.
The release assets are public and static wiring tests passed at `2cf7c365`.
On-device inference remains unverified until installation and test.

## Build request after SD15 downloader fixes

Validated commit: `38acfde30fc908c22cb3ddad9db63b0e88c01e2d`.
Static native wiring and Godot validation passed in workflows `44645012667` and `44645012689`.
This build includes resumable SHA-256 verified public models provisioning, corrupt-file recovery, Wi-Fi retry, and HTTP Content-Range validation. The APK must be tested on Xiaomi 14T Pro; model inference is not yet confirmed.
