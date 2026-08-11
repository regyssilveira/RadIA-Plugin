param(
    [string]$ValidationPath = ".\Output\Validation\GeneratedProjects",
    [string]$OutputPath = (
        ".\docs\generated_project_templates_evidence_2.0.0.json"
    )
)

$ErrorActionPreference = "Stop"

$targets = @(
    @{
        evidenceFile = "Delphi12-Win32.json"
        delphiVersion = "23.0"
    },
    @{
        evidenceFile = "Delphi13-Win32.json"
        delphiVersion = "37.0"
    }
)
$requiredTemplates = @(
    "CalculatorApp",
    "CalculatorAppTests",
    "ConsoleApp",
    "DextControllerApi",
    "DextMinimalApi",
    "DUnitXApp",
    "FmxApp",
    "LibraryApp",
    "PackageApp",
    "ServiceApp",
    "VclApp"
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
        -Message "Generated-project evidence was not found: $evidencePath"
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
            $evidence.evidenceKind -eq "generatedProjectTemplateTarget"
        ) `
        -Message "$($target.evidenceFile) has an invalid evidence kind."
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -match "^[0-9a-f]{40}$") `
        -Message "$($target.evidenceFile) has an invalid source commit."
    Assert-RadIACondition `
        -Condition ($evidence.delphiVersion -eq $target.delphiVersion) `
        -Message "$($target.evidenceFile) has an invalid Delphi version."
    Assert-RadIACondition `
        -Condition ($evidence.platform -eq "Win32") `
        -Message "$($target.evidenceFile) has an invalid platform."
    Assert-RadIACondition `
        -Condition (
            $evidence.status -eq "passed" -and
            $evidence.templateCount -eq $requiredTemplates.Count -and
            @($evidence.templates).Count -eq $requiredTemplates.Count
        ) `
        -Message "$($target.evidenceFile) has an incomplete template set."

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

    $templates = @($evidence.templates)
    foreach ($requiredTemplate in $requiredTemplates) {
        $matches = @(
            $templates |
                Where-Object { $_.template -eq $requiredTemplate }
        )
        Assert-RadIACondition `
            -Condition ($matches.Count -eq 1) `
            -Message (
                "$($target.evidenceFile) must contain $requiredTemplate once."
            )
        $template = $matches[0]
        Assert-RadIACondition `
            -Condition (
                $template.status -in @("passed", "not-required") -and
                $template.platform -eq "Win32" -and
                $template.configuration -eq "Debug" -and
                $template.durationMs -ge 0
            ) `
            -Message (
                "$($target.evidenceFile) failed $requiredTemplate validation."
            )
    }

    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        compilerProductVersion = $evidence.compilerProductVersion
        platform = $evidence.platform
        templateCount = $evidence.templateCount
        status = $evidence.status
        generatedAtUtc = $evidence.generatedAtUtc
        templates = $templates
        calculatorInterface = $evidence.calculatorInterface
        calculatorUnitTests = $evidence.calculatorUnitTests
    }
}

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force |
        Out-Null
}
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "generatedProjectTemplateMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    targetCount = $summaries.Count
    requiredTemplates = $requiredTemplates
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Generated-project matrix evidence created: $resolvedOutputPath"
