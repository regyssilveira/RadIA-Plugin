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
$resolvedEvidence = [IO.Path]::GetFullPath($EvidencePath)
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedEvidence) `
    -Force | Out-Null
if (Test-Path -LiteralPath $resolvedEvidence) {
    Remove-Item -LiteralPath $resolvedEvidence -Force
}
$previousEnvironment = $env:RADIA_IDE_SMOKE_AGENT_BUDGET
try {
    $env:RADIA_IDE_SMOKE_AGENT_BUDGET = $resolvedEvidence
    $arguments = @{
        DelphiVersion = $DelphiVersion
        Cycles = 2
        ExerciseDocking = $true
    }
    if ($IDE64) {
        $arguments.IDE64 = $true
    }
    & (Join-Path $PSScriptRoot "Test-RadIA.IDESmoke.ps1") @arguments
} finally {
    $env:RADIA_IDE_SMOKE_AGENT_BUDGET = $previousEnvironment
}
if (-not (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf)) {
    throw "Agent budget E2E evidence was not generated."
}
$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw |
    ConvertFrom-Json
$passed =
    $evidence.status -eq "passed" -and
    $evidence.planApproved -eq $true -and
    $evidence.journeyCompleted -eq $true -and
    $evidence.budgetRemaining -eq $true -and
    $evidence.repeatedReadOnlyLoop -eq $false -and
    $evidence.stepLimitReached -eq $false
if (-not $passed) {
    throw "Agent budget E2E did not satisfy the release contract."
}
Write-Host "Agent budget E2E passed: $resolvedEvidence"
