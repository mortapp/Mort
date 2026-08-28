$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'MORT.xcodeproj\project.pbxproj'

if (-not (Test-Path -LiteralPath $project)) { throw 'MORT.xcodeproj/project.pbxproj is missing.' }
[xml](Get-Content -LiteralPath (Join-Path $root 'MORT\Info.plist') -Raw) | Out-Null
[xml](Get-Content -LiteralPath (Join-Path $root 'MORT\Resources\PrivacyInfo.xcprivacy') -Raw) | Out-Null
[xml](Get-Content -LiteralPath (Join-Path $root 'MORT\MORT.entitlements') -Raw) | Out-Null

$projectText = Get-Content -LiteralPath $project -Raw
$missing = @()
Get-ChildItem -LiteralPath (Join-Path $root 'MORT') -Recurse -Filter '*.swift' | ForEach-Object {
    if (-not $projectText.Contains($_.Name)) { $missing += $_.FullName }
}
if ($missing.Count -gt 0) { throw "Swift files missing from project: $($missing -join ', ')" }

$forbiddenFiles = Get-ChildItem -LiteralPath $root -Recurse -Force -File | Where-Object {
    $_.Name -in @('.env', '.env.local', 'Secrets.xcconfig') -or
    $_.FullName -match '\\(DerivedData|build|Pods|xcuserdata)\\'
}
if ($forbiddenFiles.Count -gt 0) { throw "Forbidden generated or secret files found: $($forbiddenFiles.FullName -join ', ')" }

$secretPatterns = @(
    'eyJhbGciOiJ[A-Za-z0-9_-]{20,}',
    'sbp_[A-Za-z0-9_-]{20,}',
    'sk_(live|test)_[A-Za-z0-9]{16,}',
    'SUPABASE_SERVICE_ROLE_KEY\s*=',
    'SUPABASE_DB_PASSWORD\s*=',
    'REVENUECAT_V1_SECRET_API_KEY\s*='
)
$textFiles = Get-ChildItem -LiteralPath $root -Recurse -Force -File | Where-Object {
    $_.Name -ne 'static-audit.ps1' -and
    $_.Extension -in @('.swift', '.md', '.plist', '.xcprivacy', '.xcconfig', '.pbxproj', '.yml', '.mjs', '.ps1')
}
foreach ($pattern in $secretPatterns) {
    $matches = $textFiles | Select-String -Pattern $pattern
    if ($matches) { throw "Potential secret pattern found: $pattern" }
}

$requiredPackages = @('supabase-swift', 'purchases-ios-spm', 'swift-package-manager-google-mobile-ads')
foreach ($package in $requiredPackages) {
    if (-not $projectText.Contains($package)) { throw "Missing package reference: $package" }
}

$missionSource = Get-Content -LiteralPath (Join-Path $root 'MORT\Features\Mission\MissionPilotViews.swift') -Raw
$requiredMissionViews = @(
    'PilotEligibilityView', 'PartnerInvitationView', 'PartnerAffiliationView',
    'DiscreetModeSettingsView', 'SupportCircleView', 'FutureIndependencePlanView',
    'EarningsGoalsView', 'ResourceDirectoryView', 'PilotJobSafetyView',
    'VerificationExplanationView', 'DocumentReviewStatusView',
    'NoAddressOnboardingSupport', 'PrivacyExplanationSheet'
)
foreach ($view in $requiredMissionViews) {
    if (-not $missionSource.Contains("struct $view")) { throw "Missing mission SwiftUI view: $view" }
}

$profileSource = Get-Content -LiteralPath (Join-Path $root 'MORT\Models\Profile.swift') -Raw
if (-not $profileSource.Contains('location_setup_mode')) { throw 'Swift profile is missing no-address location setup mode.' }

$repositorySource = Get-Content -LiteralPath (Join-Path $root 'MORT\Repositories\MissionPilotRepository.swift') -Raw
foreach ($contract in @('get_closed_pilot_eligibility', 'get_document_collection_readiness', 'get_private_work_summary')) {
    if (-not $repositorySource.Contains($contract)) { throw "Mission repository is missing hosted contract: $contract" }
}

