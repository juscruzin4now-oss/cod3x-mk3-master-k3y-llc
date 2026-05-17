from http.client import HTTPConnection
from threading import Thread

from mk3_system.server import Handler, ThreadingHTTPServer, creator_auth_status, mk3_info, module_status


def test_module_status_reports_online_packets() -> None:
    modules = module_status()

    assert modules["CORE"]["status"] == "CORE_ONLINE"
    assert modules["WEB"]["status"] == "WEB_ONLINE"
    assert modules["APP"]["status"] == "APP_ONLINE"
    assert "creator.auth" not in modules["APP"]["missing"]
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


def test_http_endpoints_serve_status_info_submit_and_not_found() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()

    try:
        status_code, status_body = request(server, "GET", "/status")
        info_code, info_body = request(server, "GET", "/mk3/info")
        auth_code, auth_body = request(server, "GET", "/auth/creator")
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
    assert submit_code == 200
    assert '"status": "ACCEPTED"' in submit_body
    assert '"bytes_received": 17' in submit_body
    assert missing_code == 404
    assert '"error": "not_found"' in missing_body
