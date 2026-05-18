param(
    [string]$SnapshotId,
    [string]$CreatorConfirmation
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if ([string]::IsNullOrWhiteSpace($SnapshotId)) {
    throw "SnapshotId is required. Example: predeploy-20260517T203708Z"
}

$Expected = "CONFIRM ROLLBACK G $SnapshotId"
if ($CreatorConfirmation -ne $Expected) {
    [ordered]@{
        status = "ROLLBACK_G_BLOCKED"
        reason = "Explicit Creator confirmation required."
        required_confirmation = $Expected
        snapshot_id = $SnapshotId
        production_change_started = $false
    } | ConvertTo-Json -Depth 5
    exit 1
}

$SnapshotPath = Join-Path $Root "ops\snapshots\$SnapshotId"
if (-not (Test-Path $SnapshotPath)) {
    throw "Snapshot not found: $SnapshotPath"
}

$BundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python -and $Python.Source -notlike "*\WindowsApps\python.exe") {
    $PythonExe = $Python.Source
} elseif (Test-Path $BundledPython) {
    $PythonExe = $BundledPython
} else {
    throw "No Python runtime found."
}

$Result = & $PythonExe -c "from mk3_system.server import invoke_primitive; import json; print(json.dumps(invoke_primitive('G', {'scope':'rollback','canary':True,'snapshot':'$SnapshotId'}), indent=2))" | ConvertFrom-Json

[ordered]@{
    status = "ROLLBACK_G_CANARY_ACCEPTED"
    primitive = $Result.primitive
    snapshot_id = $SnapshotId
    confirmation = "accepted"
    external_effects = $Result.external_effects
    note = "Rollback primitive G is armed and audited. Repository rollback must be performed by a separate explicit restore command."
} | ConvertTo-Json -Depth 5
