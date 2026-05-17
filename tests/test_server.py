from mk3_system.server import mk3_info, module_status


def test_module_status_reports_online_packets() -> None:
    modules = module_status()

    assert modules["CORE"]["status"] == "CORE_ONLINE"
    assert modules["WEB"]["status"] == "WEB_ONLINE"
    assert modules["APP"]["status"] == "APP_ONLINE"
    assert modules["MANTRA"]["status"] == "MANTRA_ONLINE"
    assert modules["PRELAUNCH"]["status"] == "PRELAUNCH_ONLINE"
    assert all(report["missing"] == [] for report in modules.values())


def test_mk3_info_exposes_expected_services() -> None:
    info = mk3_info()

    assert info["name"] == "Codex MK3"
    assert info["version"] == "3.0.0"
    assert "command_interface_api" in info["services"]
    assert "modules" in info
