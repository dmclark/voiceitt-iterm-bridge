#!/usr/bin/env python3
"""Tiny HTTP server for the Voiceitt scratchpad.

Replaces `python3 -m http.server`. Two responsibilities:

  1. Serve `bridge/dictate.html` (and any sibling assets) as plain
     static content, exactly like `http.server` did.
  2. Accept `POST /transform` with a JSON body `{"text": "..."}`,
     shell out to the `voiceitt-transform` CLI, and return the
     cleaned text as `text/plain`.

Why a custom server instead of `python3 -m http.server`?
The page's auto-trigger (ERD §1.3) needs to round-trip dictated text
through an LLM. Doing the LLM call in the browser would force the API
key into localStorage; doing it through a local endpoint that shells
out to `voiceitt-transform` keeps the key in the shell env where it
already lives (Raycast inherits the user's shell env on launch — see
ROADMAP §1 open question #3).

This is the v0 of ERD §1.4 / §1.6: one endpoint, no prompt picker
plumbing yet, no rolling-context buffer. The existing Gemini-backed
`voiceitt-transform` (v0 of ERD §1.5) is invoked verbatim.

Configuration via env vars (all optional):
  VOICEITT_BRIDGE_PORT          default 7531
  VOICEITT_BRIDGE_DIR           default ~/.config/voiceitt-bridge
  VOICEITT_TRANSFORM_CMD        default $VOICEITT_BRIDGE_DIR/voiceitt-transform
  VOICEITT_TRANSFORM_HARD_TIMEOUT  default 10  (seconds; outer cap on
                                                the subprocess; the CLI
                                                has its own curl --max-time)
"""

import json
import os
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


PORT = int(os.environ.get("VOICEITT_BRIDGE_PORT", "7531"))
SERVE_DIR = os.environ.get(
    "VOICEITT_BRIDGE_DIR",
    os.path.expanduser("~/.config/voiceitt-bridge"),
)
TRANSFORM_CMD = os.environ.get(
    "VOICEITT_TRANSFORM_CMD",
    os.path.join(SERVE_DIR, "voiceitt-transform"),
)
HARD_TIMEOUT = float(os.environ.get("VOICEITT_TRANSFORM_HARD_TIMEOUT", "10"))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SERVE_DIR, **kwargs)

    # Trim the default per-request access log to one line on stderr.
    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def do_POST(self):
        if self.path != "/transform":
            self.send_error(404, "unknown endpoint")
            return

        length = int(self.headers.get("content-length", "0") or "0")
        raw = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            self.send_error(400, "invalid JSON body")
            return

        text = payload.get("text", "")
        if not isinstance(text, str):
            self.send_error(400, "'text' must be a string")
            return
        if not text:
            # Pass-through: nothing to transform, return empty 200.
            self._send_text(200, "")
            return

        try:
            result = subprocess.run(
                [TRANSFORM_CMD],
                input=text,
                capture_output=True,
                text=True,
                timeout=HARD_TIMEOUT,
                check=False,
            )
        except FileNotFoundError:
            self.send_error(
                500,
                f"voiceitt-transform not found at {TRANSFORM_CMD}",
            )
            return
        except subprocess.TimeoutExpired:
            self.send_error(504, f"voiceitt-transform timed out after {HARD_TIMEOUT}s")
            return

        if result.returncode != 0:
            # Surface stderr in the server log; the page treats any non-2xx
            # as "fail open with raw text" so the user is never blocked.
            sys.stderr.write(
                "voiceitt-transform exit %d:\n%s\n"
                % (result.returncode, (result.stderr or "").rstrip())
            )
            self.send_error(
                502,
                (result.stderr or "voiceitt-transform failed").splitlines()[-1][:200],
            )
            return

        self._send_text(200, result.stdout)

    def _send_text(self, status, body):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "text/plain; charset=utf-8")
        self.send_header("content-length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    sys.stderr.write(
        "voiceitt-bridge: serving %s on http://127.0.0.1:%d\n"
        "voiceitt-bridge: transform CLI = %s\n"
        % (SERVE_DIR, PORT, TRANSFORM_CMD)
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
