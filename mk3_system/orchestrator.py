from __future__ import annotations

import importlib
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from .components import ComponentResult, MK3Component


class MK3Orchestrator:
    def __init__(self, manifest_path: Path) -> None:
        self.manifest_path = manifest_path
        self.manifest = self._load_manifest(manifest_path)
        self.context: dict[str, Any] = {}

    def run(self) -> list[ComponentResult]:
        results: list[ComponentResult] = []
        for spec in self.manifest["components"]:
            component = self._load_component(spec)
            result = component.execute(self.context)
            results.append(result)
            if spec.get("required", False) and result.status not in {"ONLINE", "READY"}:
                break
        self.context["package_status"] = self._package_status(results)
        return results

    def report(self, results: list[ComponentResult]) -> dict[str, Any]:
        return {
            "package": self.manifest["package"],
            "version": self.manifest["version"],
            "status": self.context.get("package_status", "UNKNOWN"),
            "components": [asdict(result) for result in results],
            "context": self.context,
        }

    @staticmethod
    def _load_manifest(manifest_path: Path) -> dict[str, Any]:
        with manifest_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    @staticmethod
    def _load_component(spec: dict[str, Any]) -> MK3Component:
        module = importlib.import_module(spec["module"])
        component_type = getattr(module, spec["class"])
        return component_type()

    @staticmethod
    def _package_status(results: list[ComponentResult]) -> str:
        if not results:
            return "EMPTY"
        if all(result.status == "ONLINE" for result in results):
            return "MODULE_ONLINE"
        return "ATTENTION_REQUIRED"
