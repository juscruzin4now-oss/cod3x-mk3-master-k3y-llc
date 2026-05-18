# Primitive Access

`primitive_access.map` defines Creator-level invocation access for MK3 primitives A-J. It is a policy packet, not an execution bypass and not a credential store.

## Policy Location

```text
app/security/primitives/primitive_access.map
app/security/primitives/registry.json
```

## Intent

- Mark primitives A-J as unlocked for Creator-level invocation.
- Keep delegate operators and observers outside primitive invocation authority.
- Require audit logging for primitive invocation.
- Keep secret material outside the repository.
- Preserve manual confirmation for external effects such as network publish, payment, wallet, or credential actions.

## Verification

Primitive access is included in the APP module status check and diagnostics. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_diagnostics.ps1
python -m pytest
```

When the local API is running, primitive access policy status is available at:

```text
GET /auth/primitives
```

Canary invocation is available through:

```text
POST /auth/primitives/invoke
```

with a body such as:

```json
{"primitive":"F","payload":{"scope":"full","canary":true}}
```

Canary invocation writes an audit event and performs no external effects. Non-canary invocation returns `MANUAL_CONFIRMATION_REQUIRED`.
