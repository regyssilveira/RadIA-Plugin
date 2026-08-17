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
    throw "Chat window persistence evidence must remain inside Output."
}

function Invoke-RadIAWindowStateSmoke {
    param([switch]$Hidden)

    $arguments = @{
        DelphiVersion = $DelphiVersion
        Cycles = 2
    }
    if ($IDE64) {
        $arguments.IDE64 = $true
    }
    if ($Hidden) {
        $arguments.ExpectDockHidden = $true
    } else {
        $arguments.ExerciseDocking = $true
    }
    & (Join-Path $PSScriptRoot "Test-RadIA.IDESmoke.ps1") @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Chat window persistence smoke failed."
    }
}

Invoke-RadIAWindowStateSmoke
Invoke-RadIAWindowStateSmoke -Hidden

$evidenceDirectory = Split-Path -Parent $resolvedEvidence
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "chatWindowPersistenceE2E"
    status = "passed"
    closedStateRestored = $true
    boundsRestored = $true
    dockStateRestored = $true
    cleanShutdown = $true
    cyclesPerState = 2
} | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8

Write-Host "Chat window persistence E2E passed: $resolvedEvidence"
