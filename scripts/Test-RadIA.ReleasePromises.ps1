[CmdletBinding()]
param(
    [switch]$Enforce,
    [string]$EvidencePath = (
        ".\Output\Validation\ReleasePromises\promise-coverage.json"
    )
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$promisePath = Join-Path $repositoryRoot "Tests\Usage\release-promises.json"
$usagePath = Join-Path $repositoryRoot "Tests\Usage\usage-matrix.json"
$promises = Get-Content -LiteralPath $promisePath -Raw | ConvertFrom-Json
$usage = Get-Content -LiteralPath $usagePath -Raw | ConvertFrom-Json

if ($promises.schemaVersion -ne 1 -or $usage.schemaVersion -ne 1) {
    throw "Unsupported promise or usage matrix schema."
}

$regressionProfile = @(
    $usage.profiles | Where-Object { $_.id -eq "regression" }
)
if ($regressionProfile.Count -ne 1) {
    throw "The regression usage profile is missing or duplicated."
}

$results = @()
foreach ($promise in $promises.promises) {
    $scenario = @(
        $usage.scenarios | Where-Object { $_.id -eq $promise.scenarioId }
    )
    $reasons = @()
    if ($promise.maximumDurationSeconds -le 0) {
        $reasons += "maximum-duration-missing"
    }
    if (@($promise.expectedOutcomes).Count -lt 1) {
        $reasons += "expected-outcomes-missing"
    }
    if (@($promise.forbiddenOutcomes).Count -lt 1) {
        $reasons += "forbidden-outcomes-missing"
    }
    if ($scenario.Count -ne 1) {
        $reasons += "scenario-not-registered"
    } else {
        if ($scenario[0].scope -ne "user-journey") {
            $reasons += "scenario-is-not-a-user-journey"
        }
        if ($promise.scenarioId -notin $regressionProfile[0].scenarioIds) {
            $reasons += "scenario-not-required-by-regression"
        }
        $missingTargets = @(
            $promise.requiredTargets |
                Where-Object { $_ -notin @($scenario[0].targetIds) }
        )
        if ($missingTargets.Count -gt 0) {
            $reasons += "missing-targets:$($missingTargets -join ',')"
        }
        if (@($scenario[0].observableOutcomes).Count -lt 1) {
            $reasons += "observable-outcomes-missing"
        }
        if (@($scenario[0].requiredEvidence).Count -lt 1) {
            $reasons += "required-evidence-missing"
        }
    }
    $results += [PSCustomObject]@{
        promiseId = $promise.id
        priority = $promise.priority
        scenarioId = $promise.scenarioId
        covered = $reasons.Count -eq 0
        reasons = $reasons
    }
}

$uncovered = @($results | Where-Object { -not $_.covered })
$resolvedEvidence = [IO.Path]::GetFullPath($EvidencePath)
$outputRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "Output"))
if (-not $resolvedEvidence.StartsWith(
    $outputRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Promise coverage evidence must remain inside Output."
}
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedEvidence) -Force |
    Out-Null

[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "releasePromiseCoverage"
    product = "RadIA"
    status = if ($uncovered.Count -eq 0) { "passed" } else { "gaps-found" }
    promiseCount = $results.Count
    coveredCount = $results.Count - $uncovered.Count
    uncoveredCount = $uncovered.Count
    promises = $results
} | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8

if ($Enforce -and $uncovered.Count -gt 0) {
    throw (
        "Release promises without mandatory user-journey E2E coverage: " +
        (($uncovered | ForEach-Object { $_.promiseId }) -join ", ")
    )
}

Write-Host (
    "Promise coverage audit completed: " +
    "$($results.Count - $uncovered.Count)/$($results.Count) covered."
)
