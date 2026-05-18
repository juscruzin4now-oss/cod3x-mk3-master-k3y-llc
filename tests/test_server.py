from http.client import HTTPConnection
from threading import Thread

import mk3_system.server as server_module
from mk3_system.server import Handler, ThreadingHTTPServer, creator_auth_status, invoke_primitive, mk3_info, module_status, primitive_access_status


def test_module_status_reports_online_packets() -> None:
    modules = module_status()

    assert modules["CORE"]["status"] == "CORE_ONLINE"
    assert modules["WEB"]["status"] == "WEB_ONLINE"
    assert modules["APP"]["status"] == "APP_ONLINE"
    assert "creator.auth" not in modules["APP"]["missing"]
    assert "primitive_access.map" not in modules["APP"]["missing"]
    assert modules["MANTRA"]["status"] == "MANTRA_ONLINE"
    assert modules["PRELAUNCH"]["status"] == "PRELAUNCH_ONLINE"
    assert all(report["missing"] == [] for report in modules.values())


def test_mk3_info_exposes_expected_services() -> None:
    info = mk3_info()

    assert info["name"] == "Codex MK3"
    assert info["version"] == "3.0.0"
    assert "command_interface_api" in info["services"]
    assert "modules" in info


def test_creator_auth_status_exposes_policy_without_secrets() -> None:
    auth = creator_auth_status()

    assert auth["status"] == "CREATOR_AUTH_READY"
    assert auth["mode"] == "manual_assertion"
    assert auth["credential_storage"] == "external_only"
    assert auth["secret_material"] == "prohibited_in_repository"
    assert all(auth["guards"].values())
    assert auth["agent_authority"]["codex_execution"] is True
    assert auth["agent_authority"]["copilot_handoff"] is True
    assert auth["agent_authority"]["external_ai_surface"] is True
    assert auth["agent_authority"]["primitive_invocation"] is True
    assert auth["agent_authority"]["third_party_instruction"] is True
    assert auth["agent_authority"]["human_subject_control"] is True


def test_primitive_access_status_exposes_creator_level_a_j_unlock() -> None:
    access = primitive_access_status()

    assert access["status"] == "PRIMITIVES_UNLOCKED"
    assert access["access_level"] == "creator"
    assert access["invocation_mode"] == "creator_level"
    assert access["primitive_range"] == "A-J"
    assert set(access["primitives"]) == set("ABCDEFGHIJ")
    assert all(access["primitives"].values())
    assert all(access["guards"].values())


def test_canary_primitive_invocation_records_no_external_effects(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(server_module, "PRIMITIVE_INVOCATION_LOG", tmp_path / "primitive_invocations.jsonl")

    result = invoke_primitive("F", {"scope": "full", "canary": True})

    assert result["status"] == "CANARY_ACCEPTED"
    assert result["primitive"] == "F"
    assert result["external_effects"] == "none"
    assert result["payload"] == {"scope": "full", "canary": True}


def request(server: ThreadingHTTPServer, method: str, path: str, body: str | None = None) -> tuple[int, str]:
    host, port = server.server_address
    connection = HTTPConnection(host, port, timeout=5)
    try:
        connection.request(
            method,
            path,
            body=body,
            headers={"Content-Type": "application/json"} if body else {},
        )
        response = connection.getresponse()
        return response.status, response.read().decode("utf-8")
    finally:
        connection.close()


def test_http_endpoints_serve_status_info_submit_and_not_found(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(server_module, "PRIMITIVE_INVOCATION_LOG", tmp_path / "primitive_invocations.jsonl")

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()

    try:
        status_code, status_body = request(server, "GET", "/status")
        info_code, info_body = request(server, "GET", "/mk3/info")
        auth_code, auth_body = request(server, "GET", "/auth/creator")
        primitives_code, primitives_body = request(server, "GET", "/auth/primitives")
        invoke_code, invoke_body = request(
            server,
            "POST",
            "/auth/primitives/invoke",
            '{"primitive":"F","payload":{"scope":"full","canary":true}}',
        )
        submit_code, submit_body = request(server, "POST", "/submit", '{"packet":"test"}')
        missing_code, missing_body = request(server, "GET", "/missing")
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)

    assert status_code == 200
    assert '"status": "OK"' in status_body
    assert info_code == 200
    assert '"name": "Codex MK3"' in info_body
    assert auth_code == 200
    assert '"status": "CREATOR_AUTH_READY"' in auth_body
    assert '"secret_material": "prohibited_in_repository"' in auth_body
    assert primitives_code == 200
    assert '"status": "PRIMITIVES_UNLOCKED"' in primitives_body
    assert '"primitive_range": "A-J"' in primitives_body
    assert invoke_code == 200
    assert '"status": "CANARY_ACCEPTED"' in invoke_body
    assert '"primitive": "F"' in invoke_body
    assert '"external_effects": "none"' in invoke_body
    assert submit_code == 200
    assert '"status": "ACCEPTED"' in submit_body
    assert '"bytes_received": 17' in submit_body
    assert missing_code == 404
    assert '"error": "not_found"' in missing_body
