$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$ProdRoot = Join-Path $Root "ops\production"
$ProdDir = Join-Path $ProdRoot "prod-promotion-$Stamp"
New-Item -ItemType Directory -Force -Path $ProdDir | Out-Null

$StageReport = & .\scripts\continue_stage_tests_and_report.ps1 | ConvertFrom-Json
if ($StageReport.status -ne "STAGE_REPORT_PASS") {
    throw "Production package blocked: stage report returned $($StageReport.status)."
}

$Snapshot = & .\scripts\create_pre_deploy_snapshot.ps1 | ConvertFrom-Json

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
$ArtifactPath = Join-Path $ProdDir "codex-mk3-production-candidate-$Stamp.zip"
$ManifestPath = Join-Path $ProdDir "production-promotion-manifest.json"

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
    status = "PRODUCTION_PROMOTION_PACKAGE_READY"
    package_id = "prod-promotion-$Stamp"
    created_utc = $Stamp
    branch = $Branch
    head = $Head
    artifact = $ArtifactPath
    artifact_sha256 = $ArtifactHash
    stage_report = $StageReport.summary
    stage_report_status = $StageReport.status
    pre_promotion_snapshot = $Snapshot.snapshot_dir
    pre_promotion_snapshot_manifest_sha256 = $Snapshot.manifest_sha256
    production_change_started = $false
}

$Manifest | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $ManifestPath
$ManifestHash = (Get-FileHash -Algorithm SHA256 $ManifestPath).Hash.ToLowerInvariant()
$Manifest["manifest"] = $ManifestPath
$Manifest["manifest_sha256"] = $ManifestHash
$Manifest | ConvertTo-Json -Depth 8
