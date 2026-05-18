param(
    [string]$CreatorCommand = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Get-LatestJsonFile {
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

function Read-JsonFile {
    param([object]$File)

    if (-not $File) {
        return $null
    }
    Get-Content -Raw $File.FullName | ConvertFrom-Json
}

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$AttemptRoot = Join-Path $Root "ops\production"
$AttemptDir = Join-Path $AttemptRoot "prod-execution-$Stamp"
New-Item -ItemType Directory -Force -Path $AttemptDir | Out-Null

$Required = [ordered]@{
    PROD_DEPLOY_TARGET = $env:PROD_DEPLOY_TARGET
    PROD_API_BASE_URL = $env:PROD_API_BASE_URL
    PROD_DNS_NAME = $env:PROD_DNS_NAME
    PROD_TLS_READY = $env:PROD_TLS_READY
    PROD_SECRET_MANAGER = $env:PROD_SECRET_MANAGER
    PROD_MAINTENANCE_WINDOW = $env:PROD_MAINTENANCE_WINDOW
    PROD_APPROVER = $env:PROD_APPROVER
    PROD_CUTOVER_PROVIDER = $env:PROD_CUTOVER_PROVIDER
}

$Missing = @($Required.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Value) } | ForEach-Object { $_.Key })
$Invalid = @()
if ($env:PROD_TLS_READY -and $env:PROD_TLS_READY -notin @("true", "TRUE", "ready", "READY", "1")) {
    $Invalid += "PROD_TLS_READY"
}

$ProductionPackage = Read-JsonFile (Get-LatestJsonFile -Path "ops\production" -Filter "production-promotion-manifest.json")
$LaunchSchedule = Read-JsonFile (Get-LatestJsonFile -Path "ops\launch" -Filter "public-launch-schedule.json")
$Monitoring = & .\scripts\collect_live_monitoring_status.ps1 | ConvertFrom-Json

$CommandAccepted = $CreatorCommand -eq "EXECUTE PROD PROMOTION NOW"
$PackageReady = $ProductionPackage -and $ProductionPackage.status -eq "PRODUCTION_PROMOTION_PACKAGE_READY"
$SnapshotReady = $ProductionPackage -and -not [string]::IsNullOrWhiteSpace($ProductionPackage.pre_promotion_snapshot)
$LaunchReady = $LaunchSchedule -and $LaunchSchedule.status -eq "PUBLIC_LAUNCH_SCHEDULED"

$Blockers = @()
if (-not $CommandAccepted) { $Blockers += "explicit_execute_command_missing" }
if ($Missing.Count -gt 0) { $Blockers += "missing_production_bindings" }
if ($Invalid.Count -gt 0) { $Blockers += "invalid_production_bindings" }
if (-not $PackageReady) { $Blockers += "production_package_not_ready" }
if (-not $SnapshotReady) { $Blockers += "pre_promotion_snapshot_missing" }
if (-not $LaunchReady) { $Blockers += "public_launch_not_scheduled" }
if ($Monitoring.status -ne "LIVE_MONITORING_HEALTHY") { $Blockers += "live_monitoring_not_healthy" }

$Status = if ($Blockers.Count -eq 0) { "PROD_CUTOVER_READY_EXTERNAL_EXECUTION_REQUIRED" } else { "PROD_CUTOVER_BLOCKED" }

$Attempt = [ordered]@{
    status = $Status
    attempt_id = "prod-execution-$Stamp"
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    creator_command = if ($CommandAccepted) { "accepted" } else { "missing_or_invalid" }
    production_change_started = $false
    traffic_shift_started = $false
    post_deploy_verification_started = $false
    blockers = $Blockers
    missing_production_bindings = $Missing
    invalid_production_bindings = $Invalid
    production_package = $ProductionPackage
    launch_schedule_status = $LaunchSchedule.status
    monitoring_status = $Monitoring.status
    note = "This repository has no bound deployment-provider cutover implementation. Traffic shift remains blocked until real production bindings and provider integration are present."
}

$AttemptPath = Join-Path $AttemptDir "prod-execution-attempt.json"
$Attempt | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $AttemptPath
$Attempt["attempt_record"] = $AttemptPath
$Attempt | ConvertTo-Json -Depth 10

if ($Status -ne "PROD_CUTOVER_READY_EXTERNAL_EXECUTION_REQUIRED") {
    exit 1
}
