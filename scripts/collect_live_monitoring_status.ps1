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

$Canary = & .\scripts\monitor_dev_canary.ps1 | ConvertFrom-Json
$StageReport = Read-JsonFile (Get-LatestJsonFile -Path "ops\reports" -Filter "stage-test-summary.json")
$ProductionPackage = Read-JsonFile (Get-LatestJsonFile -Path "ops\production" -Filter "production-promotion-manifest.json")
$LaunchSchedule = Read-JsonFile (Get-LatestJsonFile -Path "ops\launch" -Filter "public-launch-schedule.json")
$Snapshot = Read-JsonFile (Get-LatestJsonFile -Path "ops\snapshots" -Filter "snapshot-manifest.json")

$Status = [ordered]@{
    status = if ($Canary.status -eq "DEV_CANARY_HEALTHY" -and $StageReport.status -eq "STAGE_REPORT_PASS") { "LIVE_MONITORING_HEALTHY" } else { "LIVE_MONITORING_ATTENTION_REQUIRED" }
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    dev_canary = $Canary
    stage_report = $StageReport
    production_package = $ProductionPackage
    launch_schedule = $LaunchSchedule
    pre_promotion_snapshot = $Snapshot
    production_change_started = $false
}

$OutputPath = Join-Path $Root "web\ui\root\monitoring-status.json"
$Status | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $OutputPath
$Status["status_file"] = $OutputPath
$Status | ConvertTo-Json -Depth 10
