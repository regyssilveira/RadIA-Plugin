param(
    [string]$LogPath = "",
    [string]$OutputPath = "",
    [ValidateRange(1, 10000)]
    [int]$LastRuns = 100,
    [string]$BaselinePath = "",
    [string]$PairingKey = ""
)

$ErrorActionPreference = "Stop"

function Get-RadIAPercent {
    param(
        [double]$Numerator,
        [double]$Denominator
    )

    if ($Denominator -le 0) {
        return 0
    }
    return [Math]::Round(($Numerator * 100) / $Denominator, 2)
}

function Get-RadIAAverage {
    param(
        [object[]]$Items,
        [string]$PropertyName
    )

    if ($Items.Count -eq 0) {
        return 0
    }
    $measure = $Items | Measure-Object -Property $PropertyName -Average
    return [Math]::Round([double]$measure.Average, 2)
}

function Get-RadIAOptionalAverage {
    param(
        [object[]]$Items,
        [string]$PropertyName
    )

    if ($Items.Count -eq 0) {
        return $null
    }
    return Get-RadIAAverage $Items $PropertyName
}

function Get-RadIAHash {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value.Trim())
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $algorithm.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant().Substring(0, 16)
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-RadIADeltaPercent {
    param(
        [double]$Current,
        [double]$Baseline
    )

    if ($Baseline -le 0) {
        return $null
    }
    return [Math]::Round((($Current - $Baseline) * 100) / $Baseline, 2)
}

function Get-RadIALogFiles {
    param([string]$ResolvedLogPath)

    if (Test-Path -LiteralPath $ResolvedLogPath -PathType Leaf) {
        return @(Get-Item -LiteralPath $ResolvedLogPath)
    }
    if (Test-Path -LiteralPath $ResolvedLogPath -PathType Container) {
        return @(
            Get-ChildItem -LiteralPath $ResolvedLogPath -Filter "radia*.log" -File |
                Sort-Object LastWriteTime, Name -Descending
        )
    }
    throw "RadIA log path was not found: $ResolvedLogPath"
}

function Get-RadIALatestRunSummaries {
    param(
        [System.IO.FileInfo[]]$LogFiles,
        [int]$Limit
    )

    $latestByRun = [ordered]@{}
    $sequence = 0
    $scannedFileCount = 0
    foreach ($file in $LogFiles) {
        $latestInFile = [ordered]@{}
        $scannedFileCount++
        $reader = [System.IO.StreamReader]::new($file.FullName, $true)
        try {
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ($line -notmatch '\[AgentMetrics\]\s+(\{.*\})\s*$') {
                    continue
                }
                try {
                    $event = $Matches[1] | ConvertFrom-Json
                }
                catch {
                    continue
                }
                if ($event.event -ne "agentRunSummary") {
                    continue
                }
                $sequence++
                $runKey = [string]$event.runId
                if ([string]::IsNullOrWhiteSpace($runKey)) {
                    $runKey = "missing-$sequence"
                }
                $event | Add-Member -NotePropertyName "_sequence" -NotePropertyValue $sequence -Force
                $latestInFile[$runKey] = $event
            }
        }
        finally {
            $reader.Dispose()
        }
        foreach ($event in @($latestInFile.Values | Sort-Object _sequence -Descending)) {
            $runKey = [string]$event.runId
            if ([string]::IsNullOrWhiteSpace($runKey)) {
                $runKey = "missing-$($event._sequence)"
            }
            if (-not $latestByRun.Contains($runKey)) {
                $latestByRun[$runKey] = $event
            }
            if ($latestByRun.Count -ge $Limit) {
                break
            }
        }
        if ($latestByRun.Count -ge $Limit) {
            break
        }
    }
    return [pscustomobject]@{
        Summaries = @($latestByRun.Values | Select-Object -First $Limit)
        ScannedFileCount = $scannedFileCount
    }
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $env:APPDATA "RadIA\Logs"
}

$files = Get-RadIALogFiles -ResolvedLogPath $LogPath
$selection = Get-RadIALatestRunSummaries -LogFiles $files -Limit $LastRuns
$summaries = @($selection.Summaries)
if ($summaries.Count -eq 0) {
    throw "No agentRunSummary events were found in the selected RadIA logs."
}

