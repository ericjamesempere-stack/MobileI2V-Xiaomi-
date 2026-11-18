#!/usr/bin/env python3
"""Read-only public Gradio capability probe; never sends user images or credentials."""
import json
import urllib.request
from urllib.error import HTTPError, URLError

SERVICES = {
    "qwen3_vl": "https://qwen-qwen3-vl-demo.hf.space",
    "smolvlm2": "https://huggingfacetb-smolvlm2.hf.space",
    "qwen_vl": "https://artificialguybr-qwen-vl.hf.space",
    "minicpm_v": "https://openbmb-minicpm-v-4-5-demo.hf.space",
}
results = []
for name, base in SERVICES.items():
    record = {"name": name, "base": base, "verified": False, "api": None, "error": None}
    for suffix in ("/gradio_api/info", "/info"):
        try:
            req = urllib.request.Request(base + suffix, headers={"User-Agent": "KarmaOne-VisionProbe/1.0"})
            with urllib.request.urlopen(req, timeout=15) as response:
                data = json.loads(response.read(500000).decode("utf-8"))
            endpoints = data.get("named_endpoints", {}) if isinstance(data, dict) else {}
            record["api"] = sorted(endpoints.keys())
            record["schemas"] = {key: {"parameters": [{"name": p.get("parameter_name"), "python_type": p.get("python_type", {}).get("type"), "component": p.get("component")} for p in value.get("parameters", [])], "returns": [{"python_type": p.get("python_type", {}).get("type"), "component": p.get("component")} for p in value.get("returns", [])]} for key, value in endpoints.items() if key in ("/add_message", "/chat", "/run_vl", "/handle_submit")}
            record["verified"] = bool(endpoints)
            record["info_path"] = suffix
            break
        except (HTTPError, URLError, TimeoutError, ValueError, OSError) as exc:
            record["error"] = str(exc)[:250]
    results.append(record)
print(json.dumps(results, ensure_ascii=False, indent=2))
with open("vision_service_probe.json", "w", encoding="utf-8") as output:
    json.dump(results, output, ensure_ascii=False, indent=2)
