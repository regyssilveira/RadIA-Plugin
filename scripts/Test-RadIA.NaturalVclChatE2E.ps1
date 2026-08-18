[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [switch]$IDE64,
    [Parameter(Mandatory = $true)]
    [string]$EvidencePath
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validationRoot = [IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "Output\Validation\NaturalVclChat")
)
New-Item -ItemType Directory -Path $validationRoot -Force | Out-Null
$journeyRoot = Join-Path $validationRoot ([Guid]::NewGuid().ToString("N"))
$initialDestination = Join-Path $journeyRoot "ExistingCalculator"
$destination = Join-Path $journeyRoot "RadIAUserCalculator"
New-Item -ItemType Directory -Path $initialDestination -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $initialDestination "existing.txt") `
    -Force | Out-Null
$resolvedEvidence = [IO.Path]::GetFullPath($EvidencePath)
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedEvidence) `
    -Force | Out-Null
if (Test-Path -LiteralPath $resolvedEvidence) {
    Remove-Item -LiteralPath $resolvedEvidence -Force
}

$previousValues = @{
    Evidence = $env:RADIA_IDE_SMOKE_NATURAL_VCL
    Destination = $env:RADIA_IDE_SMOKE_NATURAL_VCL_DESTINATION
    RetryDestination = $env:RADIA_IDE_SMOKE_NATURAL_VCL_RETRY_DESTINATION
    Root = $env:RADIA_IDE_SMOKE_NATURAL_VCL_ROOT
    DelphiVersion = $env:RADIA_IDE_SMOKE_DELPHI_VERSION
    Platform = $env:RADIA_IDE_SMOKE_TARGET_PLATFORM
    AutoConsent = $env:RADIA_IDE_SMOKE_AUTO_CONSENT
}
try {
    $env:RADIA_IDE_SMOKE_NATURAL_VCL = $resolvedEvidence
    $env:RADIA_IDE_SMOKE_NATURAL_VCL_DESTINATION = $initialDestination
    $env:RADIA_IDE_SMOKE_NATURAL_VCL_RETRY_DESTINATION = $destination
    $env:RADIA_IDE_SMOKE_NATURAL_VCL_ROOT = $journeyRoot
    $env:RADIA_IDE_SMOKE_DELPHI_VERSION = $DelphiVersion
    $env:RADIA_IDE_SMOKE_TARGET_PLATFORM = if ($IDE64) { "Win64" } else { "Win32" }
    $env:RADIA_IDE_SMOKE_AUTO_CONSENT = "1"
    $targetPlatform = $env:RADIA_IDE_SMOKE_TARGET_PLATFORM
    $journeyExecutable = Join-Path $destination (
        "bin\$targetPlatform\Debug\RadIAUserCalculator.exe"
    )
    $arguments = @{
        DelphiVersion = $DelphiVersion
        Cycles = 1
        UserJourneyEvidencePath = $resolvedEvidence
        UserJourneyExecutablePath = $journeyExecutable
    }
    if ($IDE64) {
        $arguments.IDE64 = $true
    }
    & (Join-Path $PSScriptRoot "Test-RadIA.IDESmoke.ps1") @arguments
} finally {
    $env:RADIA_IDE_SMOKE_NATURAL_VCL = $previousValues.Evidence
    $env:RADIA_IDE_SMOKE_NATURAL_VCL_DESTINATION = $previousValues.Destination
    $env:RADIA_IDE_SMOKE_NATURAL_VCL_RETRY_DESTINATION = `
        $previousValues.RetryDestination
    $env:RADIA_IDE_SMOKE_NATURAL_VCL_ROOT = $previousValues.Root
    $env:RADIA_IDE_SMOKE_DELPHI_VERSION = $previousValues.DelphiVersion
    $env:RADIA_IDE_SMOKE_TARGET_PLATFORM = $previousValues.Platform
    $env:RADIA_IDE_SMOKE_AUTO_CONSENT = $previousValues.AutoConsent
}

if (-not (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf)) {
    throw "The natural VCL chat evidence was not generated."
}
$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw | ConvertFrom-Json
$projectFile = Join-Path $destination "RadIAUserCalculator.dproj"
$passed =
    $evidence.status -eq "passed" -and
    $evidence.recommendationAccepted -eq $true -and
    $evidence.previewSucceeded -eq $true -and
    $evidence.creationSucceeded -eq $true -and
    $evidence.projectOpened -eq $true -and
    $evidence.buildPassed -eq $true -and
    $evidence.applicationStarted -eq $true -and
    $evidence.destinationRecovered -eq $true -and
    $evidence.recoveryCardVisible -eq $true -and
    $evidence.requirementsPreserved -eq $true -and
    $evidence.nativeOrchestration -eq $true -and
    $evidence.cliCompletedEarly -eq $false -and
    $evidence.toolUnavailable -eq $false -and
    (Test-Path -LiteralPath $projectFile -PathType Leaf)
if (-not $passed) {
    throw "The natural VCL chat journey did not satisfy its release contract."
}
Write-Host "Natural VCL chat E2E passed: $resolvedEvidence"
