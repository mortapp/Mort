$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceZip = Join-Path $root 'mort-guardian-jobs-profiles-features-clean.zip'
$webZip = Join-Path $root 'mort-web-production-guardian-jobs-profiles.zip'
$webRoot = (Resolve-Path (Join-Path $root 'flutter_mort\build\web')).Path
$stage = Join-Path $root '.delivery-stage-guardian-features'

function Assert-ChildPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a path outside the workspace: $full"
  }
}

Assert-ChildPath -Path $stage
Assert-ChildPath -Path $sourceZip
Assert-ChildPath -Path $webZip

if (Test-Path -LiteralPath $stage) {
  Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage | Out-Null

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
  'Pods',
  'ephemeral',
  '.symlinks',
  '.temp',
  '.delivery-stage-guardian-features'
)

$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
  $relative = $_.FullName.Substring($root.Length + 1)
  $segments = $relative -split '[\\/]'
  $name = $_.Name
  $isExcludedSegment = $false
  foreach ($segment in $segments) {
    if ($excludedSegments -contains $segment) {
      $isExcludedSegment = $true
      break
    }
  }
  -not $isExcludedSegment -and
    $name -notin @('.env', '.env.local', '.DS_Store', 'Thumbs.db') -and
    $_.Extension -ne '.zip'
}

foreach ($file in $files) {
  $relative = $file.FullName.Substring($root.Length + 1)
  $destination = Join-Path $stage $relative
  $parent = Split-Path -Parent $destination
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  Copy-Item -LiteralPath $file.FullName -Destination $destination
}

$secretNames = @(
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
  'NETLIFY_AUTH_TOKEN'
)
$scanExtensions = @(
  '.dart', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.json', '.sql', '.md',
  '.txt', '.yaml', '.yml', '.toml', '.xml', '.html', '.css', '.sh', '.ps1',
  '.properties', '.gradle', '.swift', '.plist', '.lock', '.example'
)
$scanFiles = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object {
  $scanExtensions -contains $_.Extension.ToLowerInvariant() -or
    $_.Name -in @('Podfile', 'Gemfile', 'pubspec.yaml', 'pubspec.lock')
}

foreach ($secretName in $secretNames) {
  $secret = [Environment]::GetEnvironmentVariable($secretName, 'Process')
  if ([string]::IsNullOrWhiteSpace($secret)) {
    $secret = [Environment]::GetEnvironmentVariable($secretName, 'User')
  }
  if ([string]::IsNullOrWhiteSpace($secret) -or $secret.Length -lt 12) {
    continue
  }
  foreach ($file in $scanFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content.Contains($secret)) {
      $relative = $file.FullName.Substring($stage.Length + 1)
      throw "Server secret value from $secretName was found in staged file $relative."
    }
  }
}

$jwtPattern = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
foreach ($file in $scanFiles) {
  $content = [System.IO.File]::ReadAllText($file.FullName)
  if ($content -match $jwtPattern) {
    $relative = $file.FullName.Substring($stage.Length + 1)
    throw "JWT-like value found in staged source file $relative."
  }
}

foreach ($zip in @($sourceZip, $webZip)) {
  if (Test-Path -LiteralPath $zip) {
    Remove-Item -LiteralPath $zip -Force
  }
}

[System.IO.Compression.ZipFile]::CreateFromDirectory(
  $stage,
  $sourceZip,
  [System.IO.Compression.CompressionLevel]::Optimal,
  $false
)
[System.IO.Compression.ZipFile]::CreateFromDirectory(
  $webRoot,
  $webZip,
  [System.IO.Compression.CompressionLevel]::Optimal,
  $false
)

function Get-ZipAudit {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Kind
  )
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
    $names = @($entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    if ($Kind -eq 'source') {
      $forbidden = @($names | Where-Object {
        $_ -match '(^|/)(node_modules|\.expo|\.dart_tool|\.git|build|dist|logs|backups|Pods)(/|$)' -or
          $_ -match '(^|/)\.env(\.local)?$' -or
          $_ -match '\.zip$'
      })
      if ($forbidden.Count -gt 0) {
        throw "Forbidden source archive entries: $($forbidden -join ', ')"
      }
    } else {
      foreach ($required in @(
        'index.html',
        'manifest.json',
        'flutter_bootstrap.js',
        'main.dart.js'
      )) {
        if ($names -notcontains $required) {
          throw "Web archive is missing root entry $required."
        }
      }
      foreach ($requiredPrefix in @('assets/', 'icons/')) {
        if (-not ($names | Where-Object { $_.StartsWith($requiredPrefix) })) {
          throw "Web archive is missing $requiredPrefix contents."
        }
      }
      if ($names -contains 'flutter_mort/build/web/index.html') {
        throw 'Web archive is wrapped in source directories.'
      }
    }
    return [pscustomobject]@{
      Path = $Path
      Bytes = (Get-Item -LiteralPath $Path).Length
      Files = $entries.Count
    }
  } finally {
    $archive.Dispose()
  }
}

$sourceAudit = Get-ZipAudit -Path $sourceZip -Kind 'source'
$webAudit = Get-ZipAudit -Path $webZip -Kind 'web'

Remove-Item -LiteralPath $stage -Recurse -Force

$sourceAudit
$webAudit
