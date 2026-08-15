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
    "-SkipTemplateBuild"
)
if ($IDE64) {
    $arguments += "-IDE64"
}

& powershell.exe @arguments
if ($LASTEXITCODE -ne 0) {
    throw (
        "Project creation and immediate navigation failed for Delphi " +
        "$DelphiVersion."
    )
}

Write-Host (
    "Project creation and immediate navigation passed for Delphi " +
    "$DelphiVersion."
)
