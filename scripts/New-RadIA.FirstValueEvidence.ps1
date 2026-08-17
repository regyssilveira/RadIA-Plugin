param(
    [string]$ValidationPath = ".\Output\Validation\FirstValue",
    [string]$OutputPath = (
        ".\Output\Evidence\first_value_smoke_evidence_2.0.0.json"
    ),
    [int]$RequiredToolCount = 204
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
        -Message "First-value evidence was not found: $evidencePath"
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
            $evidence.evidenceKind -eq "installationFirstValueSmoke"
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
                $cycle.FirstValueExercised -eq $true -and
                $cycle.FirstValueMcpBridgeAvailable -eq $true -and
                $cycle.FirstValueTerminalReady -eq $true -and
                $cycle.FirstValueChatReady -eq $true -and
                $cycle.FirstValueFirstToolReady -eq $true
            ) `
            -Message "$($target.evidenceFile) lacks installed readiness."
        Assert-RadIACondition `
            -Condition (
                $cycle.FirstValueReadinessScore -ge 0 -and
                $cycle.FirstValueReadinessScore -le 100 -and
                $cycle.FirstValueStatus -and
                $cycle.FirstValueExecutor -and
                $cycle.FirstValueNextAction
            ) `
            -Message "$($target.evidenceFile) lacks doctor guidance."
        Assert-RadIACondition `
            -Condition (
                $cycle.FirstValueFirstToolName -eq "GetIDEState" -and
                $cycle.FirstValueIDEVersion -and
                $cycle.FirstValueIDEPlatform -eq $target.platform
            ) `
            -Message "$($target.evidenceFile) lacks the first IDE tool."
    }

    $cycle = @($evidence.cycles)[0]
    $summaries += [PSCustomObject]@{
        delphiVersion = $evidence.delphiVersion
        platform = $evidence.platform
        installedBplSha256 = $evidence.installedBplSha256
        toolCount = $evidence.toolCount
        cyclesPassed = $evidence.cyclesPassed
        status = $cycle.FirstValueStatus
        readinessScore = $cycle.FirstValueReadinessScore
        providerConfigured = $cycle.FirstValueProviderConfigured
        executor = $cycle.FirstValueExecutor
        cliRequired = $cycle.FirstValueCliRequired
        cliDetected = $cycle.FirstValueCliDetected
        mcpBridgeAvailable = $cycle.FirstValueMcpBridgeAvailable
        mcpConfigured = $cycle.FirstValueMcpConfigured
        mcpRequired = $cycle.FirstValueMcpRequired
        terminalReady = $cycle.FirstValueTerminalReady
        chatReady = $cycle.FirstValueChatReady
        firstToolReady = $cycle.FirstValueFirstToolReady
        nextAction = $cycle.FirstValueNextAction
        firstToolName = $cycle.FirstValueFirstToolName
        ideVersion = $cycle.FirstValueIDEVersion
        idePlatform = $cycle.FirstValueIDEPlatform
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
    evidenceKind = "installationFirstValueMatrix"
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

Write-Host "First-value matrix evidence created: $resolvedOutputPath"
