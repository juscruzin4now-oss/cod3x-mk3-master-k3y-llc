# Changelog

All notable Codex MK3 package updates are tracked here.

## Unreleased

- Keep release tags aligned with `VERSION` and `CHANGELOG.md`.
- Expand endpoint tests when the command interface API gains new routes.
- Promote deployment notes as the package moves beyond local operator use.

## 2026-05-17

### Added

- Initial Codex MK3 structural upload package.
- Core manifest, component model, orchestrator, CLI, diagnostics, and local API server.
- Module registries for system, web, app, branding, and prelaunch packets.
- PowerShell scripts for running MK3, diagnostics, module status, local server, Git status, and Stripe balance checks.
- README setup, run, verification, API, Git, and safety instructions.
- `.env.example` with non-secret local configuration names.
- `.gitignore` protection for real `.env` files.
- API health-check script for `/status`, `/mk3/info`, and `/submit`.
- Python tests for orchestrator, diagnostics, and server metadata helpers.
- GitHub Actions CI for tests, MK3 verification, and diagnostics.
- `VERSION`, `RELEASE_CHECKLIST.md`, and `DEPLOYMENT.md` release support files.
- HTTP endpoint tests for `/status`, `/mk3/info`, `/submit`, and not-found responses.

### Changed

- Updated `run_mk3.ps1` and `verify_mk3.ps1` to skip the Windows Store Python alias and fall back to a usable Python runtime.
- Improved diagnostics output with a readable operator report by default and JSON output behind `-Json`.

### Safety

- Documented that Stripe, wallet, payment, and purchase actions remain manual-only and operator-confirmed.
