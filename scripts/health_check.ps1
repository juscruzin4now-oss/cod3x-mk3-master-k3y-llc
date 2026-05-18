param(
    [string]$BaseUrl = $env:MK3_API_BASE_URL
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = "http://127.0.0.1:8080"
}

$BaseUrl = $BaseUrl.TrimEnd("/")

$status = Invoke-RestMethod -Method Get -Uri "$BaseUrl/status"
$info = Invoke-RestMethod -Method Get -Uri "$BaseUrl/mk3/info"
$auth = Invoke-RestMethod -Method Get -Uri "$BaseUrl/auth/creator"
$primitives = Invoke-RestMethod -Method Get -Uri "$BaseUrl/auth/primitives"
$submit = Invoke-RestMethod -Method Post -Uri "$BaseUrl/submit" -Body '{"packet":"health_check"}' -ContentType "application/json"

$result = [ordered]@{
    status_endpoint = $status.status
    info_name = $info.name
    creator_auth = $auth.status
    primitive_access = $primitives.status
    submit_status = $submit.status
    submit_bytes = $submit.bytes_received
    base_url = $BaseUrl
}

$result | ConvertTo-Json
