from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_static_api_definition_lists_runtime_endpoints() -> None:
    endpoints = (ROOT / "web" / "api" / "definitions" / "api_endpoints.list").read_text(encoding="utf-8")

    assert "GET /status" in endpoints
    assert "GET /mk3/info" in endpoints
    assert "GET /auth/creator" in endpoints
    assert "GET /auth/primitives" in endpoints
    assert "POST /auth/primitives/invoke" in endpoints
    assert "POST /submit" in endpoints
