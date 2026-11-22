"""Minimal HTTP server serving the Harvester autoinstall config to the VM (NAT host IP)."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/config-create.yaml", "/harvester-config.yaml"):
            data = (ROOT / "docs" / "harvester-config.yaml").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/yaml")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        print(f"[config-server] {self.address_string()} - {fmt % args}", flush=True)


if __name__ == "__main__":
    print("Serving http://10.0.2.2:8000/config-create.yaml", flush=True)
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
