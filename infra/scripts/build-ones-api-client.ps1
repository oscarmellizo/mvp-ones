$ErrorActionPreference = 'Stop'

$RootDir = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$ClientDir = Join-Path $RootDir 'packages\ones_api_client'

if (-not (Test-Path $ClientDir)) {
  throw "Client package not found: $ClientDir"
}

Push-Location $ClientDir
try {
  dart run build_runner build --delete-conflicting-outputs
} finally {
  Pop-Location
}
