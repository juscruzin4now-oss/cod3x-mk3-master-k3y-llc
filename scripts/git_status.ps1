$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Git = Get-Command git -ErrorAction SilentlyContinue
if (-not $Git) {
    $Fallback = "C:\Program Files\Git\cmd\git.exe"
    if (Test-Path $Fallback) {
        $GitPath = $Fallback
    } else {
        throw "Git is not available on PATH and was not found at $Fallback."
    }
} else {
    $GitPath = $Git.Source
}

& $GitPath status --short
