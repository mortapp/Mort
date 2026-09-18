param(
  [switch]$SkipLocalReset,
  [switch]$SkipFlutter,
  [string]$EvidencePath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Resolve-Path "$PSScriptRoot\.."
if (-not $EvidencePath) {
  $EvidencePath = Join-Path $root 'artifacts\stripe\regression.json'
}

function Invoke-Step {
  param([string]$Name, [scriptblock]$Action)
  Write-Output "[stripe-regression] START: $Name"
  & $Action
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE."
  }
  Write-Output "[stripe-regression] PASS: $Name"
}

Push-Location $root
try {
  Invoke-Step 'Supabase CLI discovery' {
    & npx supabase --help *> $null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & npx supabase migration --help *> $null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  if (-not $SkipLocalReset) {
    $previousConfirm = $env:MORT_LOCAL_SUPABASE_CONFIRM
    try {
      $env:MORT_LOCAL_SUPABASE_CONFIRM = 'LOCAL_ONLY'
      Invoke-Step 'Start local Supabase' { & (Join-Path $PSScriptRoot 'local-supabase-start.ps1') }
      Invoke-Step 'Local Supabase reset' { & (Join-Path $PSScriptRoot 'local-supabase-reset.ps1') }
      Invoke-Step 'Local migration list' { & npx supabase migration list --local }
    } finally {
      $env:MORT_LOCAL_SUPABASE_CONFIRM = $previousConfirm
    }
  }

  Invoke-Step 'Full Supabase regression including Stripe QA' {
    & (Join-Path $PSScriptRoot 'run-final-supabase-regression.ps1')
  }

  Invoke-Step 'Stripe pre-provider fixture gate' {
    & node (Join-Path $PSScriptRoot 'qa-stripe-pre-provider-gate.mjs')
  }

  Invoke-Step 'Stripe Edge Function Deno tests' {
    & deno test --allow-read --allow-env supabase/functions/_tests
  }

  Invoke-Step 'Supabase advisors' {
    & node (Join-Path $PSScriptRoot 'audit-supabase-advisors.mjs')
  }

  if (-not $SkipFlutter) {
    Push-Location (Join-Path $root 'flutter_mort')
    try {
      Invoke-Step 'Flutter dependencies' { & flutter pub get }
      Invoke-Step 'Flutter format' { & dart format --output=none --set-exit-if-changed lib test integration_test }
      Invoke-Step 'Flutter analyze' { & flutter analyze --no-pub }
      Invoke-Step 'Flutter full test suite' { & flutter test --no-pub }
    } finally {
      Pop-Location
    }
  }

  Invoke-Step 'Source secret scan' { & (Join-Path $PSScriptRoot 'secret-scan.ps1') }
  Invoke-Step 'Git history secret scan' { & node (Join-Path $PSScriptRoot 'secret-scan-git-history.mjs') }
  Invoke-Step 'Stripe regression manifest' { & node (Join-Path $PSScriptRoot 'qa-stripe-sandbox-e2e-evidence.mjs') --regression-manifest }
  Invoke-Step 'Git diff check' { & git diff --check }

  $commit = (& git rev-parse HEAD).Trim()
  $evidence = [ordered]@{
    schema_version = 1
    suite = 'mort_stripe_regression'
    commit = $commit
    environment = 'sandbox_contract_and_hosted_non_provider'
    provider_e2e_executed = $false
    passed = $true
    completed_at = [DateTimeOffset]::UtcNow.ToString('o')
  }
  $parent = Split-Path $EvidencePath -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent *> $null }
  $evidence | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -NoNewline $EvidencePath
  Write-Output "[stripe-regression] COMPLETE: provider E2E was not executed. Evidence: $EvidencePath"
} finally {
  Pop-Location
}
