$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$StageRoot = Join-Path $Root "ops\stage"
$StageDir = Join-Path $StageRoot "stage-promotion-$Stamp"
$ArtifactPath = Join-Path $StageDir "codex-mk3-stage-$Stamp.zip"
$ManifestPath = Join-Path $StageDir "stage-promotion-manifest.json"
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

$Canary = & .\scripts\monitor_dev_canary.ps1 | ConvertFrom-Json
if ($Canary.status -ne "DEV_CANARY_HEALTHY") {
    throw "Stage promotion blocked: dev canary returned $($Canary.status)."
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

$Head = (& $GitPath rev-parse HEAD).Trim()
$Branch = (& $GitPath branch --show-current).Trim()

$PackagePaths = @(
    ".github",
    "app",
    "branding",
    "docs",
    "habitat",
    "integrations",
    "marketing",
    "mk3_system",
    "ops\integration_points.map",
    "ops\launch_runbook.md",
    "scripts",
    "system",
    "tests",
    "web",
    ".env.example",
    ".gitignore",
    "CHANGELOG.md",
    "DEPLOYMENT.md",
    "README.md",
    "RELEASE_CHECKLIST.md",
    "VERSION",
    "core_manifest.json",
    "mk3_structural_update.json",
    "requirements.txt"
)

Compress-Archive -Path $PackagePaths -DestinationPath $ArtifactPath -CompressionLevel Optimal -Force
$ArtifactHash = (Get-FileHash -Algorithm SHA256 $ArtifactPath).Hash.ToLowerInvariant()

$Manifest = [ordered]@{
    promotion_id = "stage-promotion-$Stamp"
    created_utc = $Stamp
    branch = $Branch
    head = $Head
    status = "STAGE_ARTIFACT_READY"
    artifact = $ArtifactPath
    artifact_sha256 = $ArtifactHash
    canary_status = $Canary.status
    production_change_started = $false
}

$Manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $ManifestPath
$ManifestHash = (Get-FileHash -Algorithm SHA256 $ManifestPath).Hash.ToLowerInvariant()

[ordered]@{
    status = "STAGE_ARTIFACT_READY"
    promotion_id = $Manifest.promotion_id
    artifact = $ArtifactPath
    artifact_sha256 = $ArtifactHash
    manifest = $ManifestPath
    manifest_sha256 = $ManifestHash
} | ConvertTo-Json -Depth 5
