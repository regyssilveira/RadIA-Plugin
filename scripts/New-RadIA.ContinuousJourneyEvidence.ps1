param(
    [string]$ValidationPath = ".\Output\Validation\ContinuousJourney",
    [string]$OutputPath = (
        ".\Output\Evidence\continuous_journey_smoke_evidence_2.3.1.json"
    )
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
        evidenceFile = "Delphi13-IDE64.json"
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
        -Message "Journey evidence was not found: $evidencePath"
    $evidence = Get-Content `
        -LiteralPath $evidencePath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    Assert-RadIACondition `
        -Condition ($evidence.schemaVersion -eq 1) `
        -Message "$($target.evidenceFile) has an invalid schema."
    Assert-RadIACondition `
        -Condition ($evidence.evidenceKind -eq "continuousDelphiJourney") `
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
        -Condition ($evidence.status -eq "passed") `
        -Message "$($target.evidenceFile) did not pass."

    $phases = $evidence.phases
    $allPhasesPassed = (
        $phases.projectCreated -and
        $phases.formDesigned -and
        $phases.sourceEdited -and
        $phases.compilerFailureObservedAndFixed -and
        $phases.buildPassed -and
        $phases.testsPassed -and
        $phases.debuggerPassed -and
        $phases.reviewedCommitCreated -and
        $phases.shutdownPassed
    )
    Assert-RadIACondition `
        -Condition $allPhasesPassed `
        -Message "$($target.evidenceFile) has an incomplete journey."
    Assert-RadIACondition `
        -Condition (
            $evidence.tests.status -eq "succeeded" -and
            $evidence.tests.exitCode -eq 0 -and
            $evidence.tests.total -gt 0 -and
            $evidence.tests.passed -eq $evidence.tests.total -and
            $evidence.tests.failed -eq 0 -and
            $evidence.tests.errors -eq 0 -and
            $evidence.tests.ignored -eq 0 -and
            $evidence.tests.allPassed -eq $true
        ) `
        -Message "$($target.evidenceFile) lacks passing test evidence."
    Assert-RadIACondition `
        -Condition (
            $evidence.debugger.state -in @("stopped", "exception") -and
            $evidence.debugger.callStackAccessible -and
            $evidence.debugger.callStackFrameCount -gt 0 -and
            $evidence.debugger.timelineEventCount -gt 0
        ) `
        -Message "$($target.evidenceFile) lacks debugger evidence."
    Assert-RadIACondition `
        -Condition (
            $evidence.git.commit -match "^[0-9a-f]{40}$" -and
            $evidence.git.diffContainedMarker -eq $true
        ) `
        -Message "$($target.evidenceFile) lacks reviewed Git evidence."

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

    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        installedBplSha256 = $evidence.installedBplSha256
        durationMs = $evidence.durationMs
        phases = $evidence.phases
        tests = $evidence.tests
        debugger = $evidence.debugger
        git = $evidence.git
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
    evidenceKind = "continuousDelphiJourneyMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    targetCount = $summaries.Count
    status = "passed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Continuous journey matrix created: $resolvedOutputPath"
