[CmdletBinding()]
param(
    [ValidateSet("startup", "release", "targeted", "regression")]
    [string]$Profile = "startup",

    [string[]]$TargetId = @(),

    [string[]]$ScenarioId = @(),

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

function Get-RadIAEvidenceValue {
    param(
        [Parameter(Mandatory = $true)]$Evidence,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $value = $Evidence
    foreach ($segment in $Path.Split('.')) {
        $property = $value.PSObject.Properties[$segment]
        if (-not $property) {
            return $null
        }
        $value = $property.Value
    }
    return $value
}

function Stop-RadIAUsageAuxiliaryProcesses {
    $runningIDEs = @(
        Get-Process bds -ErrorAction SilentlyContinue |
            Where-Object { -not $_.HasExited }
    )
    if ($runningIDEs.Count -gt 0) {
        return
    }
    $processes = @(
        Get-Process `
            -Name "RadIA.Semantic.Engine", "RadIA.MCP.Bridge" `
            -ErrorAction SilentlyContinue
    )
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        if (-not $process.HasExited -and -not $process.WaitForExit(10000)) {
            throw "RadIA auxiliary process did not stop between journeys."
        }
    }
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
if ($Profile -eq "regression") {
    $registeredScenarioIds = @($manifest.scenarios.id | Sort-Object -Unique)
    $releaseScenarioEntries = @($profileDefinition[0].scenarioIds)
    $releaseScenarioIds = @(
        $releaseScenarioEntries | Sort-Object -Unique
    )
    $missingReleaseScenarios = @(
        $registeredScenarioIds |
            Where-Object { $_ -notin $releaseScenarioIds }
    )
    $unknownReleaseScenarios = @(
        $releaseScenarioIds |
            Where-Object { $_ -notin $registeredScenarioIds }
    )
    $duplicateReleaseScenarios = @(
        $releaseScenarioEntries |
            Group-Object |
            Where-Object { $_.Count -gt 1 } |
            ForEach-Object { $_.Name }
    )
    if (
        $missingReleaseScenarios.Count -gt 0 -or
        $unknownReleaseScenarios.Count -gt 0 -or
        $duplicateReleaseScenarios.Count -gt 0
    ) {
        throw (
            "The regression profile must contain every registered usage " +
            "scenario exactly once. Missing: " +
            "$($missingReleaseScenarios -join ', '). Unknown: " +
            "$($unknownReleaseScenarios -join ', '). Duplicated: " +
            "$($duplicateReleaseScenarios -join ', ')."
        )
    }
}
if ($Profile -eq "targeted" -and $ScenarioId.Count -eq 0) {
    throw "The targeted profile requires at least one -ScenarioId."
}
$unknownScenarios = @(
    $ScenarioId | Where-Object { $_ -notin @($manifest.scenarios.id) }
)
if ($unknownScenarios.Count -gt 0) {
    throw "Unknown usage scenario(s): $($unknownScenarios -join ', ')"
}
$selectedTargets = @($manifest.targets)
if ($TargetId.Count -eq 0 -and $profileDefinition[0].targetIds) {
    $selectedTargets = @(
        $manifest.targets |
            Where-Object { $_.id -in @($profileDefinition[0].targetIds) }
    )
}
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
$selectedScenarioIds = @($profileDefinition[0].scenarioIds)
if ($ScenarioId.Count -gt 0) {
    $selectedScenarioIds = @($ScenarioId)
}
$selectedScenarios = @(
    $manifest.scenarios |
        Where-Object { $_.id -in $selectedScenarioIds }
)
if ($selectedTargets.Count -eq 0 -or $selectedScenarios.Count -eq 0) {
    throw "Usage matrix selection is empty."
}

$resolvedEvidencePath = Resolve-RadIAUsageEvidencePath -Path $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
$planEntries = @()
foreach ($target in $selectedTargets) {
    foreach ($scenario in @($selectedScenarios | Where-Object {
        $_.scope -ne "host" -and
        (-not $_.targetIds -or $target.id -in @($_.targetIds))
    })) {
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
            scope = $scenario.scope
            testPath = $scenario.testPath
            runnerArguments = @($scenario.runnerArguments)
        }
    }
}
foreach ($scenario in @($selectedScenarios | Where-Object {
    $_.scope -eq "host"
})) {
    $targetEvidence = Join-Path `
        $evidenceDirectory `
        "$($scenario.id)-host-neutral.json"
    $planEntries += [PSCustomObject]@{
        targetId = "host-neutral"
        delphiVersion = ""
        ideArchitecture = "Win32"
        scenarioId = $scenario.id
        runner = $scenario.runner
        cycles = $scenario.cycles
        startupTimeoutSeconds = $scenario.startupTimeoutSeconds
        requiredEvidence = @($scenario.requiredEvidence)
        evidencePath = $targetEvidence
        scope = $scenario.scope
        testPath = $scenario.testPath
        runnerArguments = @($scenario.runnerArguments)
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
$installedTargetId = ""
foreach ($run in $planEntries) {
    Stop-RadIAUsageAuxiliaryProcesses
    if ($Profile -in @("startup", "release", "regression") -and
        $run.scope -ne "host" -and
        $installedTargetId -ne $run.targetId) {
        $installArguments = @{
            DelphiVersion = $run.delphiVersion
            Install = $true
            Package = $true
            Release = $true
        }
        if ($run.ideArchitecture -eq "Win64") {
            $installArguments.IDE64 = $true
        }
        & (Join-Path $repositoryRoot "build.ps1") @installArguments
        if ($LASTEXITCODE -ne 0) {
            throw "Could not install the current package for $($run.targetId)."
        }
        $installedTargetId = $run.targetId
    }
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    if ($run.scope -eq "host") {
        $testFile = Join-Path $repositoryRoot $run.testPath
        $output = & node --test --test-isolation=none $testFile 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        } elseif ($run.scope -in @("ide-journey", "user-journey")) {
        $journeyPath = Join-Path $PSScriptRoot $run.runner
        $arguments = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $journeyPath,
            "-DelphiVersion",
            $run.delphiVersion,
            "-EvidencePath",
            $run.evidencePath
        )
        if ($run.ideArchitecture -eq "Win64") {
            $arguments += "-IDE64"
        }
        $arguments += @(
            $run.runnerArguments |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $output = & powershell.exe @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            if (-not (Test-Path -LiteralPath $run.evidencePath -PathType Leaf)) {
                $output += "`r`nUser-journey evidence was not created."
                $exitCode = 1
            } else {
                $journeyEvidence = Get-Content `
                    -LiteralPath $run.evidencePath `
                    -Raw |
                    ConvertFrom-Json
                foreach ($requiredPath in $run.requiredEvidence) {
                    if ((Get-RadIAEvidenceValue `
                        -Evidence $journeyEvidence `
                        -Path $requiredPath) -ne $true) {
                        $output += (
                            "`r`nRequired observable evidence was not true: " +
                            $requiredPath
                        )
                        $exitCode = 1
                        break
                    }
                }
            }
        }
    } else {
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
        $output = & powershell.exe @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
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
        evidencePath = if (
            $run.scope -eq "user-journey" -or
            ($RequirePackageProvenance -and $run.scope -eq "ide")
        ) {
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
