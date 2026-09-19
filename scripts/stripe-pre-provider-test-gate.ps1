param(
  [string]$ProjectRef = 'rakjydmgwwgtdislanbt',
  [string]$EvidencePath = '',
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
if (-not $EvidencePath) {
  $EvidencePath = Join-Path $root 'artifacts\\stripe\\pre-provider-gate.json'
}

$forbiddenLiveNames = @(
  'STRIPE_LIVE_SECRET_KEY',
  'STRIPE_LIVE_PUBLISHABLE_KEY',
  'STRIPE_LIVE_WEBHOOK_SECRET'
)
$credentialValuePattern = '(?i)(sk_(?:test|live)_[A-Za-z0-9_-]{8,}|pk_(?:test|live)_[A-Za-z0-9_-]{8,}|whsec_[A-Za-z0-9_-]{8,}|rk_(?:test|live)_[A-Za-z0-9_-]{8,}|eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,})'

function Assert-NoCredentialValue {
  param([string]$Text, [string]$Label)
  if ($Text -match $credentialValuePattern) {
    throw "$Label contained a credential-like value; refusing to continue or print command output."
  }
}

function Get-EnvValue {
  param([string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if (-not $value) { $value = [Environment]::GetEnvironmentVariable($Name, 'User') }
  return $value
}

function Invoke-SafeCapture {
  param([string[]]$Arguments, [string]$Label)
  $output = & npx @Arguments 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  Assert-NoCredentialValue -Text $output -Label $Label
  if ($exitCode -ne 0) { throw "$Label failed with exit code $exitCode." }
  return $output
}

function Has-Name {
  param([string]$Text, [string]$Name)
  return [regex]::IsMatch($Text, "(?m)(^|[^A-Z0-9_])$([regex]::Escape($Name))([^A-Z0-9_]|$)")
}

& npx supabase --help *> $null
if ($LASTEXITCODE -ne 0) { throw 'Supabase CLI is unavailable.' }
& npx supabase secrets --help *> $null
if ($LASTEXITCODE -ne 0) { throw 'Supabase secrets command is unavailable.' }
& npx supabase functions --help *> $null
if ($LASTEXITCODE -ne 0) { throw 'Supabase functions command is unavailable.' }

$secretListing = Invoke-SafeCapture -Arguments @('supabase','secrets','list','--project-ref',$ProjectRef) -Label 'Supabase secret-name listing'
$functionListing = Invoke-SafeCapture -Arguments @('supabase','functions','list','--project-ref',$ProjectRef) -Label 'Supabase function listing'

$linkedRef = ''
$linkedRefFile = Join-Path $root 'supabase\\.temp\\project-ref'
if (Test-Path $linkedRefFile) { $linkedRef = (Get-Content -Raw $linkedRefFile).Trim() }
if (-not $linkedRef) { $linkedRef = Get-EnvValue 'MORT_SUPABASE_PROJECT_REF' }

$webhookUrl = Get-EnvValue 'MORT_STRIPE_TEST_WEBHOOK_URL'
$runtimeMode = Get-EnvValue 'MORT_STRIPE_MODE'
Assert-NoCredentialValue -Text $webhookUrl -Label 'Webhook URL'

$runtimeStatus = $null
try {
  $runtimeJson = & node (Join-Path $PSScriptRoot 'stripe-pre-provider-runtime-status.mjs') 2>$null | Out-String
  if ($LASTEXITCODE -eq 0 -and $runtimeJson) { $runtimeStatus = $runtimeJson | ConvertFrom-Json }
} catch {
  $runtimeStatus = $null
}

$expectedWebhookUrl = "https://$ProjectRef.supabase.co/functions/v1/stripe-webhook"
$secretKeyPresent = Has-Name -Text $secretListing -Name 'STRIPE_TEST_SECRET_KEY'
$publishableKeyPresent = Has-Name -Text $secretListing -Name 'STRIPE_TEST_PUBLISHABLE_KEY'
$webhookFunctionPresent = Has-Name -Text $functionListing -Name 'stripe-webhook'
$webhookConfigured = $webhookFunctionPresent -and $webhookUrl -eq $expectedWebhookUrl
$webhookSecretPresent = Has-Name -Text $secretListing -Name 'STRIPE_TEST_WEBHOOK_SECRET'
$liveNamesPresent = @($forbiddenLiveNames | Where-Object { Has-Name -Text $secretListing -Name $_ })
$runtimeIsSandbox = $runtimeStatus -and $runtimeStatus.runtime_mode -eq 'sandbox'
if ($runtimeMode) { $runtimeIsSandbox = $runtimeIsSandbox -and $runtimeMode -eq 'sandbox' }
$projectAndModePass = $linkedRef -eq $ProjectRef -and $runtimeIsSandbox -and $liveNamesPresent.Count -eq 0
$mutationEligible = $runtimeStatus -and $runtimeStatus.mutation_test_eligible -eq $true

$checks = @(
  [ordered]@{ id = 'test_secret_key_name'; pass = $secretKeyPresent; detail = $(if ($secretKeyPresent) {'present'} else {'missing'}) },
  [ordered]@{ id = 'test_publishable_key_name'; pass = $publishableKeyPresent; detail = $(if ($publishableKeyPresent) {'present'} else {'missing'}) },
  [ordered]@{ id = 'test_webhook_endpoint'; pass = $webhookConfigured; detail = $(if ($webhookConfigured) {'configured'} else {'missing_or_mismatched'}) },
  [ordered]@{ id = 'test_webhook_secret_name'; pass = $webhookSecretPresent; detail = $(if ($webhookSecretPresent) {'present'} else {'missing'}) },
  [ordered]@{ id = 'sandbox_project_and_mode'; pass = $projectAndModePass; detail = $(if ($linkedRef -ne $ProjectRef) {'project_mismatch'} elseif (-not $runtimeIsSandbox) {'mode_not_sandbox'} elseif ($liveNamesPresent.Count -gt 0) {'live_secret_name_contamination'} else {'sandbox'}) },
  [ordered]@{ id = 'sandbox_mutation_test_eligible'; pass = [bool]$mutationEligible; detail = $(if ($mutationEligible) {'eligible'} else {'disabled'}) }
)

$firstFailure = -1
for ($i = 0; $i -lt $checks.Count; $i++) {
  if (-not $checks[$i].pass) { $firstFailure = $i; break }
}
for ($i = 0; $i -lt $checks.Count; $i++) {
  $checks[$i].evaluated = ($firstFailure -eq -1 -or $i -le $firstFailure)
  if (-not $checks[$i].evaluated) {
    $checks[$i].pass = $false
    $checks[$i].detail = 'not_evaluated'
  }
}

$passed = $firstFailure -eq -1
$evidence = [ordered]@{
  schema_version = 1
  gate = 'mort_stripe_pre_provider_test'
  project_ref = $ProjectRef
  environment = 'test'
  runtime_mode = $(if ($runtimeStatus) { $runtimeStatus.runtime_mode } else { 'unknown' })
  passed = $passed
  provider_mutation_performed = $false
  what_if = [bool]$WhatIf
  checked_at = [DateTimeOffset]::UtcNow.ToString('o')
  checks = $checks
}

$parent = Split-Path $EvidencePath -Parent
if ($parent) { New-Item -ItemType Directory -Force -Path $parent *> $null }
$evidence | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 -NoNewline $EvidencePath

foreach ($check in $checks) {
  if ($check.evaluated) { Write-Output "$($check.id): $($check.detail)" }
}
Write-Output "Pre-provider Stripe gate passed: $passed. Provider mutation performed: false."
Write-Output "Evidence: $EvidencePath"

if (-not $passed) { exit 2 }
exit 0
