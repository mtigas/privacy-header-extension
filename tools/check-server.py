"""Local server for checking the GPC Switch extension end to end.

Serves a test page on http://localhost:8787 whose subresources come from
http://127.0.0.1:8787 (a different site), so first-party, third-party,
iframe, XHR and redirect requests are all exercised. Every request is logged
with its DNT and Sec-GPC header values, and the page POSTs what
navigator.globalPrivacyControl / navigator.doNotTrack report from the top
frame and from a cross-site iframe.

Usage:  uv run python3 tools/check-server.py [outdir]
Then open http://localhost:8787/?n=<label> in Safari and read outdir/log.jsonl.

Variants, for checking site exceptions (put a test host such as localhost in the
generated rules and signal.js by hand; the refresh tool refuses it):
  /?n=<label>&frame=localhost     the cross-site iframe comes from localhost
                                  instead of 127.0.0.1 (an excluded site embedded
                                  in a normal page, when the page is on 127.0.0.1)
  /go?n=<label>&to=localhost      a 302 from this host to the check page on the
                                  other host (a redirect into an excluded site)
"""

import json
import re
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = 8787
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
OUT.mkdir(parents=True, exist_ok=True)
LOG = OUT / "log.jsonl"

# The run label is interpolated into HTML and script, so keep it to a safe alphabet.
LABEL_RE = re.compile(r"^[A-Za-z0-9_-]{1,32}$")
MAX_BODY = 64 * 1024

