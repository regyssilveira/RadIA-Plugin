[CmdletBinding()]
param(
    [string]$EvidenceRoot = ".\Output\Validation\ReleaseUsage",
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedEvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$outputRoot = [IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "Output")
)
if (-not $resolvedEvidenceRoot.StartsWith(
    $outputRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Release usage evidence must remain inside Output."
}
if ($PlanOnly) {
    $matrixRunner = Join-Path $PSScriptRoot "Test-RadIA.UsageMatrix.ps1"
    $startupPlan = & $matrixRunner -Profile "startup" -PlanOnly |
        ConvertFrom-Json
    $releasePlan = & $matrixRunner -Profile "release" -PlanOnly |
        ConvertFrom-Json
    [PSCustomObject]@{
        schemaVersion = 1
        profile = "release-gate"
        unitTestTargetCount = 2
        generatedProjectTargetCount = 2
        startupRunCount = $startupPlan.runCount
        criticalRunCount = $releasePlan.runCount
        totalIdeRunCount = $startupPlan.runCount + $releasePlan.runCount
        startupPlan = $startupPlan
        criticalPlan = $releasePlan
    } | ConvertTo-Json -Depth 8
    exit 0
}
$runningIDEs = @(
    Get-Process bds -ErrorAction SilentlyContinue |
        Where-Object { -not $_.HasExited }
)
if ($runningIDEs.Count -gt 0) {
    throw "Close all Delphi IDE instances before the release usage gate."
}

function Stop-RadIAReleaseAuxiliaryProcesses {
    $names = @("RadIA.Semantic.Engine", "RadIA.MCP.Bridge")
    $processes = @(Get-Process -Name $names -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force
        if (-not $process.WaitForExit(10000)) {
            throw (
                "RadIA auxiliary process did not stop: " +
                "$($process.ProcessName):$($process.Id)."
            )
        }
    }
}

Stop-RadIAReleaseAuxiliaryProcesses
New-Item `
    -ItemType Directory `
    -Path $resolvedEvidenceRoot `
    -Force |
    Out-Null

& (Join-Path $PSScriptRoot "Test-RadIA.ReleasePromises.ps1") `
    -Enforce `
    -EvidencePath (
        Join-Path $resolvedEvidenceRoot "release-promise-coverage.json"
    )

$unitTestTargets = @(
    [PSCustomObject]@{ Id = "delphi12-win32"; Version = "23.0" },
    [PSCustomObject]@{ Id = "delphi13-win32"; Version = "37.0" }
)
foreach ($target in $unitTestTargets) {
    Write-Host "Running the complete DUnitX suite for $($target.Id)."
    & (Join-Path $repositoryRoot "build.ps1") `
        -DelphiVersion $target.Version `
        -Test
    if ($LASTEXITCODE -ne 0) {
        throw "The complete DUnitX suite failed for $($target.Id)."
    }
}

$generatedProjectTargets = @(
    [PSCustomObject]@{
        Id = "delphi12-win32"
        Version = "23.0"
        EvidenceFile = "Delphi12-Win32.json"
    },
    [PSCustomObject]@{
        Id = "delphi13-win32"
        Version = "37.0"
        EvidenceFile = "Delphi13-Win32.json"
    }
)
foreach ($target in $generatedProjectTargets) {
    $generatedArguments = @{
        DelphiVersion = $target.Version
        EvidencePath = Join-Path `
            $resolvedEvidenceRoot `
            $target.EvidenceFile
    }
    if (-not $env:DEXT_ROOT) {
        $generatedArguments.SkipDext = $true
    }
    & (Join-Path $PSScriptRoot "Test-RadIA.GeneratedProjects.ps1") `
        @generatedArguments
}

& (Join-Path $PSScriptRoot "New-RadIA.GeneratedProjectsEvidence.ps1") `
    -ValidationPath $resolvedEvidenceRoot `
    -OutputPath (
        Join-Path $resolvedEvidenceRoot "generated-projects-matrix.json"
    )

& (Join-Path $PSScriptRoot "Test-RadIA.UsageMatrix.ps1") `
    -Profile "startup" `
    -EvidencePath (
        Join-Path $resolvedEvidenceRoot "startup-matrix.json"
    )

& (Join-Path $PSScriptRoot "Test-RadIA.UsageMatrix.ps1") `
    -Profile "release" `
    -EvidencePath (
        Join-Path $resolvedEvidenceRoot "release-critical-matrix.json"
    )

Write-Host (
    "Release usage gate passed: public promises, complete DUnitX, " +
    "generated projects, startup smoke on every supported target, and " +
    "bounded release-critical journeys on the representative target."
)
