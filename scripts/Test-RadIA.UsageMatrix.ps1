[CmdletBinding()]
param(
    [ValidateSet("startup")]
    [string]$Profile = "startup",

    [string[]]$TargetId = @(),

    [string]$EvidencePath = (
        ".\Output\Validation\UsageMatrix\usage-matrix.json"
    ),

    [switch]$RequirePackageProvenance,

    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path `
    $repositoryRoot `
    "Tests\Usage\usage-matrix.json"
$smokePath = Join-Path $PSScriptRoot "Test-RadIA.IDESmoke.ps1"

function Resolve-RadIAUsageEvidencePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = [IO.Path]::GetFullPath($Path)
    $outputRoot = [IO.Path]::GetFullPath(
        (Join-Path $repositoryRoot "Output")
    )
    if (-not $resolved.StartsWith(
        $outputRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Usage evidence path must remain inside Output."
    }
    return $resolved
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Usage matrix manifest was not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $smokePath -PathType Leaf)) {
    throw "IDE smoke runner was not found: $smokePath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported usage matrix schema."
}
$profileDefinition = @(
    $manifest.profiles | Where-Object { $_.id -eq $Profile }
)
if ($profileDefinition.Count -ne 1) {
    throw "Usage profile was not found: $Profile"
}
$selectedTargets = @($manifest.targets)
if ($TargetId.Count -gt 0) {
    $unknownTargets = @(
        $TargetId | Where-Object { $_ -notin @($manifest.targets.id) }
    )
    if ($unknownTargets.Count -gt 0) {
        throw "Unknown usage target(s): $($unknownTargets -join ', ')"
    }
    $selectedTargets = @(
        $manifest.targets | Where-Object { $_.id -in $TargetId }
    )
}
$selectedScenarios = @(
    $manifest.scenarios |
        Where-Object { $_.id -in $profileDefinition[0].scenarioIds }
)
if ($selectedTargets.Count -eq 0 -or $selectedScenarios.Count -eq 0) {
    throw "Usage matrix selection is empty."
}

$resolvedEvidencePath = Resolve-RadIAUsageEvidencePath -Path $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
$planEntries = @()
foreach ($target in $selectedTargets) {
    foreach ($scenario in $selectedScenarios) {
        $targetEvidence = Join-Path `
            $evidenceDirectory `
            "$($scenario.id)-$($target.id).json"
        $planEntries += [PSCustomObject]@{
            targetId = $target.id
            delphiVersion = $target.delphiVersion
            ideArchitecture = if ($target.ide64) { "Win64" } else { "Win32" }
            scenarioId = $scenario.id
            runner = $scenario.runner
            cycles = $scenario.cycles
            startupTimeoutSeconds = $scenario.startupTimeoutSeconds
            requiredEvidence = @($scenario.requiredEvidence)
            evidencePath = $targetEvidence
        }
    }
}

if ($PlanOnly) {
    [PSCustomObject]@{
        schemaVersion = 1
        profile = $Profile
        packageProvenanceRequired = [bool]$RequirePackageProvenance
        targetCount = $selectedTargets.Count
        scenarioCount = $selectedScenarios.Count
        runCount = $planEntries.Count
        runs = $planEntries
    } | ConvertTo-Json -Depth 6
    exit 0
}

New-Item `
    -ItemType Directory `
    -Path $evidenceDirectory `
    -Force |
    Out-Null
$results = @()
$matrixStopwatch = [Diagnostics.Stopwatch]::StartNew()
foreach ($run in $planEntries) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $smokePath,
        "-DelphiVersion",
        $run.delphiVersion,
        "-Cycles",
        [string]$run.cycles,
        "-StartupTimeoutSeconds",
        [string]$run.startupTimeoutSeconds
    )
    if ($run.ideArchitecture -eq "Win64") {
        $arguments += "-IDE64"
    }
    if ($RequirePackageProvenance) {
        $arguments += @("-EvidencePath", $run.evidencePath)
    } else {
        $arguments += "-SkipPackageHashCheck"
    }

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $output = & powershell.exe @arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $stopwatch.Stop()
    $status = if ($exitCode -eq 0) { "passed" } else { "failed" }
    $results += [PSCustomObject]@{
        targetId = $run.targetId
        delphiVersion = $run.delphiVersion
        ideArchitecture = $run.ideArchitecture
        scenarioId = $run.scenarioId
        status = $status
        exitCode = $exitCode
        durationMs = $stopwatch.ElapsedMilliseconds
        evidencePath = if ($RequirePackageProvenance) {
            $run.evidencePath
        } else {
            ""
        }
        outputTail = if ($output.Length -gt 8192) {
            $output.Substring($output.Length - 8192)
        } else {
            $output
        }
    }
    if ($exitCode -ne 0) {
        break
    }
}
$matrixStopwatch.Stop()

$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
& git -C $repositoryRoot diff --quiet --exit-code
$sourceDirty = $LASTEXITCODE -ne 0
& git -C $repositoryRoot diff --cached --quiet --exit-code
$sourceDirty = $sourceDirty -or ($LASTEXITCODE -ne 0)
$failedResults = @($results | Where-Object { $_.status -ne "passed" })
$matrixStatus = if (
    $failedResults.Count -eq 0 -and
    $results.Count -eq $planEntries.Count
) {
    "passed"
} else {
    "failed"
}

[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "automatedUsageMatrix"
    product = "RadIA"
    productVersion = (
        Get-Content `
            -LiteralPath (Join-Path $repositoryRoot "package.json") `
            -Raw |
            ConvertFrom-Json
    ).version
    sourceCommit = $sourceCommit
    sourceDirty = $sourceDirty
    profile = $Profile
    packageProvenanceRequired = [bool]$RequirePackageProvenance
    status = $matrixStatus
    durationMs = $matrixStopwatch.ElapsedMilliseconds
    runCount = $results.Count
    expectedRunCount = $planEntries.Count
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    runs = $results
} |
    ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

if ($matrixStatus -ne "passed") {
    throw "Automated usage matrix failed. Evidence: $resolvedEvidencePath"
}
Write-Host "Automated usage matrix passed: $resolvedEvidencePath"
