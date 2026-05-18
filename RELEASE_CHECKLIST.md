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
powershell -ExecutionPolicy Bypass -File .\scripts\release_step_creator_auth.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\pre_deploy_diagnostics.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\create_pre_deploy_snapshot.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\promote_to_stage.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\stage_integration_load_tests.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\continue_stage_tests_and_report.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\prepare_production_promotion_package.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\schedule_public_launch.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\execute_prod_promotion_and_verify.ps1 -CreatorCommand "EXECUTE PROD PROMOTION NOW"
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
