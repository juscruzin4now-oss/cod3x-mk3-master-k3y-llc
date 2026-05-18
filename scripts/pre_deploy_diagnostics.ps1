param(
    [switch]$SkipApiHealth
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

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($Arguments -join ' ')"
    }
}

Invoke-Checked -FilePath $PythonExe -Arguments @($PythonArgs + @("-m", "pytest"))
& .\scripts\verify_mk3.ps1
& .\scripts\run_diagnostics.ps1
& .\scripts\module_status.ps1 | Out-Host
Invoke-Checked -FilePath $PythonExe -Arguments @($PythonArgs + @("-c", "from mk3_system.server import invoke_primitive; import json; print(json.dumps(invoke_primitive('F', {'scope':'full','canary':True}), indent=2))"))

if (-not $SkipApiHealth) {
    $Port = if ($env:MK3_API_PORT) { $env:MK3_API_PORT } else { "8080" }
    $BaseUrl = if ($env:MK3_API_BASE_URL) { $env:MK3_API_BASE_URL } else { "http://127.0.0.1:$Port" }
    $Server = Start-Process -FilePath $PythonExe -ArgumentList @($PythonArgs + @("-m", "mk3_system.server", "--host", "127.0.0.1", "--port", $Port)) -WorkingDirectory $Root -WindowStyle Hidden -PassThru
    try {
        Start-Sleep -Seconds 2
        & .\scripts\health_check.ps1 -BaseUrl $BaseUrl
    } finally {
        if ($Server -and -not $Server.HasExited) {
            Stop-Process -Id $Server.Id -Force
        }
    }
}
