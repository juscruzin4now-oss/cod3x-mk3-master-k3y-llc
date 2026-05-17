from mk3_system.diagnostics import check_state, render_text_report, run_diagnostics


def test_diagnostics_pass_for_packaged_tree() -> None:
    report = run_diagnostics()

    assert report["status"] == "DIAGNOSTICS_PASS"
    assert report["failed"] == []
    assert report["checks"]["autonomy_loop"] is True
    assert report["checks"]["memory_write_read"] is True
    assert report["checks"]["security_boundary"] is True


def test_diagnostics_text_report_is_operator_readable() -> None:
    report = run_diagnostics()

    rendered = render_text_report(report)

    assert "CODEX MK3 Diagnostics" in rendered
    assert "Status: DIAGNOSTICS_PASS" in rendered
    assert "[PASS] autonomy_loop: True" in rendered
    assert "Attention required: none" in rendered


def test_check_state_labels_boolean_and_info_values() -> None:
    assert check_state(True) == "PASS"
    assert check_state(False) == "FAIL"
    assert check_state("planned") == "INFO"
