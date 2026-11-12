#!/usr/bin/env python3
"""Run the prototype in headless Chrome and print the resulting DOM.

    python3 tools/prototype-check.py                  # the prototype as it loads
    python3 tools/prototype-check.py driver.js        # after driver.js runs
    python3 tools/prototype-check.py driver.js --budget 9000 --verbose

The driver runs after the prototype's own script, so it can seed
`localStorage`, click the markup, and write the strings it asserts into the
page; `--dump-dom` carries them back. Wrap the driver body in
`setTimeout(fn, 0)` so it runs after the prototype's own start-up and first
render. Chrome's virtual clock jumps idle gaps, so timers settle inside the
budget instead of waiting in real time. Pass `--verbose` to keep Chrome's
console on stderr; on a failed run it is printed either way.

No network and no repository files are touched: the page is served from memory
on an ephemeral localhost port.
"""

from __future__ import annotations

import argparse
import http.server
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "prototype-workout-timer.html"

CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
]


def find_chrome() -> str:
    env = os.environ.get("CHROME")
    if env:
        return env
    for path in CHROME_CANDIDATES:
        if Path(path).exists():
            return path
    for name in ("google-chrome", "chromium", "chromium-browser"):
        found = shutil.which(name)
        if found:
            return found
    sys.exit("prototype-check: no Chrome found; set CHROME to its binary")


def instrumented_page(driver: Path | None) -> bytes:
    html = PAGE.read_text()
    if driver is not None:
        code = driver.read_text().replace("</script>", "<\\/script>")
        html = re.sub(
            r"</body>",
            lambda _match: f"<script>\n{code}\n</script>\n</body>",
            html,
            count=1,
        )
    return html.encode()


def serve(page: bytes):
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(ROOT), **kwargs)

        def do_GET(self):
            if self.path.split("?")[0] in ("/", "/index.html", "/proto-check.html"):
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(page)))
                self.end_headers()
                self.wfile.write(page)
                return
            super().do_GET()

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("driver", nargs="?", help="JS file injected before </body>")
    parser.add_argument("--budget", type=int, default=6000, help="virtual time in ms")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    driver = Path(args.driver).resolve() if args.driver else None
    if driver is not None and not driver.is_file():
        sys.exit(f"prototype-check: no such driver: {driver}")

    server = serve(instrumented_page(driver))
    port = server.server_address[1]
    profile = tempfile.mkdtemp(prefix="proto-check-")
    try:
        result = subprocess.run(
            [
                find_chrome(),
                "--headless=new",
                "--disable-gpu",
                "--no-first-run",
                "--no-default-browser-check",
                f"--user-data-dir={profile}",
                f"--virtual-time-budget={args.budget}",
                "--dump-dom",
                f"http://127.0.0.1:{port}/",
            ],
            capture_output=True,
            text=True,
            timeout=args.budget / 1000 + 60,
        )
    finally:
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)

    if result.returncode != 0 or args.verbose:
        sys.stderr.write(result.stderr)
    sys.stdout.write(result.stdout)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
