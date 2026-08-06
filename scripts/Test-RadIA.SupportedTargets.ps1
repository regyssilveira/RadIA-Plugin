param()

$ErrorActionPreference = "Stop"

$activePaths = @(
    ".\build.ps1",
    ".\installer\RadIA.iss",
    ".\scripts\Install-RadIA.Package.ps1",
    ".\scripts\New-RadIA.VisualInstaller.ps1",
    ".\scripts\New-RadIA.ReleaseEvidence.ps1",
    ".\scripts\New-RadIA.ReleaseChannel.ps1",
    ".\.github\workflows\quality-gate.yml",
    ".\.github\workflows\release.yml",
    ".\Source\Core\RadIA.Core.ProjectTemplates.pas",
    ".\Source\Core\RadIA.Core.ProjectTemplateTools.pas",
    ".\Source\UI\RadIA.UI.ProjectWizard.pas"
)
$forbiddenPatterns = @(
    '(?i)Delphi\s*11',
    '(?i)Delphi11',
    '(?i)PackageRoot22',
    '(?i)\bd11\b',
    '"22\.0"'
)

foreach ($path in $activePaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Supported-target gate path was not found: $path"
    }
    $content = Get-Content -LiteralPath $path -Raw
    foreach ($pattern in $forbiddenPatterns) {
        if ($content -match $pattern) {
            throw "Unsupported Delphi 11 target found in active path: $path"
        }
    }
}

$releaseWorkflow = Get-Content `
    -LiteralPath ".\.github\workflows\release.yml" `
    -Raw
$packageBuilds = [regex]::Matches(
    $releaseWorkflow,
    "\\build\.ps1[^\r\n]+-Release -Package"
)
if ($packageBuilds.Count -ne 3) {
    throw "Release workflow must build exactly three supported packages."
}
if (
    -not $releaseWorkflow.Contains('-DelphiVersion "23.0"') -or
    ([regex]::Matches(
        $releaseWorkflow,
        '-DelphiVersion "37\.0"'
    )).Count -ne 2
) {
    throw "Release workflow does not match the Delphi 12/13 matrix."
}

Write-Host (
    "Supported-target gate passed: Delphi 12 Win32, Delphi 13 Win32, " +
    "and Delphi 13 IDE64."
)
