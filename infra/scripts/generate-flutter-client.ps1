$ErrorActionPreference = 'Stop'

$RootDir = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$OpenApi = Join-Path $RootDir 'contracts\openapi.yaml'
$OutDir = Join-Path $RootDir 'packages\ones_api_client'

$ToolsDir = Join-Path $RootDir 'tools'
$GeneratorVersion = '7.6.0'
$JarName = "openapi-generator-cli-$GeneratorVersion.jar"
$JarPath = Join-Path $ToolsDir $JarName
$JarUrl = "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/$GeneratorVersion/$JarName"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (Get-Command docker -ErrorAction SilentlyContinue) {
  $dockerReady = $false
  try {
    docker info | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $dockerReady = $true
    }
  } catch {
    $dockerReady = $false
  }

  if ($dockerReady) {
    docker run --rm `
      -v "${RootDir}:/local" `
      openapitools/openapi-generator-cli:v$GeneratorVersion generate `
      -i /local/contracts/openapi.yaml `
      -g dart-dio `
      -o /local/packages/ones_api_client `
      --additional-properties=pubName=ones_api_client,pubVersion=0.1.0
    exit 0
  }
}

New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

if (-not (Test-Path $JarPath)) {
  Write-Host "Downloading OpenAPI Generator CLI $GeneratorVersion..."
  Invoke-WebRequest -Uri $JarUrl -OutFile $JarPath
}

java -jar $JarPath generate `
  -i $OpenApi `
  -g dart-dio `
  -o $OutDir `
  --additional-properties=pubName=ones_api_client,pubVersion=0.1.0
