param(
    [int]$Iterations = 12,
    [int]$IntervalSeconds = 300
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$RunRoot = Join-Path $Root "ops\reports\intensive-monitoring"
$RunDir = Join-Path $RunRoot "post-cutover-$Stamp"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$Samples = @()
$HighSeverityAlerts = @()

for ($Index = 1; $Index -le $Iterations; $Index++) {
    $SamplePath = Join-Path $RunDir ("sample-{0:D2}.json" -f $Index)
    $Sample = & .\scripts\collect_live_monitoring_status.ps1 | Tee-Object -FilePath $SamplePath | ConvertFrom-Json
    $Samples += $SamplePath

    if ($Sample.status -ne "LIVE_MONITORING_HEALTHY") {
        $HighSeverityAlerts += "live_monitoring_$($Sample.status)_sample_$Index"
    }
    if ($Sample.dev_canary.status -ne "DEV_CANARY_HEALTHY") {
        $HighSeverityAlerts += "dev_canary_$($Sample.dev_canary.status)_sample_$Index"
    }
    if ($Sample.stage_report.status -ne "STAGE_REPORT_PASS") {
        $HighSeverityAlerts += "stage_report_$($Sample.stage_report.status)_sample_$Index"
    }

    if ($Index -lt $Iterations) {
        Start-Sleep -Seconds $IntervalSeconds
    }
}

$Status = if ($HighSeverityAlerts.Count -eq 0) { "INTENSIVE_MONITORING_PASS" } else { "INTENSIVE_MONITORING_ALERT" }
$SummaryPath = Join-Path $RunDir "intensive-monitoring-summary.json"
$Summary = [ordered]@{
    status = $Status
    started_utc = $Stamp
    completed_utc = (Get-Date).ToUniversalTime().ToString("o")
    iterations = $Iterations
    interval_seconds = $IntervalSeconds
    high_severity_alerts = $HighSeverityAlerts
    samples = $Samples
    rollback_required = $HighSeverityAlerts.Count -gt 0
    rollback_instruction = "If high severity is confirmed, execute rollback primitive G only after explicit Creator confirmation."
    production_change_started_by_monitor = $false
}

$Summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $SummaryPath
$Summary["summary"] = $SummaryPath
$Summary | ConvertTo-Json -Depth 6

if ($Status -ne "INTENSIVE_MONITORING_PASS") {
    exit 1
}
