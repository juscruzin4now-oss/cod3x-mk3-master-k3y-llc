$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$BundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$Python = Get-Command python -ErrorAction SilentlyContinue

if ($Python -and $Python.Source -notlike "*\WindowsApps\python.exe") {
    $PythonExe = $Python.Source
} elseif (Test-Path $BundledPython) {
    $PythonExe = $BundledPython
} else {
    throw "No Python runtime found."
}

& $PythonExe -m integrations.stripe_checkout
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
