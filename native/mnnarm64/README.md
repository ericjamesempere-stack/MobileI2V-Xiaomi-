# KARMA ONE — Android ARM64 MNN native graph bridge

This is **real MNN C++ graph execution** via Android JNI, not a simulated image generator.
It does not yet generate Stable Diffusion images: that additionally requires converted,
licensed SD model weights, tokenizer, text encoder, diffusion sampler, scheduler, and VAE
decode with validated tensor input/output. Do not report this bridge as a completed image generator.

## Build prerequisites
- Android NDK with CMake 3.22.1 or newer
- A real MNN Android ARM64 SDK: `prebuilt/include/MNN/Interpreter.hpp`,
  `prebuilt/include/MNN/Tensor.hpp` and `prebuilt/lib/arm64-v8a/libMNN.so`
- Model weights must be obtained from an authorized source, verified and converted
  to MNN format. They are not in this repository.

Example build:
```sh
cmake -S native/mnnarm64 -B /tmp/karma-mnn-build \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/karma-mnn-build --parallel 2
```

The Java bridge is provided as source and must be packaged into the Android
plugin alongside both `libMNN.so` and `libkarma_mnn.so` for arm64-v8a.
The existing Godot Android plugin remains unchanged until verified.

### Acceptance gates
1. MNN SDK source/version/license and SHA256 recorded
2. Native build succeeds on CI with actual headers and arm64 binaries
3. Android JNI loads, executes and releases a real graph
4. Converted SD weights and tokenizer/scheduler/decoder connected
5. One actual on-device image with time/RAM/thermal log and PNG proof

No benchmark on the Xiaomi 14T Pro has been performed.
