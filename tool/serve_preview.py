"""Serve the current Flutter build without stale preview bundles or service workers."""
import argparse
import hashlib
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class PreviewHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        web = Path(self.directory)
        if path in ("/", "/index.html", "/flutter_bootstrap.js", "/preview"):
            revision = hashlib.sha256((web / "main.dart.js").read_bytes()).hexdigest()[:16]
            if path == "/flutter_bootstrap.js":
                source = (web / "flutter_bootstrap.js").read_text().rsplit("_flutter.loader.load(", 1)[0]
                source += """
(async () => {
  if ('serviceWorker' in navigator) {
    await Promise.all((await navigator.serviceWorker.getRegistrations()).map(r => r.unregister()));
  }
  if ('caches' in window) {
    await Promise.all((await caches.keys()).filter(k => k.startsWith('flutter-')).map(k => caches.delete(k)));
  }
  _flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
})();
"""
                source = source.replace('"mainJsPath":"main.dart.js"', '"mainJsPath":"main.dart.js?preview=' + revision + '"')
                content_type = "text/javascript"
            else:
                source = (web / "index.html").read_text().replace('src="flutter_bootstrap.js"', 'src="flutter_bootstrap.js?preview=' + revision + '"')
                content_type = "text/html"
            body = source.encode()
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Acquenta-Preview", revision)
            self.end_headers()
            self.wfile.write(body)
            return
        if "If-Modified-Since" in self.headers:
            del self.headers["If-Modified-Since"]
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=3002)
    args = parser.parse_args()
    web = Path(__file__).resolve().parent.parent / "build" / "web"
    server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(PreviewHandler, directory=str(web)))
    print(f"Acquenta preview: http://127.0.0.1:{args.port}", flush=True)
    server.serve_forever()
