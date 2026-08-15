param(
    [string]$ValidationPath = ".\Output\Validation\FunctionalClosure",
    [string]$OutputPath = ".\Output\Evidence\natural_project_prompts_evidence_2.7.0.json"
)

$ErrorActionPreference = "Stop"
$targets = @(
    @{ file = "PromptMatrix-D12.json"; version = "23.0"; architecture = "Win32" },
    @{ file = "PromptMatrix-D13-Win32.json"; version = "37.0"; architecture = "Win32" },
    @{ file = "PromptMatrix-D13-IDE64.json"; version = "37.0"; architecture = "Win64" }
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
    $evidencePath = Join-Path $resolvedValidationPath $target.file
    Assert-RadIACondition `
        -Condition (Test-Path -LiteralPath $evidencePath -PathType Leaf) `
        -Message "Natural-project prompt evidence was not found: $evidencePath"
    $evidence = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 |
        ConvertFrom-Json

    Assert-RadIACondition `
        -Condition ($evidence.evidenceKind -eq "naturalProjectPromptMatrixTarget") `
        -Message "$($target.file) has an invalid evidence kind."
    Assert-RadIACondition `
        -Condition ($evidence.sourceDirty -eq $false) `
        -Message "$($target.file) was not generated from a clean source tree."
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -match "^[0-9a-f]{40}$") `
        -Message "$($target.file) has an invalid source commit."
    Assert-RadIACondition `
        -Condition ($evidence.delphiVersion -eq $target.version) `
        -Message "$($target.file) has an invalid Delphi version."
    Assert-RadIACondition `
        -Condition ($evidence.ideArchitecture -eq $target.architecture) `
        -Message "$($target.file) has an invalid IDE architecture."
    Assert-RadIACondition `
        -Condition (
            $evidence.status -eq "passed" -and
            $evidence.promptLanguageCount -eq 2 -and
            $evidence.templateCount -eq 7 -and
            $evidence.requiredTestCount -eq 14 -and
            @($evidence.validatedTests).Count -eq 14
        ) `
        -Message "$($target.file) has an incomplete prompt matrix."

    if (-not $sourceCommit) {
        $sourceCommit = $evidence.sourceCommit
        $productVersion = $evidence.productVersion
    }
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -eq $sourceCommit) `
        -Message "All prompt targets must use the same source commit."
    Assert-RadIACondition `
        -Condition ($evidence.productVersion -eq $productVersion) `
        -Message "All prompt targets must use the same product version."

    $summaries += $evidence
}

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force |
        Out-Null
}
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "naturalProjectPromptMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    sourceDirty = $false
    targetCount = $summaries.Count
    promptLanguageCount = 2
    templateCount = 7
    requiredTestCountPerTarget = 14
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Natural-project prompt matrix evidence created: $resolvedOutputPath"