GIF = bytes.fromhex(
    "47494638396101000100800000000000ffffff21f90401000000002c00000000010001000002024401003b"
)

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>GPC Switch check {n}</title>
<script src="http://127.0.0.1:{port}/script.js?n={n}"></script>
<link rel="stylesheet" href="http://127.0.0.1:{port}/style.css?n={n}">
</head><body>
<h1>GPC Switch check {n}</h1>
<pre id="out">navigator.globalPrivacyControl = <span id="gpc"></span>
navigator.doNotTrack = <span id="dnt"></span>
</pre>
<script>
// Registered before any iframe exists, so no frame's postMessage can race it.
(function () {{
  var n = {n_json};
  window.report = function (kind, extra) {{
    var body = Object.assign({{ n: n, kind: kind }}, extra);
    fetch("http://localhost:{port}/report", {{ method: "POST", headers: {{ "content-type": "text/plain" }}, body: JSON.stringify(body) }}).catch(function () {{}});
  }};
  window.addEventListener("message", function (ev) {{ if (ev.data && ev.data.kind) {{ window.report(ev.data.kind, ev.data); }} }});
}}());
</script>
<img src="http://127.0.0.1:{port}/img.gif?n={n}">
<img src="http://localhost:{port}/redir?n={n}">
<iframe src="http://{frame_host}:{port}/frame?n={n}" width="300" height="60"></iframe>
<iframe id="blank" src="about:blank" width="300" height="20"></iframe>
<iframe srcdoc="&lt;script&gt;parent.postMessage({{kind:'srcdoc', gpc: navigator.globalPrivacyControl, dnt: navigator.doNotTrack}}, '*')&lt;/script&gt;" width="300" height="20"></iframe>
<script>
(function () {{
  var n = {n_json};
  var report = window.report;
  document.getElementById("gpc").textContent = String(navigator.globalPrivacyControl);
  document.getElementById("dnt").textContent = String(navigator.doNotTrack);
  report("top", {{ gpc: navigator.globalPrivacyControl, dnt: navigator.doNotTrack,
                   ownProp: Object.prototype.hasOwnProperty.call(Navigator.prototype, "globalPrivacyControl") }});
  fetch("http://127.0.0.1:{port}/xhr?n=" + n, {{ credentials: "include" }}).catch(function () {{}});
  var b = document.getElementById("blank");
  try {{
    var w = b.contentWindow;
    report("about_blank", {{ gpc: w.navigator.globalPrivacyControl, dnt: w.navigator.doNotTrack }});
  }} catch (e) {{ report("about_blank", {{ error: String(e) }}); }}
}}());
</script>
</body></html>"""

FRAME = """<!doctype html><html><body>cross-site frame {n}
<img src="http://{host}:{port}/frame-img.gif?n={n}">
<script>parent.postMessage({{kind:'iframe', gpc: navigator.globalPrivacyControl, dnt: navigator.doNotTrack}}, '*')</script>
</body></html>"""


def log(obj: dict) -> None:
    with LOG.open("a") as f:
        f.write(json.dumps(obj) + "\n")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def _record(self) -> None:
        log({
            "ts": time.time(),
            "kind": "request",
            "method": self.command,
            "host": self.headers.get("Host"),
            "path": self.path,
            "dnt": self.headers.get("DNT"),
            "sec_gpc": self.headers.get("Sec-GPC"),
            "sec_fetch_dest": self.headers.get("Sec-Fetch-Dest"),
            "ua": (self.headers.get("User-Agent") or "")[:80],
        })

    def _send(self, code: int, ctype: str, body: bytes, extra: dict | None = None) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        # The cross-site fetch only needs to be *sent*; its response may fail CORS.
        self.send_header("Access-Control-Allow-Origin", "*")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _label(self, query: str) -> str | None:
        n = parse_qs(query).get("n", ["0"])[0]
        return n if LABEL_RE.match(n) else None

    @staticmethod
    def _test_host(host: str) -> str | None:
        """The two hosts the test page uses; anything else is refused (it goes into HTML)."""
        return host if host in ("localhost", "127.0.0.1") else None

    def do_POST(self):
        self._record()
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = -1
        if not 0 <= length <= MAX_BODY:
            self._send(400, "text/plain", b"bad length")
            return
        body = self.rfile.read(length).decode("utf-8", "replace")
        if self.path.startswith("/report"):
            try:
                msg = json.loads(body)
            except json.JSONDecodeError:
                msg = {"raw": body}
            log({"ts": time.time(), "kind": "report", "msg": msg})
            self._send(204, "text/plain", b"")
        else:
            self._send(404, "text/plain", b"nope")

    def do_GET(self):
        self._record()
        u = urlparse(self.path)
        n = self._label(u.query)
        if n is None:
            self._send(400, "text/plain", b"n must match [A-Za-z0-9_-]{1,32}")
            return
        query = parse_qs(u.query)
        if u.path in ("/", "/page"):
            frame_host = self._test_host(query.get("frame", ["127.0.0.1"])[0])
            if frame_host is None:
                self._send(400, "text/plain", b"frame must be localhost or 127.0.0.1")
                return
            html = PAGE.format(n=n, n_json=json.dumps(n), port=PORT, frame_host=frame_host)
            self._send(200, "text/html; charset=utf-8", html.encode())
        elif u.path == "/frame":
            host = self._test_host((self.headers.get("Host") or "").rsplit(":", 1)[0]) or "127.0.0.1"
            self._send(200, "text/html; charset=utf-8", FRAME.format(n=n, port=PORT, host=host).encode())
        elif u.path == "/go":
            to = self._test_host(query.get("to", ["localhost"])[0])
            if to is None:
                self._send(400, "text/plain", b"to must be localhost or 127.0.0.1")
                return
            self.send_response(302)
            self.send_header("Location", f"http://{to}:{PORT}/?n={n}")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif u.path in ("/img.gif", "/frame-img.gif"):
            self._send(200, "image/gif", GIF)
        elif u.path == "/script.js":
            self._send(200, "text/javascript", b"/* check */")
        elif u.path == "/style.css":
            self._send(200, "text/css", b"body{font-family:sans-serif}")
        elif u.path == "/xhr":
            self._send(200, "application/json", b'{"ok":true}')
        elif u.path == "/redir":
            self.send_response(302)
            self.send_header("Location", f"http://127.0.0.1:{PORT}/img.gif?redirected=1&n={n}")
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self._send(404, "text/plain", b"not found")


class V6Server(ThreadingHTTPServer):
    address_family = socket.AF_INET6


if __name__ == "__main__":
    v4 = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    listening = [f"127.0.0.1:{PORT}"]
    try:
        # Safari may resolve "localhost" to ::1, so listen there too when possible.
        v6 = V6Server(("::1", PORT), Handler)
        threading.Thread(target=v6.serve_forever, daemon=True).start()
        listening.append(f"[::1]:{PORT}")
    except OSError as exc:
        print(f"warning: not listening on ::1 ({exc})", file=sys.stderr, flush=True)
    print(f"serving on {' and '.join(listening)}; log: {LOG}", flush=True)
    try:
        v4.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        v4.server_close()
