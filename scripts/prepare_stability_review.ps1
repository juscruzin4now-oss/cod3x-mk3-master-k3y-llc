param(
    [ValidateSet("24h", "72h")]
    [string]$Window = "24h"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Get-LatestFile {
    param(
        [string]$Path,
        [string]$Filter
    )

    if (-not (Test-Path $Path)) {
        return $null
    }
    Get-ChildItem $Path -Recurse -File -Filter $Filter |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$ReviewRoot = Join-Path $Root "ops\reports\stability-reviews"
New-Item -ItemType Directory -Force -Path $ReviewRoot | Out-Null
$OutputPath = Join-Path $ReviewRoot "stability-review-$Window-$Stamp.md"

$Monitoring = & .\scripts\collect_live_monitoring_status.ps1 | ConvertFrom-Json
$PostDeployReport = Get-LatestFile -Path "ops\reports\stakeholders" -Filter "post-deploy-stakeholder-report-*.md"
$IntensiveSummary = Get-LatestFile -Path "ops\reports\intensive-monitoring" -Filter "intensive-monitoring-summary.json"

$Lines = @(
    "# MK3 $Window Stability Review",
    "",
    "Generated UTC: $((Get-Date).ToUniversalTime().ToString("o"))",
    "",
    "## Attached Reports",
    "",
    "- Post-deploy stakeholder report: $($PostDeployReport.FullName)",
    "- Intensive monitoring summary: $($IntensiveSummary.FullName)",
    "",
    "## Current Signals",
    "",
    "- Live monitoring: $($Monitoring.status)",
    "- Dev canary: $($Monitoring.dev_canary.status)",
    "- Stage report: $($Monitoring.stage_report.status)",
    "- Production package: $($Monitoring.production_package.status)",
    "- Public launch: $($Monitoring.launch_schedule.status)",
    "- Production change started: false",
    "",
    "## Review Decision",
    "",
    "Production stability review cannot be finalized until production cutover and post-deploy verification occur. Current state remains production-package-ready and launch-gated."
)

$Lines -join "`n" | Set-Content -Encoding UTF8 $OutputPath

[ordered]@{
    status = "STABILITY_REVIEW_PREPARED"
    window = $Window
    review = $OutputPath
    post_deploy_report = $PostDeployReport.FullName
    intensive_monitoring_summary = $IntensiveSummary.FullName
    production_change_started = $false
} | ConvertTo-Json -Depth 5
