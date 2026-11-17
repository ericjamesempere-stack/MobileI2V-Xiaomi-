"""Local HTTP transport fixture. No remote service, image upload or GPU."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def main():
    counts = {"POST": 0, "GET": 0}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_POST(self):
            counts["POST"] += 1
            self.rfile.read(int(self.headers.get("Content-Length", "0")))
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            body = json.dumps({"event_id": f"fixture{counts['POST']}"}).encode()
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            counts["GET"] += 1
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            body = ("event: complete\ndata: " + json.dumps([{"get": counts["GET"]}]) + "\n\n").encode()
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    root = Path(__file__).resolve().parents[1]
    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server, tempfile.TemporaryDirectory() as folder:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = dict(os.environ, KARMA_JOB_CACHE=folder,
                   KARMA_JOB_SERVER=f"http://127.0.0.1:{server.server_port}")
        # This fixture talks only to its own loopback server.
        env.pop("HTTPS_PROXY", None)
        try:
            result = subprocess.run(["godot", "--headless", "--path", str(root), "--script",
                                 "res://tests/test_generation_job_resume.gd"],
                                    env=env, capture_output=True, text=True, timeout=15)
        except subprocess.TimeoutExpired as exc:
            print(exc.stdout, exc.stderr, counts)
            raise
        server.shutdown()
        print(result.stdout)
        if result.returncode or "GENERATION_JOB_RESUME_OK" not in result.stdout or "SCRIPT ERROR" in result.stderr:
            raise RuntimeError(result.stdout + result.stderr)
        assert counts == {"POST": 3, "GET": 4}, counts
        print("LOCAL_HTTP_COUNTS_OK", counts)


if __name__ == "__main__":
    main()
