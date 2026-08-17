[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,

    [switch]$IDE64,

    [switch]$Complete,

    [string]$EvidencePath = ""
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
    $DelphiVersion
)
if ($Complete) {
    $arguments += @("-ExerciseDebugger", "-ExerciseCalculatorRuntime")
} else {
    $arguments += @("-SkipBuildAndTests", "-SkipTemplateBuild")
}
if ($IDE64) {
    $arguments += "-IDE64"
}
if ($EvidencePath) {
    $arguments += @("-EvidencePath", $EvidencePath)
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
