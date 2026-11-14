#!/usr/bin/env python3
"""Inspect public AnyPose Gradio parameter defaults and API routes. No image uploads."""
import json
from urllib.request import Request, urlopen

URL = "https://abidlabs-qwen-image-edit-2511-anypose.hf.space/config"
with urlopen(Request(URL, headers={"User-Agent": "MobileI2V-api-inspector/1.0"}), timeout=35) as response:
    config = json.load(response)
components = {item.get("id"): item for item in config.get("components", [])}
for dependency in config.get("dependencies", []):
    if dependency.get("api_name") != "infer":
        continue
    print("API:", dependency.get("api_name"))
    for idx, component_id in enumerate(dependency.get("inputs", [])):
        item = components.get(component_id, {})
        props = item.get("props", {})
        safe = {k: props.get(k) for k in ("label", "value", "minimum", "maximum", "step", "type", "sources") if k in props}
        print(f"INPUT {idx}: {item.get('type')} {json.dumps(safe, ensure_ascii=False)}")
    for idx, component_id in enumerate(dependency.get("outputs", [])):
        item = components.get(component_id, {})
        print(f"OUTPUT {idx}: {item.get('type')} {item.get('props', {}).get('label', '')}")
    break
else:
    raise SystemExit("AnyPose infer API missing")
