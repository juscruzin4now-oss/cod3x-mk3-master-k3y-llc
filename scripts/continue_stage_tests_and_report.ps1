$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$ReportRoot = Join-Path $Root "ops\reports"
$ReportDir = Join-Path $ReportRoot "stage-test-$Stamp"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$BundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$Python = Get-Command python -ErrorAction SilentlyContinue
$PyLauncher = Get-Command py -ErrorAction SilentlyContinue

if ($Python -and $Python.Source -notlike "*\WindowsApps\python.exe") {
    $PythonExe = $Python.Source
    $PythonArgs = @()
} elseif ($PyLauncher) {
    $PythonExe = $PyLauncher.Source
    $PythonArgs = @("-3")
} elseif (Test-Path $BundledPython) {
    $PythonExe = $BundledPython
    $PythonArgs = @()
} else {
    throw "No Python runtime found. Install Python or run from a Codex workspace with bundled dependencies."
}

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$OutputPath
    )

    $Output = & $FilePath @Arguments 2>&1
    $Output | Set-Content -Encoding UTF8 $OutputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($Arguments -join ' ')"
    }
    $Output
}

$PytestPath = Join-Path $ReportDir "pytest.txt"
$VerifyPath = Join-Path $ReportDir "verify_mk3.json"
$DiagnosticsPath = Join-Path $ReportDir "diagnostics.txt"
$CanaryPath = Join-Path $ReportDir "dev-canary.json"
$Stage100Path = Join-Path $ReportDir "stage-load-100.json"
$Stage500Path = Join-Path $ReportDir "stage-load-500.json"
$Stage1000Path = Join-Path $ReportDir "stage-load-1000.json"
$SummaryPath = Join-Path $ReportDir "stage-test-summary.json"

Invoke-Checked -FilePath $PythonExe -Arguments @($PythonArgs + @("-m", "pytest")) -OutputPath $PytestPath | Out-Null
& .\scripts\verify_mk3.ps1 | Set-Content -Encoding UTF8 $VerifyPath
if (-not $?) { throw "MK3 verification failed." }
& .\scripts\run_diagnostics.ps1 | Set-Content -Encoding UTF8 $DiagnosticsPath
if (-not $?) { throw "Diagnostics failed." }

$Canary = & .\scripts\monitor_dev_canary.ps1 | Tee-Object -FilePath $CanaryPath | ConvertFrom-Json
$Stage100 = & .\scripts\stage_integration_load_tests.ps1 -Requests 100 | Tee-Object -FilePath $Stage100Path | ConvertFrom-Json
$Stage500 = & .\scripts\stage_integration_load_tests.ps1 -Requests 500 | Tee-Object -FilePath $Stage500Path | ConvertFrom-Json
$Stage1000 = & .\scripts\stage_integration_load_tests.ps1 -Requests 1000 | Tee-Object -FilePath $Stage1000Path | ConvertFrom-Json

$StageRuns = @($Stage100, $Stage500, $Stage1000)
$Warnings = @()
foreach ($Run in $StageRuns) {
    if ($Run.p95_latency_ms -ge 500 -and $Run.p95_latency_ms -lt 750) {
        $Warnings += "medium_latency_warning_$($Run.requests)_requests"
    }
    if ($Run.error_rate_percent -gt 0 -and $Run.error_rate_percent -lt 2) {
        $Warnings += "medium_error_rate_warning_$($Run.requests)_requests"
    }
}

$Status = if (
    $Canary.status -eq "DEV_CANARY_HEALTHY" -and
    ($StageRuns | Where-Object { $_.status -ne "STAGE_TESTS_PASS" }).Count -eq 0 -and
    $Warnings.Count -eq 0
) { "STAGE_REPORT_PASS" } else { "STAGE_REPORT_ATTENTION_REQUIRED" }

$Summary = [ordered]@{
    status = $Status
    report_id = "stage-test-$Stamp"
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    report_dir = $ReportDir
    dev_canary = $Canary
    stage_runs = $StageRuns
    warnings = $Warnings
    production_change_started = $false
    files = [ordered]@{
        pytest = $PytestPath
        verify_mk3 = $VerifyPath
        diagnostics = $DiagnosticsPath
        dev_canary = $CanaryPath
        stage_load_100 = $Stage100Path
        stage_load_500 = $Stage500Path
        stage_load_1000 = $Stage1000Path
    }
}

$Summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $SummaryPath
$Summary["summary"] = $SummaryPath
$Summary | ConvertTo-Json -Depth 8

if ($Status -ne "STAGE_REPORT_PASS") {
    exit 1
}
