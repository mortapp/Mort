[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stageRoot = Join-Path $root 'build\package-0.9.3'

function Assert-WorkspaceChild {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a package path outside the workspace: $full"
  }
}

Assert-WorkspaceChild $stageRoot
if (Test-Path -LiteralPath $stageRoot) {
  Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null

$excludedSegments = @(
  '.git', '.dart_tool', '.expo', '.gradle', '.idea', '.supabase-cli-config',
  '.temp', '.vscode', 'backups', 'build', 'coverage', 'DerivedData', 'dist',
  'ephemeral', 'logs', 'node_modules', 'outputs', 'Pods', '.symlinks'
)
$forbiddenNames = @(
  '.env', '.env.local', '.env.production', '.flutter-plugins-dependencies',
  'GeneratedPluginRegistrant.java', 'key.properties', 'local.properties'
)
$forbiddenExtensions = @('.aab', '.apk', '.bak', '.db', '.dump', '.jks', '.key', '.keystore', '.log', '.mobileprovision', '.p12', '.pem', '.pfx', '.sqlite', '.sqlite3', '.zip')

function Test-SourceFileAllowed {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)
  $relative = $File.FullName.Substring($root.Length + 1)
  foreach ($segment in ($relative -split '[\\/]')) {
    if ($excludedSegments -contains $segment) { return $false }
  }
  if ($forbiddenNames -contains $File.Name) { return $false }
  if ($File.Name -match '^\.env\.' -and $File.Name -notmatch '^\.env\.(example|sample|template)$') { return $false }
  if ($forbiddenExtensions -contains $File.Extension.ToLowerInvariant()) { return $false }
  return $true
}

function Copy-RelativeFile {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$DestinationRoot
  )
  $source = Join-Path $root $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Required package file is missing: $RelativePath"
  }
  $file = Get-Item -LiteralPath $source
  if (-not (Test-SourceFileAllowed $file)) {
    throw "Selected package file violates clean-source rules: $RelativePath"
  }
  $destination = Join-Path $DestinationRoot $RelativePath
  New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Copy-RelativeTree {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$DestinationRoot
  )
  $source = Join-Path $root $RelativePath
  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Required package directory is missing: $RelativePath"
  }
  foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File -Force) {
    if (-not (Test-SourceFileAllowed $file)) { continue }
    $relative = $file.FullName.Substring($root.Length + 1)
    Copy-RelativeFile -RelativePath $relative -DestinationRoot $DestinationRoot
  }
}

function New-SelectedPackage {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string[]]$Files = @(),
    [string[]]$Trees = @()
  )
  $stage = Join-Path $stageRoot $Name
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  foreach ($file in $Files) { Copy-RelativeFile -RelativePath $file -DestinationRoot $stage }
  foreach ($tree in $Trees) { Copy-RelativeTree -RelativePath $tree -DestinationRoot $stage }
  $zip = Join-Path $root "$Name.zip"
  Assert-WorkspaceChild $zip
  if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  return $zip
}

