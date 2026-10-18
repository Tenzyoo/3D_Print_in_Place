"""Loopback shim between dsh and a Gemini API relay that pins the request's thinking level.

pi-ai (dsh's multi-provider adapter) only uses Gemini's discrete `thinkingLevel` control for model ids
it recognizes (gemini-3*-pro/flash and a few aliases). For any other id, such as the relay's
gemini-4-argon-high, it sends the token-budget form `thinkingBudget: -1` (dynamic thinking). The
relay honours the difference (measured: thinkingLevel HIGH ~1.1k thought tokens, dynamic ~1.35k,
LOW 0 on the same prompt), while Gemini CLI sends `thinkingLevel: HIGH`. The shim rewrites every
generateContent / streamGenerateContent body that asks for thinking (thinkingBudget != 0) to
`{includeThoughts: true, thinkingLevel: <level>}` and passes every other byte through.

  python3 -I gemini_thinking_shim.py --listen 127.0.0.1:18081 --upstream https://api.supergpt.dev --level HIGH
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
LEVEL = "HIGH"
TIMEOUT_SEC = 1800.0


def pin_thinking_level(body: bytes) -> tuple[bytes, str]:
    """Return the request with its thinking budget replaced by the pinned level, and what was done."""
    try:
        req = json.loads(body)
    except ValueError:
        return body, "not-json"
    if not isinstance(req, dict):
        return body, "not-object"
    gen = req.get("generationConfig")
    tc = gen.get("thinkingConfig") if isinstance(gen, dict) else None
    if not isinstance(tc, dict):
        return body, "no-thinkingConfig"
    if tc.get("thinkingLevel"):
        return body, f"kept-level-{tc['thinkingLevel']}"
    budget = tc.get("thinkingBudget")
    if budget == 0:
        return body, "kept-off"
    tc.pop("thinkingBudget", None)
    tc["thinkingLevel"] = LEVEL
    tc.setdefault("includeThoughts", True)
    return json.dumps(req, ensure_ascii=False).encode(), f"budget-{budget}->level-{LEVEL}"


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
        action = "-"
        if self.command == "POST" and "generatecontent" in self.path.split("?", 1)[0].lower():
            body, action = pin_thinking_level(body)
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
            self._log(f"{self.command} {self.path} thinking={action} upstream-error={exc!r}")
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
        self._log(f"{self.command} {self.path.split('?', 1)[0]} thinking={action} status={resp.status} "
                  f"bytes={sent} secs={time.monotonic() - started:.1f}")

    def _log(self, msg: str) -> None:
        sys.stderr.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
        sys.stderr.flush()

    def log_message(self, *args):  # per-request lines come from _log instead
        pass


def main():
    global UPSTREAM, LEVEL
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen", default="127.0.0.1:18081")
    ap.add_argument("--upstream", required=True)
    ap.add_argument("--level", default="HIGH", choices=["MINIMAL", "LOW", "MEDIUM", "HIGH"])
    a = ap.parse_args()
    UPSTREAM = urlsplit(a.upstream)
    LEVEL = a.level
    host, port = a.listen.rsplit(":", 1)
    server = ThreadingHTTPServer((host, int(port)), Handler)
    server.daemon_threads = True
    sys.stderr.write(f"shim listening on {a.listen} -> {a.upstream} (thinkingLevel {LEVEL})\n")
    sys.stderr.flush()
    server.serve_forever()


if __name__ == "__main__":
    main()
