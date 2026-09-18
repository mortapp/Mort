param(
  [string]$ProjectRef = 'rakjydmgwwgtdislanbt',
  [string]$EvidencePath = '',
  [string]$GateEvidencePath = '',
  [string]$ScenarioEvidencePath = '',
  [switch]$ExecuteProvider
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
if (-not $EvidencePath) {
  $EvidencePath = Join-Path $root 'artifacts\stripe\sandbox-e2e.json'
}
if (-not $GateEvidencePath) {
  $GateEvidencePath = Join-Path $root 'artifacts\stripe\pre-provider-gate.json'
}

$requiredScenarios = @(
  'capture_success',
  'capture_decline',
  'requires_action',
  'processing_or_pending',
  'network_ambiguity',
  'duplicate_submission',
  'webhook_duplicate',
  'webhook_out_of_order',
  'webhook_lease_retry',
  'full_refund',
  'partial_refund',
  'exact_transfer',
  'transfer_reversal',
  'transfer_reversal_failure',
  'tip_success',
  'tip_failure',
  'dispute_won',
  'dispute_lost',
  'payout_separation',
  'minor_account_restricted',
  'minor_account_ready',
  'cross_user_denial'
)

$unsafeEvidencePattern = '(?i)(sk_(?:test|live)_[A-Za-z0-9_-]{8,}|pk_(?:test|live)_[A-Za-z0-9_-]{8,}|whsec_[A-Za-z0-9_-]{8,}|rk_(?:test|live)_[A-Za-z0-9_-]{8,}|pi_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}|\b[0-9]{12,19}\b)'
$fullProviderIdPattern = '(?i)\b(?:pi|ch|tr|re|dp|po|acct|evt|cus)_[A-Za-z0-9]{6,}\b'

function Assert-SafeEvidenceText {
  param([Parameter(Mandatory = $true)][string]$Text)
  if ($Text -match $unsafeEvidencePattern) {
    throw 'Sandbox evidence contains a credential, client-secret, JWT, or card-number-like value.'
  }
  if ($Text -match $fullProviderIdPattern) {
    throw 'Sandbox evidence contains a full provider object ID; record suffixes only.'
  }
}

function Write-Evidence {
  param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Payload)
  $json = $Payload | ConvertTo-Json -Depth 10
  Assert-SafeEvidenceText -Text $json
  $parent = Split-Path $EvidencePath -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent *> $null }
  $json | Set-Content -LiteralPath $EvidencePath -Encoding utf8 -NoNewline
}

function Empty-ScenarioRows {
  param([string]$Status, [string]$ResultCode)
  return @(
    $requiredScenarios | ForEach-Object {
      [ordered]@{
        id = $_
        status = $Status
        result_code = $ResultCode
        request_ref = $null
        trace_ref = $null
        provider_object_suffix = $null
      }
    }
  )
}

$mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'Process')
if (-not $mode) { $mode = [Environment]::GetEnvironmentVariable('MORT_STRIPE_MODE', 'User') }
if ($mode -and $mode -ne 'sandbox') {
  throw 'MORT_STRIPE_MODE must be sandbox. Live provider execution is refused.'
}

$gateScript = Join-Path $PSScriptRoot 'stripe-pre-provider-test-gate.ps1'
if (-not (Test-Path -LiteralPath $gateScript)) {
  throw 'Task 30 pre-provider gate is missing.'
}

& $gateScript -ProjectRef $ProjectRef -EvidencePath $GateEvidencePath -WhatIf
$gateExit = $LASTEXITCODE
$gate = $null
if (Test-Path -LiteralPath $GateEvidencePath) {
  $gateText = Get-Content -Raw -LiteralPath $GateEvidencePath
  Assert-SafeEvidenceText -Text $gateText
  $gate = $gateText | ConvertFrom-Json
}

$connectPreflight = Join-Path $PSScriptRoot 'stripe-connect-webhook-preflight.ps1'
if (-not (Test-Path -LiteralPath $connectPreflight)) {
  throw 'Task 31 Connect webhook preflight is missing.'
}

if ($gateExit -ne 0 -or -not $gate -or $gate.passed -ne $true) {
  Write-Evidence -Payload ([ordered]@{
    schema_version = 1
    suite = 'mort_stripe_sandbox_e2e'
    project_ref = $ProjectRef
    environment = 'test'
    mode = 'sandbox'
    gate_passed = $false
    provider_e2e_executed = $false
    live_mode_detected = $false
    complete = $false
    scenarios = Empty-ScenarioRows -Status 'blocked' -ResultCode 'pre_provider_gate_failed'
    reconciliation = [ordered]@{ unreconciled_count = $null }
    no_live_money_proof = [ordered]@{
      live_objects_detected = 0
      live_credentials_detected = $false
      real_card_data_used = $false
    }
    completed_at = [DateTimeOffset]::UtcNow.ToString('o')
  })
  Write-Output 'Stripe sandbox E2E BLOCKED: Task 30 gate did not pass. No provider mutation was attempted.'
  exit 2
}

