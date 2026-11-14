#!/usr/bin/env python3
"""Read-only probe for the public AnyPose Gradio API. No image upload or GPU use.

Usage:
  python -m pip install gradio_client
  python tools/probe_anypose_api.py

Optional HF_TOKEN environment variable; never print or commit it.
"""
import json
import os
import sys

SPACE = "abidlabs/Qwen-Image-Edit-2511-AnyPose"


def inspect(client_factory):
    client = client_factory(SPACE, token=os.getenv("HF_TOKEN") or None)
    return client.view_api(return_format="dict")


def main():
    try:
        from gradio_client import Client
    except ImportError:
        print("Install gradio_client first: python -m pip install gradio_client", file=sys.stderr)
        return 2
    try:
        schema = inspect(Client)
    except Exception as exc:
        print(f"Space API unavailable: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(schema, indent=2, ensure_ascii=False, default=str))
    print("\nRead-only inspection complete. No images submitted or GPU quota used.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