$reportedUsage = @($summaries | Where-Object { $_.usageStatus -eq "reported" })
$responsiveRuns = @(
    $summaries | Where-Object {
        $_.PSObject.Properties.Name -contains "firstDecisionDurationMilliseconds"
    }
)
$reportedTokenTotals = @(
    $reportedUsage | ForEach-Object {
        [pscustomobject]@{
            totalTokens = [double]$_.promptTokens + [double]$_.completionTokens
        }
    }
)
$executedToolCalls = [double](($summaries | Measure-Object -Property toolCallCount -Sum).Sum)
$suppressedToolCalls = [double](($summaries | Measure-Object -Property suppressedToolCallCount -Sum).Sum)
$repeatedDecisions = [double](($summaries | Measure-Object -Property repeatedDecisionCount -Sum).Sum)
$recoveredRepeats = [double](($summaries | Measure-Object -Property recoveredRepeatCount -Sum).Sum)

$statusCounts = [ordered]@{}
$stopReasonCounts = [ordered]@{}
foreach ($summary in $summaries) {
    $status = [string]$summary.status
    $stopReason = [string]$summary.stopReason
    if (-not $statusCounts.Contains($status)) {
        $statusCounts[$status] = 0
    }
    if (-not $stopReasonCounts.Contains($stopReason)) {
        $stopReasonCounts[$stopReason] = 0
    }
    $statusCounts[$status]++
    $stopReasonCounts[$stopReason]++
}

$metrics = [ordered]@{
    runCount = $summaries.Count
    usageReportedRunCount = $reportedUsage.Count
    averageDecisionCount = Get-RadIAAverage $summaries "decisionCount"
    averageToolCallCount = Get-RadIAAverage $summaries "toolCallCount"
    averageSuppressedToolCallCount = Get-RadIAAverage $summaries "suppressedToolCallCount"
    averageDurationMilliseconds = Get-RadIAAverage $summaries "durationMilliseconds"
    averageFirstDecisionDurationMilliseconds = Get-RadIAOptionalAverage `
        $responsiveRuns `
        "firstDecisionDurationMilliseconds"
    totalToolCallCount = [int]$executedToolCalls
    totalSuppressedToolCallCount = [int]$suppressedToolCalls
    toolCallSuppressionPercent = Get-RadIAPercent `
        $suppressedToolCalls `
        ($executedToolCalls + $suppressedToolCalls)
    totalRepeatedDecisionCount = [int]$repeatedDecisions
    totalRecoveredRepeatCount = [int]$recoveredRepeats
    repeatRecoveryPercent = Get-RadIAPercent $recoveredRepeats $repeatedDecisions
    averagePromptTokens = Get-RadIAOptionalAverage $reportedUsage "promptTokens"
    averageCompletionTokens = Get-RadIAOptionalAverage $reportedUsage "completionTokens"
    averageTotalTokens = Get-RadIAOptionalAverage $reportedTokenTotals "totalTokens"
}

$result = [ordered]@{
    schemaVersion = 2
    sample = [ordered]@{
        requestedLastRuns = $LastRuns
        analyzedRuns = $summaries.Count
        pairingKeyHash = Get-RadIAHash $PairingKey
        responsivenessMeasuredRunCount = $responsiveRuns.Count
        tokenUsageMeasuredRunCount = $reportedUsage.Count
        availableSourceFileCount = $files.Count
        scannedSourceFileCount = $selection.ScannedFileCount
    }
    statusCounts = $statusCounts
    stopReasonCounts = $stopReasonCounts
    metrics = $metrics
}

if (-not [string]::IsNullOrWhiteSpace($BaselinePath)) {
    if (-not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
        throw "Agent efficiency baseline was not found: $BaselinePath"
    }
    $baseline = Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json
    $result.comparison = [ordered]@{
        decisionCountDeltaPercent = Get-RadIADeltaPercent `
            $metrics.averageDecisionCount `
            $baseline.metrics.averageDecisionCount
        toolCallCountDeltaPercent = Get-RadIADeltaPercent `
            $metrics.averageToolCallCount `
            $baseline.metrics.averageToolCallCount
        durationDeltaPercent = Get-RadIADeltaPercent `
            $metrics.averageDurationMilliseconds `
            $baseline.metrics.averageDurationMilliseconds
        promptTokensDeltaPercent = Get-RadIADeltaPercent `
            $metrics.averagePromptTokens `
            $baseline.metrics.averagePromptTokens
        totalTokensDeltaPercent = Get-RadIADeltaPercent `
            $metrics.averageTotalTokens `
            $baseline.metrics.averageTotalTokens
        responsivenessDeltaPercent = Get-RadIADeltaPercent `
            $metrics.averageFirstDecisionDurationMilliseconds `
            $baseline.metrics.averageFirstDecisionDurationMilliseconds
    }
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
