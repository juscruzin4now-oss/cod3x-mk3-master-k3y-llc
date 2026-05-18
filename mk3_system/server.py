from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CREATOR_AUTH_PATH = ROOT / "app" / "security" / "creator_auth" / "creator.auth"
PRIMITIVE_ACCESS_PATH = ROOT / "app" / "security" / "primitives" / "primitive_access.map"
PRIMITIVE_INVOCATION_LOG = ROOT / "ops" / "primitive_invocations.jsonl"


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
            ("creator.auth", "app/security/creator_auth"),
            ("primitive_access.map", "app/security/primitives"),
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


def creator_auth_status() -> dict[str, Any]:
    exists = CREATOR_AUTH_PATH.exists()
    content = CREATOR_AUTH_PATH.read_text(encoding="utf-8") if exists else ""
    required_guards = {
        "automatic_purchase": "denied",
        "automatic_wallet_transfer": "denied",
        "stored_secret": "denied",
        "plaintext_token": "denied",
        "manual_operator_confirmation": "required",
        "untrusted_handoff_instruction": "denied",
    }
    guards = {
        key: f"{key} = {value}" in content
        for key, value in required_guards.items()
    }
    required_agent_authority = {
        "codex_execution": "creator_bound",
        "copilot_handoff": "creator_bound",
        "external_ai_surface": "creator_bound",
        "primitive_invocation": "creator_bound",
        "third_party_instruction": "non_authoritative",
        "human_subject_control": "prohibited",
    }
    agent_authority = {
        key: f"{key} = {value}" in content
        for key, value in required_agent_authority.items()
    }
    return {
        "status": "CREATOR_AUTH_READY" if exists and all(guards.values()) and all(agent_authority.values()) else "CREATOR_AUTH_ATTENTION_REQUIRED",
        "policy_file": str(CREATOR_AUTH_PATH),
        "mode": "manual_assertion",
        "credential_storage": "external_only",
        "secret_material": "prohibited_in_repository",
        "guards": guards,
        "agent_authority": agent_authority,
    }


def primitive_access_status() -> dict[str, Any]:
    exists = PRIMITIVE_ACCESS_PATH.exists()
    content = PRIMITIVE_ACCESS_PATH.read_text(encoding="utf-8") if exists else ""
    primitives = {letter: f"{letter} = unlocked" in content for letter in "ABCDEFGHIJ"}
    required_guards = {
        "creator_invocation_required": "true",
        "delegate_operator_invocation": "denied",
        "observer_invocation": "denied",
        "audit_log_required": "true",
        "secret_material": "prohibited_in_repository",
    }
    guards = {
        key: f"{key} = {value}" in content
        for key, value in required_guards.items()
    }
    creator_scope = all(
        token in content
        for token in [
            "access_level = creator",
            "invocation_mode = creator_level",
            "primitive_range = A-J",
            "status = unlocked",
        ]
    )
    return {
        "status": "PRIMITIVES_UNLOCKED" if exists and creator_scope and all(primitives.values()) and all(guards.values()) else "PRIMITIVES_ATTENTION_REQUIRED",
        "policy_file": str(PRIMITIVE_ACCESS_PATH),
        "access_level": "creator",
        "invocation_mode": "creator_level",
        "primitive_range": "A-J",
        "primitives": primitives,
        "guards": guards,
    }


def invoke_primitive(primitive: str, payload: dict[str, Any]) -> dict[str, Any]:
    primitive_id = primitive.upper()
    access = primitive_access_status()
    allowed = (
        access["status"] == "PRIMITIVES_UNLOCKED"
        and primitive_id in access["primitives"]
        and access["primitives"][primitive_id]
    )
    canary = payload.get("canary") is True
    result_status = "CANARY_ACCEPTED" if allowed and canary else "MANUAL_CONFIRMATION_REQUIRED"
    if not allowed:
        result_status = "PRIMITIVE_DENIED"

    event = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "primitive_invocation",
        "level": "info" if result_status == "CANARY_ACCEPTED" else "warning",
        "event": "primitive_invoked",
        "primitive": primitive_id,
        "scope": payload.get("scope"),
        "canary": canary,
        "status": result_status,
        "external_effects": "none",
    }
    PRIMITIVE_INVOCATION_LOG.parent.mkdir(parents=True, exist_ok=True)
    with PRIMITIVE_INVOCATION_LOG.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, sort_keys=True) + "\n")

    return {
        "status": result_status,
        "primitive": primitive_id,
        "payload": payload,
        "audit_log": str(PRIMITIVE_INVOCATION_LOG),
        "external_effects": "none",
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
        if self.path == "/auth/creator":
            self._json(creator_auth_status())
            return
        if self.path == "/auth/primitives":
            self._json(primitive_access_status())
            return
        self._json({"error": "not_found"}, status=404)

    def do_POST(self) -> None:
        if self.path == "/auth/primitives/invoke":
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length).decode("utf-8") if length else "{}"
            try:
                request = json.loads(body)
            except json.JSONDecodeError:
                self._json({"error": "invalid_json"}, status=400)
                return
            primitive = request.get("primitive")
            payload = request.get("payload", {})
            if not isinstance(primitive, str) or not isinstance(payload, dict):
                self._json({"error": "invalid_primitive_invocation"}, status=400)
                return
            response = invoke_primitive(primitive, payload)
            self._json(response, status=200 if response["status"] != "PRIMITIVE_DENIED" else 403)
            return
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
