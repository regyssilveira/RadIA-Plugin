[CmdletBinding()]
param(
    [string]$EvidencePath = (
        ".\Output\Validation\FireDACAdvisor\firedac-advisor-plan.json"
    ),
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path `
    $repositoryRoot `
    "Tests\Usage\firedac-advisor-matrix.json"

function Resolve-RadIAFireDACEvidencePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = [IO.Path]::GetFullPath($Path)
    $outputRoot = [IO.Path]::GetFullPath(
        (Join-Path $repositoryRoot "Output")
    )
    if (-not $resolved.StartsWith(
        $outputRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "FireDAC Advisor evidence must remain inside Output."
    }
    return $resolved
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "FireDAC Advisor matrix was not found: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported FireDAC Advisor matrix schema."
}
$targets = @($manifest.targets)
$scenarios = @($manifest.scenarios)
if ($targets.Count -ne 3) {
    throw "FireDAC Advisor matrix must contain exactly three IDE targets."
}
if ($scenarios.Count -ne 16) {
    throw "FireDAC Advisor matrix must contain exactly 16 scenarios."
}
$expectedTargets = @(
    "delphi12-win32",
    "delphi13-win32",
    "delphi13-ide64"
)
if ((@($targets.id) -join ",") -ne ($expectedTargets -join ",")) {
    throw "FireDAC Advisor matrix targets are incomplete or out of order."
}
$duplicateIds = @(
    $scenarios.id |
        Group-Object |
        Where-Object { $_.Count -gt 1 }
)
if ($duplicateIds.Count -gt 0) {
    throw "FireDAC Advisor matrix contains duplicate scenario identifiers."
}
$runs = @()
foreach ($scenario in $scenarios) {
    if ($scenario.id -notmatch '^firedac-[a-z0-9-]+$') {
        throw "Invalid FireDAC Advisor scenario identifier: $($scenario.id)"
    }
    if (@($scenario.tools).Count -eq 0) {
        throw "Scenario $($scenario.id) does not declare tools."
    }
    if (@($scenario.requiredEvidence).Count -eq 0) {
        throw "Scenario $($scenario.id) does not declare evidence."
    }
    if ($scenario.rollbackExpected -and -not $scenario.mutationExpected) {
        throw "Scenario $($scenario.id) expects rollback without mutation."
    }
    foreach ($target in $targets) {
        $runs += [PSCustomObject]@{
            scenarioId = $scenario.id
            targetId = $target.id
            delphiVersion = $target.delphiVersion
            ideArchitecture = if ($target.ide64) { "Win64" } else { "Win32" }
            tools = @($scenario.tools)
            mutationExpected = [bool]$scenario.mutationExpected
            rollbackExpected = [bool]$scenario.rollbackExpected
            requiredEvidence = @($scenario.requiredEvidence)
        }
    }
}

$plan = [PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "fireDACAdvisorIDEPlan"
    targetCount = $targets.Count
    scenarioCount = $scenarios.Count
    runCount = $runs.Count
    runs = $runs
}
if ($PlanOnly) {
    $plan | ConvertTo-Json -Depth 7
    exit 0
}

$resolvedEvidence = Resolve-RadIAFireDACEvidencePath -Path $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidence
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$plan | ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8
throw (
    "FireDAC Advisor IDE execution is not connected yet. " +
    "The deterministic 48-run plan was written to $resolvedEvidence."
)
