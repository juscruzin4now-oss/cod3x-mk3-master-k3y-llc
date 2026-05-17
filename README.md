# CODEX MK3 Structural Update Package

This workspace contains an executable MK3 package generated from the upload sequence.

## Run

```powershell
.\scripts\run_mk3.ps1
```

For the full execution context:

```powershell
.\scripts\run_mk3.ps1 -Json
```

## Components

- `environment`: verifies connection, auth, shell state, and mounted root.
- `framework`: imports the base package and activates heartbeat.
- `channels`: opens core logic, interface, and external channels.
- `packet`: initiates packet transfer and waits for receipt.
- `integration`: verifies logs, conflicts, and module registration.
- `advancement`: advances the upload loop and monitors stability.

## Server

Run the local command interface API:

```powershell
.\scripts\run_server.ps1
```

Available endpoints:

- `GET /status`
- `GET /mk3/info`
- `POST /submit`

Run diagnostics:

```powershell
.\scripts\run_diagnostics.ps1
```

Cloud/server architecture lives in `habitat/architecture.yaml`, with a local container sketch in `habitat/docker-compose.yml`.

## Stripe

Set your Stripe secret key in the environment, then run the balance check:

```powershell
$env:STRIPE_SECRET_KEY = "sk_live_or_test_key_here"
.\scripts\stripe_balance.ps1
```

The key is never stored in the repository.
