param(
    [Parameter(Mandatory = $true)]
    [string]$BaselinePath,
    [Parameter(Mandatory = $true)]
    [string]$CurrentPath,
    [string]$OutputPath = "",
    [ValidateRange(1, 10000)]
    [int]$MinimumRuns = 20,
    [ValidateRange(0, 1000)]
    [double]$MaximumDurationRegressionPercent = 20,
    [ValidateRange(0, 1000)]
    [double]$MaximumDecisionRegressionPercent = 10,
    [ValidateRange(0, 1000)]
    [double]$MaximumToolCallRegressionPercent = 10,
    [ValidateRange(0, 1000)]
    [double]$MaximumTokenRegressionPercent = 10,
    [ValidateRange(0, 1000)]
    [double]$MaximumResponsivenessRegressionPercent = 20
)

$ErrorActionPreference = "Stop"

function Read-RadIAEvidence {
    param([string]$FileName)

    if (-not (Test-Path -LiteralPath $FileName -PathType Leaf)) {
        throw "Agent efficiency evidence was not found: $FileName"
    }
    return Get-Content -LiteralPath $FileName -Raw | ConvertFrom-Json
}

function Get-RadIADeltaPercent {
    param(
        [double]$Current,
        [double]$Baseline
    )

    if ($Baseline -eq 0) {
        if ($Current -eq 0) {
            return 0
        }
        return [double]::PositiveInfinity
    }
    return [Math]::Round((($Current - $Baseline) * 100) / $Baseline, 2)
}

function New-RadIAComparison {
    param(
        [string]$Name,
        [double]$Baseline,
        [double]$Current,
        [double]$MaximumRegressionPercent
    )

    $delta = Get-RadIADeltaPercent $Current $Baseline
    return [ordered]@{
        name = $Name
        baseline = $Baseline
        current = $Current
        deltaPercent = $delta
        maximumRegressionPercent = $MaximumRegressionPercent
        passed = $delta -le $MaximumRegressionPercent
    }
}

function Assert-RadIAComparableEvidence {
    param(
        [object]$Baseline,
        [object]$Current
    )

    if (($Baseline.schemaVersion -lt 2) -or ($Current.schemaVersion -lt 2)) {
        throw "Paired efficiency gates require schemaVersion 2 evidence."
    }
    if ([string]::IsNullOrWhiteSpace([string]$Baseline.sample.pairingKeyHash) -or
        ($Baseline.sample.pairingKeyHash -ne $Current.sample.pairingKeyHash)) {
        throw "Baseline and current evidence must use the same non-empty pairing key."
    }
    if (($Baseline.sample.analyzedRuns -lt $MinimumRuns) -or
        ($Current.sample.analyzedRuns -lt $MinimumRuns)) {
        throw "Both samples must contain at least $MinimumRuns runs."
    }
    if ($Baseline.sample.analyzedRuns -ne $Current.sample.analyzedRuns) {
        throw "Paired efficiency samples must contain the same number of runs."
    }
    if (($Baseline.sample.responsivenessMeasuredRunCount -ne $Baseline.sample.analyzedRuns) -or
        ($Current.sample.responsivenessMeasuredRunCount -ne $Current.sample.analyzedRuns)) {
        throw "Responsiveness must be measured for every run in both samples."
    }
    if (($Baseline.sample.tokenUsageMeasuredRunCount -eq 0) -or
        ($Baseline.sample.tokenUsageMeasuredRunCount -ne $Current.sample.tokenUsageMeasuredRunCount)) {
        throw "Token usage must be reported for the same non-zero run count in both samples."
    }
}

$baseline = Read-RadIAEvidence $BaselinePath
$current = Read-RadIAEvidence $CurrentPath
Assert-RadIAComparableEvidence $baseline $current

$comparisons = @(
    New-RadIAComparison `
        "duration" `
        $baseline.metrics.averageDurationMilliseconds `
        $current.metrics.averageDurationMilliseconds `
        $MaximumDurationRegressionPercent
    New-RadIAComparison `
        "decisions" `
        $baseline.metrics.averageDecisionCount `
        $current.metrics.averageDecisionCount `
        $MaximumDecisionRegressionPercent
    New-RadIAComparison `
        "toolCalls" `
        $baseline.metrics.averageToolCallCount `
        $current.metrics.averageToolCallCount `
        $MaximumToolCallRegressionPercent
    New-RadIAComparison `
        "tokens" `
        $baseline.metrics.averageTotalTokens `
        $current.metrics.averageTotalTokens `
        $MaximumTokenRegressionPercent
    New-RadIAComparison `
        "responsiveness" `
        $baseline.metrics.averageFirstDecisionDurationMilliseconds `
        $current.metrics.averageFirstDecisionDurationMilliseconds `
        $MaximumResponsivenessRegressionPercent
)

$failed = @($comparisons | Where-Object { -not $_.passed })
$result = [ordered]@{
    schemaVersion = 1
    passed = $failed.Count -eq 0
    pairingKeyHash = $baseline.sample.pairingKeyHash
    runCount = $baseline.sample.analyzedRuns
    tokenUsageMeasuredRunCount = $baseline.sample.tokenUsageMeasuredRunCount
    comparisons = $comparisons
}
$json = $result | ConvertTo-Json -Depth 8

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($resolvedOutputPath, $json, $utf8WithoutBom)
}

$json
if ($failed.Count -gt 0) {
    $failedNames = ($failed | ForEach-Object { $_.name }) -join ", "
    throw "Agent efficiency gate rejected regressions in: $failedNames."
}
