import http.server
import socketserver
import os
import sys
import argparse

parser = argparse.ArgumentParser(description="Preview Quadrilateral World locally")
parser.add_argument("--port", type=int, default=8080)
options = parser.parse_args()
PORT = options.port
DIRECTORY = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def guess_type(self, path):
        if path.endswith(".wasm"):
            return "application/wasm"
        if path.endswith(".pck"):
            return "application/octet-stream"
        return super().guess_type(path)

socketserver.TCPServer.allow_reuse_address = True
print(f"Starting server at http://localhost:{PORT} from {DIRECTORY}", flush=True)

try:
    with socketserver.TCPServer(("127.0.0.1", PORT), CustomHandler) as httpd:
        httpd.serve_forever()
except Exception as e:
    print(f"Error running server: {e}", file=sys.stderr, flush=True)
