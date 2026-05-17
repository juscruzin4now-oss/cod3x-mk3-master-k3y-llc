# Deployment Notes

Codex MK3 is currently packaged for local operator use first. Treat deployment as a controlled promotion of the same verified package, not as a separate behavior path.

## Local Operator Mode

Use local operator mode for normal development and review:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_mk3.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\run_diagnostics.ps1
```

Start the local API only when you need endpoint access:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_server.ps1
```

The default API bind address is `127.0.0.1:8080`.

## Container Sketch

The repository includes `habitat/docker-compose.yml` as a sketch for local container planning. Review `habitat/architecture.yaml` before promoting any service beyond local use.

Before using containers, confirm:

- Python dependencies are installed from `requirements.txt`.
- The command interface API binds only to the intended host and port.
- Secrets are provided by environment variables or a secure secret manager.
- `.env` files are not committed.

## Promotion Guidelines

- Run tests, verification, diagnostics, and API health checks before promotion.
- Keep `VERSION`, `CHANGELOG.md`, and release tags aligned.
- Prefer read-only or status endpoints until deployment boundaries are reviewed.
- Keep Stripe, wallet, payment, and purchase operations manual-only.

## Rollback

Rollback is Git-based:

```powershell
git log --oneline -5
git checkout <known-good-tag-or-commit>
```

For hosted environments, redeploy the known-good tag or commit after verifying diagnostics locally.
