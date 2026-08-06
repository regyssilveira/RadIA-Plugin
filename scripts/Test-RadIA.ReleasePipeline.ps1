param(
    [string]$WorkflowPath = ".\.github\workflows\release.yml"
)

$ErrorActionPreference = "Stop"
$resolvedWorkflow = [IO.Path]::GetFullPath($WorkflowPath)
if (-not (Test-Path -LiteralPath $resolvedWorkflow -PathType Leaf)) {
    throw "Release workflow was not found: $resolvedWorkflow"
}

$workflow = Get-Content -LiteralPath $resolvedWorkflow -Raw
$requiredFragments = @(
    "environment: production",
    "New-RadIA.ReleaseEvidence.ps1",
    "New-RadIA.VisualInstaller.ps1",
    "Test-RadIA.VisualInstaller.ps1",
    "New-RadIA.ReleaseChannel.ps1",
    "https://github.com/",
    "actions/upload-artifact@v4",
    "gh release upload",
    "SHA256SUMS.txt"
)

foreach ($fragment in $requiredFragments) {
    if (-not $workflow.Contains($fragment)) {
        throw "Release workflow is missing required gate: $fragment"
    }
}

$packageBuilds = [regex]::Matches(
    $workflow,
    "\\build\.ps1[^\r\n]+-Release -Package"
)
if ($packageBuilds.Count -ne 3) {
    throw "Release workflow must build exactly three Delphi 12/13 packages."
}
if (
    $workflow.Contains("RADIA_SIGNING_PFX") -or
    $workflow.Contains("Import-PfxCertificate") -or
    $workflow.Contains("-RequireSignature")
) {
    throw "Release workflow cannot require code-signing material."
}
if ($workflow.Contains("http://github.com/")) {
    throw "Signed release workflow contains an insecure release URL."
}

Write-Host (
    "Release workflow validation succeeded with three Delphi 12/13 package " +
    "targets, SHA-256 evidence, and no certificate dependency."
)
