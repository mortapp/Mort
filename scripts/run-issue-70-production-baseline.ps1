[CmdletBinding()]
param([switch]$VerifyOnly)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# This immutable commit contains the recovered 73-migration, schema-only
# production archive and its SHA-256 manifest. It is deliberately separate
# from the generic local Supabase migration chain.
$baselineCommit = '05325088dcbb117e5d144828bc613fef5b47777f'
$projectId = 'mort-issue70-baseline'
$containerName = "supabase_db_$projectId"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("mort-issue70-baseline-" + [guid]::NewGuid().ToString('N'))
$archiveZip = "$tempRoot.zip"
$archiveRoot = Join-Path $tempRoot 'archive'
$supabaseRoot = Join-Path $tempRoot 'test-project'
$stackStarted = $false

function Invoke-Supabase {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
  & $supabaseCommand @supabasePrefixArgs @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Supabase CLI failed with exit code $LASTEXITCODE." }
}

function Invoke-Git {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
  & git -C $repoRoot @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Git command failed with exit code $LASTEXITCODE." }
}

try {
  New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $supabaseRoot -Force | Out-Null

  # Fetch only the immutable archive commit and extract only its production
  # migration bundle. No database credentials or remote Supabase targets are used.
  Invoke-Git fetch --no-tags --depth=1 origin $baselineCommit
  Invoke-Git archive --format=zip --output=$archiveZip $baselineCommit supabase-production
  Expand-Archive -LiteralPath $archiveZip -DestinationPath $archiveRoot -Force

  $productionArchive = Join-Path $archiveRoot 'supabase-production'
  $manifestPath = Join-Path $productionArchive 'migration-history.json'
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if ($manifest.source_project_ref -ne 'jxbnrkasktbhtiujkhay' -or $manifest.migration_count -ne 73 -or $manifest.migrations.Count -ne 73) {
    throw 'Pinned production migration manifest identity/count check failed.'
  }

  $migrationSource = Join-Path $productionArchive 'migrations'
  $migrationTarget = Join-Path $supabaseRoot 'supabase\migrations'
  $versions = @()
  $sourceByVersion = @{}
  foreach ($entry in $manifest.migrations) {
    if ($entry.version -notmatch '^\d{14}$' -or $entry.sha256 -notmatch '^[0-9a-f]{64}$') {
      throw 'Pinned migration manifest contains an invalid version or hash.'
    }
    $archiveFiles = @(Get-ChildItem -LiteralPath $migrationSource -File -Filter "$($entry.version)_*.sql")
    if ($archiveFiles.Count -ne 1) { throw "Expected one archived SQL source for migration $($entry.version)." }
    $sourcePath = $archiveFiles[0].FullName
    $actualHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $entry.sha256) {
      # The recovered production ledger payload is the authoritative source for
      # this one archive mismatch. The fallback is separately checked against
      # the manifest SHA-256; the archived historical file remains unchanged.
      if ($entry.version -ne '20261102040639') {
        throw "Unreconciled archived production migration hash mismatch at $($entry.version)."
      }
      $recoveryMetadataPath = Join-Path $repoRoot 'supabase\production-baseline-recovery\20261102040639_restrict_job_application_direct_select.json'
      if (-not (Test-Path -LiteralPath $recoveryMetadataPath)) { throw 'The ledger-recovery provenance record is missing.' }
      $recoveryMetadata = Get-Content -LiteralPath $recoveryMetadataPath -Raw | ConvertFrom-Json
      if ($recoveryMetadata.source_project_ref -ne 'jxbnrkasktbhtiujkhay' -or
          $recoveryMetadata.version -ne $entry.version -or
          $recoveryMetadata.name -ne $entry.name -or
          $recoveryMetadata.ledger_statements_md5 -ne '806bed46eb996e0fed98e87ea9a03f3c' -or
          $recoveryMetadata.archived_file_sha256 -ne $actualHash -or
          $recoveryMetadata.manifest_source_sha256 -ne $entry.sha256) {
        throw 'The ledger-recovery provenance record does not match the pinned archive and migration manifest.'
      }
      $sourcePath = Join-Path $repoRoot 'supabase\production-baseline-recovery\20261102040639_restrict_job_application_direct_select.sql'
      if (-not (Test-Path -LiteralPath $sourcePath)) { throw 'The read-only ledger-recovered migration source is missing.' }
      $actualHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($actualHash -ne $entry.sha256 -or $actualHash -ne $recoveryMetadata.recovered_source_sha256) { throw "Ledger-recovered migration source does not match the verified manifest hash at $($entry.version)." }
      Write-Host "[qa-issue-70-production-baseline] Recovered exact ledger source for $($entry.version); archived copy differed."
    }
    $sourceByVersion[$entry.version] = $sourcePath
    $versions += $entry.version
  }
  if (($versions | Sort-Object -Unique).Count -ne 73 -or (($versions | Sort-Object) -join ',') -ne ($versions -join ',')) {
    throw 'Production migration versions are duplicated or not ordered.'
  }
  Write-Host "[qa-issue-70-production-baseline] Verified 73 source hashes from $($versions[0]) through $($versions[-1])."
  if ($VerifyOnly) {
    Write-Host '[qa-issue-70-production-baseline] Verify-only mode: no database or Docker operations were attempted.'
    return
  }

  $cli = Get-Command supabase -ErrorAction SilentlyContinue
  if ($cli) {
    $supabaseCommand = $cli.Source
    $supabasePrefixArgs = @()
  } else {
    $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $pnpm) { throw 'Supabase CLI or pnpm is required.' }
    $supabaseCommand = $pnpm.Source
    $supabasePrefixArgs = @('exec', 'supabase')
  }

  Invoke-Supabase init --workdir $supabaseRoot
  $configPath = Join-Path $supabaseRoot 'supabase\config.toml'
  $config = Get-Content -LiteralPath $configPath -Raw
  $config = [regex]::Replace($config, '(?m)^project_id\s*=\s*"[^"]*"', "project_id = `"$projectId`"", 1)
  if ($config -notmatch '(?m)^\[db\]') { throw 'Supabase init did not create the expected [db] config section.' }
  if ($config -match '(?ms)^\[db\]\s*.*?^major_version\s*=\s*\d+') {
    $config = [regex]::Replace($config, '(?ms)(^\[db\]\s*.*?^major_version\s*=\s*)\d+', '${1}17', 1)
  } else {
    $config = [regex]::Replace($config, '(?m)^\[db\]\s*$', "[db]`nmajor_version = 17", 1)
  }
  [IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))

  foreach ($entry in $manifest.migrations) {
    Copy-Item -LiteralPath $sourceByVersion[$entry.version] -Destination $migrationTarget
  }
  if (@(Get-ChildItem -LiteralPath $migrationTarget -File -Filter '*.sql').Count -ne 73) {
    throw 'The disposable production baseline does not contain exactly 73 SQL files.'
  }

  $exclude = 'gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
  $stackStarted = $true
  Invoke-Supabase start --exclude $exclude --workdir $supabaseRoot
  # Repeat explicitly from a clean disposable database so migration replay is
  # the tested operation, independent of start-time behavior.
  Invoke-Supabase db reset --local --no-seed --workdir $supabaseRoot

  & (Join-Path $PSScriptRoot 'qa-issue-70-guardian-application-reader.ps1') -ContainerName $containerName
}
finally {
  # Cleanup is scoped to the uniquely named, temporary local project only.
  if ($stackStarted) {
    try { Invoke-Supabase stop --workdir $supabaseRoot --no-backup } catch { Write-Warning 'Local temporary Supabase stack cleanup needs attention.' }
  }
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $archiveZip -Force -ErrorAction SilentlyContinue
}

Write-Host '[qa-issue-70-production-baseline] PASS: 73 verified production migration sources and Guardian pgTAP regression.' -ForegroundColor Green
