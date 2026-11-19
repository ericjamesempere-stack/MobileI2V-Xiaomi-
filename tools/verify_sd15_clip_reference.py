#!/usr/bin/env python3
"""Generate deterministic CLIP token reference vectors from the pinned SD1.5 tokenizer.
This does not assert MNN .mtok parity; a separate runtime test must compare IDs.
"""
import json
import sys
from pathlib import Path
from transformers import CLIPTokenizer

def main(root):
    tok = CLIPTokenizer.from_pretrained(str(root), local_files_only=True)
    prompts = ["", "a red apple", "Un été à Nice, très lumineux",
               "Moto, liberté et café !", "hello " * 120]
    vectors = {}
    for prompt in prompts:
        ids = tok(prompt, padding="max_length", truncation=True, max_length=77,
                  return_attention_mask=False)["input_ids"]
        if len(ids) != 77 or ids[0] != 49406 or 49407 not in ids:
            raise AssertionError("invalid official CLIP reference sequence")
        vectors[prompt] = ids
    out = Path("clip_reference_vectors.json")
    out.write_text(json.dumps({"source": "pinned SD1.5 CLIPTokenizer",
                               "vectors": vectors}, ensure_ascii=False, indent=2)+"\n")
    print("KARMA_CLIP_OFFICIAL_REFERENCE_VECTORS_OK", len(vectors))
if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: verify_sd15_clip_reference.py /path/to/tokenizer")
    main(sys.argv[1])
