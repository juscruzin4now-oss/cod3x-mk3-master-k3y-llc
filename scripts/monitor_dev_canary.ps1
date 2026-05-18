param(
    [int]$Port = 8080
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

function Invoke-JsonPython {
    param([string]$Code)

    $Output = & $PythonExe @PythonArgs -c $Code
    if ($LASTEXITCODE -ne 0) {
        throw "Python monitor command failed with exit code $LASTEXITCODE."
    }
    $Output | ConvertFrom-Json
}

$Diagnostics = Invoke-JsonPython "from mk3_system.diagnostics import run_diagnostics; import json; print(json.dumps(run_diagnostics()))"
$Canary = Invoke-JsonPython "from mk3_system.server import invoke_primitive; import json; print(json.dumps(invoke_primitive('F', {'scope':'dev','canary':True})))"

$BaseUrl = "http://127.0.0.1:$Port"
$Server = Start-Process -FilePath $PythonExe -ArgumentList @($PythonArgs + @("-m", "mk3_system.server", "--host", "127.0.0.1", "--port", $Port)) -WorkingDirectory $Root -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Seconds 2
    $Health = & .\scripts\health_check.ps1 -BaseUrl $BaseUrl | ConvertFrom-Json
    if (-not $?) {
        throw "Health check failed with exit code $LASTEXITCODE."
    }
} finally {
    if ($Server -and -not $Server.HasExited) {
        Stop-Process -Id $Server.Id -Force
    }
}

$Status = if (
    $Diagnostics.status -eq "DIAGNOSTICS_PASS" -and
    $Canary.status -eq "CANARY_ACCEPTED" -and
    $Health.status_endpoint -eq "OK" -and
    $Health.creator_auth -eq "CREATOR_AUTH_READY" -and
    $Health.primitive_access -eq "PRIMITIVES_UNLOCKED"
) { "DEV_CANARY_HEALTHY" } else { "DEV_CANARY_ATTENTION_REQUIRED" }

[ordered]@{
    status = $Status
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    diagnostics = $Diagnostics.status
    primitive_f = $Canary.status
    api = $Health.status_endpoint
    creator_auth = $Health.creator_auth
    primitive_access = $Health.primitive_access
    external_effects = $Canary.external_effects
} | ConvertTo-Json -Depth 5
