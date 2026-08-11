param(
    [string]$ValidationPath = ".\Output\Validation\FunctionalClosure",
    [string]$OutputPath = ".\docs\block_review_feedback_evidence_2.7.0.json"
)

$ErrorActionPreference = "Stop"
$targets = @(
    @{ file = "CC04-D12.json"; version = "23.0"; platform = "Win32" },
    @{ file = "CC04-D13-Win32.json"; version = "37.0"; platform = "Win32" },
    @{ file = "CC04-D13-IDE64.json"; version = "37.0"; platform = "Win64" }
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
        -Message "Block review feedback evidence was not found: $evidencePath"
    $evidence = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 |
        ConvertFrom-Json

    Assert-RadIACondition `
        -Condition ($evidence.sourceDirty -eq $false) `
        -Message "$($target.file) was not generated from a clean source tree."
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -match "^[0-9a-f]{40}$") `
        -Message "$($target.file) has an invalid source commit."
    Assert-RadIACondition `
        -Condition (
            $evidence.evidenceKind -eq "continuousDelphiJourney" -and
            $evidence.delphiVersion -eq $target.version -and
            $evidence.platform -eq $target.platform -and
            $evidence.status -eq "passed"
        ) `
        -Message "$($target.file) has an invalid target or status."
    Assert-RadIACondition `
        -Condition (
            $evidence.phases.reviewChangeRequest -eq $true -and
            $evidence.phases.shutdownPassed -eq $true
        ) `
        -Message "$($target.file) did not prove review feedback and shutdown."

    if (-not $sourceCommit) {
        $sourceCommit = $evidence.sourceCommit
        $productVersion = $evidence.productVersion
    }
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -eq $sourceCommit) `
        -Message "All review feedback targets must use the same source commit."
    Assert-RadIACondition `
        -Condition ($evidence.productVersion -eq $productVersion) `
        -Message "All review feedback targets must use the same product version."

    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        feedbackWithoutMutation = $evidence.phases.reviewChangeRequest
        shutdown = $evidence.phases.shutdownPassed
        status = $evidence.status
        completedAtUtc = $evidence.completedAtUtc
    }
}

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force |
        Out-Null
}
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "blockReviewFeedbackMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    sourceDirty = $false
    targetCount = $summaries.Count
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Block review feedback evidence created: $resolvedOutputPath"
