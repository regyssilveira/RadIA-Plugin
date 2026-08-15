[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,

    [switch]$IDE64
)

$ErrorActionPreference = "Stop"
$smokePath = Join-Path $PSScriptRoot "Test-RadIA.KnowledgeNotifierSmoke.ps1"
$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $smokePath,
    "-DelphiVersion",
    $DelphiVersion,
    "-SkipBuildAndTests",
    "-SkipTemplateBuild",
    "-ExerciseProjectTransition"
)
if ($IDE64) {
    $arguments += "-IDE64"
}

& powershell.exe @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Knowledge project-transition gate failed for Delphi $DelphiVersion."
}

Write-Host (
    "Knowledge project-transition gate passed for Delphi $DelphiVersion."
)
