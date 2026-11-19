#!/usr/bin/env python3
"""Read-only diagnostic for pinned CLIP-vs-MNN tokenizer ID mismatches.

Does not replace expected IDs or alter the native runtime. The strict parity
check in validate-sd15-mtok-parity.yml remains the release gate.
"""
import json
import sys
from pathlib import Path


def main(tokenizer_dir, actual_csv, reference_json):
    root = Path(tokenizer_dir)
    vocab = json.loads((root / "vocab.json").read_text(encoding="utf-8"))
    merges = (root / "merges.txt").read_text(encoding="utf-8").splitlines()
    config = json.loads((root / "tokenizer_config.json").read_text(encoding="utf-8"))
    expected = json.loads(Path(reference_json).read_text(encoding="utf-8"))["vectors"]
    actual = [
        [int(part) for part in line.split(",")]
        for line in Path(actual_csv).read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if len(expected) != len(actual):
        raise ValueError("reference and native case counts differ")
    reverse_vocab = {int(index): token for token, index in vocab.items()}
    print("KARMA_CLIP_DIAGNOSTIC vocab_size=", len(vocab),
          "merges=", len(merges),
          "bos=", config.get("bos_token"), "eos=", config.get("eos_token"))
    differences = 0
    for (prompt, want), got in zip(expected.items(), actual):
        if len(want) != 77 or len(got) != 77:
            raise ValueError("CLIP case does not contain exactly 77 IDs")
        mismatches = [(i, a, b) for i, (a, b) in enumerate(zip(got, want)) if a != b]
        differences += len(mismatches)
        print("KARMA_CLIP_DIAGNOSTIC_CASE prompt=", repr(prompt[:100]),
              "differences=", len(mismatches))
        for position, native_id, official_id in mismatches[:12]:
            print("KARMA_CLIP_DIAGNOSTIC_DIFF", "position=", position,
                  "native_id=", native_id,
                  "native_vocab=", repr(reverse_vocab.get(native_id, "<missing>")),
                  "official_id=", official_id,
                  "official_vocab=", repr(reverse_vocab.get(official_id, "<missing>")))
    print("KARMA_CLIP_DIAGNOSTIC_TOTAL differences=", differences)
    print("KARMA_CLIP_DIAGNOSTIC_NOTE token labels reveal symptoms, not the first divergent stage")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: diagnose_clip_mtok.py TOKENIZER_DIR ACTUAL_CSV REFERENCE_JSON")
    main(*sys.argv[1:])
