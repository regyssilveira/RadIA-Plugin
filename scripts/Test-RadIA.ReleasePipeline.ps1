param(
    [string]$WorkflowPath = ".\.github\workflows\release.yml",
    [string]$QualityWorkflowPath = ".\.github\workflows\quality-gate.yml"
)

$ErrorActionPreference = "Stop"
$resolvedWorkflow = [IO.Path]::GetFullPath($WorkflowPath)
if (-not (Test-Path -LiteralPath $resolvedWorkflow -PathType Leaf)) {
    throw "Release workflow was not found: $resolvedWorkflow"
}

$workflow = Get-Content -LiteralPath $resolvedWorkflow -Raw
$automaticTagTrigger = [regex]::IsMatch(
    $workflow,
    '(?ms)^on:\s*\r?\n\s+push:\s*\r?\n\s+tags:'
)
if ($automaticTagTrigger) {
    throw (
        "Release workflow cannot run automatically from a tag push. " +
        "Official artifacts are generated and published locally."
    )
}
if (-not $workflow.Contains("workflow_dispatch:")) {
    throw "Release workflow must remain available as an optional manual validation."
}
if ($workflow.Contains("github.event_name == 'push'")) {
    throw "Release publication cannot depend on a GitHub push event."
}

$resolvedQualityWorkflow = [IO.Path]::GetFullPath($QualityWorkflowPath)
if (-not (Test-Path -LiteralPath $resolvedQualityWorkflow -PathType Leaf)) {
    throw "Quality workflow was not found: $resolvedQualityWorkflow"
}
$qualityWorkflow = Get-Content -LiteralPath $resolvedQualityWorkflow -Raw
if (-not $qualityWorkflow.Contains("workflow_dispatch:")) {
    throw "SonarQube workflow must remain available as an optional manual validation."
}
$automaticQualityTriggers = [regex]::IsMatch(
    $qualityWorkflow,
    '(?m)^\s{2}(?:push|pull_request):\s*$'
)
if ($automaticQualityTriggers) {
    throw (
        "SonarQube GitHub validation cannot run from push, pull request, or tag. " +
        "The official Quality Gate runs locally."
    )
}
$requiredFragments = @(
    "New-RadIA.ReleaseEvidence.ps1",
    "New-RadIA.VisualInstaller.ps1",
    "Test-RadIA.VisualInstaller.ps1",
    "Test-RadIA.ReleaseUsage.ps1",
    "Prepare a clean distribution directory",
    "https://github.com/",
    "actions/upload-artifact@v4",
    "gh release upload",
    "INSTALLER_NAME"
)

foreach ($fragment in $requiredFragments) {
    if (-not $workflow.Contains($fragment)) {
        throw "Release workflow is missing required gate: $fragment"
    }
}

$mandatoryUsageGate = [regex]::IsMatch(
    $workflow,
    '(?im)^\s*- name:\s*Run mandatory .*integration.*calculator.*project.*usage gate\s*$'
)
if (-not $mandatoryUsageGate) {
    throw (
        "Release workflow is missing the mandatory integration, calculator, " +
        "project opening, and usage gate."
    )
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
if (
    $workflow.Contains('Destination ".\Output\Distribution\$package"') -or
    $workflow.Contains(
        'Destination ".\Output\Distribution\SHA256SUMS.txt"'
    )
) {
    throw "Internal package ZIP files cannot be published in the distribution."
}
if ($workflow.Contains('".\Output\Distribution\*"')) {
    throw "GitHub Release cannot publish the internal evidence bundle."
}
if (-not $workflow.Contains('".\Output\Distribution\$env:INSTALLER_NAME"')) {
    throw "GitHub Release is missing the public installer."
}
if ($workflow.Contains('".\Output\Distribution\stable.json"')) {
    throw "GitHub Release cannot publish an unused update catalog."
}

$packageInstallerPath = ".\scripts\Install-RadIA.Package.ps1"
$packageInstaller = Get-Content -LiteralPath $packageInstallerPath -Raw
$packageInstallerFragments = @(
    "Get-Process bds",
    "Close all Delphi IDE instances before changing RadIA",
    '$runningIDEs.Count -gt 0'
)
foreach ($fragment in $packageInstallerFragments) {
    if (-not $packageInstaller.Contains($fragment)) {
        throw "Package installer is missing required IDE-open gate: $fragment"
    }
}
if ($packageInstaller.Contains("Close all instances of the target Delphi IDE")) {
    throw "Package installer must block every Delphi IDE instance, not only the target IDE."
}

$visualInstallerPath = ".\installer\RadIA.iss"
$visualInstaller = Get-Content -LiteralPath $visualInstallerPath -Raw
$visualInstallerFragments = @(
    "PrepareToInstall",
    "InitializeUninstall",
    "Win32_Process WHERE Name = ""bds.exe""",
    "Close all Delphi IDE instances before installing"
)
foreach ($fragment in $visualInstallerFragments) {
    if (-not $visualInstaller.Contains($fragment)) {
        throw "Visual installer is missing required IDE-open gate: $fragment"
    }
}

Write-Host (
    "Release workflow validation succeeded with three internal Delphi inputs, " +
    "mandatory usage tests, one public installer, internal evidence, " +
    "no unused update catalog, " +
    "manual-only GitHub validation, local artifact publication, " +
    "no certificate dependency, and " +
    "Delphi-open installer gates."
)
