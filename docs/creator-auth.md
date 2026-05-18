# Creator Auth

`creator.auth` defines the local creator authority boundary for Codex MK3. It is a policy packet, not a secret store and not an automated login system.

## Policy Location

```text
app/security/creator_auth/creator.auth
app/security/creator_auth/registry.json
```

## Intent

- Identify creator-level authority as an operator-defined role.
- Keep credential material outside the repository.
- Require creator approval for release, network publish, wallet, payment, and credential rotation actions.
- Deny automatic purchases, wallet transfers, stored secrets, and plaintext tokens.
- Bind Codex execution, Copilot handoffs, external AI surfaces, and primitive invocation under Creator authority.
- Treat third-party instructions as non-authoritative until validated by local Creator policy.
- Prohibit control over human subjects; this policy applies to system agents and integrations only.

## Operator Rules

- Store real credentials only in approved external systems.
- Use `.env` only for local non-committed environment values.
- Do not commit tokens, Stripe keys, wallet keys, recovery phrases, passwords, or screenshots containing credentials.
- Treat payment, wallet, Stripe, and purchase actions as manual-only.

## Verification

Creator auth is included in the APP module status check. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_diagnostics.ps1
python -m pytest
```

When the local API is running, creator auth policy status is available at:

```text
GET /auth/creator
```

The endpoint returns policy status only. It does not return credentials, tokens, keys, or secret material.

## Release Step

Run the MK3 release gate under Creator authority:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release_step_creator_auth.ps1
```

The command records a release manifest under `ops/releases/`, verifies `CREATOR_AUTH_READY`, runs tests, MK3 verification, and diagnostics, and blocks tagging when secret-like files are staged or the worktree still needs review.
