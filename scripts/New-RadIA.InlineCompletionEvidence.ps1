param(
    [string]$ValidationPath = ".\Output\Validation\InlineCompletion",
    [string]$OutputPath = (
        ".\Output\Evidence\inline_completion_smoke_evidence_2.3.1.json"
    ),
    [int]$RequiredToolCount = 199,
    [int]$RequiredLineCount = 2,
    [int]$RequiredAlternativeCount = 2
)

$ErrorActionPreference = "Stop"

$targets = @(
    @{
        evidenceFile = "Delphi12-Win32.json"
        delphiVersion = "23.0"
        platform = "Win32"
    },
    @{
        evidenceFile = "Delphi13-Win32.json"
        delphiVersion = "37.0"
        platform = "Win32"
    },
    @{
        evidenceFile = "Delphi13-Win64.json"
        delphiVersion = "37.0"
        platform = "Win64"
    }
)

function Assert-RadIACondition {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,
        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$resolvedValidationPath = [IO.Path]::GetFullPath($ValidationPath)
$resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
$summaries = @()
$sourceCommit = ""
$productVersion = ""

foreach ($target in $targets) {
    $evidencePath = Join-Path `
        $resolvedValidationPath `
        $target.evidenceFile
    Assert-RadIACondition `
        -Condition (Test-Path -LiteralPath $evidencePath -PathType Leaf) `
        -Message "Inline completion evidence was not found: $evidencePath"
    $evidence = Get-Content `
        -LiteralPath $evidencePath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    Assert-RadIACondition `
        -Condition ($evidence.schemaVersion -eq 1) `
        -Message "$($target.evidenceFile) has an invalid schema."
    Assert-RadIACondition `
        -Condition (
            $evidence.evidenceKind -eq "inlineCompletionVisualSmoke"
        ) `
        -Message "$($target.evidenceFile) has an invalid evidence kind."
    Assert-RadIACondition `
        -Condition ($evidence.sourceDirty -eq $false) `
        -Message "$($target.evidenceFile) was generated from dirty source."
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -match "^[0-9a-f]{40}$") `
        -Message "$($target.evidenceFile) has an invalid source commit."
    Assert-RadIACondition `
        -Condition ($evidence.delphiVersion -eq $target.delphiVersion) `
        -Message "$($target.evidenceFile) has an invalid Delphi version."
    Assert-RadIACondition `
        -Condition ($evidence.platform -eq $target.platform) `
        -Message "$($target.evidenceFile) has an invalid platform."
    Assert-RadIACondition `
        -Condition ($evidence.installedBplSha256 -match "^[A-F0-9]{64}$") `
        -Message "$($target.evidenceFile) has an invalid BPL hash."
    Assert-RadIACondition `
        -Condition ($evidence.toolCount -eq $RequiredToolCount) `
        -Message "$($target.evidenceFile) has an invalid tool count."
    Assert-RadIACondition `
        -Condition (
            $evidence.cyclesRequested -gt 0 -and
            $evidence.cyclesPassed -eq $evidence.cyclesRequested -and
            @($evidence.cycles).Count -eq $evidence.cyclesRequested
        ) `
        -Message "$($target.evidenceFile) has incomplete cycles."

    if (-not $sourceCommit) {
        $sourceCommit = $evidence.sourceCommit
        $productVersion = $evidence.productVersion
    }
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -eq $sourceCommit) `
        -Message "All targets must use the same source commit."
    Assert-RadIACondition `
        -Condition ($evidence.productVersion -eq $productVersion) `
        -Message "All targets must use the same product version."

    foreach ($cycle in @($evidence.cycles)) {
        Assert-RadIACondition `
            -Condition (
                $cycle.InlineCompletionExercised -eq $true -and
                $cycle.InlineCompletionPrepared -eq $true -and
                $cycle.InlineCompletionPainted -eq $true -and
                $cycle.InlineCompletionAlternativesPainted -eq $true -and
                $cycle.InlineCompletionPreviewClean -eq $true -and
                $cycle.InlineCompletionAccepted -eq $true -and
                $cycle.InlineCompletionSingleUndo -eq $true -and
                $cycle.InlineCompletionUndoRestored -eq $true -and
                $cycle.InlineCompletionRejectedClean -eq $true
            ) `
            -Message (
                "$($target.evidenceFile) contains an incomplete " +
                "inline completion cycle."
            )
        Assert-RadIACondition `
            -Condition (
                $cycle.InlineCompletionLineCount -eq $RequiredLineCount
            ) `
            -Message "$($target.evidenceFile) has an invalid line count."
        Assert-RadIACondition `
            -Condition (
                $cycle.InlineCompletionAlternativeCount -eq
                    $RequiredAlternativeCount
            ) `
            -Message "$($target.evidenceFile) has an invalid alternative count."
    }

    $seconds = @($evidence.cycles | ForEach-Object { $_.Seconds })
    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        installedBplSha256 = $evidence.installedBplSha256
        toolCount = $evidence.toolCount
        cyclesPassed = $evidence.cyclesPassed
        minimumSeconds = ($seconds | Measure-Object -Minimum).Minimum
        maximumSeconds = ($seconds | Measure-Object -Maximum).Maximum
        prepared = $true
        painted = $true
        alternativesPainted = $true
        alternativeCount = $RequiredAlternativeCount
        previewClean = $true
        accepted = $true
        singleUndo = $true
        undoRestored = $true
        rejectedClean = $true
        lineCount = $RequiredLineCount
        generatedAtUtc = $evidence.generatedAtUtc
    }
}

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force |
        Out-Null
}
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "inlineCompletionVisualMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    requiredToolCount = $RequiredToolCount
    requiredLineCount = $RequiredLineCount
    requiredAlternativeCount = $RequiredAlternativeCount
    targetCount = $summaries.Count
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Inline completion matrix evidence created: $resolvedOutputPath"
