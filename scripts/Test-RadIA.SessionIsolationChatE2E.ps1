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
$previousSmoke = $env:RADIA_IDE_SMOKE_SESSION_ISOLATION
try {
    $env:RADIA_IDE_SMOKE_SESSION_ISOLATION = $resolvedEvidence
    $arguments = @{
        DelphiVersion = $DelphiVersion
        Cycles = 1
        UserJourneyEvidencePath = $resolvedEvidence
    }
    if ($IDE64) {
        $arguments.IDE64 = $true
    }
    & (Join-Path $PSScriptRoot "Test-RadIA.IDESmoke.ps1") @arguments
} finally {
    $env:RADIA_IDE_SMOKE_SESSION_ISOLATION = $previousSmoke
}

$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw |
    ConvertFrom-Json
if ($evidence.status -ne "passed" -or
    -not $evidence.sessionContextIsolated -or
    -not $evidence.pendingActionIsolated -or
    -not $evidence.historyCleared) {
    throw "The chat session isolation journey did not satisfy its contract."
}
Write-Host "Chat session isolation E2E passed: $resolvedEvidence"
