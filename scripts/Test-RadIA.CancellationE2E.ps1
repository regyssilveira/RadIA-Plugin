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
$resolvedEvidence = [IO.Path]::GetFullPath($EvidencePath)
$outputRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "Output"))
if (-not $resolvedEvidence.StartsWith(
    $outputRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Cancellation E2E evidence must remain inside Output."
}
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedEvidence) `
    -Force | Out-Null
if (Test-Path -LiteralPath $resolvedEvidence) {
    Remove-Item -LiteralPath $resolvedEvidence -Force
}

$previousEnvironment = $env:RADIA_IDE_SMOKE_CANCELLATION
try {
    $env:RADIA_IDE_SMOKE_CANCELLATION = $resolvedEvidence
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
    $env:RADIA_IDE_SMOKE_CANCELLATION = $previousEnvironment
}

if (-not (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf)) {
    throw "Cancellation E2E evidence was not generated."
}
$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw |
    ConvertFrom-Json
$passed =
    $evidence.status -eq "passed" -and
    $evidence.requestCancelled -eq $true -and
    $evidence.uiIdle -eq $true -and
    $evidence.nextAnswerVisible -eq $true -and
    $evidence.ideRestartRequired -eq $false -and
    $evidence.elapsedMilliseconds -le 90000
if (-not $passed) {
    throw "Cancellation E2E evidence did not satisfy the release contract."
}

Write-Host "Cancellation E2E passed: $resolvedEvidence"
