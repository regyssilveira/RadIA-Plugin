param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion
)

$ErrorActionPreference = "Stop"

$bdsKey = "HKCU:\Software\Embarcadero\BDS\$DelphiVersion"
$rootDir = (
    Get-ItemProperty -LiteralPath $bdsKey -Name "RootDir"
).RootDir
$compilerPath = Join-Path $rootDir "bin\dcc32.exe"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$projectDirectory = Join-Path $repositoryRoot "Tests\RuntimeLab"
$outputRoot = Join-Path $repositoryRoot "Output\$DelphiVersion\runtime-lab"
$binaryDirectory = Join-Path $outputRoot "bin"
$dcuDirectory = Join-Path $outputRoot "dcu"

if (-not (Test-Path -LiteralPath $compilerPath)) {
    throw "Delphi compiler was not found at '$compilerPath'."
}

New-Item -ItemType Directory -Force -Path $binaryDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $dcuDirectory | Out-Null

Push-Location $projectDirectory
try {
    & $compilerPath `
        -B `
        -Q `
        "-E$binaryDirectory" `
        "-N$dcuDirectory" `
        "RadIARuntimeLab.dpr"
    if ($LASTEXITCODE -ne 0) {
        throw "Runtime laboratory build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$executablePath = Join-Path $binaryDirectory "RadIARuntimeLab.exe"
if (-not (Test-Path -LiteralPath $executablePath)) {
    throw "Runtime laboratory executable was not produced."
}

Write-Host "Runtime laboratory compiled: $executablePath" -ForegroundColor Green
