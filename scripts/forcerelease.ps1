param(
    [ValidateSet("patch", "minor", "major")]
    [string]$BumpType = "patch"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

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

function Set-Text {
    param(
        [string]$Path,
        [string]$Value
    )

    $Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path $Root $Path), "$Value`n", $Utf8NoBom)
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

$CurrentVersion = (Get-Content -Raw VERSION).Trim()
if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
    throw "VERSION must be semantic major.minor.patch, got '$CurrentVersion'."
}

$Major = [int]$Matches[1]
$Minor = [int]$Matches[2]
$Patch = [int]$Matches[3]

switch ($BumpType) {
    "major" {
        $Major += 1
        $Minor = 0
        $Patch = 0
    }
    "minor" {
        $Minor += 1
        $Patch = 0
    }
    "patch" {
        $Patch += 1
    }
}

$NewVersion = "$Major.$Minor.$Patch"
$NewMajorMinor = "$Major.$Minor"
$Tag = "v$NewVersion"

if (& $GitPath rev-parse -q --verify "refs/tags/$Tag") {
    throw "Tag $Tag already exists locally."
}

$TrackedTargets = @(
    "VERSION",
    "core_manifest.json",
    "system\manifest\core_manifest.json",
    "mk3_structural_update.json",
    "mk3_system\__init__.py",
    "mk3_system\server.py",
    "tests\test_orchestrator.py",
    "tests\test_server.py",
    "CHANGELOG.md",
    "scripts\forcerelease.ps1"
)

Set-Text -Path "VERSION" -Value $NewVersion

$JsonVersionFiles = @(
    "core_manifest.json",
    "system\manifest\core_manifest.json",
    "mk3_structural_update.json"
)
foreach ($Path in $JsonVersionFiles) {
    $Content = Get-Content -Raw $Path
    $Content = $Content -replace [regex]::Escape($CurrentVersion), $NewVersion
    Set-Text -Path $Path -Value $Content.TrimEnd()
}

$Init = Get-Content -Raw "mk3_system\__init__.py"
$Init = $Init -replace "__version__ = `"$([regex]::Escape($CurrentVersion))`"", "__version__ = `"$NewVersion`""
Set-Text -Path "mk3_system\__init__.py" -Value $Init.TrimEnd()

$Server = Get-Content -Raw "mk3_system\server.py"
$Server = $Server -replace "`"version`": `"$([regex]::Escape($CurrentVersion))`"", "`"version`": `"$NewVersion`""
$Server = $Server -replace "server_version = `"CodexMK3/[^`"]+`"", "server_version = `"CodexMK3/$NewMajorMinor`""
Set-Text -Path "mk3_system\server.py" -Value $Server.TrimEnd()

$TestFiles = @("tests\test_orchestrator.py", "tests\test_server.py")
foreach ($Path in $TestFiles) {
    $Content = Get-Content -Raw $Path
    $Content = $Content -replace [regex]::Escape($CurrentVersion), $NewVersion
    Set-Text -Path $Path -Value $Content.TrimEnd()
}

$Today = (Get-Date).ToString("yyyy-MM-dd")
$Changelog = Get-Content -Raw "CHANGELOG.md"
$Entry = @"
## $Today - $NewVersion

### Changed

- Force release patch bump from `$CurrentVersion` to `$NewVersion`.
- Re-ran Creator-authorized release readiness, diagnostics, and tests.

"@
$Changelog = $Changelog -replace "## Unreleased\r?\n\r?\n", "## Unreleased`r`n`r`n$Entry"
Set-Text -Path "CHANGELOG.md" -Value $Changelog.TrimEnd()

$Temp = Join-Path $Root "ops\releases\pytest-temp"
New-Item -ItemType Directory -Force -Path $Temp | Out-Null
$env:TEMP = $Temp
$env:TMP = $Temp
$env:PYTEST_ADDOPTS = "-p no:cacheprovider"

Invoke-Checked -FilePath $PythonExe -Arguments @($PythonArgs + @("-m", "pytest"))
Invoke-Checked -FilePath "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", ".\scripts\verify_mk3.ps1")
Invoke-Checked -FilePath "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", ".\scripts\run_diagnostics.ps1")

& $GitPath add @TrackedTargets
Invoke-Checked -FilePath $GitPath -Arguments @("commit", "-m", "Force release $NewVersion")
Invoke-Checked -FilePath "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", ".\scripts\release_step_creator_auth.ps1", "-ReleaseVersion", $NewVersion)
Invoke-Checked -FilePath $GitPath -Arguments @("tag", $Tag)
Invoke-Checked -FilePath $GitPath -Arguments @("push", "origin", "main")
Invoke-Checked -FilePath $GitPath -Arguments @("push", "origin", $Tag)

[ordered]@{
    status = "FORCE_RELEASE_COMPLETE"
    previous_version = $CurrentVersion
    version = $NewVersion
    tag = $Tag
    head = (& $GitPath rev-parse HEAD).Trim()
} | ConvertTo-Json -Depth 4
