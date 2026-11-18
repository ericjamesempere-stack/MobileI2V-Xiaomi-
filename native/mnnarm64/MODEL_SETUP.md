# Real Stable Diffusion 1.5 weights for KARMA ONE

Status: **not downloaded, not converted, not installed, not tested on phone**.

Official MNN Diffusion instructions:
https://github.com/alibaba/MNN/tree/master/transformers/diffusion
https://mnn-docs.readthedocs.io/en/latest/transformers/diffusion.html

Original SD1.5 checkpoint: https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5
Check the model license and access conditions before downloading.

## Offline conversion on a capable PC / CI runner

Use MNN's own `transformers/diffusion/export/onnx_export.py` and
`convert_mnn.py` scripts with the same pinned MNN revision used for the
runtime; inspect their `--help` and dependencies before executing. Official
documentation shows:

```sh
python onnx_export.py --model_path /path/to/stable-diffusion-v1-5 --output_path /path/to/onnx --opset 18
python3 convert_mnn.py /path/to/onnx /path/to/models/sd15 "--weightQuantBits=8"
```

Conversion requires substantial disk/RAM and real checkpoint files. Do not
download multi-GB weights into Git or attach them to a routine APK build.

## Expected runtime resources

```
models/sd15/
  tokenizer.mtok
  text_encoder.mnn
  unet.mnn
  vae_decoder.mnn
```

Verify local files and SHA256:
```sh
python3 tools/mnn_sd_model_manifest.py --model-dir /path/to/models/sd15
```

This verifies integrity of the actual local files, NOT whether the models
are runnable, correctly licensed, have matching tensor names, or generate images.

## Known integration gaps

- The existing native library builds with MNN_BUILD_DIFFUSION=OFF and
  MNN_BUILD_LLM=OFF. Official tokenizer.mtok support requires MNN_BUILD_LLM=ON.
- The standalone KarmaSdInference Java loop requires actual CLIP embeddings
  supplied externally. It does not yet run tokenizer.mtok or text_encoder.mnn.
- MNN converted graphs may use different tensor names and dimensions. Inspect
  model metadata and verify before enabling the loop.
- Test RAM, thermals, execution time and PNG output on Xiaomi 14T Pro before
  declaring successful local text-to-image generation.
- Do not claim that this repository contains actual converted SD weights.
