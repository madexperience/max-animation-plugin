"""HTTP server compatible with the existing Roblox Studio animation plugin."""

from __future__ import annotations

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse
import zlib

from .max_scene import MaxSceneAdapter


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 31337


class MaxAnimationHandler(BaseHTTPRequestHandler):
    adapter = MaxSceneAdapter()

    def log_message(self, format: str, *args: Any) -> None:
        print(f"[rbx-max] {self.address_string()} - {format % args}")

    def _send_json(self, payload: dict[str, Any], status: int = 200) -> None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_bytes(self, payload: bytes, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _send_error_json(self, message: str, status: int = 500) -> None:
        self._send_json({"success": False, "error": message}, status)

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/health":
            self._send_json({"success": True, "dcc": "3dsmax"})
            return

        if path == "/list_armatures":
            self._send_json({"success": True, "armatures": self.adapter.list_armatures()})
            return

        if path.startswith("/get_bone_rest/"):
            armature_name = unquote(path.rsplit("/", 1)[-1])
            self._send_json(self.adapter.get_bone_rest(armature_name))
            return

        if path.startswith("/export_animation/"):
            armature_name = unquote(path.rsplit("/", 1)[-1])
            try:
                self._send_bytes(self.adapter.export_animation(armature_name))
            except NotImplementedError as exc:
                self._send_error_json(str(exc), 501)
            except Exception as exc:
                self._send_error_json(str(exc), 500)
            return

        if path == "/animation_status":
            self._send_json({"success": True, "changed": False})
            return

        self._send_error_json(f"Unknown endpoint: {path}", 404)

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)

        if path.startswith("/export_animation/"):
            armature_name = unquote(path.rsplit("/", 1)[-1])
            request_data = self._decode_json_body(body)
            target_bone_rest = request_data.get("target_bone_rest") if isinstance(request_data, dict) else None
            try:
                self._send_bytes(self.adapter.export_animation(armature_name, target_bone_rest))
            except NotImplementedError as exc:
                self._send_error_json(str(exc), 501)
            except Exception as exc:
                self._send_error_json(str(exc), 500)
            return

        if path == "/import_animation":
            query = parse_qs(parsed.query)
            target_armature = query.get("armature", [None])[0]
            try:
                animation_data = self._decode_json_body(body)
                if not isinstance(animation_data, dict):
                    raise ValueError("Animation payload must be a JSON object.")
                self.adapter.import_animation(animation_data, target_armature)
                self._send_json({"success": True})
            except NotImplementedError as exc:
                self._send_error_json(str(exc), 501)
            except Exception as exc:
                self._send_error_json(str(exc), 400)
            return

        self._send_error_json(f"Unknown endpoint: {path}", 404)

    def do_OPTIONS(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    @staticmethod
    def _decode_json_body(body: bytes) -> Any:
        if not body:
            return {}

        try:
            decoded = zlib.decompress(body, 16 + zlib.MAX_WBITS)
        except zlib.error:
            try:
                decoded = zlib.decompress(body)
            except zlib.error:
                decoded = body

        return json.loads(decoded.decode("utf-8"))


def start_server(host: str = DEFAULT_HOST, port: int = DEFAULT_PORT) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer((host, port), MaxAnimationHandler)
    server.daemon_threads = True

    # In 3ds Max this is a development bridge. Real scene operations must be
    # marshalled onto the Max main thread before touching pymxs-managed data.
    import threading

    thread = threading.Thread(target=server.serve_forever, name="rbx-max-http", daemon=True)
    thread.start()
    return server
