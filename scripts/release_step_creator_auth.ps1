param(
    [string]$ReleaseVersion = "",
    [string]$CreatorAuthority = "creator.auth"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$ReleaseRoot = Join-Path $Root "ops\releases"
$ReleaseDir = Join-Path $ReleaseRoot "release-step-$Stamp"
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

if ([string]::IsNullOrWhiteSpace($ReleaseVersion)) {
    $ReleaseVersion = (Get-Content -Raw VERSION).Trim()
}

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

$CreatorAuthPath = Join-Path $ReleaseDir "creator-auth.json"
$PytestPath = Join-Path $ReleaseDir "pytest.txt"
$VerifyPath = Join-Path $ReleaseDir "verify-mk3.json"
$DiagnosticsPath = Join-Path $ReleaseDir "diagnostics.txt"
$GitStatusPath = Join-Path $ReleaseDir "git-status.txt"
$ManifestPath = Join-Path $ReleaseDir "release-step-manifest.json"

$CreatorAuth = & $PythonExe @PythonArgs -c "from mk3_system.server import creator_auth_status; import json; print(json.dumps(creator_auth_status()))" | Tee-Object -FilePath $CreatorAuthPath | ConvertFrom-Json
$AuthorityOk = $CreatorAuthority -eq "creator.auth" -and $CreatorAuth.status -eq "CREATOR_AUTH_READY"

Invoke-Checked -FilePath $PythonExe -Arguments @($PythonArgs + @("-m", "pytest")) -OutputPath $PytestPath | Out-Null
& .\scripts\verify_mk3.ps1 | Set-Content -Encoding UTF8 $VerifyPath
if (-not $?) { throw "MK3 verification failed." }
& .\scripts\run_diagnostics.ps1 | Set-Content -Encoding UTF8 $DiagnosticsPath
if (-not $?) { throw "Diagnostics failed." }
$GitStatus = @(& $GitPath status --short)
$GitStatus | Set-Content -Encoding UTF8 $GitStatusPath

$StagedFiles = @(& $GitPath diff --cached --name-only)
$StagedSecretFiles = @($StagedFiles | Where-Object { $_ -match '(^|/)\.env($|[./])|secret|token|password|wallet|recovery' })
$Dirty = ($GitStatus | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0

$Blockers = @()
if (-not $AuthorityOk) { $Blockers += "creator_auth_not_ready" }
if ($StagedSecretFiles.Count -gt 0) { $Blockers += "staged_secret_like_files" }
if ($Dirty) { $Blockers += "worktree_has_uncommitted_changes" }

$Status = if ($Blockers.Count -eq 0) { "MK3_RELEASE_STEP_READY" } else { "MK3_RELEASE_STEP_RECORDED_WITH_BLOCKERS" }
$Head = (& $GitPath rev-parse HEAD).Trim()
$Branch = (& $GitPath branch --show-current).Trim()

$Manifest = [ordered]@{
    status = $Status
    release_step_id = "release-step-$Stamp"
    release_version = $ReleaseVersion
    creator_authority = $CreatorAuthority
    creator_auth_status = $CreatorAuth.status
    release_approval_required = "creator"
    branch = $Branch
    head = $Head
    blockers = $Blockers
    tagging_allowed = $Blockers.Count -eq 0
    production_change_started = $false
    files = [ordered]@{
        creator_auth = $CreatorAuthPath
        pytest = $PytestPath
        verify_mk3 = $VerifyPath
        diagnostics = $DiagnosticsPath
        git_status = $GitStatusPath
    }
}

$Manifest | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $ManifestPath
$ManifestHash = (Get-FileHash -Algorithm SHA256 $ManifestPath).Hash.ToLowerInvariant()
$Manifest["manifest"] = $ManifestPath
$Manifest["manifest_sha256"] = $ManifestHash
$Manifest | ConvertTo-Json -Depth 6

if (-not $AuthorityOk -or $StagedSecretFiles.Count -gt 0) {
    exit 1
}
