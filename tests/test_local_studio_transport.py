"""Exercise production Godot local adapters against a loopback HTTP fixture.
No model, remote service or GPU is used. Fixtures are not inference evidence.
"""
import base64
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]

def main():
    counts = {"models": 0, "analysis": 0, "review": 0, "generate": 0}
    scene = json.loads((ROOT / "tests/fixtures/universal_a_annotation.json").read_text())
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass
        def send(self, value, sse=False):
            body = ("event: complete\ndata: " + json.dumps(value) + "\n\n" if sse else json.dumps(value)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream" if sse else "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def do_GET(self):
            assert self.path == "/v1/models"
            assert self.headers.get("Authorization") == "Bearer test-local-secret"
            counts["models"] += 1
            self.send({"data": [{"id": "SIMULATED-vision-model"}]})
        def do_POST(self):
            data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            if self.path == "/v1/chat/completions":
                assert self.headers.get("Authorization") == "Bearer test-local-secret"
                assert data["model"] == "SIMULATED-vision-model" and not data["stream"]
                content = data["messages"][0]["content"]
                for item in content[1:]:
                    assert item["image_url"]["url"].startswith("data:image/png;base64,")
                prompt = content[0]["text"]
                if prompt.startswith("Inspect the supplied"):
                    counts["analysis"] += 1
                    result = scene
                else:
                    expected = json.loads(prompt.split("Expected drawings: ", 1)[1].split(". Scene registry: ", 1)[0])
                    counts["review"] += len(expected)
                    result = {"frames": [dict(index=i, identity_match=True, count_match=True, action_match=True, environment_match=True, perspective_match=True, uncertain=False, defects=[]) for i in range(len(expected))]}
                self.send({"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(result)}}]})
            elif self.path == "/generate":
                assert data["use_opencl"] is False
                if "image" in data:
                    encoded = base64.b64decode(data["image"])
                    assert encoded.startswith(b"\x89PNG")
                    assert struct.unpack(">II", encoded[16:24]) == (512, 512)
                    assert "Preserve the reference" in data["prompt"]
                else:
                    assert "User subject description" in data["prompt"]
                index = counts["generate"]
                counts["generate"] += 1
                pixels = bytearray(b"\xff\xff\xff" * 512 * 512)
                for y in range(150, 350):
                    a = (y * 512 + 16 + index * 25) * 3
                    pixels[a:a + 300] = b"\xa5\x40\x30" * 100
                self.send(dict(type="complete", image=base64.b64encode(pixels).decode(), width=512, height=512, channels=3, seed=1234), sse=True)
            else:
                raise AssertionError(self.path)
    with tempfile.TemporaryDirectory() as folder, ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = dict(os.environ, XDG_DATA_HOME=folder, KARMA_LOCAL_TEST_SERVER=f"http://127.0.0.1:{server.server_port}")
        # Keep a broken proxy to verify production loopback never uses it.
        env["HTTPS_PROXY"] = "http://127.0.0.1:1"
        godot = env.get("GODOT_BIN") or shutil.which("godot")
        assert godot
        result = subprocess.run([godot, "--headless", "--path", str(ROOT), "--script", "res://tests/test_local_studio_transport.gd"], env=env, capture_output=True, text=True, timeout=45)
        server.shutdown()
        print(result.stdout)
        assert result.returncode == 0 and "LOCAL_STUDIO_TRANSPORT_OK" in result.stdout and "SCRIPT ERROR" not in result.stderr, result.stdout + result.stderr
        # Initial keypose checks: 8. In-betweens: 4 * (1 + 3) = 16.
        # One repaired keypose: 1. Its changed neighbor transition: 1 + 3 = 4.
        assert counts == {"models": 1, "analysis": 1, "review": 29, "generate": 14}, counts
        print("LOCAL_HTTP_NO_CLOUD_COUNTS_OK", counts)
if __name__ == "__main__":
    main()