& $connectPreflight -ProjectRef $ProjectRef
if ($LASTEXITCODE -ne 0) {
  Write-Evidence -Payload ([ordered]@{
    schema_version = 1
    suite = 'mort_stripe_sandbox_e2e'
    project_ref = $ProjectRef
    environment = 'test'
    mode = 'sandbox'
    gate_passed = $true
    connect_webhook_preflight_passed = $false
    provider_e2e_executed = $false
    live_mode_detected = $false
    complete = $false
    scenarios = Empty-ScenarioRows -Status 'blocked' -ResultCode 'connect_webhook_preflight_failed'
    reconciliation = [ordered]@{ unreconciled_count = $null }
    no_live_money_proof = [ordered]@{
      live_objects_detected = 0
      live_credentials_detected = $false
      real_card_data_used = $false
    }
    completed_at = [DateTimeOffset]::UtcNow.ToString('o')
  })
  Write-Output 'Stripe sandbox E2E BLOCKED: Connect webhook preflight did not pass. No provider mutation was attempted.'
  exit 2
}

if (-not $ExecuteProvider) {
  Write-Evidence -Payload ([ordered]@{
    schema_version = 1
    suite = 'mort_stripe_sandbox_e2e'
    project_ref = $ProjectRef
    environment = 'test'
    mode = 'sandbox'
    gate_passed = $true
    connect_webhook_preflight_passed = $true
    provider_e2e_executed = $false
    live_mode_detected = $false
    complete = $false
    scenarios = Empty-ScenarioRows -Status 'not_run' -ResultCode 'provider_execution_not_requested'
    reconciliation = [ordered]@{ unreconciled_count = $null }
    no_live_money_proof = [ordered]@{
      live_objects_detected = 0
      live_credentials_detected = $false
      real_card_data_used = $false
    }
    completed_at = [DateTimeOffset]::UtcNow.ToString('o')
  })
  Write-Output 'Stripe sandbox E2E NOT RUN: pass -ExecuteProvider only during the approved sandbox QA window.'
  exit 3
}

if (-not $ScenarioEvidencePath) {
  throw 'ScenarioEvidencePath is required for provider execution. It must be produced by MORT-created sandbox objects and the controlled QA flow.'
}
if (-not (Test-Path -LiteralPath $ScenarioEvidencePath)) {
  throw 'ScenarioEvidencePath does not exist.'
}

$scenarioText = Get-Content -Raw -LiteralPath $ScenarioEvidencePath
Assert-SafeEvidenceText -Text $scenarioText
$scenarioEvidence = $scenarioText | ConvertFrom-Json

if ($scenarioEvidence.environment -ne 'test' -or $scenarioEvidence.mode -ne 'sandbox') {
  throw 'Scenario evidence must come from Stripe test/sandbox mode.'
}
if ($scenarioEvidence.live_mode_detected -eq $true) {
  throw 'Live mode was detected. Sandbox E2E is aborted.'
}
if ($scenarioEvidence.provider_e2e_executed -ne $true) {
  throw 'Scenario evidence does not prove provider execution.'
}

$rows = @($scenarioEvidence.scenarios)
foreach ($required in $requiredScenarios) {
  $row = @($rows | Where-Object { $_.id -eq $required })
  if ($row.Count -ne 1 -or $row[0].status -ne 'pass') {
    throw "Missing passing MORT sandbox evidence for scenario: $required"
  }
}

if ([int]$scenarioEvidence.reconciliation.unreconciled_count -ne 0) {
  throw 'Provider objects remain unreconciled.'
}
if ([int]$scenarioEvidence.no_live_money_proof.live_objects_detected -ne 0 -or
    $scenarioEvidence.no_live_money_proof.live_credentials_detected -eq $true -or
    $scenarioEvidence.no_live_money_proof.real_card_data_used -eq $true) {
  throw 'No-live-money proof failed.'
}

$final = [ordered]@{
  schema_version = 1
  suite = 'mort_stripe_sandbox_e2e'
  project_ref = $ProjectRef
  environment = 'test'
  mode = 'sandbox'
  gate_passed = $true
  connect_webhook_preflight_passed = $true
  provider_e2e_executed = $true
  live_mode_detected = $false
  complete = $true
  scenarios = $rows
  reconciliation = $scenarioEvidence.reconciliation
  no_live_money_proof = $scenarioEvidence.no_live_money_proof
  completed_at = [DateTimeOffset]::UtcNow.ToString('o')
}

Write-Evidence -Payload $final
& node (Join-Path $PSScriptRoot 'qa-stripe-sandbox-e2e-evidence.mjs') $EvidencePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output "Stripe sandbox E2E evidence PASS: $EvidencePath"
exit 0
