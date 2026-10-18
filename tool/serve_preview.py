"""Serve build/web locally without retaining stale Flutter bundles in Chrome."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class PreviewHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if "If-Modified-Since" in self.headers:
            del self.headers["If-Modified-Since"]
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()


if __name__ == "__main__":
    web = Path(__file__).resolve().parent.parent / "build" / "web"
    server = ThreadingHTTPServer(
        ("127.0.0.1", 3001), partial(PreviewHandler, directory=str(web))
    )
    print("MetCue preview: http://127.0.0.1:3001", flush=True)
    server.serve_forever()
