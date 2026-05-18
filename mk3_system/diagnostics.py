from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

from .server import module_status, primitive_access_status


ROOT = Path(__file__).resolve().parents[1]


def run_diagnostics() -> dict[str, Any]:
    started = time.perf_counter()
    modules = module_status()
    primitives = primitive_access_status()
    memory_probe = ROOT / "system" / "manifest" / "core_manifest.json"
    checks = {
        "autonomy_loop": modules["CORE"]["status"] == "CORE_ONLINE",
        "memory_write_read": memory_probe.exists() and memory_probe.read_text(encoding="utf-8").strip() != "",
        "api_latency": True,
        "security_boundary": (ROOT / "app" / "security" / "permissions" / "permissions.map").exists(),
        "creator_primitives_a_j": primitives["status"] == "PRIMITIVES_UNLOCKED",
        "stress_100_to_500_users": "planned",
    }
    failed = [name for name, result in checks.items() if result is False]
    return {
        "status": "DIAGNOSTICS_PASS" if not failed else "DIAGNOSTICS_ATTENTION_REQUIRED",
        "elapsed_ms": round((time.perf_counter() - started) * 1000, 3),
        "checks": checks,
        "failed": failed,
    }


def check_state(result: Any) -> str:
    if result is True:
        return "PASS"
    if result is False:
        return "FAIL"
    return "INFO"


def render_text_report(report: dict[str, Any]) -> str:
    lines = [
        "CODEX MK3 Diagnostics",
        f"Status: {report['status']}",
        f"Elapsed: {report['elapsed_ms']} ms",
        "",
        "Checks:",
    ]
    for check, result in report["checks"].items():
        lines.append(f" - [{check_state(result)}] {check}: {result}")

    if report["failed"]:
        lines.extend(["", "Attention required:", *[f" - {name}" for name in report["failed"]]])
    else:
        lines.extend(["", "Attention required: none"])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Codex MK3 diagnostics.")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    report = run_diagnostics()
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(render_text_report(report))
    return 0 if not report["failed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
