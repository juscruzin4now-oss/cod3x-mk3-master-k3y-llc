# Deployment Pipeline

The MK3 promotion pipeline is gated by local and CI diagnostics before any hosted deployment step.

## CI

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`.

It verifies:

- Python dependency installation.
- Unit tests.
- MK3 structural verification.
- Diagnostics.
- Pre-deployment diagnostics without starting the API server.

## Promotion

`.github/workflows/promotion.yml` is manually dispatched with a target environment of `staging` or `production`.

The promotion job runs:

- Pre-deployment diagnostics.
- Optional Stripe test checkout when `STRIPE_SECRET_KEY` and `STRIPE_TEST_PRICE_ID` are present as GitHub environment secrets.
- Stage artifact packaging when `target_environment` is `staging`.
- Stage integration and load tests when `target_environment` is `staging`.
- A promotion gate that confirms the package is ready for an external deployment binding.

Hosted deployment is intentionally external to this repository until the production target, DNS, TLS, and secret manager are named.

## Stripe Binding

Bind Stripe through environment variables or GitHub environment secrets only:

```text
STRIPE_SECRET_KEY
STRIPE_TEST_PRICE_ID
STRIPE_SUCCESS_URL
STRIPE_CANCEL_URL
```

The test checkout script accepts only `sk_test_` keys. Live-mode payment activity remains manual and operator-confirmed.

## Local Pre-Deploy

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pre_deploy_diagnostics.ps1
```

For checks that do not start the local API server:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pre_deploy_diagnostics.ps1 -SkipApiHealth
```

Create a checkpoint before production changes:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\create_pre_deploy_snapshot.ps1
```

Snapshots are written under `ops/snapshots/` with Git status, worktree diff, tracked file list, and a SHA-256 manifest.

## Dev Canary Monitoring

Run a lightweight canary monitor:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\monitor_dev_canary.ps1
```

The monitor checks diagnostics, briefly starts the local API, runs API health, invokes primitive `F` with `{"scope":"dev","canary":true}`, and reports `DEV_CANARY_HEALTHY` only when all checks pass.

## Stage Promotion

Promote verified artifacts to a stage package:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\promote_to_stage.ps1
```

Run stage integration and load tests:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\stage_integration_load_tests.ps1
```

Continue stage tests to completion and collect full reports:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\continue_stage_tests_and_report.ps1
```

Prepare a production promotion package and pre-promotion snapshot after stage passes:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare_production_promotion_package.ps1
```

Production approval remains blocked until production target, DNS, TLS, secret manager, maintenance window, and approver values are bound:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\approve_prod_promotion.ps1
```

Post-deploy verification requires `PROD_API_BASE_URL`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\post_deploy_verification.ps1
```

Execute the final production promotion gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\execute_prod_promotion_and_verify.ps1 -CreatorCommand "EXECUTE PROD PROMOTION NOW"
```

This command records the explicit execute request and blocks traffic cutover unless production bindings, public launch scheduling, production package, snapshot, monitoring, and a real cutover provider binding are present.

Schedule public launch after all production and launch gates are bound:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\schedule_public_launch.ps1
```

Run first-hour intensive monitoring after cutover:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\intensive_post_cutover_monitor.ps1
```

Prepare stability reviews:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare_stability_review.ps1 -Window 24h
powershell -ExecutionPolicy Bypass -File .\scripts\prepare_stability_review.ps1 -Window 72h
```
