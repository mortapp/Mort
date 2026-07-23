$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$raw = Join-Path $root 'build\play\assets\raw'
$output = [IO.Path]::GetFullPath((Join-Path $root 'build\play\store-assets'))
$magick = (Get-Command magick -ErrorAction Stop).Source

if (-not $output.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Store asset output escaped the MORT workspace.'
}
if (Test-Path -LiteralPath $output) {
  Remove-Item -LiteralPath $output -Recurse -Force
}

$iconDirectory = New-Item -ItemType Directory -Force -Path (Join-Path $output 'app-icon')
$graphicDirectory = New-Item -ItemType Directory -Force -Path (Join-Path $output 'feature-graphic')
$largeDirectory = New-Item -ItemType Directory -Force -Path (Join-Path $output 'phone-large')
$smallDirectory = New-Item -ItemType Directory -Force -Path (Join-Path $output 'phone-small')

$iconSource = Join-Path $root 'flutter_mort\web\icons\Icon-512.png'
if (-not (Test-Path -LiteralPath $iconSource)) {
  throw "Missing app icon source: $iconSource"
}

$iconOutput = Join-Path $iconDirectory 'mort-play-icon-512.png'
& $magick $iconSource -resize '512x512!' -colorspace sRGB -strip $iconOutput
if ($LASTEXITCODE -ne 0) { throw 'App icon generation failed.' }

$featureOutput = Join-Path $graphicDirectory 'mort-feature-graphic-1024x500.png'
$featureArguments = @(
  '-size', '1024x500', 'xc:#050706',
  '(', $iconSource, '-resize', '260x260', ')',
  '-geometry', '+58+120', '-composite',
  '-font', 'Arial', '-fill', '#F4F7F5', '-pointsize', '92',
  '-annotate', '+360+205', 'MORT',
  '-fill', '#76FF69', '-pointsize', '38',
  '-annotate', '+360+278', 'Earn nearby. Move smart.',
  '-fill', '#C4CCC8', '-pointsize', '28',
  '-annotate', '+360+335', 'Approved-participant local work',
  '-alpha', 'off', '-colorspace', 'sRGB', '-strip', $featureOutput
)
& $magick @featureArguments
if ($LASTEXITCODE -ne 0) { throw 'Feature graphic generation failed.' }

$screens = @(
  @{ Name = '01-local-work'; Source = '01-release-launch-clean.png'; Caption = 'Earn nearby. Move smart.' },
  @{ Name = '02-closed-pilot'; Source = '03-account-status.png'; Caption = 'Clear closed-pilot access and verification limits.' },
  @{ Name = '03-teen-home'; Source = '04-teen-home.png'; Caption = 'Safety tools and essential teen workflows stay easy to reach.' },
  @{ Name = '04-nearby-jobs'; Source = '05-job-feed-final.png'; Caption = 'Discover approved local opportunities without exposing exact addresses.' },
  @{ Name = '05-job-details'; Source = '06-job-detail-final.png'; Caption = 'Review scope, schedule, location type, and payment preference.' },
  @{ Name = '06-applications'; Source = '07-applications-final.png'; Caption = 'Track applications and job-context next steps.' },
  @{ Name = '07-safety-center'; Source = '08-safety-center.png'; Caption = 'Report, block, and Safety Ping tools remain free.' },
  @{ Name = '08-job-agreements'; Source = '09-contracts.png'; Caption = 'Keep work, pay, and safety terms in a shared job agreement.' }
)

$inventory = @()
foreach ($screen in $screens) {
  $source = Join-Path $raw $screen.Source
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing accepted release capture: $source"
  }

  $large = Join-Path $largeDirectory ("{0}-1080x1920.png" -f $screen.Name)
  $small = Join-Path $smallDirectory ("{0}-720x1280.png" -f $screen.Name)
  & $magick $source -gravity North -crop '1080x1920+0+0' +repage -alpha off -colorspace sRGB -strip $large
  if ($LASTEXITCODE -ne 0) { throw "Large screenshot generation failed: $($screen.Name)" }
  & $magick $large -resize '720x1280!' -alpha off -colorspace sRGB -strip $small
  if ($LASTEXITCODE -ne 0) { throw "Small screenshot generation failed: $($screen.Name)" }

  $inventory += [ordered]@{
    order = $inventory.Count + 1
    caption = $screen.Caption
    releaseCapture = $screen.Source
    large = "phone-large/$([IO.Path]::GetFileName($large))"
    small = "phone-small/$([IO.Path]::GetFileName($small))"
  }
}

$inventoryDocument = [ordered]@{
  generatedAtUtc = [DateTime]::UtcNow.ToString('o')
  sourceBuild = 'MORT Android release 0.9.1+91'
  physicalDeviceClaim = $false
  tabletAssetsIncluded = $false
  screenshots = $inventory
}
$inventoryDocument | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'asset-inventory.json') -Encoding utf8

$captions = $inventory | ForEach-Object { "{0}. {1}" -f $_.order, $_.caption }
$captions | Set-Content -LiteralPath (Join-Path $output 'screenshot-captions.txt') -Encoding utf8

Write-Output "Generated Play assets: 1 icon, 1 feature graphic, $($screens.Count) large-phone screenshots, and $($screens.Count) small-phone screenshots."

