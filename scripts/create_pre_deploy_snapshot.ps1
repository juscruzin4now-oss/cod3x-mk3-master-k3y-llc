$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$SnapshotRoot = Join-Path $Root "ops\snapshots"
$SnapshotDir = Join-Path $SnapshotRoot "predeploy-$Stamp"
New-Item -ItemType Directory -Force -Path $SnapshotDir | Out-Null

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

$Head = (& $GitPath rev-parse HEAD).Trim()
$Branch = (& $GitPath branch --show-current).Trim()
$StatusPath = Join-Path $SnapshotDir "git-status.txt"
$DiffPath = Join-Path $SnapshotDir "worktree.diff"
$TrackedPath = Join-Path $SnapshotDir "tracked-files.txt"
$UntrackedPath = Join-Path $SnapshotDir "untracked-files.txt"
$UntrackedHashPath = Join-Path $SnapshotDir "untracked-file-hashes.json"
$ManifestPath = Join-Path $SnapshotDir "snapshot-manifest.json"

function Write-EvidenceFile {
    param(
        [object[]]$Content,
        [string]$Path
    )

    $Content | Set-Content -Encoding UTF8 $Path
    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Path $Path | Out-Null
    }
}

Write-EvidenceFile -Content @(& $GitPath status --short) -Path $StatusPath
$Diff = @(& $GitPath diff --binary)
Write-EvidenceFile -Content $Diff -Path $DiffPath
Write-EvidenceFile -Content @(& $GitPath ls-files) -Path $TrackedPath
$Untracked = @(& $GitPath ls-files --others --exclude-standard | Where-Object { $_ -notlike "ops/snapshots/*" })
Write-EvidenceFile -Content $Untracked -Path $UntrackedPath
$UntrackedHashes = [ordered]@{}
foreach ($Path in $Untracked) {
    if (Test-Path $Path -PathType Leaf) {
        $UntrackedHashes[$Path] = (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant()
    }
}
$UntrackedHashes | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $UntrackedHashPath

$DiffHash = (Get-FileHash -Algorithm SHA256 $DiffPath).Hash.ToLowerInvariant()
$StatusHash = (Get-FileHash -Algorithm SHA256 $StatusPath).Hash.ToLowerInvariant()
$TrackedHash = (Get-FileHash -Algorithm SHA256 $TrackedPath).Hash.ToLowerInvariant()
$UntrackedHash = (Get-FileHash -Algorithm SHA256 $UntrackedPath).Hash.ToLowerInvariant()
$UntrackedFileHash = (Get-FileHash -Algorithm SHA256 $UntrackedHashPath).Hash.ToLowerInvariant()

$Manifest = [ordered]@{
    snapshot_id = "predeploy-$Stamp"
    created_utc = $Stamp
    branch = $Branch
    head = $Head
    immutable_record = $true
    production_change_started = $false
    files = [ordered]@{
        "git-status.txt" = $StatusHash
        "worktree.diff" = $DiffHash
        "tracked-files.txt" = $TrackedHash
        "untracked-files.txt" = $UntrackedHash
        "untracked-file-hashes.json" = $UntrackedFileHash
    }
}

$Manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $ManifestPath
$ManifestHash = (Get-FileHash -Algorithm SHA256 $ManifestPath).Hash.ToLowerInvariant()

[ordered]@{
    snapshot_id = $Manifest.snapshot_id
    snapshot_dir = $SnapshotDir
    manifest_sha256 = $ManifestHash
    head = $Head
    branch = $Branch
} | ConvertTo-Json -Depth 5
