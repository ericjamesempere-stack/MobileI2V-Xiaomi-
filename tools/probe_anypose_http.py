#!/usr/bin/env python3
"""Check AnyPose public Gradio config; no user photos, GPU calls or credentials."""
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

URL = "https://abidlabs-qwen-image-edit-2511-anypose.hf.space/config"


def main():
    try:
        req = Request(URL, headers={"User-Agent": "MobileI2V-readonly-api-probe/1.0"})
        with urlopen(req, timeout=35) as response:
            config = json.load(response)
    except (HTTPError, URLError, TimeoutError, ValueError) as exc:
        print(f"AnyPose unavailable or config inaccessible: {type(exc).__name__}: {exc}")
        return 1
    components = {item.get("id"): item for item in config.get("components", [])}
    print("Space:", URL)
    print("Gradio version:", config.get("version", "unknown"))
    found = 0
    for key, dependency in enumerate(config.get("dependencies", [])):
        if not dependency.get("backend_fn"):
            continue
        api = dependency.get("api_name")
        inputs = [components.get(i, {}).get("type", "unknown") for i in dependency.get("inputs", [])]
        outputs = [components.get(i, {}).get("type", "unknown") for i in dependency.get("outputs", [])]
        print(f"Endpoint {key}: api={api!r}; input_types={inputs}; output_types={outputs}")
        found += 1
    if not found:
        print("No callable backend endpoints found; do not integrate blindly.")
        return 2
    print("Read-only inspection complete. No images submitted.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