$sourceStage = Join-Path $stageRoot 'mort-android-0.9.3-final-source-clean'
New-Item -ItemType Directory -Force -Path $sourceStage | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
  if (-not (Test-SourceFileAllowed $file)) { continue }
  $relative = $file.FullName.Substring($root.Length + 1)
  Copy-RelativeFile -RelativePath $relative -DestinationRoot $sourceStage
}
$sourceZip = Join-Path $root 'mort-android-0.9.3-final-source-clean.zip'
if (Test-Path -LiteralPath $sourceZip) { Remove-Item -LiteralPath $sourceZip -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($sourceStage, $sourceZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)

$supportZip = New-SelectedPackage -Name 'mort-support-chat-setup-and-evidence' -Files @(
  'docs\MORT_SUPPORT_SYSTEM.md',
  'docs\MORT_AI_SAFETY.md',
  'docs\MORT_SUPPORT_TEST_REPORT.md',
  'docs\operations\MORT_SUPPORT_CHAT_RUNBOOK.md',
  'docs\operations\MORT_EMAIL_EVIDENCE_FALLBACK_RUNBOOK.md',
  'flutter_mort\lib\data\repositories\support_repository.dart',
  'scripts\qa-support-cross-user-isolation.mjs',
  'scripts\qa-support-staff-forgery.mjs',
  'scripts\qa-support-email-fallback-contract.mjs',
  'scripts\qa-evidence-isolation.mjs',
  'supabase\migrations\20260722202139_mort_0_9_3_support_execution_evidence_payments.sql',
  'supabase\migrations\20260722213502_mort_0_9_3_support_staff_queue.sql',
  'supabase\migrations\20260722214515_mort_0_9_3_evidence_draft_removal.sql',
  'supabase\migrations\20260722215041_mort_0_9_3_support_case_number_default.sql',
  'supabase\migrations\20260722215459_mort_0_9_3_support_rls_helper_permissions.sql',
  'supabase\migrations\20260722215544_mort_0_9_3_support_message_rls_permission.sql',
  'supabase\migrations\20260722222534_mort_0_9_3_ai_and_signed_media_rate_limits.sql'
) -Trees @(
  'flutter_mort\lib\features\support',
  'supabase\functions\ai-support',
  'supabase\functions\support-evidence-url'
)

$pinZip = New-SelectedPackage -Name 'mort-job-start-finish-pin-evidence' -Files @(
  'docs\MORT_PIN_JOB_VERIFICATION.md',
  'docs\MORT_JOB_STATE_MACHINE.md',
  'docs\security\MORT_START_FINISH_PIN_THREAT_MODEL.md',
  'docs\operations\MORT_ADULT_CANCELLATION_AFTER_START_RUNBOOK.md',
  'docs\operations\MORT_TEEN_ABANDONMENT_REVIEW_RUNBOOK.md',
  'flutter_mort\lib\data\repositories\job_execution_repository.dart',
  'flutter_mort\lib\features\jobs\job_progress_screen.dart',
  'scripts\qa-job-start-funding-gate.mjs',
  'scripts\qa-job-pin-replay-lock.mjs',
  'scripts\qa-abandonment-safety-cooldown.mjs',
  'supabase\migrations\20260722202206_mort_0_9_3_job_execution_pins.sql',
  'supabase\migrations\20260722212441_mort_0_9_3_abandonment_decision_safety.sql',
  'supabase\migrations\20260722225742_fix_adult_job_cancellation_enum_cast.sql'
)

$stripeZip = New-SelectedPackage -Name 'mort-stripe-resolution-sandbox-package' -Files @(
  'docs\MORT_PAYMENT_ARCHITECTURE_DECISION.md',
  'docs\MORT_STRIPE_CONNECT_ARCHITECTURE.md',
  'docs\MORT_PAYMENT_STATE_MACHINE.md',
  'docs\MORT_PAYMENT_TEST_REPORT.md',
  'docs\MORT_DISPUTE_AND_EVIDENCE_SYSTEM.md',
  'docs\operations\MORT_PAYMENT_DISPUTE_REVIEW_RUNBOOK.md',
  'docs\payments\MORT_FUNDED_JOB_RELEASE_MODEL.md',
  'docs\payments\MORT_PARTIAL_TRANSFER_AND_REFUND_RUNBOOK.md',
  'flutter_mort\lib\data\repositories\stripe_marketplace_repository.dart',
  'scripts\qa-payment-operations-queue-boundary.mjs',
  'scripts\qa-payment-resolution-boundary.mjs',
  'scripts\stripe-qa-suites.mjs',
  'supabase\migrations\20260722202208_mort_0_9_3_payment_resolution.sql',
  'supabase\migrations\20260722213243_mort_0_9_3_refund_webhook_reconciliation.sql',
  'supabase\migrations\20260722223231_mort_0_9_3_payment_operations_queue.sql'
) -Trees @(
  'flutter_mort\lib\features\payments',
  'supabase\functions\stripe-resolve-job-payment'
)

$legalZip = New-SelectedPackage -Name 'mort-legal-drafts-0.9.3' -Files @(
  'docs\MORT_LEGAL_REVIEW_CHECKLIST.md',
  'docs\MORT_TERMS_DRAFT.md',
  'supabase\migrations\20260722202142_mort_0_9_3_legal_draft_catalog.sql'
) -Trees @('docs\legal')

$playZip = New-SelectedPackage -Name 'mort-play-review-and-console-package-0.9.3' -Files @(
  'docs\MORT_RELEASE_READINESS.md',
  'docs\MORT_EXTERNAL_ACTION_TRACKER.md',
  'docs\play-final\MORT_CLOSED_TEST_RELEASE_NOTES.txt',
  'docs\play-final\MORT_DATA_SAFETY_FINAL_WORKBOOK.md',
  'docs\play-final\MORT_PLAY_CONSOLE_MASTER_CHECKLIST.md',
  'docs\play-final\MORT_TARGET_AUDIENCE_FINAL_WORKBOOK.md',
  'docs\play-final\MORT_REVIEWER_WALKTHROUGH.md',
  'docs\play-final\MORT_COMMAND_RESULTS_0_9_3.md',
  'docs\play-final\MORT_FINAL_STATUS_0_9_3.md',
  'scripts\qa-android-apk.ps1',
  'scripts\android-lint-release.ps1',
  'scripts\verify-play-aab.ps1'
)

$evidenceZip = New-SelectedPackage -Name 'mort-0.9.3-test-evidence' -Files @(
  'docs\MORT_ADVERSARIAL_SECURITY_REPORT.md',
  'docs\MORT_COMPLETION_SCORE.md',
  'docs\MORT_DEPLOYED_SUPABASE_AUDIT.md',
  'docs\MORT_PAYMENT_TEST_REPORT.md',
  'docs\MORT_RLS_TEST_REPORT.md',
  'docs\MORT_SCHEMA_DRIFT_REPORT.md',
  'docs\MORT_SECRET_AUDIT.md',
  'docs\MORT_SUPPORT_TEST_REPORT.md',
  'docs\MORT_90_90_SCORECARD.md',
  'docs\play-final\MORT_COMMAND_RESULTS_0_9_3.md',
  'docs\play-final\MORT_FINAL_CHANGED_FILES_0_9_3.md',
  'docs\play-final\MORT_FINAL_STATUS_0_9_3.md'
)

$secretNames = @(
  'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD',
  'MORT_UPLOAD_STORE_PASSWORD', 'MORT_UPLOAD_KEY_PASSWORD',
  'REVENUECAT_V1_SECRET_API_KEY', 'REVENUECAT_WEBHOOK_AUTH_HEADER',
  'SEND_PUSH_INVOKE_SECRET', 'OPENAI_API_KEY', 'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET'
)
$secretValues = @()
foreach ($name in $secretNames) {
  $value = [Environment]::GetEnvironmentVariable($name, 'Process')
  if ([string]::IsNullOrWhiteSpace($value)) { $value = [Environment]::GetEnvironmentVariable($name, 'User') }
  if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 8) { $secretValues += $value }
}

