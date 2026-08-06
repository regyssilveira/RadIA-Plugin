<#
.SYNOPSIS
    Waits for the exact SonarQube analysis and fails unless its Quality Gate is OK.
.PARAMETER Token
    SonarQube token. Falls back to .env and then SONAR_TOKEN.
.PARAMETER HostUrl
    SonarQube server URL. Falls back to the scanner report and SONAR_HOST_URL.
.PARAMETER ReportTaskFile
    SonarScanner report-task.txt produced by the analysis being verified.
.PARAMETER TimeoutSeconds
    Maximum time to wait for Compute Engine processing.
#>
param(
    [string]$Token = "",
    [string]$HostUrl = "",
    [string]$ReportTaskFile = "",
    [ValidateRange(10, 1800)]
    [int]$TimeoutSeconds = 300,
    [ValidateRange(0, 100)]
    [decimal]$MinimumCoverage = 80,
    [ValidateRange(0, 100)]
    [decimal]$MaximumDuplication = 3,
    [string]$EvidencePath = ""
)

$ErrorActionPreference = "Stop"

function Get-RadIAEnvValue {
    param(
        [string]$FileName,
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $FileName)) {
        return ""
    }
    foreach ($line in Get-Content -LiteralPath $FileName) {
        $trimmedLine = $line.Trim()
        if (-not $trimmedLine -or $trimmedLine.StartsWith("#")) {
            continue
        }
        $parts = $trimmedLine.Split("=", 2)
        if (($parts.Count -eq 2) -and ($parts[0].Trim() -eq $Name)) {
            return $parts[1].Trim().Trim('"').Trim("'")
        }
    }
    return ""
}

