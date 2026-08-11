param(
    [string]$ValidationPath = ".\Output\Validation\FunctionalClosure",
    [string]$OutputPath = ".\docs\ide_intent_navigation_evidence_2.7.0.json"
)

$ErrorActionPreference = "Stop"
$targets = @(
    @{ file = "CC03-D12.json"; version = "23.0"; platform = "Win32" },
    @{ file = "CC03-D13-Win32.json"; version = "37.0"; platform = "Win32" },
    @{ file = "CC03-D13-IDE64.json"; version = "37.0"; platform = "Win64" }
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
        -Message "IDE intent evidence was not found: $evidencePath"
    $evidence = Get-Content -LiteralPath $evidencePath -Raw -Encoding UTF8 |
        ConvertFrom-Json

    Assert-RadIACondition `
        -Condition ($evidence.evidenceKind -eq "continuousDelphiJourney") `
        -Message "$($target.file) has an invalid evidence kind."
    Assert-RadIACondition `
        -Condition ($evidence.sourceDirty -eq $false) `
        -Message "$($target.file) was not generated from a clean source tree."
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -match "^[0-9a-f]{40}$") `
        -Message "$($target.file) has an invalid source commit."
    Assert-RadIACondition `
        -Condition (
            $evidence.delphiVersion -eq $target.version -and
            $evidence.platform -eq $target.platform -and
            $evidence.status -eq "passed"
        ) `
        -Message "$($target.file) has an invalid target or status."
    Assert-RadIACondition `
        -Condition (
            $evidence.phases.developmentSurfaceDesign -eq $true -and
            $evidence.phases.developmentSurfaceCode -eq $true -and
            $evidence.phases.developmentSurfaceError -eq $true -and
            $evidence.phases.developmentSurfaceCancellation -eq $true -and
            $evidence.phases.shutdownPassed -eq $true
        ) `
        -Message "$($target.file) has an incomplete IDE intent smoke."

    if (-not $sourceCommit) {
        $sourceCommit = $evidence.sourceCommit
        $productVersion = $evidence.productVersion
    }
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -eq $sourceCommit) `
        -Message "All IDE intent targets must use the same source commit."
    Assert-RadIACondition `
        -Condition ($evidence.productVersion -eq $productVersion) `
        -Message "All IDE intent targets must use the same product version."

    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        design = $evidence.phases.developmentSurfaceDesign
        code = $evidence.phases.developmentSurfaceCode
        invalidIntent = $evidence.phases.developmentSurfaceError
        cancellation = $evidence.phases.developmentSurfaceCancellation
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
    evidenceKind = "ideIntentNavigationMatrix"
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

Write-Host "IDE intent navigation evidence created: $resolvedOutputPath"
