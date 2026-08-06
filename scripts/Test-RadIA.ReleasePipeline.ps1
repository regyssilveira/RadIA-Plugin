param(
    [string]$WorkflowPath = ".\.github\workflows\signed-release.yml"
)

$ErrorActionPreference = "Stop"
$resolvedWorkflow = [IO.Path]::GetFullPath($WorkflowPath)
if (-not (Test-Path -LiteralPath $resolvedWorkflow -PathType Leaf)) {
    throw "Signed release workflow was not found: $resolvedWorkflow"
}

$workflow = Get-Content -LiteralPath $resolvedWorkflow -Raw
$requiredFragments = @(
    "RADIA_SIGNING_PFX_BASE64",
    "RADIA_SIGNING_PFX_PASSWORD",
    "environment: production",
    "Import-PfxCertificate",
    "1.3.6.1.5.5.7.3.3",
    "New-RadIA.ReleaseEvidence.ps1",
    "New-RadIA.VisualInstaller.ps1",
    "Test-RadIA.VisualInstaller.ps1",
    "-RequireSignature",
    "New-RadIA.ReleaseChannel.ps1",
    "https://github.com/",
    "actions/upload-artifact@v4",
    "gh release upload",
    "Remove signing material from runner",
    "if: always()"
)

foreach ($fragment in $requiredFragments) {
    if (-not $workflow.Contains($fragment)) {
        throw "Signed release workflow is missing required gate: $fragment"
    }
}

$packageBuilds = [regex]::Matches(
    $workflow,
    "\\build\.ps1[^\r\n]+-Release -Package"
)
if ($packageBuilds.Count -ne 3) {
    throw "Signed release workflow must build exactly three Delphi 12/13 packages."
}
if ($workflow.Contains("AllowUnsignedDevelopment")) {
    throw "Signed release workflow cannot allow unsigned development mode."
}
if ($workflow.Contains("http://github.com/")) {
    throw "Signed release workflow contains an insecure release URL."
}

Write-Host (
    "Signed release workflow validation succeeded with three Delphi 12/13 package " +
    "targets and fail-closed signing."
)
