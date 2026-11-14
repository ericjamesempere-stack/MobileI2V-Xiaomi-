"""Optional self-hosted ComfyUI pose + identity bridge for MobileI2V.

Requires a user-provided ComfyUI API workflow containing two LoadImage nodes:
reference and pose. The workflow must ALREADY connect these to compatible
identity conditioning and pose ControlNet. This adapter never claims to create
a capable model from a workflow that lacks these nodes.

Environment:
 MOBILEI2V_API_TOKEN=... (required)
 COMFYUI_URL=http://127.0.0.1:8188 (localhost only)
 COMFYUI_WORKFLOW=/path/to/api_workflow.json
 COMFYUI_REFERENCE_NODE=<LoadImage node ID>
 COMFYUI_POSE_NODE=<LoadImage node ID>
 COMFYUI_OUTPUT_NODE=<SaveImage node ID>
Run behind a private authenticated HTTPS reverse proxy.
"""
import base64
import copy
import hmac
import io
import json
import os
import time
import uuid
from urllib.parse import urlparse
import requests
from fastapi import FastAPI, Header, HTTPException
from PIL import Image
from backend.anypose_bridge import Request, decode

app = FastAPI(title="MobileI2V ComfyUI pose bridge")


def config():
    token = os.environ.get("MOBILEI2V_API_TOKEN", "")
    base = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")
    parsed = urlparse(base)
    if parsed.scheme != "http" or parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise HTTPException(503, "ComfyUI must be bound to localhost")
    workflow_path = os.environ.get("COMFYUI_WORKFLOW", "")
    ids = [os.environ.get("COMFYUI_" + name + "_NODE", "") for name in ("REFERENCE", "POSE", "OUTPUT")]
    if not token or not workflow_path or not all(ids):
        raise HTTPException(503, "ComfyUI pose workflow is not configured")
    return token, base, workflow_path, ids


@app.get("/health")
def health():
    try:
        config()
        return {"ready": True, "remote_verified": False, "backend": "comfyui",
                "note": "Configuration present; no GPU inference has been verified"}
    except HTTPException:
        return {"ready": False, "remote_verified": False, "backend": "comfyui"}


def upload(base, image, prefix):
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    response = requests.post(base + "/upload/image",
        files={"image": (prefix + ".png", buf.getvalue(), "image/png")},
        data={"overwrite": "false"}, timeout=30)
    response.raise_for_status()
    name = response.json().get("name")
    if not isinstance(name, str) or not name:
        raise ValueError("ComfyUI upload did not return a filename")
    return name


@app.post("/generate")
def generate(req: Request, authorization: str | None = Header(default=None)):
    token, base, path, ids = config()
    if not hmac.compare_digest(authorization or "", "Bearer " + token):
        raise HTTPException(401, "Unauthorized")
    if req.frame_index >= req.total_frames:
        raise HTTPException(400, "Frame index out of bounds")
    if abs(req.temporal_position - req.frame_index / max(1, req.total_frames - 1)) > 0.02:
        raise HTTPException(400, "Invalid temporal position")
    reference = decode(req.image_base64)
    pose = decode(req.pose_image_base64)
    try:
        with open(path, encoding="utf-8") as stream:
            workflow = json.load(stream)
        if not isinstance(workflow, dict):
            raise ValueError("Workflow must be an API-format node dictionary")
        ref_id, pose_id, out_id = ids
        for node_id in ids:
            if node_id not in workflow:
                raise ValueError("Missing workflow node")
        if workflow[ref_id].get("class_type") != "LoadImage" or workflow[pose_id].get("class_type") != "LoadImage":
            raise ValueError("Reference and pose nodes must be LoadImage")
        if workflow[out_id].get("class_type") != "SaveImage":
            raise ValueError("Output node must be SaveImage")
        workflow = copy.deepcopy(workflow)
        workflow[ref_id]["inputs"]["image"] = upload(base, reference, "mobilei2v_ref_" + uuid.uuid4().hex)
        workflow[pose_id]["inputs"]["image"] = upload(base, pose, "mobilei2v_pose_" + uuid.uuid4().hex)
        job = requests.post(base + "/prompt", json={"prompt": workflow, "client_id": str(uuid.uuid4())}, timeout=30)
        job.raise_for_status()
        prompt_id = job.json()["prompt_id"]
        deadline = time.monotonic() + 115
        while time.monotonic() < deadline:
            response = requests.get(base + "/history/" + prompt_id, timeout=15)
            response.raise_for_status()
            record = response.json().get(prompt_id)
            if record:
                outputs = record.get("outputs", {}).get(out_id, {}).get("images", [])
                if not outputs:
                    raise ValueError("No generated image from selected SaveImage node")
                image_info = outputs[0]
                output = requests.get(base + "/view", params={
                    "filename": image_info["filename"], "subfolder": image_info.get("subfolder", ""),
                    "type": image_info.get("type", "output")}, timeout=30)
                output.raise_for_status()
                rendered = Image.open(io.BytesIO(output.content))
                rendered.load()
                if rendered.width * rendered.height > 1024 * 1024:
                    raise ValueError("Output too large")
                encoded = io.BytesIO()
                rendered.convert("RGB").save(encoded, format="PNG")
                return {"image_base64": base64.b64encode(encoded.getvalue()).decode(),
                        "frame_index": req.frame_index, "backend": "comfyui"}
            time.sleep(1)
        raise TimeoutError("ComfyUI inference timeout")
    except (requests.RequestException, OSError, ValueError, KeyError, TimeoutError, json.JSONDecodeError):
        raise HTTPException(503, "ComfyUI generation unavailable or workflow invalid",
                            headers={"Retry-After": "30"})
