#!/usr/bin/env python3
"""Serve a live curl trace while the watch app is attached to the Mac.

The watch app writes one `CURL,<t>,<angle>,<reps>,<phase>` line to stdout ten
times a second. `devicectl device process launch --console` carries that over
the paired iPhone's cable, this script collects it, and the browser page polls
the samples from the local HTTP server.

Run from the repo root:

    python3 tools/curl_live.py

Options:
    --device UDID      Apple Watch UDID
    --bundle ID        watch app bundle id
    --port PORT        local HTTP port (default 8787)
    --demo             synthetic trace, no watch
    --no-open          do not open the browser
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import subprocess
import sys
import threading
import time
import webbrowser
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

WATCH_UDID = "00008301-988218883E08402E"
WATCH_BUNDLE = "com.whc.restless.watchkitapp"
ROOT = Path(__file__).resolve().parent.parent


class LiveState:
    def __init__(self, csv_path: Path) -> None:
        self.csv_path = csv_path
        self.lock = threading.Lock()
        self.samples: list[dict] = []
        self.next_id = 1
        self.last_rx = 0.0
        self.generation = time.time()
        self.csv_file = csv_path.open("w", newline="", encoding="utf-8")
        self.writer = csv.writer(self.csv_file)
        self.writer.writerow(["id", "time", "swing", "reps", "phase", "bottom", "peak"])
        self.csv_file.flush()

    def add(self, t: float, swing: float, reps: int, phase: str, bottom: float = 0.0, peak: float = 0.0) -> None:
        with self.lock:
            sample = {
                "id": self.next_id,
                "t": round(t, 3),
                "swing": round(swing, 2),
                "reps": reps,
                "phase": phase,
                "bottom": round(bottom, 2),
                "peak": round(peak, 2),
            }
            self.samples.append(sample)
            self.next_id += 1
            self.last_rx = time.time()
            self.writer.writerow([
                sample["id"],
                sample["t"],
                sample["swing"],
                sample["reps"],
                sample["phase"],
                sample["bottom"],
                sample["peak"],
            ])
            self.csv_file.flush()
            if len(self.samples) > 12000:
                self.samples = self.samples[-6000:]

    def since(self, sample_id: int) -> tuple[list[dict], float]:
        with self.lock:
            return [s for s in self.samples if s["id"] >= sample_id][-3000:], self.last_rx

    def close(self) -> None:
        with self.lock:
            self.csv_file.close()


class ConsoleReader:
    def __init__(self, device: str, bundle: str, state: LiveState) -> None:
        self.device = device
        self.bundle = bundle
        self.state = state
        self.proc: subprocess.Popen[str] | None = None
        self.thread: threading.Thread | None = None

    def start(self) -> None:
        cmd = [
            "xcrun",
            "devicectl",
            "device",
            "process",
            "launch",
            "--console",
            "--terminate-existing",
            "--device",
            self.device,
            self.bundle,
        ]
        print("Launching watch app…")
        try:
            self.proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except FileNotFoundError:
            print("xcrun was not found.", file=sys.stderr)
            return
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()

    def _read(self) -> None:
        assert self.proc is not None and self.proc.stdout is not None
        for raw in self.proc.stdout:
            line = raw.strip()
            if not line:
                continue
            marker = line.find("CURL,")
            if marker >= 0:
                parts = line[marker:].split(",")
                if len(parts) >= 5:
                    try:
                        t = float(parts[1])
                        swing = float(parts[2])
                        reps = int(float(parts[3]))
                        phase = parts[4].strip()
                        bottom = float(parts[5]) if len(parts) >= 7 else 0.0
                        peak = float(parts[6]) if len(parts) >= 7 else 0.0
                    except ValueError:
                        continue
                    self.state.add(t, swing, reps, phase, bottom, peak)
                continue
            if line.startswith("CURL_BOOT"):
                print("Watch app connected.")
                continue
            if "error" in line.lower() or "failed" in line.lower():
                print(line, file=sys.stderr)
        self.proc.wait()
        print("Watch console ended. Start the app from Xcode or rerun this script.")

    def stop(self) -> None:
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()


class Handler(BaseHTTPRequestHandler):
    state: LiveState
    html: bytes

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._send(200, "text/html; charset=utf-8", self.html)
            return
        if parsed.path == "/samples":
            query = parse_qs(parsed.query)
            try:
                since = int(query.get("since", ["0"])[0])
            except ValueError:
                since = 0
            samples, last_rx = self.state.since(since)
            stale = (time.time() - last_rx) > 2.0 if last_rx else True
            body = json.dumps({
                "samples": samples,
                "stale": stale,
                "generation": self.state.generation,
            }).encode("utf-8")
            self._send(200, "application/json; charset=utf-8", body)
            return
        if parsed.path == "/csv":
            path = self.state.csv_path
            if path.exists():
                self._send(200, "text/csv; charset=utf-8", path.read_bytes())
            else:
                self._send(404, "text/plain; charset=utf-8", b"no csv yet")
            return
        self._send(404, "text/plain; charset=utf-8", b"not found")

    def _send(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args) -> None:  # keep the console clean
        pass


def demo(state: LiveState) -> None:
    """A synthetic curl cycle for testing the page without the watch."""
    t = 0.0
    reps = 0
    phase = "active"
    while True:
        cycle = t % 3.0
        if cycle < 1.1:
            k = cycle / 1.1
            angle = 130 * (3 * k * k - 2 * k * k * k)
        elif cycle < 1.35:
            angle = 130
        elif cycle < 2.35:
            k = (cycle - 1.35) / 1.0
            angle = 130 * (1 - (3 * k * k - 2 * k * k * k))
        else:
            angle = 0
        if cycle < 0.1 and t > 0:
            reps += 1
        state.add(t, angle, reps, phase, 0.0, 130.0)
        t += 0.1
        time.sleep(0.1)


def main() -> int:
    parser = argparse.ArgumentParser(description="Live curl trace for the Restless watch lab")
    parser.add_argument("--device", default=WATCH_UDID, help="Apple Watch UDID")
    parser.add_argument("--bundle", default=WATCH_BUNDLE, help="watch app bundle id")
    parser.add_argument("--port", type=int, default=8787, help="local HTTP port")
    parser.add_argument("--demo", action="store_true", help="synthetic trace, no watch")
    parser.add_argument("--no-open", action="store_true", help="do not open the browser")
    args = parser.parse_args()

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_dir = ROOT / "build"
    log_dir.mkdir(parents=True, exist_ok=True)
    csv_path = log_dir / f"curl-live-{stamp}.csv"

    html_path = Path(__file__).with_name("curl_live.html")
    html = html_path.read_bytes()

    state = LiveState(csv_path)
    handler = type("BoundHandler", (Handler,), {"state": state, "html": html})
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    url = f"http://127.0.0.1:{args.port}/"
    print(f"Live page: {url}")
    print(f"CSV:       {csv_path}")
    print("Start a set on the watch. Ctrl-C stops the page.")

    if not args.no_open:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()

    console = ConsoleReader(args.device, args.bundle, state)
    demo_thread = None
    if args.demo:
        print("Demo mode: synthetic curls.")
        demo_thread = threading.Thread(target=demo, args=(state,), daemon=True)
        demo_thread.start()
    else:
        console.start()

    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        pass
    finally:
        console.stop()
        server.shutdown()
        state.close()
        print("\nStopped.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
