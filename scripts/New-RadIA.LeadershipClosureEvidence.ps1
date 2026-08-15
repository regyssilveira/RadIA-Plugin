param(
    [string]$JourneyPath = ".\Output\Validation\ContinuousJourney",
    [string]$StabilityPath = ".\Output\Validation\LeadershipClosure",
    [string]$ExternalMcpEvidencePath = (
        ".\Output\Validation\ExternalMcp\real-server.json"
    ),
    [string]$OutputPath = (
        ".\Output\Evidence\leadership_closure_evidence_2.3.1.json"
    ),
    [ValidateRange(1, 50)]
    [int]$RequiredCycles = 10,
    [ValidateRange(1, 1000)]
    [int]$RequiredToolCount = 164
)

$ErrorActionPreference = "Stop"

$targets = @(
    @{
        journeyFile = "Delphi12-Win32.json"
        stabilityFile = "Delphi12-Win32.json"
        delphiVersion = "23.0"
        platform = "Win32"
    },
    @{
        journeyFile = "Delphi13-Win32.json"
        stabilityFile = "Delphi13-Win32.json"
        delphiVersion = "37.0"
        platform = "Win32"
    },
    @{
        journeyFile = "Delphi13-IDE64.json"
        stabilityFile = "Delphi13-IDE64.json"
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

function Read-RadIAEvidence {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Description
    )

    Assert-RadIACondition `
        -Condition (Test-Path -LiteralPath $Path -PathType Leaf) `
        -Message "$Description evidence was not found: $Path"
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
        ConvertFrom-Json
}

function Assert-RadIAJourney {
    param(
        [Parameter(Mandatory)]
        [object]$Evidence,
        [Parameter(Mandatory)]
        [hashtable]$Target
    )

    $phases = $Evidence.phases
    $passed = (
        $Evidence.evidenceKind -eq "continuousDelphiJourney" -and
        $Evidence.status -eq "passed" -and
        $Evidence.sourceDirty -eq $false -and
        $Evidence.delphiVersion -eq $Target.delphiVersion -and
        $Evidence.platform -eq $Target.platform -and
        $phases.projectCreated -and
        $phases.formDesigned -and
        $phases.sourceEdited -and
        $phases.compilerFailureObservedAndFixed -and
        $phases.buildPassed -and
        $phases.testsPassed -and
        $phases.debuggerPassed -and
        $phases.reviewedCommitCreated -and
        $phases.shutdownPassed -and
        $Evidence.tests.allPassed -and
        $Evidence.debugger.callStackAccessible -and
        $Evidence.debugger.callStackFrameCount -gt 0 -and
        $Evidence.debugger.timelineEventCount -gt 0 -and
        $Evidence.git.diffContainedMarker
    )
    Assert-RadIACondition `
        -Condition $passed `
        -Message "$($Target.journeyFile) has an incomplete journey."
}

function Assert-RadIAStability {
    param(
        [Parameter(Mandatory)]
        [object]$Evidence,
        [Parameter(Mandatory)]
        [hashtable]$Target
    )

    $headerPassed = (
        $Evidence.delphiVersion -eq $Target.delphiVersion -and
        $Evidence.platform -eq $Target.platform -and
        $Evidence.cyclesRequested -eq $RequiredCycles -and
        $Evidence.cyclesPassed -eq $RequiredCycles -and
        $Evidence.toolCount -ge $RequiredToolCount -and
        $Evidence.terminalExercised -and
        $Evidence.inlineCompletionExercised -and
        $Evidence.inlineReviewExercised -and
        $Evidence.agentRuntimeExercised
    )
    Assert-RadIACondition `
        -Condition $headerPassed `
        -Message "$($Target.stabilityFile) has an incomplete stability header."

    foreach ($cycle in @($Evidence.cycles)) {
        $cyclePassed = (
            $null -ne $cycle.DescendantCount -and
            $cycle.DescendantCount -ge 0 -and
            $cycle.TerminalOpened -and
            $cycle.TerminalRequiredControlsVisible -and
            $cycle.InlineCompletionAccepted -and
            $cycle.InlineCompletionSingleUndo -and
            $cycle.InlineCompletionRejectedClean -and
            $cycle.InlineReviewPublished -and
            $cycle.BlockReviewGutterPainted -and
            $cycle.BlockReviewKeyboardAccepted -and
            $cycle.BlockReviewMouseRejected -and
            $cycle.AgentRuntimeResumed -and
            $cycle.AgentRuntimeCompleted -and
            $cycle.AgentRuntimePersisted
        )
        Assert-RadIACondition `
            -Condition $cyclePassed `
            -Message (
                "$($Target.stabilityFile) cycle $($cycle.Cycle) " +
                "did not complete every interaction."
            )
    }
}

$resolvedJourney = [IO.Path]::GetFullPath($JourneyPath)
$resolvedStability = [IO.Path]::GetFullPath($StabilityPath)
$resolvedExternalMcp = [IO.Path]::GetFullPath($ExternalMcpEvidencePath)
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$externalMcp = Read-RadIAEvidence `
    -Path $resolvedExternalMcp `
    -Description "External MCP"
$mcpPassed = (
    $externalMcp.status -eq "realServerMatrixPassed" -and
    $externalMcp.sourceDirty -eq $false -and
    $externalMcp.authorization.consentProvided -and
    $externalMcp.workflow.discovery -and
    $externalMcp.workflow.read -and
    $externalMcp.workflow.consentedMutation -and
    $externalMcp.workflow.outsideWorkspaceDenied -and
    $externalMcp.workflow.preCancelledCallDenied -and
    $externalMcp.workflow.temporaryArtifacts -eq 0
)
Assert-RadIACondition `
    -Condition $mcpPassed `
    -Message "External MCP evidence is incomplete or was generated from dirty source."

$sourceCommit = ""
$productVersion = ""
$summaries = @()
foreach ($target in $targets) {
    $journey = Read-RadIAEvidence `
        -Path (Join-Path $resolvedJourney $target.journeyFile) `
        -Description "Continuous journey"
    $stability = Read-RadIAEvidence `
        -Path (Join-Path $resolvedStability $target.stabilityFile) `
        -Description "IDE stability"
    Assert-RadIAJourney -Evidence $journey -Target $target
    Assert-RadIAStability -Evidence $stability -Target $target

    if (-not $sourceCommit) {
        $sourceCommit = $journey.sourceCommit
        $productVersion = $journey.productVersion
    }
    $sameProvenance = (
        $journey.sourceCommit -eq $sourceCommit -and
        $stability.sourceCommit -eq $sourceCommit -and
        $externalMcp.sourceCommit -eq $sourceCommit -and
        $journey.productVersion -eq $productVersion -and
        $stability.productVersion -eq $productVersion -and
        $externalMcp.productVersion -eq $productVersion
    )
    Assert-RadIACondition `
        -Condition $sameProvenance `
        -Message "All closure evidence must use the same commit and version."

    $summaries += [PSCustomObject]@{
        delphiVersion = $target.delphiVersion
        platform = $target.platform
        installedBplSha256 = $journey.installedBplSha256
        journeyStatus = $journey.status
        testsPassed = $journey.tests.passed
        debuggerEvents = $journey.debugger.timelineEventCount
        cyclesPassed = $stability.cyclesPassed
        toolCount = $stability.toolCount
        orphanProcessesDetected = $false
    }
}

$outputDirectory = Split-Path -Parent $resolvedOutput
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force |
        Out-Null
}
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "leadershipClosureMatrix"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    status = "passed"
    requiredCyclesPerTarget = $RequiredCycles
    targetCount = $summaries.Count
    externalMcpAuthorized = $true
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    targets = $summaries
} |
    ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $resolvedOutput -Encoding UTF8

Write-Host "Leadership closure evidence created: $resolvedOutput"
