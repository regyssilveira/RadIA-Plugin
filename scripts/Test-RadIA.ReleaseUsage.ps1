[CmdletBinding()]
param(
    [string]$EvidenceRoot = ".\Output\Validation\ReleaseUsage"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedEvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$outputRoot = [IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "Output")
)
if (-not $resolvedEvidenceRoot.StartsWith(
    $outputRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Release usage evidence must remain inside Output."
}
$runningIDEs = @(
    Get-Process bds -ErrorAction SilentlyContinue |
        Where-Object { -not $_.HasExited }
)
if ($runningIDEs.Count -gt 0) {
    throw "Close all Delphi IDE instances before the release usage gate."
}

function Stop-RadIAReleaseAuxiliaryProcesses {
    $names = @("RadIA.Semantic.Engine", "RadIA.MCP.Bridge")
    $processes = @(Get-Process -Name $names -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force
        if (-not $process.WaitForExit(10000)) {
            throw (
                "RadIA auxiliary process did not stop: " +
                "$($process.ProcessName):$($process.Id)."
            )
        }
    }
}

function Stop-RadIAReleaseIDEProcesses {
    $processes = @(
        Get-Process bds -ErrorAction SilentlyContinue |
            Where-Object { -not $_.HasExited }
    )
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force
        if (-not $process.WaitForExit(10000)) {
            throw "Delphi process did not stop after a failed startup probe."
        }
    }
}

function Install-RadIAReleaseTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DelphiVersion,
        [switch]$IDE64
    )

    Stop-RadIAReleaseAuxiliaryProcesses
    $installArguments = @{
        DelphiVersion = $DelphiVersion
        Install = $true
    }
    if ($IDE64) {
        $installArguments.IDE64 = $true
    }
    & (Join-Path $repositoryRoot "build.ps1") @installArguments
    if ($LASTEXITCODE -ne 0) {
        throw (
            "The current build could not be installed for Delphi " +
            "$DelphiVersion " +
            $(if ($IDE64) { "Win64" } else { "Win32" }) + "."
        )
    }
}

Stop-RadIAReleaseAuxiliaryProcesses
New-Item `
    -ItemType Directory `
    -Path $resolvedEvidenceRoot `
    -Force |
    Out-Null

& (Join-Path $PSScriptRoot "Test-RadIA.ReleasePromises.ps1") `
    -Enforce `
    -EvidencePath (
        Join-Path $resolvedEvidenceRoot "release-promise-coverage.json"
    )

$unitTestTargets = @(
    [PSCustomObject]@{ Id = "delphi12-win32"; Version = "23.0" },
    [PSCustomObject]@{ Id = "delphi13-win32"; Version = "37.0" }
)
foreach ($target in $unitTestTargets) {
    Write-Host "Running the complete DUnitX suite for $($target.Id)."
    & (Join-Path $repositoryRoot "build.ps1") `
        -DelphiVersion $target.Version `
        -Test
    if ($LASTEXITCODE -ne 0) {
        throw "The complete DUnitX suite failed for $($target.Id)."
    }
}

$generatedProjectTargets = @(
    [PSCustomObject]@{
        Id = "delphi12-win32"
        Version = "23.0"
        EvidenceFile = "Delphi12-Win32.json"
    },
    [PSCustomObject]@{
        Id = "delphi13-win32"
        Version = "37.0"
        EvidenceFile = "Delphi13-Win32.json"
    }
)
foreach ($target in $generatedProjectTargets) {
    $generatedArguments = @{
        DelphiVersion = $target.Version
        EvidencePath = Join-Path `
            $resolvedEvidenceRoot `
            $target.EvidenceFile
    }
    if (-not $env:DEXT_ROOT) {
        $generatedArguments.SkipDext = $true
    }
    & (Join-Path $PSScriptRoot "Test-RadIA.GeneratedProjects.ps1") `
        @generatedArguments
}

& (Join-Path $PSScriptRoot "New-RadIA.GeneratedProjectsEvidence.ps1") `
    -ValidationPath $resolvedEvidenceRoot `
    -OutputPath (
        Join-Path $resolvedEvidenceRoot "generated-projects-matrix.json"
    )

