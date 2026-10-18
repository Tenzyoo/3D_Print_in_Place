"""Loopback shim between dsh and an OpenAI Responses relay that injects its own instructions.

The GPT relay (api.supergpt.dev) fills in a default Codex system prompt (~4.4k tokens,
"You are Codex ...", including an apply_patch tool) whenever a Responses request carries no
`instructions` field. pi-ai, dsh's multi-provider adapter, sends the system prompt as a leading
`developer` message instead, so without this shim GPT would see both prompts. The shim moves
that leading developer/system message into `instructions` and passes every other byte through.

  python3 -I responses_instructions_shim.py --listen 127.0.0.1:18080 --upstream https://api.supergpt.dev
"""

import argparse
import http.client
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers",
    "transfer-encoding", "upgrade", "host", "content-length", "accept-encoding",
}
UPSTREAM = urlsplit("https://api.supergpt.dev")
TIMEOUT_SEC = 1800.0


def lift_instructions(body: bytes) -> tuple[bytes, bool]:
    """Return the request with its leading developer/system message moved into `instructions`."""
    try:
        req = json.loads(body)
    except ValueError:
        return body, False
    if not isinstance(req, dict) or req.get("instructions"):
        return body, False
    items = req.get("input")
    if not isinstance(items, list) or len(items) < 2:
        return body, False
    first = items[0]
    if not (isinstance(first, dict) and first.get("role") in ("developer", "system")
            and first.get("type", "message") == "message"):
        return body, False
    content = first.get("content")
    if isinstance(content, str):
        text = content
    elif isinstance(content, list) and all(
        isinstance(c, dict) and c.get("type") in ("input_text", "text") for c in content
    ):
        text = "\n".join(c.get("text", "") for c in content)
    else:
        return body, False
    req["instructions"] = text
    req["input"] = items[1:]
    return json.dumps(req, ensure_ascii=False).encode(), True


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self._forward()

    def do_POST(self):
        self._forward()

    def _forward(self):
        started = time.monotonic()
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        lifted = False
        if self.command == "POST" and self.path.split("?", 1)[0].rstrip("/").endswith("/responses"):
            body, lifted = lift_instructions(body)
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP_BY_HOP}
        headers["Accept-Encoding"] = "identity"
        if body:
            headers["Content-Length"] = str(len(body))
        conn_cls = http.client.HTTPSConnection if UPSTREAM.scheme == "https" else http.client.HTTPConnection
        conn = conn_cls(UPSTREAM.hostname, UPSTREAM.port, timeout=TIMEOUT_SEC)
        try:
            conn.request(self.command, UPSTREAM.path.rstrip("/") + self.path, body=body or None, headers=headers)
            resp = conn.getresponse()
        except Exception as exc:  # report transport failures to the client as a gateway error
            conn.close()
            self._log(f"{self.command} {self.path} lifted={lifted} upstream-error={exc!r}")
            self.send_error(502, f"shim upstream error: {exc}")
            return
        self.send_response(resp.status, resp.reason)
        for k, v in resp.getheaders():
            if k.lower() not in HOP_BY_HOP:
                self.send_header(k, v)
        self.send_header("Transfer-Encoding", "chunked")
        self.send_header("Connection", "close")
        self.end_headers()
        sent = 0
        try:
            while chunk := resp.read1(65536):
                self.wfile.write(b"%x\r\n%s\r\n" % (len(chunk), chunk))
                self.wfile.flush()
                sent += len(chunk)
            self.wfile.write(b"0\r\n\r\n")
        except OSError as exc:
            self._log(f"stream aborted: {exc!r}")
        finally:
            conn.close()
            self.close_connection = True
        self._log(f"{self.command} {self.path} lifted={lifted} status={resp.status} "
                  f"bytes={sent} secs={time.monotonic() - started:.1f}")

    def _log(self, msg: str) -> None:
        sys.stderr.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
        sys.stderr.flush()

    def log_message(self, *args):  # per-request lines come from _log instead
        pass


def main():
    global UPSTREAM
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen", default="127.0.0.1:18080")
    ap.add_argument("--upstream", required=True)
    a = ap.parse_args()
    UPSTREAM = urlsplit(a.upstream)
    host, port = a.listen.rsplit(":", 1)
    server = ThreadingHTTPServer((host, int(port)), Handler)
    server.daemon_threads = True
    sys.stderr.write(f"shim listening on {a.listen} -> {a.upstream}\n")
    sys.stderr.flush()
    server.serve_forever()


if __name__ == "__main__":
    main()
