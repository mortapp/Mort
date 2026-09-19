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

$script:regressionCommit = ''
$script:evidenceMatrix = @()
$environmentName = 'sandbox_contract_and_hosted_non_provider'

function Invoke-Step {
  param(
    [string]$Name,
    [string]$Command,
    [scriptblock]$Action
  )
  Write-Output "[stripe-regression] START: $Name"
  & $Action
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE."
  }
  $script:evidenceMatrix += [ordered]@{
    command = $Command
    commit = $script:regressionCommit
    timestamp = [DateTimeOffset]::UtcNow.ToString('o')
    result = 'PASS'
    environment = $environmentName
  }
  Write-Output "[stripe-regression] PASS: $Name"
}

Push-Location $root
try {
  $script:regressionCommit = (& git rev-parse HEAD).Trim()

  $requiredMigrationSlugs = @(
    'mort_stripe_policy_and_funding_v1',
    'mort_stripe_funding_attempts_and_state_v1',
    'mort_stripe_webhook_lease_v1',
    'mort_stripe_settlement_ledger_v1',
    'mort_financial_documents_history_v1',
    'mort_stripe_financial_access_hardening_v1'
  )

  Invoke-Step 'Planned Stripe migration responsibilities' 'verify six implemented Stripe migration responsibility anchors' {
    foreach ($slug in $requiredMigrationSlugs) {
      $matches = @(Get-ChildItem (Join-Path $root 'supabase\migrations') -Filter "*_$slug.sql")
      if ($matches.Count -ne 1) {
        throw "Expected exactly one migration for $slug; found $($matches.Count)."
      }
    }
  }

  Invoke-Step 'Supabase CLI discovery' 'npx supabase --help; npx supabase migration --help' {
    & npx supabase --help *> $null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & npx supabase migration --help *> $null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  if (-not $SkipLocalReset) {
    $previousConfirm = $env:MORT_LOCAL_SUPABASE_CONFIRM
    try {
      $env:MORT_LOCAL_SUPABASE_CONFIRM = 'LOCAL_ONLY'
      Invoke-Step 'Start local Supabase' 'scripts/local-supabase-start.ps1' {
        & (Join-Path $PSScriptRoot 'local-supabase-start.ps1')
      }
      Invoke-Step 'Local Supabase reset' 'scripts/local-supabase-reset.ps1' {
        & (Join-Path $PSScriptRoot 'local-supabase-reset.ps1')
      }
      Invoke-Step 'Local migration list' 'npx supabase migration list --local' {
        & npx supabase migration list --local
      }

      Invoke-Step 'Local Supabase QA environment' 'supabase status -o env' {
        $statusLines = & npx supabase status -o env
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $local = @{}
        foreach ($line in $statusLines) {
          if ($line -match '^([A-Z0-9_]+)=(.*)    } finally {
      $env:MORT_LOCAL_SUPABASE_CONFIRM = $previousConfirm
    }
  }

  Invoke-Step 'Full Supabase regression including Stripe QA' 'scripts/run-final-supabase-regression.ps1' {
    & (Join-Path $PSScriptRoot 'run-final-supabase-regression.ps1')
  }

  Invoke-Step 'Stripe pre-provider fixture gate' 'node scripts/qa-stripe-pre-provider-gate.mjs' {
    & node (Join-Path $PSScriptRoot 'qa-stripe-pre-provider-gate.mjs')
  }

  Invoke-Step 'Stripe Edge Function Deno tests' 'deno test --node-modules-dir=auto --allow-read --allow-env supabase/functions/_tests' {
    & deno test --node-modules-dir=auto --allow-read --allow-env supabase/functions/_tests
  }

  if (-not [string]::IsNullOrWhiteSpace($env:SUPABASE_ACCESS_TOKEN)) {
    Invoke-Step 'Supabase advisors' 'node scripts/audit-supabase-advisors.mjs' {
      & node (Join-Path $PSScriptRoot 'audit-supabase-advisors.mjs')
    }
  } else {
    Write-Output '[stripe-regression] SKIP: hosted Supabase advisors require SUPABASE_ACCESS_TOKEN; verify through connected Supabase advisor tooling.'
    $script:evidenceMatrix += [ordered]@{
      command = 'node scripts/audit-supabase-advisors.mjs'
      commit = $script:regressionCommit
      timestamp = [DateTimeOffset]::UtcNow.ToString('o')
      result = 'EXTERNAL_VERIFICATION_REQUIRED'
      environment = 'hosted_supabase'
    }
  }

  if (-not $SkipFlutter) {
    Push-Location (Join-Path $root 'flutter_mort')
    try {
      Invoke-Step 'Flutter dependencies' 'flutter pub get' { & flutter pub get }
      Invoke-Step 'Flutter format' 'dart format --output=none --set-exit-if-changed lib test integration_test' {
        & dart format --output=none --set-exit-if-changed lib test integration_test
      }
      Invoke-Step 'Flutter analyze' 'flutter analyze --no-pub' { & flutter analyze --no-pub }
      Invoke-Step 'Flutter focused payment OS integration' 'flutter test --no-pub test/features/payment_os_integration_test.dart' {
        & flutter test --no-pub test/features/payment_os_integration_test.dart
      }
      Invoke-Step 'Flutter full test suite' 'flutter test --no-pub' { & flutter test --no-pub }
    } finally {
      Pop-Location
    }
  }

  Invoke-Step 'Source secret scan' 'scripts/secret-scan.ps1' {
    & (Join-Path $PSScriptRoot 'secret-scan.ps1')
  }
  Invoke-Step 'Secret extraction scan' 'node scripts/secret_extraction_scan.mjs' {
    & node (Join-Path $PSScriptRoot 'secret_extraction_scan.mjs')
  }
  Invoke-Step 'Git history secret scan' 'node scripts/secret-scan-git-history.mjs' {
    & node (Join-Path $PSScriptRoot 'secret-scan-git-history.mjs')
  }
  Invoke-Step 'Stripe regression manifest' 'node scripts/qa-stripe-sandbox-e2e-evidence.mjs --regression-manifest' {
    & node (Join-Path $PSScriptRoot 'qa-stripe-sandbox-e2e-evidence.mjs') --regression-manifest
  }
  Invoke-Step 'Git diff check' 'git diff --check' { & git diff --check }

  $evidence = [ordered]@{
    schema_version = 1
    suite = 'mort_stripe_regression'
    commit = $script:regressionCommit
    environment = $environmentName
    provider_e2e_executed = $false
    passed = $true
    timestamp = [DateTimeOffset]::UtcNow.ToString('o')
    result = 'PASS'
    evidence_matrix = $script:evidenceMatrix
    completed_at = [DateTimeOffset]::UtcNow.ToString('o')
  }
  $parent = Split-Path $EvidencePath -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent *> $null }
  $evidence | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 -NoNewline $EvidencePath
  Write-Output "[stripe-regression] COMPLETE: provider E2E was not executed. Evidence: $EvidencePath"
} finally {
  Pop-Location
}
) {
            $local[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
          }
        }
        foreach ($required in @('API_URL','ANON_KEY','SERVICE_ROLE_KEY','DB_URL')) {
          if ([string]::IsNullOrWhiteSpace($local[$required])) {
            throw "Local Supabase status did not provide $required."
          }
        }
        $env:EXPO_PUBLIC_SUPABASE_URL = $local['API_URL']
        $env:EXPO_PUBLIC_SUPABASE_ANON_KEY = $local['ANON_KEY']
        $env:SUPABASE_SERVICE_ROLE_KEY = $local['SERVICE_ROLE_KEY']
        $env:SUPABASE_DB_URL = $local['DB_URL']
        $env:MORT_QA_LOCAL_SUPABASE = 'true'
      }
    } finally {
      $env:MORT_LOCAL_SUPABASE_CONFIRM = $previousConfirm
    }
  }

  Invoke-Step 'Full Supabase regression including Stripe QA' 'scripts/run-final-supabase-regression.ps1' {
    & (Join-Path $PSScriptRoot 'run-final-supabase-regression.ps1')
  }

  Invoke-Step 'Stripe pre-provider fixture gate' 'node scripts/qa-stripe-pre-provider-gate.mjs' {
    & node (Join-Path $PSScriptRoot 'qa-stripe-pre-provider-gate.mjs')
  }

  Invoke-Step 'Stripe Edge Function Deno tests' 'deno test --node-modules-dir=auto --allow-read --allow-env supabase/functions/_tests' {
    & deno test --node-modules-dir=auto --allow-read --allow-env supabase/functions/_tests
  }

  Invoke-Step 'Supabase advisors' 'node scripts/audit-supabase-advisors.mjs' {
    & node (Join-Path $PSScriptRoot 'audit-supabase-advisors.mjs')
  }

  if (-not $SkipFlutter) {
    Push-Location (Join-Path $root 'flutter_mort')
    try {
      Invoke-Step 'Flutter dependencies' 'flutter pub get' { & flutter pub get }
      Invoke-Step 'Flutter format' 'dart format --output=none --set-exit-if-changed lib test integration_test' {
        & dart format --output=none --set-exit-if-changed lib test integration_test
      }
      Invoke-Step 'Flutter analyze' 'flutter analyze --no-pub' { & flutter analyze --no-pub }
      Invoke-Step 'Flutter focused payment OS integration' 'flutter test --no-pub test/features/payment_os_integration_test.dart' {
        & flutter test --no-pub test/features/payment_os_integration_test.dart
      }
      Invoke-Step 'Flutter full test suite' 'flutter test --no-pub' { & flutter test --no-pub }
    } finally {
      Pop-Location
    }
  }

  Invoke-Step 'Source secret scan' 'scripts/secret-scan.ps1' {
    & (Join-Path $PSScriptRoot 'secret-scan.ps1')
  }
  Invoke-Step 'Secret extraction scan' 'node scripts/secret_extraction_scan.mjs' {
    & node (Join-Path $PSScriptRoot 'secret_extraction_scan.mjs')
  }
  Invoke-Step 'Git history secret scan' 'node scripts/secret-scan-git-history.mjs' {
    & node (Join-Path $PSScriptRoot 'secret-scan-git-history.mjs')
  }
  Invoke-Step 'Stripe regression manifest' 'node scripts/qa-stripe-sandbox-e2e-evidence.mjs --regression-manifest' {
    & node (Join-Path $PSScriptRoot 'qa-stripe-sandbox-e2e-evidence.mjs') --regression-manifest
  }
  Invoke-Step 'Git diff check' 'git diff --check' { & git diff --check }

  $evidence = [ordered]@{
    schema_version = 1
    suite = 'mort_stripe_regression'
    commit = $script:regressionCommit
    environment = $environmentName
    provider_e2e_executed = $false
    passed = $true
    timestamp = [DateTimeOffset]::UtcNow.ToString('o')
    result = 'PASS'
    evidence_matrix = $script:evidenceMatrix
    completed_at = [DateTimeOffset]::UtcNow.ToString('o')
  }
  $parent = Split-Path $EvidencePath -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent *> $null }
  $evidence | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 -NoNewline $EvidencePath
  Write-Output "[stripe-regression] COMPLETE: provider E2E was not executed. Evidence: $EvidencePath"
} finally {
  Pop-Location
}
