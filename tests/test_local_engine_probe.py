"""Real loopback transport, simulated engines. No model or cloud inference."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT=Path(__file__).resolve().parents[1]
def main():
    godot=os.environ.get('GODOT_BIN') or shutil.which('godot')
    assert godot
    for scenario in ['ready','auth','empty','multiple','health_missing','redirect']:
        seen=[]
        posts=[]
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args): pass
            def do_POST(self):
                posts.append(self.path)
                self.send_response(500);self.end_headers()
            def do_GET(self):
                seen.append(self.path)
                if self.path=='/v1/models':
                    assert self.headers.get('Authorization')=='Bearer private-probe-token'
                    code=401 if scenario=='auth' else 200
                    models=[] if scenario=='empty' else [{'id':'fixture-vision'}]
                    if scenario=='multiple': models.append({'id':'fixture-text'})
                    body=json.dumps({'data':models}).encode()
                elif self.path=='/health':
                    assert self.headers.get('Authorization') is None
                    code=503 if scenario=='health_missing' else (302 if scenario=='redirect' else 200)
                    body=b'' # Actual upstream /health sends an empty 200 body.
                else:
                    code=500;body=b''
                self.send_response(code)
                if code==302:self.send_header('Location','/must-not-follow')
                self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        with tempfile.TemporaryDirectory() as data_dir, ThreadingHTTPServer(('127.0.0.1',0),Handler) as server:
            t=threading.Thread(target=server.serve_forever,daemon=True);t.start()
            env=dict(os.environ,XDG_DATA_HOME=data_dir,KARMA_PROBE_SERVER=f'http://127.0.0.1:{server.server_port}',KARMA_PROBE_SCENARIO=scenario,HTTPS_PROXY='http://127.0.0.1:1')
            result=subprocess.run([godot,'--headless','--path',str(ROOT),'--script','res://tests/test_local_engine_probe.gd'],env=env,capture_output=True,text=True,timeout=35)
            server.shutdown()
            assert result.returncode==0 and 'LOCAL_ENGINE_PROBE_OK '+scenario in result.stdout and not any(x in result.stdout+result.stderr for x in ['SCRIPT ERROR','Assertion failed','Parse Error','ERROR:']),result.stdout+result.stderr
            assert not posts and set(seen)<= {'/health','/v1/models'},(posts,seen)
            print('PASS_LOCAL_PROBE',scenario,'GETs',len(seen),'POSTs',len(posts))
    print('LOCAL_ENGINE_PROBE_HTTP_OK: six scenarios, real loopback, simulated engine metadata, zero POSTs/cloud calls')
if __name__=='__main__':main()
