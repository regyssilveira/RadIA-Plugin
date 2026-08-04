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
    [int]$TimeoutSeconds = 300
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

Write-Host "The exact SonarQube analysis passed the Quality Gate." -ForegroundColor Green
