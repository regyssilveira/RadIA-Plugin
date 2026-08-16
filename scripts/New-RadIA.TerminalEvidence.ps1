param(
    [string]$ValidationPath = ".\Output\Validation\Terminal",
    [string]$OutputPath = (
        ".\Output\Evidence\terminal_smoke_evidence_2.6.0.json"
    ),
    [int]$RequiredToolCount = 190,
    [int]$MinimumTabStopCount = 13,
    [int]$MinimumPaletteItemCount = 1,
    [int]$MinimumProfileCount = 2
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
        -Message "Terminal evidence was not found: $evidencePath"
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
            $evidence.evidenceKind -eq "interactiveTerminalVisualSmoke"
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
                $cycle.TerminalExercised -eq $true -and
                $cycle.TerminalOpened -eq $true -and
                $cycle.TerminalRequiredControlsVisible -eq $true -and
                $cycle.TerminalCommandInputAvailable -eq $true -and
                $cycle.TerminalOutputAvailable -eq $true -and
                $cycle.TerminalPaletteAvailable -eq $true -and
                $cycle.TerminalAccessibleLabelsAvailable -eq $true
            ) `
            -Message (
                "$($target.evidenceFile) contains an incomplete " +
                "terminal cycle."
            )
        Assert-RadIACondition `
            -Condition (
                $cycle.TerminalWidth -ge 300 -and
                $cycle.TerminalHeight -ge 200
            ) `
            -Message "$($target.evidenceFile) has unusable geometry."
        Assert-RadIACondition `
            -Condition (
                $cycle.TerminalTabStopCount -ge $MinimumTabStopCount
            ) `
            -Message "$($target.evidenceFile) has too few tab stops."
        Assert-RadIACondition `
            -Condition (
                $cycle.TerminalPaletteItemCount -ge $MinimumPaletteItemCount
            ) `
            -Message "$($target.evidenceFile) has an empty command palette."
        Assert-RadIACondition `
            -Condition (
                $cycle.TerminalProfileCount -ge $MinimumProfileCount
            ) `
            -Message "$($target.evidenceFile) has too few terminal profiles."
    }

    $seconds = @($evidence.cycles | ForEach-Object { $_.Seconds })
    $minimumTabStops = (
        @(
            $evidence.cycles |
                ForEach-Object { $_.TerminalTabStopCount }
        ) |
            Measure-Object -Minimum
    ).Minimum
    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        installedBplSha256 = $evidence.installedBplSha256
        toolCount = $evidence.toolCount
        cyclesPassed = $evidence.cyclesPassed
        minimumSeconds = ($seconds | Measure-Object -Minimum).Minimum
        maximumSeconds = ($seconds | Measure-Object -Maximum).Maximum
        opened = $true
        requiredControlsVisible = $true
        commandInputAvailable = $true
        outputAvailable = $true
        paletteAvailable = $true
        minimumPaletteItemCount = (
            @(
                $evidence.cycles |
                    ForEach-Object { $_.TerminalPaletteItemCount }
            ) |
                Measure-Object -Minimum
        ).Minimum
        minimumProfileCount = (
            @(
                $evidence.cycles |
                    ForEach-Object { $_.TerminalProfileCount }
            ) |
                Measure-Object -Minimum
        ).Minimum
        accessibleLabelsAvailable = $true
        minimumTabStopCount = $minimumTabStops
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
    evidenceKind = "interactiveTerminalVisualMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    requiredToolCount = $RequiredToolCount
    minimumTabStopCount = $MinimumTabStopCount
    minimumPaletteItemCount = $MinimumPaletteItemCount
    minimumProfileCount = $MinimumProfileCount
    targetCount = $summaries.Count
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Terminal matrix evidence created: $resolvedOutputPath"
