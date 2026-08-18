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
$arguments = @{
    DelphiVersion = $DelphiVersion
    ExerciseTestCorrection = $true
    EvidencePath = $EvidencePath
}
if ($IDE64) {
    $arguments.IDE64 = $true
}
$previousAutoConsent = $env:RADIA_IDE_SMOKE_AUTO_CONSENT
try {
    $env:RADIA_IDE_SMOKE_AUTO_CONSENT = "1"
    & (Join-Path $PSScriptRoot "Test-RadIA.KnowledgeNotifierSmoke.ps1") @arguments
} finally {
    $env:RADIA_IDE_SMOKE_AUTO_CONSENT = $previousAutoConsent
}
$evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
if (-not $evidence.phases.testFailureObservedAndFixed -or
    -not $evidence.phases.testsPassed -or
    -not $evidence.phases.shutdownPassed) {
    throw "The DUnitX repair journey did not satisfy its release contract."
}
Write-Host "DUnitX repair E2E passed: $EvidencePath"
