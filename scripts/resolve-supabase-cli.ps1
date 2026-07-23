function Initialize-SupabaseCliEnvironment {
  $configDir = Join-Path (Resolve-Path "$PSScriptRoot\..") ".supabase-cli-config"
  New-Item -ItemType Directory -Force -Path $configDir | Out-Null
  $env:XDG_CONFIG_HOME = $configDir
}

function Resolve-SupabaseCli {
  Initialize-SupabaseCliEnvironment

  $globalCommand = Get-Command supabase -ErrorAction SilentlyContinue
  if ($globalCommand) {
    return $globalCommand.Source
  }

  $localCommand = Join-Path (Resolve-Path "$PSScriptRoot\..") "node_modules\.bin\supabase.cmd"
  if (Test-Path -LiteralPath $localCommand) {
    return $localCommand
  }

  throw "Supabase CLI is not installed. Install it with Scoop or run pnpm add -D supabase in this project."
}

function Invoke-SupabaseCli {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $supabaseCli = Resolve-SupabaseCli
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"

  try {
    $output = & $supabaseCli @Arguments 2>&1 | ForEach-Object { $_.ToString() }
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  [pscustomobject]@{
    Output = $output
    ExitCode = $exitCode
  }
}
