#!/usr/bin/env python3
"""Lightweight local HTTP server for Godot Web export with gzip compression and caching headers.

Mimics GitHub Pages behavior (gzipped transfers, ETag, Cache-Control) so local
testing accurately reflects web load times and transfer sizes.
"""

import argparse
import gzip
import io
import mimetypes
import os
import sys
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

COMPRESSIBLE_EXTENSIONS = {
    ".wasm",
    ".pck",
    ".js",
    ".html",
    ".css",
    ".json",
    ".svg",
    ".txt",
    ".map",
}

# (path, mtime, size) -> gzipped bytes
_GZIP_CACHE: dict[tuple[str, float, int], bytes] = {}


class WebExportRequestHandler(SimpleHTTPRequestHandler):
    """Simple HTTP request handler with gzip compression and caching."""

    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
        ".svg": "image/svg+xml",
    }

    def end_headers(self) -> None:
        # Cross-origin isolation headers if needed by SharedArrayBuffer / WebAssembly
        # self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        # self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def send_head(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            parts = self.path.split("?", 1)[0].split("#", 1)[0]
            if not parts.endswith("/"):
                # Redirect to trailing slash for directories
                self.send_response(HTTPStatus.MOVED_PERMANENTLY)
                new_parts = list(parts)
                new_parts.append("/")
                if "?" in self.path:
                    new_parts.extend(["?", self.path.split("?", 1)[1]])
                self.send_header("Location", "".join(new_parts))
                self.end_headers()
                return None
            for index in ("index.html", "index.htm"):
                index_path = os.path.join(path, index)
                if os.path.isfile(index_path):
                    path = index_path
                    break
            else:
                return super().send_head()

        if not os.path.isfile(path):
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        try:
            stat = os.stat(path)
            mtime = stat.st_mtime
            size = stat.st_size
            etag = f'"{int(mtime):x}-{size:x}"'
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        # Check If-None-Match for 304 Not Modified
        if self.headers.get("If-None-Match") == etag:
            self.send_response(HTTPStatus.NOT_MODIFIED)
            self.send_header("ETag", etag)
            self.send_header("Cache-Control", "no-cache" if path.endswith(".html") else "public, max-age=600")
            self.end_headers()
            return None

        ctype = self.guess_type(path)
        ext = os.path.splitext(path)[1].lower()
        accept_encoding = self.headers.get("Accept-Encoding", "")

        # Check if gzip compression should be applied
        if "gzip" in accept_encoding and ext in COMPRESSIBLE_EXTENSIONS and size > 256:
            cache_key = (path, mtime, size)
            compressed_data = _GZIP_CACHE.get(cache_key)
            if compressed_data is None:
                try:
                    with open(path, "rb") as f:
                        raw_data = f.read()
                    compressed_data = gzip.compress(raw_data, compresslevel=6)
                    # Clear cache if it grows too large (> 256 MB)
                    total_cached = sum(len(v) for v in _GZIP_CACHE.values())
                    if total_cached > 256 * 1024 * 1024:
                        _GZIP_CACHE.clear()
                    _GZIP_CACHE[cache_key] = compressed_data
                except OSError:
                    self.send_error(HTTPStatus.INTERNAL_SERVER_ERROR, "Failed to read file")
                    return None

            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(compressed_data)))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Vary", "Accept-Encoding")
            self.send_header("ETag", etag)
            self.send_header(
                "Cache-Control",
                "no-cache" if ext == ".html" else "public, max-age=600",
            )
            self.send_header("Last-Modified", self.date_time_string(int(mtime)))
            self.end_headers()
            return io.BytesIO(compressed_data)

        # Uncompressed response
        try:
            f = open(path, "rb")
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(size))
        self.send_header("Vary", "Accept-Encoding")
        self.send_header("ETag", etag)
        self.send_header(
            "Cache-Control",
            "no-cache" if ext == ".html" else "public, max-age=600",
        )
        self.send_header("Last-Modified", self.date_time_string(int(mtime)))
        self.end_headers()
        return f


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", type=int, nargs="?", default=8080, help="Port to serve on (default: 8080)")
    parser.add_argument(
        "--directory",
        "-d",
        type=str,
        default="build/web",
        help="Directory to serve (default: build/web)",
    )
    parser.add_argument(
        "--bind",
        "-b",
        type=str,
        default="127.0.0.1",
        help="Address to bind to (default: 127.0.0.1)",
    )
    args = parser.parse_args()

    os.makedirs(args.directory, exist_ok=True)

    class CustomHandler(WebExportRequestHandler):
        def __init__(self, *handler_args, **kwargs):
            super().__init__(*handler_args, directory=args.directory, **kwargs)

    server = ThreadingHTTPServer((args.bind, args.port), CustomHandler)
    url = f"http://{args.bind}:{args.port}"
    print(f"Serving '{args.directory}' at {url} (gzip compression & caching enabled)...")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
