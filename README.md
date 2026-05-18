# CODEX MK3 Master K3Y LLC

Codex MK3 is a structural upload package for the MK3 operator system. It contains the core manifest, module registry maps, interface scaffolding, prelaunch planning packets, local diagnostics, and a small command interface API.

The current package is designed to be run locally first. Wallet, purchase, and Stripe actions remain manual-only and require an explicit operator step.

## Repository Layout

- `CHANGELOG.md` - Build history and release notes.
- `DEPLOYMENT.md` - Local and promoted deployment notes.
- `RELEASE_CHECKLIST.md` - Pre-tag release checklist.
- `VERSION` - Current package version.
- `mk3_system/` - Python CLI, orchestrator, diagnostics, component model, and local API server.
- `scripts/` - PowerShell entry points for running MK3, diagnostics, module status, server, Git status, and Stripe balance checks.
- `system/` - Core behavior, parser schema, manifest, and mimic engine maps.
- `web/` - Root UI layout, router maps, API endpoint definitions, and branding embed.
- `app/` - App screen registry, logic flow, and permission maps.
- `docs/creator-auth.md` - Creator auth policy notes and operator rules.
- `docs/primitive-access.md` - Creator-level primitive access notes for primitives A-J.
- `docs/deployment-pipeline.md` - CI/CD promotion, pre-deploy diagnostics, and Stripe test checkout notes.
- `docs/public-launch-plan.md` - Launch readiness gates, workstreams, and no-go conditions.
- `branding/` - Identity, tone, and logo placement guidance.
- `marketing/prelaunch/` - Five-phase prelaunch packet plan.
- `habitat/` - Architecture spec and local container sketch.
- `integrations/` - Optional integration helpers.

## Prerequisites

- Windows PowerShell.
- Python 3.10+ available as `python`, `py -3`, or through the Codex bundled runtime.
- Git for Windows if you plan to commit and push changes.
- Optional: a Stripe secret key for manual balance checks.

Install Python dependencies when you want to use optional integrations:

```powershell
python -m pip install -r requirements.txt
```

If `python` points to the Microsoft Store launcher, use:

```powershell
py -3 -m pip install -r requirements.txt
```

Create local environment settings only if you need to override defaults:

```powershell
Copy-Item .env.example .env
```

Do not put real secrets in committed files. `.env` and `.env.*` are ignored by Git.

## Quick Start

From the repository root:

```powershell
.\scripts\run_mk3.ps1
```

If PowerShell blocks local scripts on your machine, run the command through a process-scoped execution policy bypass:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_mk3.ps1
```

For machine-readable output:

```powershell
.\scripts\run_mk3.ps1 -Json
```

Verify the package:

```powershell
.\scripts\verify_mk3.ps1
```

Record the Creator-authorized release step:

```powershell
.\scripts\release_step_creator_auth.ps1
```

Run diagnostics:

```powershell
.\scripts\run_diagnostics.ps1
```

Monitor the dev canary:

```powershell
.\scripts\monitor_dev_canary.ps1
```

For machine-readable diagnostics:

```powershell
.\scripts\run_diagnostics.ps1 -Json
```

Run the Python test suite:

```powershell
python -m pytest
```

Check module packet status:

```powershell
.\scripts\module_status.ps1
```

## Local API Server

Start the command interface API:

```powershell
.\scripts\run_server.ps1
```

The server listens on:

```text
http://127.0.0.1:8080
```

Available endpoints:

- `GET /status` - Returns module health and missing packet status.
- `GET /mk3/info` - Returns MK3 metadata, services, architecture path, and module report.
- `GET /auth/creator` - Returns creator auth policy readiness and guard status.
- `POST /submit` - Accepts a submitted packet body and returns byte count.

Example requests:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/status
Invoke-RestMethod http://127.0.0.1:8080/mk3/info
Invoke-RestMethod http://127.0.0.1:8080/auth/creator
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8080/submit -Body '{"packet":"demo"}' -ContentType 'application/json'
```

Stop the server with `Ctrl+C` in the terminal where it is running.

Run the API health check from another terminal while the server is running:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\health_check.ps1
```

To point at another server:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\health_check.ps1 -BaseUrl http://127.0.0.1:8080
```

## Git Workflow

Check the current branch, local changes, and recent commits:

```powershell
.\scripts\git_status.ps1
```

Standard update flow:

```powershell
git status
git add .
git commit -m "Describe the update"
git push
```

The current remote is expected to be:

```text
https://github.com/juscruzin4now-oss/cod3x-mk3-master-k3y-llc.git
```

GitHub Actions runs the Python tests, MK3 verification, and diagnostics on pushes to `main` and on pull requests.

## Release Workflow

Release notes live in `CHANGELOG.md`, deployment notes live in `DEPLOYMENT.md`, and pre-tag checks live in `RELEASE_CHECKLIST.md`.

The current package version is tracked in:

```text
VERSION
```

## Stripe Balance Check

Stripe support is intentionally limited to a manual balance check. The repository does not store API keys.

Set your key only in the current shell session:

```powershell
$env:STRIPE_SECRET_KEY = "sk_live_or_test_key_here"
.\scripts\stripe_balance.ps1
```

Do not commit secrets, `.env` files, screenshots of keys, or terminal output that contains credentials.

## Components

- `environment` - Verifies connection, auth, shell state, and mounted root.
- `framework` - Imports the base package and activates heartbeat.
- `channels` - Opens core logic, interface, and external channels.
- `packet` - Initiates packet transfer and waits for receipt.
- `integration` - Verifies logs, conflicts, and module registration.
- `advancement` - Advances the upload loop and monitors stability.

## Safety Boundary

This repository may describe wallet, purchase, automation, and integration surfaces, but it does not perform purchases or move funds automatically. Any wallet, Stripe, payment, or purchase action must remain manual and operator-confirmed.

Creator authority is described in `app/security/creator_auth/creator.auth` and documented in `docs/creator-auth.md`. Primitive access is described in `app/security/primitives/primitive_access.map` and documented in `docs/primitive-access.md`. These packets are policy only; they must not contain passwords, tokens, keys, recovery phrases, or other secret material.

## Next Build Targets

- Keep release tags aligned with `VERSION` and `CHANGELOG.md`.
- Expand endpoint tests when the command interface API gains new routes.
- Promote deployment notes as the package moves beyond local operator use.
