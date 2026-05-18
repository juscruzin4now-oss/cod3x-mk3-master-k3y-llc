$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$LaunchRequired = [ordered]@{
    PUBLIC_LAUNCH_WINDOW_UTC = $env:PUBLIC_LAUNCH_WINDOW_UTC
    PUBLIC_LAUNCH_OWNER = $env:PUBLIC_LAUNCH_OWNER
    PUBLIC_SUPPORT_OWNER = $env:PUBLIC_SUPPORT_OWNER
    PUBLIC_ROLLBACK_OWNER = $env:PUBLIC_ROLLBACK_OWNER
    PUBLIC_RELEASE_NOTES_READY = $env:PUBLIC_RELEASE_NOTES_READY
    PUBLIC_SUPPORT_READY = $env:PUBLIC_SUPPORT_READY
}

$ProdRequired = [ordered]@{
    PROD_DEPLOY_TARGET = $env:PROD_DEPLOY_TARGET
    PROD_API_BASE_URL = $env:PROD_API_BASE_URL
    PROD_DNS_NAME = $env:PROD_DNS_NAME
    PROD_TLS_READY = $env:PROD_TLS_READY
    PROD_SECRET_MANAGER = $env:PROD_SECRET_MANAGER
    PROD_MAINTENANCE_WINDOW = $env:PROD_MAINTENANCE_WINDOW
    PROD_APPROVER = $env:PROD_APPROVER
}

$MissingLaunch = @($LaunchRequired.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Value) } | ForEach-Object { $_.Key })
$MissingProd = @($ProdRequired.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Value) } | ForEach-Object { $_.Key })

$Canary = & .\scripts\monitor_dev_canary.ps1 | ConvertFrom-Json
$Stage = & .\scripts\stage_integration_load_tests.ps1 -Requests 25 | ConvertFrom-Json

$PostDeployStatus = if ([string]::IsNullOrWhiteSpace($env:PROD_API_BASE_URL)) {
    "POST_DEPLOY_BLOCKED"
} else {
    $PostDeploy = & .\scripts\post_deploy_verification.ps1 | ConvertFrom-Json
    $PostDeploy.status
}

$Gates = [ordered]@{
    dev_canary = $Canary.status
    stage_tests = $Stage.status
    post_deploy = $PostDeployStatus
    production_requirements_bound = $MissingProd.Count -eq 0
    launch_requirements_bound = $MissingLaunch.Count -eq 0
}

$Status = if (
    $Gates.dev_canary -eq "DEV_CANARY_HEALTHY" -and
    $Gates.stage_tests -eq "STAGE_TESTS_PASS" -and
    $Gates.post_deploy -eq "POST_DEPLOY_VERIFY_PASS" -and
    $Gates.production_requirements_bound -and
    $Gates.launch_requirements_bound
) { "PUBLIC_LAUNCH_SCHEDULED" } else { "PUBLIC_LAUNCH_BLOCKED" }

$Schedule = [ordered]@{
    status = $Status
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    launch_window_utc = $env:PUBLIC_LAUNCH_WINDOW_UTC
    launch_owner = $env:PUBLIC_LAUNCH_OWNER
    support_owner = $env:PUBLIC_SUPPORT_OWNER
    rollback_owner = $env:PUBLIC_ROLLBACK_OWNER
    gates = $Gates
    missing_launch_requirements = $MissingLaunch
    missing_production_requirements = $MissingProd
    production_change_started = $false
}

$OutputRoot = Join-Path $Root "ops\launch"
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$OutputPath = Join-Path $OutputRoot "public-launch-schedule.json"
$Schedule | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $OutputPath

$Schedule["schedule_record"] = $OutputPath
$Schedule | ConvertTo-Json -Depth 6

if ($Status -ne "PUBLIC_LAUNCH_SCHEDULED") {
    exit 1
}