function Read-RadIAScannerReport {
    param([string]$FileName)

    if (-not (Test-Path -LiteralPath $FileName)) {
        throw "SonarScanner report not found: $FileName"
    }
    $result = @{}
    foreach ($line in Get-Content -LiteralPath $FileName) {
        $parts = $line.Split("=", 2)
        if ($parts.Count -eq 2) {
            $result[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    return $result
}

function Invoke-RadIASonarApi {
    param(
        [string]$Uri,
        [hashtable]$Headers
    )

    return Invoke-RestMethod `
        -Method Get `
        -Uri $Uri `
        -Headers $Headers `
        -TimeoutSec 30
}

function Get-RadIAMeasureValue {
    param(
        [Parameter(Mandatory)]
        [object[]]$Measures,
        [Parameter(Mandatory)]
        [string]$Metric
    )

    $measure = @(
        $Measures |
            Where-Object { $_.metric -eq $Metric }
    ) | Select-Object -First 1
    if (-not $measure) {
        throw "SonarQube did not return the global metric $Metric."
    }
    return $measure.value
}

if ([string]::IsNullOrWhiteSpace($ReportTaskFile)) {
    $ReportTaskFile = Join-Path $PSScriptRoot "..\.scannerwork\report-task.txt"
}
$ReportTaskFile = [IO.Path]::GetFullPath($ReportTaskFile)
$report = Read-RadIAScannerReport -FileName $ReportTaskFile

if ([string]::IsNullOrWhiteSpace($HostUrl)) {
    $HostUrl = $env:SONAR_HOST_URL
}
if ([string]::IsNullOrWhiteSpace($HostUrl) -and $report.ContainsKey("serverUrl")) {
    $HostUrl = $report["serverUrl"]
}
if ([string]::IsNullOrWhiteSpace($HostUrl)) {
    $HostUrl = "http://localhost:9000"
}
$HostUrl = $HostUrl.TrimEnd("/")

if ([string]::IsNullOrWhiteSpace($Token)) {
    $Token = Get-RadIAEnvValue `
        -FileName (Join-Path $PSScriptRoot "..\.env") `
        -Name "SONAR_TOKEN"
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    $Token = $env:SONAR_TOKEN
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "SONAR_TOKEN is required to verify the SonarQube Quality Gate."
}
if (-not $report.ContainsKey("ceTaskId")) {
    throw "The SonarScanner report does not contain ceTaskId."
}

$credentials = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes("${Token}:")
)
$headers = @{ Authorization = "Basic $credentials" }
$taskId = $report["ceTaskId"]
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
$task = $null

do {
    $taskResponse = Invoke-RadIASonarApi `
        -Uri "$HostUrl/api/ce/task?id=$taskId" `
        -Headers $headers
    $task = $taskResponse.task
    if ($task.status -in @("PENDING", "IN_PROGRESS")) {
        Start-Sleep -Seconds 2
    }
} while (
    ($task.status -in @("PENDING", "IN_PROGRESS")) -and
    ([DateTime]::UtcNow -lt $deadline)
)

if ($task.status -in @("PENDING", "IN_PROGRESS")) {
    throw "Timed out waiting for SonarQube Compute Engine task $taskId."
}
if ($task.status -ne "SUCCESS") {
    throw "SonarQube Compute Engine task $taskId finished with status $($task.status)."
}
if ([string]::IsNullOrWhiteSpace($task.analysisId)) {
    throw "SonarQube Compute Engine task $taskId did not publish an analysisId."
}

$gateResponse = Invoke-RadIASonarApi `
    -Uri "$HostUrl/api/qualitygates/project_status?analysisId=$($task.analysisId)" `
    -Headers $headers
$gate = $gateResponse.projectStatus

Write-Host "SonarQube Quality Gate: $($gate.status)"
foreach ($condition in $gate.conditions) {
    Write-Host (
        "  {0}: {1} (actual {2}, threshold {3}, comparator {4})" -f
        $condition.status,
        $condition.metricKey,
        $condition.actualValue,
        $condition.errorThreshold,
        $condition.comparator
    )
}

if ($gate.status -ne "OK") {
    throw "SonarQube Quality Gate rejected analysis $($task.analysisId)."
}

if (-not $report.ContainsKey("projectKey")) {
    throw "The SonarScanner report does not contain projectKey."
}
$projectKey = $report["projectKey"]
$metricKeys = @(
    "bugs",
    "vulnerabilities",
    "security_hotspots",
    "code_smells",
    "coverage",
    "duplicated_lines_density",
    "reliability_rating",
    "security_rating",
    "sqale_rating"
) -join ","
$measureResponse = Invoke-RadIASonarApi `
    -Uri (
        "$HostUrl/api/measures/component?component=$projectKey" +
        "&metricKeys=$metricKeys"
    ) `
    -Headers $headers
$measures = @($measureResponse.component.measures)
$issueResponse = Invoke-RadIASonarApi `
    -Uri (
        "$HostUrl/api/issues/search?componentKeys=$projectKey" +
        "&resolved=false&ps=1"
    ) `
    -Headers $headers

$bugs = [int](Get-RadIAMeasureValue $measures "bugs")
$vulnerabilities = [int](
    Get-RadIAMeasureValue $measures "vulnerabilities"
)
$securityHotspots = [int](
    Get-RadIAMeasureValue $measures "security_hotspots"
)
$codeSmells = [int](Get-RadIAMeasureValue $measures "code_smells")
$coverage = [decimal]::Parse(
    (Get-RadIAMeasureValue $measures "coverage"),
    [Globalization.CultureInfo]::InvariantCulture
)
$duplication = [decimal]::Parse(
    (Get-RadIAMeasureValue $measures "duplicated_lines_density"),
    [Globalization.CultureInfo]::InvariantCulture
)
$reliabilityRating = [decimal]::Parse(
    (Get-RadIAMeasureValue $measures "reliability_rating"),
    [Globalization.CultureInfo]::InvariantCulture
)
$securityRating = [decimal]::Parse(
    (Get-RadIAMeasureValue $measures "security_rating"),
    [Globalization.CultureInfo]::InvariantCulture
)
$maintainabilityRating = [decimal]::Parse(
    (Get-RadIAMeasureValue $measures "sqale_rating"),
    [Globalization.CultureInfo]::InvariantCulture
)
$unresolvedIssues = [int]$issueResponse.total

if ($bugs -ne 0 -or
    $vulnerabilities -ne 0 -or
    $securityHotspots -ne 0 -or
    $codeSmells -ne 0 -or
    $unresolvedIssues -ne 0) {
    throw (
        "Global SonarQube debt is not zero: bugs=$bugs, " +
        "vulnerabilities=$vulnerabilities, hotspots=$securityHotspots, " +
        "smells=$codeSmells, issues=$unresolvedIssues."
    )
}
if ($coverage -lt $MinimumCoverage) {
    throw "Global coverage $coverage is below $MinimumCoverage."
}
if ($duplication -gt $MaximumDuplication) {
    throw "Global duplication $duplication exceeds $MaximumDuplication."
}
if ($reliabilityRating -ne 1 -or
    $securityRating -ne 1 -or
    $maintainabilityRating -ne 1) {
    throw (
        "Global ratings must all be A (1.0): reliability=" +
        "$reliabilityRating, security=$securityRating, " +
        "maintainability=$maintainabilityRating."
    )
}

Write-Host (
    "Global metrics: coverage=$coverage%, duplication=$duplication%, " +
    "issues=0, bugs=0, vulnerabilities=0, hotspots=0, smells=0, ratings=A."
)

if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
    $workspaceRoot = [IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "..")
    )
    $sourceCommit = (& git -C $workspaceRoot rev-parse HEAD).Trim()
    $sourceDirty = @(
        & git -C $workspaceRoot status --porcelain --untracked-files=no
    ).Count -gt 0
    $resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
    $evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
    if ($evidenceDirectory) {
        New-Item -ItemType Directory -Path $evidenceDirectory -Force |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "sonarGlobalQuality"
        product = "RadIA"
        productVersion = "2.0.0"
        sourceCommit = $sourceCommit
        sourceDirty = $sourceDirty
        analysisId = $task.analysisId
        qualityGate = $gate.status
        bugs = $bugs
        vulnerabilities = $vulnerabilities
        securityHotspots = $securityHotspots
        codeSmells = $codeSmells
        unresolvedIssues = $unresolvedIssues
        coverage = $coverage
        duplicatedLinesDensity = $duplication
        reliabilityRating = $reliabilityRating
        securityRating = $securityRating
        maintainabilityRating = $maintainabilityRating
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        status = "passed"
    } |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8
}

Write-Host (
    "The exact SonarQube analysis and global metrics passed."
) -ForegroundColor Green
