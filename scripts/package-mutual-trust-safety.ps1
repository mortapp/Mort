$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$masterZip = Join-Path $root 'mort-mutual-trust-safety-verification-master-clean.zip'
$webZip = Join-Path $root 'mort-web-mutual-trust-safety.zip'
$swiftZip = Join-Path $root 'mort-swiftui-mutual-trust-safety-clean.zip'
$webRoot = (Resolve-Path (Join-Path $root 'flutter_mort\build\web')).Path
$swiftRoot = (Resolve-Path (Join-Path $root 'swift_mort')).Path
$sourceStage = Join-Path $root '.delivery-stage-mutual-trust-source'
$swiftStage = Join-Path $root '.delivery-stage-mutual-trust-swift'

function Assert-ChildPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a path outside the workspace: $full"
  }
}

foreach ($path in @($masterZip, $webZip, $swiftZip, $sourceStage, $swiftStage)) {
  Assert-ChildPath -Path $path
}

$excludedSegments = @(
  'node_modules',
  '.expo',
  '.supabase-cli-config',
  '.dart_tool',
  '.git',
  '.idea',
  '.vscode',
  'build',
  'dist',
  'logs',
  'backups',
  'coverage',
  'outputs',
  'DerivedData',
  'Pods',
  'ephemeral',
  '.symlinks',
  '.temp',
  '.delivery-stage-mutual-trust-source',
  '.delivery-stage-mutual-trust-swift'
)

function Test-AllowedSourceFile {
  param(
    [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
    [Parameter(Mandatory = $true)][string]$BasePath
  )
  $relative = $File.FullName.Substring($BasePath.Length + 1)
  $segments = $relative -split '[\\/]'
  foreach ($segment in $segments) {
    if ($excludedSegments -contains $segment) { return $false }
  }
  if ($File.Name -in @('.env', '.env.local', '.DS_Store', 'Thumbs.db')) { return $false }
  if ($File.Extension -in @('.zip', '.log')) { return $false }
  return $true
}

function Copy-CleanTree {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File -Force) {
    if (-not (Test-AllowedSourceFile -File $file -BasePath $Source)) { continue }
    $relative = $file.FullName.Substring($Source.Length + 1)
    $target = Join-Path $Destination $relative
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $target
  }
}

function Get-ServerSecrets {
  $names = @(
    'SUPABASE_SERVICE_ROLE_KEY',
    'SUPABASE_ACCESS_TOKEN',
    'SUPABASE_DB_PASSWORD',
    'REVENUECAT_V1_SECRET_API_KEY',
    'REVENUECAT_WEBHOOK_AUTH_HEADER',
    'REVENUECAT_WEBHOOK_SECRET',
    'SEND_PUSH_INVOKE_SECRET',
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
    'GEMINI_API_KEY',
    'NETLIFY_AUTH_TOKEN',
    'VERCEL_TOKEN'
  )
  $values = @()
  foreach ($name in $names) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
      $value = [Environment]::GetEnvironmentVariable($name, 'User')
    }
    if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 12) {
      $values += [pscustomobject]@{ Name = $name; Value = $value }
    }
  }
  return $values
}

function Get-ZipAudit {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet('master', 'web', 'swift')][string]$Kind,
    [Parameter(Mandatory = $true)][array]$Secrets
  )
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
    $names = @($entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    $forbidden = @($names | Where-Object {
      $_ -match '(^|/)(node_modules|\.expo|\.supabase-cli-config|\.dart_tool|\.git|\.idea|\.vscode|build|dist|logs|backups|coverage|outputs|DerivedData|Pods)(/|$)' -or
        $_ -match '(^|/)\.env(\.local)?$' -or
        $_ -match '\.(zip|log)$' -or
        $_ -match '(^|/)(raw[-_ ]?identity[-_ ]?evidence|qa[-_ ]?identity[-_ ]?documents?|legal[-_ ]?request[-_ ]?evidence|law[-_ ]?enforcement[-_ ]?evidence)(/|$)'
    })
    if ($forbidden.Count -gt 0) {
      throw "Forbidden $Kind archive entries: $($forbidden -join ', ')"
    }

    if ($Kind -eq 'master') {
      foreach ($required in @(
        'docs/MORT_MUTUAL_TRUST_RLS_MATRIX.md',
        'docs/MORT_MUTUAL_TRUST_SAFETY_IMPLEMENTATION_RESULTS.md',
        'supabase/migrations/20260718040458_fix_mutual_safety_job_word_boundaries.sql'
      )) {
        if ($names -notcontains $required) { throw "Master archive is missing $required." }
      }
    }
    if ($Kind -eq 'web') {
      foreach ($required in @('index.html', 'manifest.json', 'flutter_bootstrap.js', 'main.dart.js')) {
        if ($names -notcontains $required) { throw "Web archive is missing root entry $required." }
      }
      foreach ($requiredPrefix in @('assets/', 'icons/')) {
        if (-not ($names | Where-Object { $_.StartsWith($requiredPrefix) })) {
          throw "Web archive is missing $requiredPrefix contents."
        }
      }
      if ($names | Where-Object { $_ -match '(^|/)(lib|test|supabase|scripts|docs)(/|$)' }) {
        throw 'Web archive contains source directories.'
      }
    }
    if ($Kind -eq 'swift') {
      foreach ($required in @('MORT.xcodeproj/project.pbxproj', 'MORT/App/MORTApp.swift', 'MORT/Features/Safety/TrustSafetyViews.swift')) {
        if ($names -notcontains $required) { throw "Swift archive is missing $required." }
      }
      if ($names | Where-Object { $_ -match '(^|/)(flutter_mort|node_modules|supabase)(/|$)' }) {
        throw 'Swift archive contains non-Swift project trees.'
      }
    }

    foreach ($entry in $entries) {
      $stream = $entry.Open()
      $memory = New-Object System.IO.MemoryStream
      try {
        $stream.CopyTo($memory)
        $content = [Text.Encoding]::UTF8.GetString($memory.ToArray())
        foreach ($secret in $Secrets) {
          if ($content.Contains($secret.Value)) {
            throw "Server secret value from $($secret.Name) was found in $Kind archive entry $($entry.FullName)."
          }
        }
      } finally {
        $memory.Dispose()
        $stream.Dispose()
      }
    }

    return [pscustomobject]@{
      Kind = $Kind
      Path = $Path
      Bytes = (Get-Item -LiteralPath $Path).Length
      Files = $entries.Count
      Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
      SecretValuesChecked = $Secrets.Count
      SensitivePathAudit = 'PASS'
    }
  } finally {
    $archive.Dispose()
  }
}

foreach ($path in @($sourceStage, $swiftStage)) {
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  New-Item -ItemType Directory -Path $path | Out-Null
}

try {
  Copy-CleanTree -Source $root -Destination $sourceStage
  Copy-CleanTree -Source $swiftRoot -Destination $swiftStage

  foreach ($zip in @($masterZip, $webZip, $swiftZip)) {
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  }

  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourceStage, $masterZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  [System.IO.Compression.ZipFile]::CreateFromDirectory($webRoot, $webZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  [System.IO.Compression.ZipFile]::CreateFromDirectory($swiftStage, $swiftZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)

  $secrets = @(Get-ServerSecrets)
  Get-ZipAudit -Path $masterZip -Kind 'master' -Secrets $secrets
  Get-ZipAudit -Path $webZip -Kind 'web' -Secrets $secrets
  Get-ZipAudit -Path $swiftZip -Kind 'swift' -Secrets $secrets
} finally {
  foreach ($path in @($sourceStage, $swiftStage)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  }
}
