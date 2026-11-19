#!/usr/bin/env python3
"""Stage verified KARMA MNN ARM64 libraries into an extracted Godot Android Gradle template.

No APK is built. Java/JNI registration is a separate gate; do not mark the
native bridge operational just because its shared objects are packaged.
"""
import argparse
import hashlib
import shutil
from pathlib import Path

LIBRARIES = ("libMNN.so", "libllm.so", "libkarma_mnn.so")
ELF_AARCH64 = b"\x7fELF\x02\x01\x01"
AARCH64_MACHINE = b"\xb7\x00"


def stage(artifact: Path, android_build: Path):
    sums = {}
    for line in (artifact / "SHA256SUMS").read_text().splitlines():
        digest, filename = line.split(maxsplit=1)
        sums[Path(filename.lstrip("*")).name] = digest
    for name in LIBRARIES:
        src = artifact / name
        data = src.read_bytes()
        if len(data) < 64 or not data.startswith(ELF_AARCH64) or data[18:20] != AARCH64_MACHINE:
            raise ValueError(f"Invalid Android AArch64 ELF: {name}")
        if hashlib.sha256(data).hexdigest() != sums.get(name):
            raise ValueError(f"SHA256 mismatch: {name}")
    if not (android_build / "build.gradle").is_file():
        raise ValueError("Expected extracted Godot Android Gradle template")
    dest = android_build / "src" / "main" / "jniLibs" / "arm64-v8a"
    dest.mkdir(parents=True, exist_ok=True)
    for name in LIBRARIES:
        shutil.copyfile(artifact / name, dest / name)
        if hashlib.sha256((dest / name).read_bytes()).hexdigest() != sums[name]:
            raise ValueError(f"Staged file mismatch: {name}")
    print("KARMA_MNN_ARM64_LIBRARIES_STAGED_OK", dest)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("android_build", type=Path)
    args = parser.parse_args()
    stage(args.artifact, args.android_build)
