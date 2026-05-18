param(
    [int]$Port = 8080,
    [int]$Requests = 50
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

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

$BaseUrl = "http://127.0.0.1:$Port"
$Server = Start-Process -FilePath $PythonExe -ArgumentList @($PythonArgs + @("-m", "mk3_system.server", "--host", "127.0.0.1", "--port", $Port)) -WorkingDirectory $Root -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Seconds 2
    $Health = & .\scripts\health_check.ps1 -BaseUrl $BaseUrl | ConvertFrom-Json
    if (-not $?) {
        throw "Health check failed with exit code $LASTEXITCODE."
    }

    $Latencies = @()
    $Failures = 0
    for ($Index = 0; $Index -lt $Requests; $Index++) {
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $null = Invoke-RestMethod -Method Get -Uri "$BaseUrl/status" -TimeoutSec 5
        } catch {
            $Failures += 1
        } finally {
            $Timer.Stop()
            $Latencies += $Timer.ElapsedMilliseconds
        }
    }

    $Sorted = @($Latencies | Sort-Object)
    $P95Index = [Math]::Min($Sorted.Count - 1, [Math]::Ceiling($Sorted.Count * 0.95) - 1)
    $P95 = if ($Sorted.Count -gt 0) { $Sorted[$P95Index] } else { 0 }
    $ErrorRate = if ($Requests -gt 0) { [Math]::Round(($Failures / $Requests) * 100, 3) } else { 100 }

    $CanaryBody = '{"primitive":"F","payload":{"scope":"stage","canary":true}}'
    $Canary = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/primitives/invoke" -Body $CanaryBody -ContentType "application/json"
} finally {
    if ($Server -and -not $Server.HasExited) {
        Stop-Process -Id $Server.Id -Force
    }
}

$Status = if (
    $Health.status_endpoint -eq "OK" -and
    $Health.creator_auth -eq "CREATOR_AUTH_READY" -and
    $Health.primitive_access -eq "PRIMITIVES_UNLOCKED" -and
    $Canary.status -eq "CANARY_ACCEPTED" -and
    $Failures -eq 0 -and
    $P95 -lt 750
) { "STAGE_TESTS_PASS" } else { "STAGE_TESTS_ATTENTION_REQUIRED" }

[ordered]@{
    status = $Status
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    requests = $Requests
    failures = $Failures
    error_rate_percent = $ErrorRate
    p95_latency_ms = $P95
    api = $Health.status_endpoint
    creator_auth = $Health.creator_auth
    primitive_access = $Health.primitive_access
    primitive_f = $Canary.status
    external_effects = $Canary.external_effects
} | ConvertTo-Json -Depth 5
