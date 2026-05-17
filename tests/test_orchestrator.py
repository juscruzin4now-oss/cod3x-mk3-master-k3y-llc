from pathlib import Path

from mk3_system.orchestrator import MK3Orchestrator


def test_orchestrator_runs_all_required_components() -> None:
    orchestrator = MK3Orchestrator(Path("mk3_structural_update.json"))

    results = orchestrator.run()
    report = orchestrator.report(results)

    assert report["package"] == "CODEX_MK3_STRUCTURAL_UPDATE"
    assert report["version"] == "3.0.0"
    assert report["status"] == "MODULE_ONLINE"
    assert [result.component_id for result in results] == [
        "environment",
        "framework",
        "channels",
        "packet",
        "integration",
        "advancement",
    ]
    assert all(result.status == "ONLINE" for result in results)
    assert report["context"]["integration"]["status"] == "MODULE_ONLINE"
