$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:PROD_API_BASE_URL)) {
    [ordered]@{
        status = "POST_DEPLOY_BLOCKED"
        reason = "Missing PROD_API_BASE_URL."
        production_change_started = $false
    } | ConvertTo-Json -Depth 5
    exit 1
}

$BaseUrl = $env:PROD_API_BASE_URL.TrimEnd("/")
$StatusEndpoint = Invoke-RestMethod -Method Get -Uri "$BaseUrl/status" -TimeoutSec 10
$Info = Invoke-RestMethod -Method Get -Uri "$BaseUrl/mk3/info" -TimeoutSec 10
$Creator = Invoke-RestMethod -Method Get -Uri "$BaseUrl/auth/creator" -TimeoutSec 10
$Primitives = Invoke-RestMethod -Method Get -Uri "$BaseUrl/auth/primitives" -TimeoutSec 10

$PaymentFlow = if ($env:STRIPE_SECRET_KEY -and $env:STRIPE_SECRET_KEY.StartsWith("sk_live_")) {
    "MANUAL_PROD_PAYMENT_SMOKE_REQUIRED"
} elseif ($env:STRIPE_SECRET_KEY -and $env:STRIPE_SECRET_KEY.StartsWith("sk_test_")) {
    "TEST_MODE_ONLY"
} else {
    "NOT_BOUND"
}

$Status = if (
    $StatusEndpoint.status -eq "OK" -and
    $Info.name -eq "Codex MK3" -and
    $Creator.status -eq "CREATOR_AUTH_READY" -and
    $Primitives.status -eq "PRIMITIVES_UNLOCKED"
) { "POST_DEPLOY_VERIFY_PASS" } else { "POST_DEPLOY_ATTENTION_REQUIRED" }

[ordered]@{
    status = $Status
    checked_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    base_url = $BaseUrl
    api = $StatusEndpoint.status
    info_name = $Info.name
    creator_auth = $Creator.status
    primitive_access = $Primitives.status
    payment_flow = $PaymentFlow
} | ConvertTo-Json -Depth 5
