#!/usr/bin/env bash
# Converts real locally available HF SD1.5 weights via the pinned official MNN tools.
# Requires Python dependencies, a compiled MNNConvert, ample disk/RAM.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo "Usage: $0 /path/to/MNN /path/to/HF-SD1.5 /path/to/onnx /path/to/output-mnn" >&2
  exit 2
fi
MNN="$(realpath "$1")"
MODEL="$(realpath "$2")"
ONNX="$(realpath -m "$3")"
OUTPUT="$(realpath -m "$4")"
test -f "$MODEL/model_index.json" || { echo "Missing genuine diffusers model_index.json" >&2; exit 1; }
test -f "$MNN/transformers/diffusion/export/onnx_export.py"
test -f "$MNN/transformers/diffusion/export/convert_mnn.py"
test -x "$MNN/build/MNNConvert" || { echo "Build MNNConvert in MNN/build first" >&2; exit 1; }
mkdir -p "$ONNX" "$OUTPUT"
cd "$MNN/transformers/diffusion/export"
python3 onnx_export.py --model_path "$MODEL" --output_path "$ONNX" --opset 18
for graph in text_encoder unet vae_decoder; do
  test -s "$ONNX/$graph/model.onnx" || { echo "Missing real ONNX graph: $graph" >&2; exit 1; }
done
python3 convert_mnn.py "$ONNX" "$OUTPUT" "--weightQuantBits=8"
for graph in text_encoder unet vae_decoder; do
  test -s "$OUTPUT/$graph.mnn" || { echo "MNN conversion failed: $graph" >&2; exit 1; }
done
cd - >/dev/null
python3 "$(dirname "$0")/verify_mnn_sd_export.py" --model-dir "$OUTPUT"
echo KARMA_SD_REAL_CONVERSION_FILES_OK