$legalSource = Get-Content -LiteralPath (Join-Path $root 'MORT\Features\Settings\LegalCenterView.swift') -Raw
foreach ($view in @('LegalCenterView', 'TeenTermsSummaryView', 'LegalReacceptanceView')) {
    if (-not $legalSource.Contains("struct $view")) { throw "Missing legal SwiftUI view: $view" }
}

$contractSource = Get-Content -LiteralPath (Join-Path $root 'MORT\Features\Jobs\ContractPaymentViews.swift') -Raw
foreach ($view in @('JobContractsView', 'JobContractReviewView', 'JobContractChangeView', 'PaymentStatusView', 'NonpaymentReportView', 'PaymentDisputeView', 'EvidenceExportView')) {
    if (-not $contractSource.Contains("struct $view")) { throw "Missing contract/payment SwiftUI view: $view" }
}

$trustSource = Get-Content -LiteralPath (Join-Path $root 'MORT\Features\Trust\FirstPartyTrustViews.swift') -Raw
foreach ($view in @('DocumentCaptureQualityView', 'LivePresenceChallengeView', 'LivePresenceAccessibilityView', 'TeamAccessReviewView', 'ReviewerAssignmentView')) {
    if (-not $trustSource.Contains("struct $view")) { throw "Missing first-party trust SwiftUI view: $view" }
}

$biometricSource = Get-Content -LiteralPath (Join-Path $root 'MORT\Features\Settings\BiometricSettingsView.swift') -Raw
foreach ($view in @('BiometricSettingsView', 'AppLockView')) {
    if (-not $biometricSource.Contains("struct $view")) { throw "Missing biometric SwiftUI view: $view" }
}

$legalRepository = Get-Content -LiteralPath (Join-Path $root 'MORT\Repositories\LegalAcceptanceRepository.swift') -Raw
foreach ($repository in @('LegalAcceptanceRepository', 'JobContractRepository', 'FirstPartyTrustRepository')) {
    if (-not $legalRepository.Contains("final class $repository")) { throw "Missing legal/trust repository: $repository" }
}

$appLockSource = Get-Content -LiteralPath (Join-Path $root 'MORT\Services\AppLockService.swift') -Raw
foreach ($symbol in @('final class AppLockService', 'enum BiometricFailureReason', 'didEnterBackground', 'didBecomeActive', 'consumeAuthorization')) {
    if (-not $appLockSource.Contains($symbol)) { throw "App lock source is missing: $symbol" }
}
if ($appLockSource -match 'Supabase|from\(|rpc\(') { throw 'App lock source must remain device-only and must not call Supabase.' }

$infoPlist = Get-Content -LiteralPath (Join-Path $root 'MORT\Info.plist') -Raw
if (-not $infoPlist.Contains('MORT uses Face ID or Touch ID to protect private information on this device. It does not verify your legal identity.')) {
    throw 'NSFaceIDUsageDescription is missing the required device-only identity limitation.'
}

$deviceAuthenticationTests = Get-Content -LiteralPath (Join-Path $root 'MORTTests\DeviceAuthenticationServiceTests.swift') -Raw
foreach ($test in @('testUnavailableBiometrics', 'testDeniedPermission', 'testFailedMatch', 'testCancelledPrompt', 'testLockoutWithoutFallback', 'testPasscodeFallback', 'testSuccessUnlocksOnlyRequestedActionAndIsOneShot')) {
    if (-not $deviceAuthenticationTests.Contains($test)) { throw "Missing device-authentication source test: $test" }
}

Write-Host "Static audit passed for $root"
Write-Host "Swift source files: $((Get-ChildItem -LiteralPath (Join-Path $root 'MORT') -Recurse -Filter '*.swift').Count)"
Write-Host "Unit test files: $((Get-ChildItem -LiteralPath (Join-Path $root 'MORTTests') -Recurse -Filter '*.swift').Count)"
Write-Host 'No local secrets, env files, DerivedData, Pods, or build output found.'
