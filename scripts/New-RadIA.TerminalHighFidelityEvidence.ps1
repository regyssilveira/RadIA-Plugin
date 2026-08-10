param(
    [string]$OutputPath = (
        ".\docs\terminal_high_fidelity_evidence_2.4.2.json"
    ),
    [int]$ExpectedTestCount = 1024,
    [string]$VisualSmokeEvidencePath = (
        ".\docs\terminal_smoke_evidence_2.4.2.json"
    )
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$productVersion = (
    Get-Content -LiteralPath "$repositoryRoot\package.json" -Raw |
        ConvertFrom-Json
).version
$sourceCommit = (
    & git -C $repositoryRoot rev-parse HEAD
).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch "^[0-9a-f]{40}$") {
    throw "The source commit could not be resolved."
}
& git -C $repositoryRoot diff --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Terminal evidence requires a clean tracked source."
}
& git -C $repositoryRoot diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    throw "Terminal evidence requires a clean staged source."
}

$requiredTests = @(
    "PseudoTerminalStreamsInputAndResizes",
    "NativeEmulatorPreservesScreenContract",
    "ScreenRestoresPrimaryContentAfterAlternateScreen",
    "ScreenSupportsExtendedColorsAttributesAndHyperlinks",
    "ScreenNegotiatesBracketedPasteAndMouseInput",
    "ScreenUsesDisplayWidthForWideAndCombiningCharacters",
    "ScreenReflowsSoftWrapsAndPreservesHardBreaks",
    "ScreenSupportsTuiInsertDeleteAndEraseCharacters"
)
$targetDefinitions = @(
    @{
        delphiVersion = "23.0"
        platform = "Win32"
        resultPath = "Output\23.0\bin\Win32\Debug\dunitx-results.xml"
    },
    @{
        delphiVersion = "37.0"
        platform = "Win32"
        resultPath = "Output\37.0\bin\Win32\Debug\dunitx-results.xml"
    },
    @{
        delphiVersion = "37.0"
        platform = "Win64"
        resultPath = "Output\37.0\bin\Win64\Debug\dunitx-results.xml"
    }
)

$targets = @()
foreach ($definition in $targetDefinitions) {
    $resultPath = Join-Path $repositoryRoot $definition.resultPath
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        throw "DUnitX evidence was not found: $resultPath"
    }
    [xml]$document = Get-Content -LiteralPath $resultPath -Raw
    $root = $document.'test-results'
    if (
        [int]$root.total -ne $ExpectedTestCount -or
        [int]$root.errors -ne 0 -or
        [int]$root.failures -ne 0 -or
        [int]$root.ignored -ne 0 -or
        [int]$root.'not-run' -ne 0
    ) {
        throw "DUnitX matrix failed for $($definition.delphiVersion) $($definition.platform)."
    }
    foreach ($testName in $requiredTests) {
        $testCase = $document.SelectSingleNode(
            "//test-case[@name='$testName']"
        )
        if (-not $testCase -or $testCase.result -ne "Success") {
            throw (
                "Required terminal test '$testName' did not pass for " +
                "$($definition.delphiVersion) $($definition.platform)."
            )
        }
    }
    $targets += [PSCustomObject]@{
        delphiVersion = $definition.delphiVersion
        platform = $definition.platform
        testsPassed = [int]$root.total
        failures = [int]$root.failures
        errors = [int]$root.errors
        ignored = [int]$root.ignored
        conPtyProcessPassed = $true
        vtTuiContractPassed = $true
    }
}

$executorDefinitions = @(
    @{ id = "codex"; package = "@openai/codex@latest" },
    @{ id = "claude"; package = "@anthropic-ai/claude-code@latest" },
    @{ id = "gemini"; package = "@google/gemini-cli@latest" },
    @{ id = "copilot"; package = "@github/copilot@latest" }
)
$executors = @()
foreach ($definition in $executorDefinitions) {
    $versionOutput = & npx.cmd --yes $definition.package --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to execute the $($definition.id) runtime."
    }
    $normalizedVersion = ($versionOutput -join " ").Trim()
    if (-not $normalizedVersion) {
        throw "The $($definition.id) runtime returned an empty version."
    }
    $executors += [PSCustomObject]@{
        id = $definition.id
        package = $definition.package
        versionOutput = $normalizedVersion
        status = "passed"
    }
}

$resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
$resolvedVisualSmokePath = [IO.Path]::GetFullPath(
    $VisualSmokeEvidencePath
)
$visualSmokeStatus = "pending: installed IDE matrix not found"
if (Test-Path -LiteralPath $resolvedVisualSmokePath -PathType Leaf) {
    $visualSmokeEvidence = Get-Content `
        -LiteralPath $resolvedVisualSmokePath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    if (
        $visualSmokeEvidence.status -eq "passed" -and
        $visualSmokeEvidence.targetCount -eq 3
    ) {
        $visualSmokeStatus = (
            "passed: " +
            [IO.Path]::GetFileName($resolvedVisualSmokePath)
        )
    }
}
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "terminalHighFidelityMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    sourceDirty = $false
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    status = "passed"
    targetCount = $targets.Count
    executorCount = $executors.Count
    requiredTests = $requiredTests
    targets = $targets
    executors = $executors
    visualSmoke = $visualSmokeStatus
} |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "High-fidelity terminal evidence created: $resolvedOutputPath"
