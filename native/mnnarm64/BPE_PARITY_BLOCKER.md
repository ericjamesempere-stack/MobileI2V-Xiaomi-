# SD1.5 CLIP BPE parity blocker — verified 2026-11-19

## Verified evidence

- Pinned original SD1.5 model revision: `451f4fe16113bff5a5d2269ed5ad43b0592e9a14`.
- Pinned MNN revision: `40ad7e340cdf5cb29fe9d5f1f9eec794adbaef6d`.
- Reference vectors: GitHub Actions run `44445594311`, five cases, 77 IDs each, successful.
- Real `tokenizer.mtok` parity run `44451341140`: **FAILED** with 95/385 differing positions.
- Empty prompt: 0 differences.
- `a red apple`: 3 differences; actual [49406,64,1893,8629,49407], expected [49406,320,736,3055,49407].
- French accented: 10 differences; punctuation and accents: 7; long prompt: 75.

## Confirmed provenance

The pinned MNN `transformers/diffusion/export/convert_mnn.py` exports `tokenizer.mtok` by invoking `LlmTokenizer(..., model_type='clip').export(...)` from `transformers/llm/export/utils/tokenizer.py`. It is **not** proof that the exported native tokenizer produces the same IDs as Hugging Face CLIPTokenizer.

The Android JNI `nativeTokenizeClip` currently uses `MNN::Transformer::Tokenizer::createTokenizer(path)->encode(text)` and normalizes BOS/EOS/padding. The host parity probe reproduces that same normalization.

## Release gate

**Do not declare text-to-image validated or build a final APK while parity fails.**
The mismatch must be corrected in the actual runtime tokenizer path, not hidden by changing reference vectors or suppressing test failures.

## Next controlled investigation

1. Compare `tokenizer.json` from pinned HF CLIP with the tokenizer metadata serialized into `tokenizer.mtok` (pre-tokenizer, byte-level BPE, merges, post-processor, special tokens).
2. Determine whether the error is in MNN export or native `PipelineTokenizer` interpretation.
3. Correct the smallest responsible component, retaining all three already-tested MNN graphs.
4. Re-run strict 385-token parity and then expand coverage before full DDIM/PNG integration.

This file records observed evidence, not a claimed fix.
