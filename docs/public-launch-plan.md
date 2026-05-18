# Public Launch Plan

Public launch starts only after production promotion is approved and post-deploy verification passes.

## Readiness Gates

- Dev canary reports `DEV_CANARY_HEALTHY`.
- Stage artifact reports `STAGE_ARTIFACT_READY`.
- Stage integration and load tests report `STAGE_TESTS_PASS`.
- Production environment variables and maintenance window are set.
- Post-deploy verification reports `POST_DEPLOY_VERIFY_PASS`.
- Stripe production payment smoke is manually confirmed by the Creator/operator.
- Public launch window, launch owner, support owner, rollback owner, release notes, and support readiness are bound.

## Launch Workstreams

- Release notes: summarize MK3 version, primitive access policy, deployment pipeline, and known safety boundaries.
- Support readiness: prepare escalation owner, rollback path, and first 48-hour watch schedule.
- Marketing: align prelaunch phase assets, public copy, and launch timing.
- Operations: monitor request latency, error rate, active users, task volume, and autonomy loop stability.

## No-Go Conditions

- Any failed canary, stage, or post-deploy check.
- Missing DNS, TLS, secret manager, or maintenance window.
- Any automatic wallet, purchase, payment, or live Stripe movement path.
- Unreviewed production environment configuration.

## Schedule Command

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\schedule_public_launch.ps1
```

The command writes `ops/launch/public-launch-schedule.json` and returns `PUBLIC_LAUNCH_SCHEDULED` only when dev canary, stage tests, post-deploy verification, production bindings, and launch readiness values are all present.

Required launch values:

```text
PUBLIC_LAUNCH_WINDOW_UTC
PUBLIC_LAUNCH_OWNER
PUBLIC_SUPPORT_OWNER
PUBLIC_ROLLBACK_OWNER
PUBLIC_RELEASE_NOTES_READY
PUBLIC_SUPPORT_READY
```

## Cutover Operations

- Keep intensive monitoring active for the first 60 minutes after cutover.
- Confirm marketing assets at T-1 hour only after `PUBLIC_LAUNCH_SCHEDULED`.
- Confirm support standby at T-1 hour only after `PUBLIC_SUPPORT_READY`.
- If any high-severity alert appears, rollback primitive `G` requires explicit Creator confirmation in the form `CONFIRM ROLLBACK G <snapshot-id>`.
- Prepare 24-hour and 72-hour stability reviews with the post-deploy stakeholder report attached.