$installationTargets = @(
    [PSCustomObject]@{ Version = "23.0"; IDE64 = $false },
    [PSCustomObject]@{ Version = "37.0"; IDE64 = $false },
    [PSCustomObject]@{ Version = "37.0"; IDE64 = $true }
)
foreach ($target in $installationTargets) {
    Install-RadIAReleaseTarget `
        -DelphiVersion $target.Version `
        -IDE64:$target.IDE64
}

$openingTargets = @(
    [PSCustomObject]@{ Id = "delphi12-win32"; Version = "23.0"; IDE64 = $false },
    [PSCustomObject]@{ Id = "delphi13-win32"; Version = "37.0"; IDE64 = $false },
    [PSCustomObject]@{ Id = "delphi13-ide64"; Version = "37.0"; IDE64 = $true }
)
$openingResults = @()
$openingEvidencePath = Join-Path `
    $resolvedEvidenceRoot `
    "project-opening-matrix.json"

function Test-RadIAReleaseJourneyRetryable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Output
    )

    $retryableMessages = @(
        "Delphi did not become ready for the smoke test.",
        "The Delphi File menu did not open.",
        "The Delphi file dialog did not open."
    )
    foreach ($message in $retryableMessages) {
        if ($Output.Contains($message)) {
            return $true
        }
    }
    return $false
}

foreach ($target in $openingTargets) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "Test-RadIA.ProjectCreationNavigation.ps1"),
        "-DelphiVersion",
        $target.Version
    )
    if ($target.IDE64) {
        $arguments += "-IDE64"
    }
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & powershell.exe @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $attemptCount = 1
    $startupRetryUsed = $false
    if (
        $exitCode -ne 0 -and
        (Test-RadIAReleaseJourneyRetryable -Output $output)
    ) {
        $firstAttemptOutput = $output
        Stop-RadIAReleaseIDEProcesses
        Install-RadIAReleaseTarget `
            -DelphiVersion $target.Version `
            -IDE64:$target.IDE64
        try {
            $ErrorActionPreference = "Continue"
            $output = & powershell.exe @arguments 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        $attemptCount = 2
        $startupRetryUsed = $true
        $output = (
            "First startup attempt failed and was preserved:`r`n" +
            $firstAttemptOutput +
            "`r`nBounded startup retry:`r`n" +
            $output
        )
    }
    $stopwatch.Stop()
    $openingResults += [PSCustomObject]@{
        targetId = $target.Id
        delphiVersion = $target.Version
        ideArchitecture = if ($target.IDE64) { "Win64" } else { "Win32" }
        status = if ($exitCode -eq 0) { "passed" } else { "failed" }
        exitCode = $exitCode
        durationMs = $stopwatch.ElapsedMilliseconds
        attemptCount = $attemptCount
        startupRetryUsed = $startupRetryUsed
        outputTail = if ($output.Length -gt 8192) {
            $output.Substring($output.Length - 8192)
        } else {
            $output
        }
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "projectCreationOpeningMatrix"
        product = "RadIA"
        status = if (
            @($openingResults | Where-Object { $_.status -eq "failed" }).Count `
                -eq 0
        ) {
            "passed"
        } else {
            "failed"
        }
        expectedTargetCount = $openingTargets.Count
        completedTargetCount = $openingResults.Count
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        targets = $openingResults
    } |
        ConvertTo-Json -Depth 6 |
        Set-Content `
            -LiteralPath $openingEvidencePath `
            -Encoding UTF8
    if ($exitCode -ne 0) {
        throw "Project creation and opening failed for $($target.Id)."
    }
}

& (Join-Path $PSScriptRoot "Test-RadIA.UsageMatrix.ps1") `
    -Profile "release" `
    -EvidencePath (
        Join-Path $resolvedEvidenceRoot "automated-usage-matrix.json"
    )

Write-Host (
    "Release usage gate passed: public promises, complete DUnitX, " +
    "registered integration " +
    "and end-to-end scenarios, calculator, generated projects, project " +
    "opening, and automated usage matrix."
)
