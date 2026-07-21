import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web_build")
PORT = 5000


class WasmHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_GET(self):
        # SPA fallback: any path without a real file → index.html
        path = self.path.split("?")[0].split("#")[0]
        file_path = os.path.join(WEB_DIR, path.lstrip("/"))
        if not os.path.isfile(file_path):
            self.path = "/index.html"
        return super().do_GET()

    def guess_type(self, path):
        if path.endswith(".wasm"):
            return "application/wasm"
        if path.endswith(".js"):
            return "application/javascript"
        return super().guess_type(path)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    os.chdir(WEB_DIR)
    httpd = HTTPServer(("0.0.0.0", PORT), WasmHandler)
    print(f"Serving Watchtower web on port {PORT}", flush=True)
    httpd.serve_forever()
