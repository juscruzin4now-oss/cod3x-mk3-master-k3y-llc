$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Required = [ordered]@{
    PROD_DEPLOY_TARGET = $env:PROD_DEPLOY_TARGET
    PROD_API_BASE_URL = $env:PROD_API_BASE_URL
    PROD_DNS_NAME = $env:PROD_DNS_NAME
    PROD_TLS_READY = $env:PROD_TLS_READY
    PROD_SECRET_MANAGER = $env:PROD_SECRET_MANAGER
    PROD_MAINTENANCE_WINDOW = $env:PROD_MAINTENANCE_WINDOW
    PROD_APPROVER = $env:PROD_APPROVER
}

$Missing = @($Required.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Value) } | ForEach-Object { $_.Key })
$Stage = & .\scripts\stage_integration_load_tests.ps1 -Requests 25 | ConvertFrom-Json

$Status = if ($Missing.Count -eq 0 -and $Stage.status -eq "STAGE_TESTS_PASS") {
    "PROD_PROMOTION_APPROVED"
} else {
    "PROD_PROMOTION_BLOCKED"
}

[ordered]@{
    status = $Status
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    stage_status = $Stage.status
    missing_requirements = $Missing
    production_change_started = $false
} | ConvertTo-Json -Depth 5

if ($Status -ne "PROD_PROMOTION_APPROVED") {
    exit 1
}
