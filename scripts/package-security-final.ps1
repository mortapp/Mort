$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceZip = Join-Path $root 'mort-security-rls-performance-final-clean.zip'
$webZip = Join-Path $root 'mort-web-security-hardened.zip'
$webRoot = (Resolve-Path (Join-Path $root 'flutter_mort\build\web')).Path
$stage = Join-Path $root '.delivery-stage-security-final'

function Assert-ChildPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a path outside the workspace: $full"
  }
}

foreach ($path in @($stage, $sourceZip, $webZip)) {
  Assert-ChildPath -Path $path
}

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
  '.delivery-stage-security-final'
)

try {
  $files = Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
    $relative = $_.FullName.Substring($root.Length + 1)
    $segments = $relative -split '[\\/]'
    $excluded = $false
    foreach ($segment in $segments) {
      if ($excludedSegments -contains $segment) {
        $excluded = $true
        break
      }
    }
    -not $excluded -and
      $_.Name -notin @('.env', '.env.local', '.DS_Store', 'Thumbs.db') -and
      $_.Extension -notin @('.zip', '.log')
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
    'NETLIFY_AUTH_TOKEN',
    'VERCEL_TOKEN'
  )
  $secretValues = @()
  foreach ($name in $secretNames) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
      $value = [Environment]::GetEnvironmentVariable($name, 'User')
    }
    if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 12) {
      $secretValues += [pscustomobject]@{ Name = $name; Value = $value }
    }
  }

  function Get-ZipAudit {
    param(
      [Parameter(Mandatory = $true)][string]$Path,
      [Parameter(Mandatory = $true)][ValidateSet('source', 'web')][string]$Kind
    )
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
      $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
      $names = @($entries | ForEach-Object { $_.FullName.Replace('\', '/') })
      if ($Kind -eq 'source') {
        $forbidden = @($names | Where-Object {
          $_ -match '(^|/)(node_modules|\.expo|\.supabase-cli-config|\.dart_tool|\.git|\.idea|\.vscode|build|dist|logs|backups|coverage|outputs|Pods)(/|$)' -or
            $_ -match '(^|/)\.env(\.local)?$' -or
            $_ -match '\.(zip|log)$'
        })
        if ($forbidden.Count -gt 0) {
          throw "Forbidden source archive entries: $($forbidden -join ', ')"
        }
      } else {
        foreach ($required in @('index.html', 'manifest.json', 'flutter_bootstrap.js', 'main.dart.js')) {
          if ($names -notcontains $required) {
            throw "Web archive is missing root entry $required."
          }
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

      foreach ($entry in $entries) {
        $stream = $entry.Open()
        $memory = New-Object System.IO.MemoryStream
        try {
          $stream.CopyTo($memory)
          $bytes = $memory.ToArray()
          $content = [Text.Encoding]::UTF8.GetString($bytes)
          foreach ($secret in $secretValues) {
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
        SecretValuesChecked = $secretValues.Count
      }
    } finally {
      $archive.Dispose()
    }
  }

  $sourceAudit = Get-ZipAudit -Path $sourceZip -Kind 'source'
  $webAudit = Get-ZipAudit -Path $webZip -Kind 'web'
  $sourceAudit
  $webAudit
} finally {
  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
}
