# Release Checklist

Use this checklist before tagging a Codex MK3 release.

## Preflight

- Confirm `VERSION` matches the intended release version.
- Confirm `mk3_structural_update.json` uses the same version.
- Update `CHANGELOG.md` with the release date and notable changes.
- Confirm no real `.env`, Stripe, wallet, payment, or credential files are staged.

## Verification

```powershell
python -m pytest
powershell -ExecutionPolicy Bypass -File .\scripts\verify_mk3.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\run_diagnostics.ps1
```

For API checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_server.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\health_check.ps1
```

Stop the server with `Ctrl+C` after the health check passes.

## Tagging

```powershell
git status
git tag v3.0.0
git push origin v3.0.0
```

Replace `v3.0.0` with the release version.

## Safety Boundary

Do not tag a release that introduces automatic wallet, purchase, payment, or Stripe fund movement. Those actions must remain manual and operator-confirmed.
