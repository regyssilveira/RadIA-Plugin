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
$chatEvidence = [IO.Path]::Combine(
    [IO.Path]::GetDirectoryName($resolvedEvidence),
    [IO.Path]::GetFileNameWithoutExtension($resolvedEvidence) +
        "-chat.json"
)
$arguments = @{
    DelphiVersion = $DelphiVersion
    ExerciseProjectTransition = $true
    SkipBuildAndTests = $true
    SkipTemplateBuild = $true
    EvidencePath = $EvidencePath
}
if ($IDE64) {
    $arguments.IDE64 = $true
}
& (Join-Path $PSScriptRoot "Test-RadIA.KnowledgeNotifierSmoke.ps1") @arguments
& (Join-Path $PSScriptRoot "Test-RadIA.SessionIsolationChatE2E.ps1") `
    -DelphiVersion $DelphiVersion `
    -IDE64:$IDE64 `
    -EvidencePath $chatEvidence
$evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
$chat = Get-Content -LiteralPath $chatEvidence -Raw | ConvertFrom-Json
$evidence.phases.sessionContextIsolated = [bool]$chat.sessionContextIsolated
$evidence.phases.pendingActionIsolated = [bool]$chat.pendingActionIsolated
$evidence | ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $EvidencePath -Encoding UTF8
if (-not $evidence.phases.projectContextSwitched -or
    -not $evidence.phases.sessionContextIsolated -or
    -not $evidence.phases.pendingActionIsolated -or
    -not $evidence.phases.shutdownPassed) {
    throw "The project and session isolation journey did not satisfy its release contract."
}
Write-Host "Project and session isolation E2E passed: $EvidencePath"
