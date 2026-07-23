param(
  [string]$FunctionUrl = $env:SUPABASE_FUNCTION_URL,
  [string]$ProjectUrl = $env:SUPABASE_URL,
  [string]$Jwt = $env:SUPABASE_FUNCTION_JWT,
  [string]$PushSecret = $env:SEND_PUSH_INVOKE_SECRET,
  [int]$BatchSize = 25,
  [string]$NotificationId = "",
  [string]$UserId = "",
  [string]$Title = "",
  [string]$Body = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FunctionUrl) -and [string]::IsNullOrWhiteSpace($ProjectUrl)) {
  throw "Set SUPABASE_FUNCTION_URL or SUPABASE_URL, or pass -FunctionUrl/-ProjectUrl."
}

if ([string]::IsNullOrWhiteSpace($Jwt)) {
  throw "Set SUPABASE_FUNCTION_JWT to a temporary test JWT or pass -Jwt. Do not put service-role keys in this script."
}

if ([string]::IsNullOrWhiteSpace($PushSecret)) {
  throw "Set SEND_PUSH_INVOKE_SECRET or pass -PushSecret. This value must match the Edge Function secret."
}

$payload = @{}
if (-not [string]::IsNullOrWhiteSpace($NotificationId)) {
  $payload.notificationId = $NotificationId
} elseif (-not [string]::IsNullOrWhiteSpace($UserId)) {
  if ([string]::IsNullOrWhiteSpace($Title) -or [string]::IsNullOrWhiteSpace($Body)) {
    throw "Direct user tests require -UserId, -Title, and -Body."
  }
  $payload.userId = $UserId
  $payload.title = $Title
  $payload.body = $Body
} else {
  $payload.batchSize = $BatchSize
}

$uri = if ([string]::IsNullOrWhiteSpace($FunctionUrl)) {
  "$($ProjectUrl.TrimEnd('/'))/functions/v1/send-push"
} else {
  $FunctionUrl
}

Write-Host "Invoking send-push at $uri"
Invoke-RestMethod -Method Post -Uri $uri -Headers @{
  Authorization = "Bearer $Jwt"
  "x-mort-push-secret" = $PushSecret
  "Content-Type" = "application/json"
} -Body ($payload | ConvertTo-Json -Depth 5)
