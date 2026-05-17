from mk3_system.diagnostics import run_diagnostics


def test_diagnostics_pass_for_packaged_tree() -> None:
    report = run_diagnostics()

    assert report["status"] == "DIAGNOSTICS_PASS"
    assert report["failed"] == []
    assert report["checks"]["autonomy_loop"] is True
    assert report["checks"]["memory_write_read"] is True
    assert report["checks"]["security_boundary"] is True
