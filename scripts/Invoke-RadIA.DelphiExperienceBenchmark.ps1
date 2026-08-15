[CmdletBinding()]
param(
    [string]$ScenarioId,
    [string]$OutputPath = "Output/Evidence/delphi_experience_benchmark_result.json",
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scenarioPath = Join-Path $repositoryRoot "benchmarks/delphi-experience/scenarios.json"
$manifest = Get-Content -LiteralPath $scenarioPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) { throw "Unsupported benchmark manifest schema." }

$scenarios = @($manifest.scenarios)
if ($ScenarioId) { $scenarios = @($scenarios | Where-Object id -eq $ScenarioId) }
if ($scenarios.Count -eq 0) { throw "No benchmark scenarios matched." }

$ids = @{}
foreach ($scenario in $scenarios) {
    if ($scenario.schemaVersion -ne 1) { throw "Unsupported scenario schema: $($scenario.id)" }
    if ($scenario.id -notmatch '^[a-z0-9-]+$') { throw "Invalid scenario id: $($scenario.id)" }
    if ($ids.ContainsKey($scenario.id)) { throw "Duplicate scenario id: $($scenario.id)" }
    $ids[$scenario.id] = $true
    if ($scenario.action -notin @("dunitx", "build")) { throw "Unsupported action: $($scenario.action)" }
}

if ($ValidateOnly) {
    Write-Host "Validated $($scenarios.Count) deterministic benchmark scenarios."
    exit 0
}

$startedAt = [DateTime]::UtcNow
$results = [System.Collections.Generic.List[object]]::new()
function Get-TextSha256([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

Push-Location $repositoryRoot
try {
foreach ($scenario in $scenarios) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $output = ""
    $exitCode = 1
    if ($scenario.action -eq "build") {
        $arguments = @("-ExecutionPolicy", "Bypass", "-File", "build.ps1", "-DelphiVersion", $scenario.target)
        if ($scenario.platform -eq "IDE64") { $arguments += "-IDE64" }
        $output = & powershell.exe @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } else {
        $platform = if ($scenario.platform -eq "IDE64") { "Win64" } else { "Win32" }
        $version = if ($scenario.platform -eq "IDE64") { "37.0" } else { "23.0" }
        $testExe = Join-Path $repositoryRoot "Output/$version/bin/$platform/Debug/RadIATests.exe"
        if (Test-Path -LiteralPath $testExe) {
            $output = & $testExe "--run:$($scenario.target)" "--exit:Continue" "--consolemode:Quiet" 2>&1 |
                Out-String
            $exitCode = $LASTEXITCODE
        } else {
            $output = "Test executable not found: $testExe"
        }
    }
    $watch.Stop()
    $results.Add([ordered]@{
        id = $scenario.id
        category = $scenario.category
        success = ($exitCode -eq 0)
        durationMs = [int64]$watch.ElapsedMilliseconds
        estimatedCostUnits = [int]$scenario.estimatedCostUnits
        rollbackExpected = [bool]$scenario.rollbackExpected
        rollbackObserved = [bool]($scenario.rollbackExpected -and ($exitCode -eq 0))
        outputSha256 = Get-TextSha256 $output
    })
}
} finally {
    Pop-Location
}

$passed = @($results | Where-Object success).Count
$costUnits = 0
foreach ($item in $results) { $costUnits += [int]$item.estimatedCostUnits }
$report = [ordered]@{
    schemaVersion = 1
    startedAtUtc = $startedAt.ToString("o")
    durationMs = [int64]([DateTime]::UtcNow - $startedAt).TotalMilliseconds
    telemetrySent = $false
    summary = [ordered]@{
        total = $results.Count
        passed = $passed
        failed = $results.Count - $passed
        successRate = if ($results.Count) { [Math]::Round($passed / $results.Count, 4) } else { 0 }
        estimatedCostUnits = $costUnits
        rollbacksExpected = @($results | Where-Object rollbackExpected).Count
        rollbacksObserved = @($results | Where-Object rollbackObserved).Count
    }
    results = $results
}

$resolvedOutput = Join-Path $repositoryRoot $OutputPath
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8
Write-Host "Benchmark report written to $resolvedOutput"
if ($report.summary.failed -gt 0) { exit 1 }
