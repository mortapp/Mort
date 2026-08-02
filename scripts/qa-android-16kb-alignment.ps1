[CmdletBinding()]
param(
  [string]$ApkPath = 'build\play\mort-closed-test-0.9.12.apk'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not [IO.Path]::IsPathRooted($ApkPath)) {
  $ApkPath = Join-Path $root $ApkPath
}
$ApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
$readelf = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Android\Sdk\ndk') `
  -Recurse -Filter llvm-readelf.exe -ErrorAction Stop |
  Select-Object -First 1 -ExpandProperty FullName
if (-not $readelf) { throw 'NDK llvm-readelf.exe is unavailable.' }

$tempRoot = (Resolve-Path $env:TEMP).Path
$work = Join-Path $tempRoot ('mort-elf-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

try {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $apk = [IO.Compression.ZipFile]::OpenRead($ApkPath)
  try {
    foreach ($entry in $apk.Entries | Where-Object { $_.FullName -match '^lib/.+\.so$' }) {
      $destination = Join-Path $work $entry.FullName
      New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
    }
  } finally {
    $apk.Dispose()
  }
  $failures = @()
  $libraryCount = 0
  foreach ($library in Get-ChildItem (Join-Path $work 'lib') -Recurse -Filter *.so) {
    $libraryCount += 1
    $loads = & $readelf -lW $library.FullName |
      Where-Object { $_ -match '^\s*LOAD\s' }
    if ($LASTEXITCODE -ne 0) { throw "llvm-readelf failed for $($library.Name)." }
    foreach ($line in $loads) {
      if ($line -notmatch '\s(0x[0-9a-fA-F]+)\s*$') {
        throw "Could not parse LOAD alignment for $($library.Name)."
      }
      $alignment = [Convert]::ToInt64($Matches[1].Substring(2), 16)
      if ($alignment -lt 0x4000) {
        $failures += "$($library.FullName.Substring($work.Length + 1)):$($Matches[1])"
      }
    }
  }
  if ($libraryCount -eq 0) { throw 'No native libraries were found in the APK.' }
  if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "MISALIGNED=$_" }
    throw 'ELF LOAD segment alignment below 16 KB detected.'
  }
  Write-Output 'ELF_16KB_ALIGNMENT=PASS'
  Write-Output "NATIVE_LIBRARIES_CHECKED=$libraryCount"
} finally {
  $resolvedWork = (Resolve-Path -LiteralPath $work -ErrorAction SilentlyContinue).Path
  if ($resolvedWork -and
      $resolvedWork.StartsWith("$tempRoot\mort-elf-", [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedWork -Recurse -Force
  }
}
