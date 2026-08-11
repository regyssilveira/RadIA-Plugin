[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,

    [switch]$IDE64,

    [Parameter(Mandatory = $true)]
    [string]$EvidencePath
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$platform = if ($IDE64) { "Win64" } else { "Win32" }
$testExecutable = Join-Path `
    $repositoryRoot `
    "Output\$DelphiVersion\bin\$platform\Debug\RadIATests.exe"
$resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
$reportPath = [IO.Path]::ChangeExtension($resolvedEvidencePath, ".xml")
$requiredTests = @(
    "TestNaturalConsolePromptPt",
    "TestNaturalConsolePromptEn",
    "TestNaturalVclPromptPt",
    "TestNaturalVclPromptEn",
    "TestNaturalFmxPromptPt",
    "TestNaturalFmxPromptEn",
    "TestNaturalLibraryPromptPt",
    "TestNaturalLibraryPromptEn",
    "TestNaturalPackagePromptPt",
    "TestNaturalPackagePromptEn",
    "TestNaturalDUnitXPromptPt",
    "TestNaturalDUnitXPromptEn",
    "TestNaturalServicePromptPt",
    "TestNaturalServicePromptEn"
)

if (-not (Test-Path -LiteralPath $testExecutable -PathType Leaf)) {
    throw "RadIATests executable was not found: $testExecutable"
}
if ($evidenceDirectory) {
    New-Item -ItemType Directory -Path $evidenceDirectory -Force |
        Out-Null
}

& $testExecutable `
    "--hidebanner" `
    "--run:RadIA.Tests.ChatPresenter" `
    "--consolemode:Off" `
    "--xmlfile:$reportPath"
if ($LASTEXITCODE -ne 0) {
    throw "Natural-project prompt tests failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Natural-project prompt report was not created."
}

[xml]$report = Get-Content -LiteralPath $reportPath -Raw
$root = $report.'test-results'
if (-not $root -or [int]$root.errors -ne 0 -or [int]$root.failures -ne 0) {
    throw "Natural-project prompt report contains failures or errors."
}
$testCases = @($report.SelectNodes('//test-case'))
$validatedTests = @()
foreach ($requiredTest in $requiredTests) {
    $matches = @($testCases | Where-Object { $_.name -eq $requiredTest })
    if ($matches.Count -ne 1 -or $matches[0].success -ne "True") {
        throw "Natural-project prompt test was not proven: $requiredTest"
    }
    $validatedTests += $requiredTest
}

$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Unable to resolve the source commit."
}
& git -C $repositoryRoot diff --quiet --exit-code
$sourceDirty = $LASTEXITCODE -ne 0
& git -C $repositoryRoot diff --cached --quiet --exit-code
$sourceDirty = $sourceDirty -or ($LASTEXITCODE -ne 0)
$productVersion = (
    Get-Content `
        -LiteralPath (Join-Path $repositoryRoot "package.json") `
        -Raw |
        ConvertFrom-Json
).version

[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "naturalProjectPromptMatrixTarget"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    sourceDirty = $sourceDirty
    delphiVersion = $DelphiVersion
    ideArchitecture = $platform
    promptLanguageCount = 2
    templateCount = 7
    requiredTestCount = $requiredTests.Count
    validatedTests = $validatedTests
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
} |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8

Write-Host "Natural-project prompt matrix passed: $resolvedEvidencePath"