function Get-CleanZipAudit {
  param([Parameter(Mandatory = $true)][string]$Path)
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
    foreach ($entry in $entries) {
      $normalized = $entry.FullName.Replace('\', '/')
      if ($normalized -match '(^|/)(node_modules|\.dart_tool|\.expo|\.git|\.gradle|backups|build/logs|dist|logs)(/|$)' -or
          $normalized -match '(^|/)\.env($|\.)' -and $normalized -notmatch '(^|/)\.env\.(example|sample|template)$' -or
          [System.IO.Path]::GetExtension($normalized).ToLowerInvariant() -in @('.jks', '.keystore', '.p12', '.pem', '.key', '.log')) {
        throw "Forbidden archive entry: $normalized"
      }
      if ($entry.Length -le 100MB) {
        $stream = $entry.Open()
        $memory = New-Object System.IO.MemoryStream
        try {
          $stream.CopyTo($memory)
          $content = [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
          foreach ($secret in $secretValues) {
            if ($content.Contains($secret)) { throw "Sensitive environment value found in $normalized" }
          }
        } finally {
          $memory.Dispose()
          $stream.Dispose()
        }
      }
    }
    [pscustomobject]@{
      Path = $Path
      Bytes = (Get-Item -LiteralPath $Path).Length
      Files = $entries.Count
      Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
      SecretValuesChecked = $secretValues.Count
    }
  } finally {
    $archive.Dispose()
  }
}

$results = @($sourceZip, $supportZip, $pinZip, $stripeZip, $legalZip, $playZip, $evidenceZip) | ForEach-Object {
  Get-CleanZipAudit -Path $_
}
$results | Format-Table -AutoSize

Assert-WorkspaceChild $stageRoot
Remove-Item -LiteralPath $stageRoot -Recurse -Force
