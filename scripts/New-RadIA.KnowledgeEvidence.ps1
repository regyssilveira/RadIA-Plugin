param(
    [string]$ValidationPath = ".\Output\Validation\Knowledge",
    [string]$OutputPath = (
        ".\Output\Evidence\knowledge_smoke_evidence_2.0.0.json"
    ),
    [int]$RequiredToolCount = 197
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
        -Message "Knowledge evidence was not found: $evidencePath"
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
            $evidence.evidenceKind -eq
                "privateSemanticKnowledgeSmoke"
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
                $cycle.KnowledgeExercised -eq $true -and
                $cycle.KnowledgeIndexedFiles -ge 2 -and
                $cycle.KnowledgeResultCount -ge 1 -and
                $cycle.KnowledgeSemanticHitCount -ge 1 -and
                $cycle.KnowledgeProvider -eq "local-hash-v1"
            ) `
            -Message "$($target.evidenceFile) lacks semantic evidence."
        Assert-RadIACondition `
            -Condition (
                $cycle.KnowledgeProjectId -and
                $cycle.KnowledgeFileName -and
                $cycle.KnowledgeStartLine -ge 1 -and
                $cycle.KnowledgeExplanation -and
                $cycle.KnowledgeNavigationTool -eq "NavigateToFile"
            ) `
            -Message "$($target.evidenceFile) lacks provenance evidence."
        Assert-RadIACondition `
            -Condition (
                $cycle.KnowledgeEstimatedIndexBytes -gt 0 -and
                $cycle.KnowledgeChunkCount -ge 2 -and
                $cycle.KnowledgeDocumentRetrieved -eq $true -and
                $cycle.KnowledgeWorkspaceIsolated -eq $true -and
                $cycle.KnowledgeIndexDurationMs -ge 0 -and
                $cycle.KnowledgeSearchDurationMs -ge 0
            ) `
            -Message "$($target.evidenceFile) lacks metrics or isolation."
    }

    $cycle = @($evidence.cycles)[0]
    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        installedBplSha256 = $evidence.installedBplSha256
        toolCount = $evidence.toolCount
        cyclesPassed = $evidence.cyclesPassed
        projectId = $cycle.KnowledgeProjectId
        indexedFiles = $cycle.KnowledgeIndexedFiles
        semanticHitCount = $cycle.KnowledgeSemanticHitCount
        provider = $cycle.KnowledgeProvider
        citedFile = $cycle.KnowledgeFileName
        citedLine = $cycle.KnowledgeStartLine
        navigationTool = $cycle.KnowledgeNavigationTool
        estimatedIndexBytes = $cycle.KnowledgeEstimatedIndexBytes
        chunkCount = $cycle.KnowledgeChunkCount
        indexDurationMs = $cycle.KnowledgeIndexDurationMs
        searchDurationMs = $cycle.KnowledgeSearchDurationMs
        documentRetrieved = $true
        workspaceIsolated = $true
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
    evidenceKind = "privateSemanticKnowledgeMatrix"
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

Write-Host "Knowledge matrix evidence created: $resolvedOutputPath"
