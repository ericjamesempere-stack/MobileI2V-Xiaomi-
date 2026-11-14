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
        _, base, workflow_path, ids = config()
        with open(workflow_path, encoding="utf-8") as stream:
            workflow = json.load(stream)
        prompt_node = os.environ.get("COMFYUI_PROMPT_NODE", "").strip()
        if (not isinstance(workflow, dict) or not prompt_node
                or any(node_id not in workflow for node_id in ids + [prompt_node])
                or workflow[ids[0]].get("class_type") != "LoadImage"
                or workflow[ids[1]].get("class_type") != "LoadImage"
                or workflow[ids[2]].get("class_type") != "SaveImage"
                or workflow[prompt_node].get("class_type") != "CLIPTextEncode"):
            raise ValueError("ComfyUI workflow configuration is incomplete")
        return {"ready": True, "remote_verified": False, "backend": "comfyui",
                "note": "Workflow file and node types present; GPU inference not verified"}
    except (HTTPException, OSError, ValueError, KeyError, json.JSONDecodeError, TypeError):
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
        # Reject disconnected templates: a workflow with unused reference or
        # pose LoadImage nodes could produce an unrelated image while claiming
        # to preserve the user's identity and follow the requested pose.
        def upstream(node_id, visited=None):
            visited = set() if visited is None else visited
            if node_id in visited:
                return visited
            visited.add(node_id)
            inputs = workflow[node_id].get("inputs", {})
            for value in inputs.values():
                if isinstance(value, list) and len(value) == 2 and isinstance(value[0], str):
                    if value[0] in workflow:
                        upstream(value[0], visited)
            return visited
        reachable = upstream(out_id)
        if ref_id not in reachable or pose_id not in reachable:
            raise ValueError("Reference and pose must both feed the output workflow")
        # Mere graph connectivity is insufficient: a template can blend
        # reference and pose as raw pixels while ignoring skeletal guidance.
        # Require an explicit ControlNet node on the output dependency path.
        pose_control_classes = ("ControlNetApply", "ControlNetApplyAdvanced",
                                "ACN_AdvancedControlNetApply", "ApplyControlNet")
        if not any(any(token in str(workflow[node_id].get("class_type", "")) for token in pose_control_classes)
                   for node_id in reachable):
            raise ValueError("A ControlNet pose conditioning node must feed the output")
        # An arbitrary ControlNet node in the output graph is not proof
        # that the actual pose guide reaches it. Check both graph paths.
        def descendants_of(source_id):
            result = {source_id}
            changed = True
            while changed:
                changed = False
                for target_id, node in workflow.items():
                    for value in node.get("inputs", {}).values():
                        if (isinstance(value, list) and len(value) == 2
                                and str(value[0]) in result and target_id not in result):
                            result.add(target_id)
                            changed = True
            return result
        pose_path = descendants_of(pose_id)
        if not any(node_id in pose_path and node_id in reachable
                   and any(token in str(workflow[node_id].get("class_type", "")) for token in pose_control_classes)
                   for node_id in workflow):
            raise ValueError("Pose image must feed the ControlNet conditioning path")
        # Optional temporal-conditioning input. Without this node the model
        # receives the original reference for every frame, not the previous
        # generated frame; do not pretend temporal identity is guaranteed.
        previous_node = os.environ.get("COMFYUI_PREVIOUS_NODE", "").strip()
        if previous_node:
            if previous_node not in reachable or workflow[previous_node].get("class_type") != "LoadImage":
                raise ValueError("COMFYUI_PREVIOUS_NODE must be an upstream LoadImage node")
            if not req.previous_image_base64:
                raise ValueError("Previous generated frame required for temporal conditioning")
        workflow = copy.deepcopy(workflow)
        # Optional CLIPTextEncode node: insert the current story action into
        # the model conditioning instead of repeatedly running a static prompt.
        prompt_node = os.environ.get("COMFYUI_PROMPT_NODE", "").strip()
        if not prompt_node:
            raise ValueError("COMFYUI_PROMPT_NODE is required for story-driven generation")
        if prompt_node not in reachable or workflow[prompt_node].get("class_type") != "CLIPTextEncode":
            raise ValueError("COMFYUI_PROMPT_NODE must be an upstream CLIPTextEncode node")
        workflow[prompt_node]["inputs"]["text"] = (
            "Same person, same face, same hair and outfit as reference image. "
            "Full-body action, pose exactly matching the pose guide. "
            + req.prompt
        )
        workflow[ref_id]["inputs"]["image"] = upload(base, reference, "mobilei2v_ref_" + uuid.uuid4().hex)
        workflow[pose_id]["inputs"]["image"] = upload(base, pose, "mobilei2v_pose_" + uuid.uuid4().hex)
        if previous_node:
            previous = decode(req.previous_image_base64)
            workflow[previous_node]["inputs"]["image"] = upload(base, previous, "mobilei2v_prev_" + uuid.uuid4().hex)
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
