#!/usr/bin/env python3
"""Experimental pinned-MNN CLIP end-of-word BPE patch. Fail closed if upstream changes."""
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_mnn_clip_eow_experiment.py /path/to/tokenizer.cpp")
path = Path(sys.argv[1])
source = path.read_text()
needle = """        while (out.size() > 1) {
            int best = -1, min_r = (int)1e9;"""
replacement = """        // CLIP byte-level BPE uses </w> on the final initial symbol.
        // Restrict this experiment to vocabularies with a matching EOW token.
        if (!out.empty()) {
            std::string final_symbol = id_to_token(out.back()) + "</w>";
            int final_id = token_to_id(final_symbol);
            if (final_id >= 0) out.back() = final_id;
        }
        while (out.size() > 1) {
            int best = -1, min_r = (int)1e9;"""
if source.count(needle) != 1:
    raise SystemExit("KARMA_MNN_EOW_PATCH_CONTEXT_MISMATCH")
path.write_text(source.replace(needle, replacement))
print("KARMA_MNN_EOW_EXPERIMENT_PATCH_APPLIED")
