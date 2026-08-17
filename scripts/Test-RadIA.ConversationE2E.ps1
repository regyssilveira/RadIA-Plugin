[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [switch]$IDE64,
    [switch]$SensitiveDataAudit,
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
    throw "Conversation E2E evidence must remain inside Output."
}
$evidenceDirectory = Split-Path -Parent $resolvedEvidence
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
if (Test-Path -LiteralPath $resolvedEvidence) {
    Remove-Item -LiteralPath $resolvedEvidence -Force
}

$previousEnvironment = $env:RADIA_IDE_SMOKE_CONVERSATION
$previousPromptEnvironment = $env:RADIA_IDE_SMOKE_CONVERSATION_PROMPT
$secretMarker = ""
try {
    $env:RADIA_IDE_SMOKE_CONVERSATION = $resolvedEvidence
    if ($SensitiveDataAudit) {
        $secretMarker = "RADIA_E2E_SECRET_$([Guid]::NewGuid().ToString('N'))"
        $env:RADIA_IDE_SMOKE_CONVERSATION_PROMPT = (
            "Who are you? Do not repeat this diagnostic marker: " +
            $secretMarker
        )
    }
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
    $env:RADIA_IDE_SMOKE_CONVERSATION = $previousEnvironment
    $env:RADIA_IDE_SMOKE_CONVERSATION_PROMPT = $previousPromptEnvironment
}

if (-not (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf)) {
    throw "Conversation E2E evidence was not generated."
}
$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw |
    ConvertFrom-Json
$passed =
    $evidence.status -eq "passed" -and
    $evidence.answerVisible -eq $true -and
    $evidence.planVisible -eq $false -and
    $evidence.consentVisible -eq $false -and
    $evidence.stepLimitReached -eq $false -and
    $evidence.elapsedMilliseconds -le 20000 -and
    $evidence.promptContentStored -eq $false -and
    $evidence.responseContentStored -eq $false
if (-not $passed) {
    throw "Conversation E2E evidence did not satisfy the release contract."
}

if ($SensitiveDataAudit) {
    $logRoot = Join-Path $env:APPDATA "RadIA\Logs"
    $logFiles = @(
        Get-ChildItem -LiteralPath $logRoot -Filter "*.log" -File `
            -ErrorAction SilentlyContinue
    )
    foreach ($logFile in $logFiles) {
        if ((Get-Content -LiteralPath $logFile.FullName -Raw).Contains(
            $secretMarker
        )) {
            throw "Sensitive diagnostic marker was written to a RadIA log."
        }
    }
    $evidenceText = Get-Content -LiteralPath $resolvedEvidence -Raw
    if ($evidenceText.Contains($secretMarker)) {
        throw "Sensitive diagnostic marker was written to E2E evidence."
    }
    $evidence | Add-Member -NotePropertyName secretRedacted `
        -NotePropertyValue $true -Force
    $evidence | Add-Member -NotePropertyName promptContentOmitted `
        -NotePropertyValue $true -Force
    $evidence | Add-Member -NotePropertyName diagnosticActionable `
        -NotePropertyValue $true -Force
    $evidence | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8
}

Write-Host "Conversation E2E passed: $resolvedEvidence"
