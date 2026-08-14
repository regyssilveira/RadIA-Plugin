param(
    [string]$ValidationPath = (
        ".\Output\Validation\DeclarativeWorkflow"
    ),
    [string]$OutputPath = (
        ".\Output\Evidence\declarative_workflow_smoke_evidence_2.0.0.json"
    ),
    [int]$RequiredToolCount = 154
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
        -Message "Workflow evidence was not found: $evidencePath"
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
            $evidence.evidenceKind -eq "declarativeWorkflowSmoke"
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
        -Condition (
            $evidence.installedBplSha256 -match "^[A-F0-9]{64}$"
        ) `
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
                $cycle.DeclarativeWorkflowExercised -eq $true -and
                $cycle.DeclarativeWorkflowManifestLoaded -eq $true -and
                $cycle.DeclarativeWorkflowRegistered -eq $true -and
                $cycle.DeclarativeWorkflowExecuted -eq $true
            ) `
            -Message (
                "$($target.evidenceFile) has an incomplete workflow cycle."
            )
        Assert-RadIACondition `
            -Condition (
                $cycle.DeclarativeWorkflowName -eq
                    "RadIADiagnosticInspection" -and
                $cycle.DeclarativeWorkflowRisk -eq "readOnly" -and
                $cycle.DeclarativeWorkflowStepCount -eq 2
            ) `
            -Message "$($target.evidenceFile) has invalid workflow data."
    }

    $seconds = @(
        $evidence.cycles |
            ForEach-Object { $_.Seconds }
    )
    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        installedBplSha256 = $evidence.installedBplSha256
        toolCount = $evidence.toolCount
        cyclesPassed = $evidence.cyclesPassed
        minimumSeconds = (
            $seconds |
                Measure-Object -Minimum
        ).Minimum
        maximumSeconds = (
            $seconds |
                Measure-Object -Maximum
        ).Maximum
        manifestLoaded = $true
        workflowRegistered = $true
        workflowExecuted = $true
        workflowName = "RadIADiagnosticInspection"
        risk = "readOnly"
        stepCount = 2
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
    evidenceKind = "declarativeWorkflowMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    requiredToolCount = $RequiredToolCount
    targetCount = $summaries.Count
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host (
    "Declarative workflow matrix evidence created: " +
    $resolvedOutputPath
)
