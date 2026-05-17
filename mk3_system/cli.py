from __future__ import annotations

import argparse
import json
from pathlib import Path

from .orchestrator import MK3Orchestrator


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mk3",
        description="Run the CODEX MK3 structural update package.",
    )
    parser.add_argument(
        "--manifest",
        default="mk3_structural_update.json",
        help="Path to the MK3 structural update manifest.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit the full execution report as JSON.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    orchestrator = MK3Orchestrator(Path(args.manifest))
    results = orchestrator.run()
    report = orchestrator.report(results)

    if args.json:
        print(json.dumps(report, indent=2))
        return 0 if report["status"] == "MODULE_ONLINE" else 1

    print(f"[{report['package']}] version={report['version']} status={report['status']}")
    for result in results:
        print(f" - {result.component_id}: {result.status}")
    return 0 if report["status"] == "MODULE_ONLINE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
