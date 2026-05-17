from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def module_status() -> dict[str, Any]:
    modules = {
        "CORE": [
            ("autonomy_profile.cfg", "system/behavior/autonomy"),
            ("codex_mk3.schema", "system/parser/v3"),
            ("mimic_engine.map", "system/mimic/engine"),
            ("core_manifest.json", "system/manifest"),
        ],
        "WEB": [
            ("index.layout", "web/ui/root"),
            ("routes.map", "web/router"),
            ("api_endpoints.list", "web/api/definitions"),
            ("branding.embed", "web/ui/branding"),
        ],
        "APP": [
            ("ui_frameset.json", "app/ui/screens"),
            ("app_logic.flow", "app/logic/flow"),
            ("permissions.map", "app/security/permissions"),
        ],
        "MANTRA": [
            ("codex_identity.txt", "branding/core"),
            ("logo_positions.map", "branding/placement"),
            ("tone_guide.md", "branding/tone"),
        ],
        "PRELAUNCH": [
            ("phase1_tease.plan", "marketing/prelaunch/phase1"),
            ("phase2_identity.plan", "marketing/prelaunch/phase2"),
            ("phase3_capabilities.plan", "marketing/prelaunch/phase3"),
            ("phase4_hype.plan", "marketing/prelaunch/phase4"),
            ("phase5_launch.plan", "marketing/prelaunch/phase5"),
        ],
    }
    report: dict[str, Any] = {}
    for name, mappings in modules.items():
        missing = [
            source
            for source, target in mappings
            if not (ROOT / target / source).exists()
        ]
        report[name] = {
            "status": f"{name}_ONLINE" if not missing else f"{name}_MISSING_PACKETS",
            "missing": missing,
        }
    return report


def mk3_info() -> dict[str, Any]:
    architecture = ROOT / "habitat" / "architecture.yaml"
    return {
        "name": "Codex MK3",
        "version": "3.0.0",
        "architecture_spec": str(architecture),
        "services": [
            "identity_access",
            "task_orchestration",
            "autonomy_loop",
            "memory_layer",
            "command_interface_api",
            "emotion_module",
        ],
        "modules": module_status(),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "CodexMK3/3.0"

    def do_GET(self) -> None:
        if self.path == "/status":
            self._json({"status": "OK", "modules": module_status()})
            return
        if self.path == "/mk3/info":
            self._json(mk3_info())
            return
        self._json({"error": "not_found"}, status=404)

    def do_POST(self) -> None:
        if self.path != "/submit":
            self._json({"error": "not_found"}, status=404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8") if length else ""
        self._json({"status": "ACCEPTED", "bytes_received": len(body)})

    def log_message(self, format: str, *args: Any) -> None:
        event = {
            "service": "command_interface_api",
            "level": "info",
            "event": format % args,
        }
        print(json.dumps(event))

    def _json(self, payload: dict[str, Any], status: int = 200) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Codex MK3 command interface API.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Codex MK3 API listening on http://{args.host}:{args.port}")
    httpd.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
