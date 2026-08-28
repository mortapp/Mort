[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifactDirectory = Join-Path $root 'artifacts'
$stageRoot = Join-Path $root 'build\package-google-sign-in-0.9.8'
$zipPath = Join-Path $artifactDirectory 'mort-google-sign-in-0.9.8-source-clean.zip'
$excludedSegments = @(
  '.git', '.dart_tool', '.expo', '.gradle', '.idea', '.supabase-cli-config',
  '.temp', '.vscode', '.symlinks', 'artifacts', 'backups', 'build', 'coverage',
  'DerivedData', 'dist', 'ephemeral', 'logs', 'node_modules', 'outputs', 'Pods',
  'RorkIOSManualCopy', 'temp_old_zip', 'temp_zip'
)
$forbiddenNames = @(
  '.env', '.env.local', '.env.production', '.flutter-plugins-dependencies',
  'GeneratedPluginRegistrant.java', 'key.properties', 'local.properties'
)
$forbiddenExtensions = @(
  '.aab', '.apk', '.bak', '.db', '.dump', '.jks', '.key', '.keystore', '.log',
  '.mobileprovision', '.p12', '.pem', '.pfx', '.sqlite', '.sqlite3', '.zip'
)

function Assert-WorkspaceChild {
  param([Parameter(Mandatory)][string]$Path)
  $full = [IO.Path]::GetFullPath($Path)
  $prefix = $root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a package path outside the workspace: $full"
  }
}

function Test-SourceFileAllowed {
  param([Parameter(Mandatory)][IO.FileInfo]$File)
  $relative = $File.FullName.Substring($root.Length + 1)
  foreach ($segment in ($relative -split '[\\/]')) {
    if ($excludedSegments -contains $segment) { return $false }
  }
  if ($forbiddenNames -contains $File.Name) { return $false }
  if ($File.Name -match '^\.env\.' -and
      $File.Name -notmatch '^\.env\.(example|sample|template)$') {
    return $false
  }
  if ($File.Name -match '(?i)^client_secret_.+\.json$') { return $false }
  return $forbiddenExtensions -notcontains $File.Extension.ToLowerInvariant()
}

foreach ($path in @($artifactDirectory, $stageRoot, $zipPath)) {
  Assert-WorkspaceChild $path
}
if (Test-Path -LiteralPath $stageRoot) {
  Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $artifactDirectory, $stageRoot | Out-Null

foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
  if (-not (Test-SourceFileAllowed $file)) { continue }
  $relative = $file.FullName.Substring($root.Length + 1)
  $destination = Join-Path $stageRoot $relative
  New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}
[IO.Compression.ZipFile]::CreateFromDirectory(
  $stageRoot,
  $zipPath,
  [IO.Compression.CompressionLevel]::Optimal,
  $false
)

& (Join-Path $PSScriptRoot 'sensitive-file-scan.ps1') `
  -RootPath $stageRoot `
  -ArchivePath $zipPath

$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $entries = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') })
  $forbidden = @($entries | Where-Object {
    $name = $_.FullName.Replace('\', '/')
    $fileName = [IO.Path]::GetFileName($name)
    $extension = [IO.Path]::GetExtension($fileName).ToLowerInvariant()
    $name -match '(^|/)(\.git|\.dart_tool|\.expo|node_modules|build|dist|logs|backups)(/|$)' -or
      ($fileName -match '^\.env($|\.)' -and
        $fileName -notmatch '^\.env\.(example|sample|template)$') -or
      $fileName -match '(?i)^client_secret_.+\.json$' -or
      $forbiddenExtensions -contains $extension
  })
  if ($forbidden.Count -gt 0) {
    throw "Forbidden package entries found: $($forbidden.Count)"
  }
  $zip = Get-Item -LiteralPath $zipPath
  Write-Output "ZIP_PATH=$($zip.FullName)"
  Write-Output "ZIP_SIZE_BYTES=$($zip.Length)"
  Write-Output "ZIP_FILE_COUNT=$($entries.Count)"
  Write-Output "ZIP_SHA256=$((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash)"
} finally {
  $archive.Dispose()
}

Remove-Item -LiteralPath $stageRoot -Recurse -Force
