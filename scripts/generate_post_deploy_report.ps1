$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$OutputRoot = Join-Path $Root "ops\reports\stakeholders"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$OutputPath = Join-Path $OutputRoot "post-deploy-stakeholder-report-$Stamp.md"

$Monitoring = & .\scripts\collect_live_monitoring_status.ps1 | ConvertFrom-Json
$PostDeploy = if ([string]::IsNullOrWhiteSpace($env:PROD_API_BASE_URL)) {
    [pscustomobject]@{
        status = "POST_DEPLOY_BLOCKED"
        reason = "Missing PROD_API_BASE_URL."
        production_change_started = $false
    }
} else {
    & .\scripts\post_deploy_verification.ps1 | ConvertFrom-Json
}

$Lines = @(
    "# MK3 Post-Deploy Stakeholder Report",
    "",
    "Generated UTC: $((Get-Date).ToUniversalTime().ToString("o"))",
    "",
    "## Executive Status",
    "",
    "- Live monitoring: $($Monitoring.status)",
    "- Dev canary: $($Monitoring.dev_canary.status)",
    "- Stage report: $($Monitoring.stage_report.status)",
    "- Production package: $($Monitoring.production_package.status)",
    "- Post-deploy verification: $($PostDeploy.status)",
    "- Production change started: false",
    "",
    "## Stage Evidence",
    "",
    "- Latest stage report: $($Monitoring.stage_report.report_id)",
    "- Warnings: $(@($Monitoring.stage_report.warnings).Count)",
    "- Latest stage p95 latency: $($Monitoring.stage_report.stage_runs[-1].p95_latency_ms) ms",
    "- Latest stage failures: $($Monitoring.stage_report.stage_runs[-1].failures)",
    "",
    "## Production Candidate",
    "",
    "- Package: $($Monitoring.production_package.package_id)",
    "- Artifact SHA-256: $($Monitoring.production_package.artifact_sha256)",
    "- Pre-promotion snapshot: $($Monitoring.production_package.pre_promotion_snapshot)",
    "",
    "## Blockers",
    "",
    "- Post-deploy verification remains blocked until PROD_API_BASE_URL is bound.",
    "- Public launch remains blocked until production and launch readiness values are bound.",
    "- Live Stripe/payment smoke remains manual and operator-confirmed.",
    "",
    "## Decision",
    "",
    "Production launch is not approved from this report. The system is stage-passed and production-package-ready, but production deployment and public launch remain gated."
)

$Lines -join "`n" | Set-Content -Encoding UTF8 $OutputPath

[ordered]@{
    status = "POST_DEPLOY_REPORT_READY"
    report = $OutputPath
    post_deploy_status = $PostDeploy.status
    production_change_started = $false
} | ConvertTo-Json -Depth 5
