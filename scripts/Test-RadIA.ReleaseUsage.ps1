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
if (Get-Process bds -ErrorAction SilentlyContinue) {
    throw "Close all Delphi IDE instances before the release usage gate."
}
New-Item `
    -ItemType Directory `
    -Path $resolvedEvidenceRoot `
    -Force |
    Out-Null

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

$openingTargets = @(
    [PSCustomObject]@{ Id = "delphi12-win32"; Version = "23.0"; IDE64 = $false },
    [PSCustomObject]@{ Id = "delphi13-win32"; Version = "37.0"; IDE64 = $false },
    [PSCustomObject]@{ Id = "delphi13-ide64"; Version = "37.0"; IDE64 = $true }
)
$openingResults = @()
$openingEvidencePath = Join-Path `
    $resolvedEvidenceRoot `
    "project-opening-matrix.json"
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
    $output = & powershell.exe @arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $stopwatch.Stop()
    $openingResults += [PSCustomObject]@{
        targetId = $target.Id
        delphiVersion = $target.Version
        ideArchitecture = if ($target.IDE64) { "Win64" } else { "Win32" }
        status = if ($exitCode -eq 0) { "passed" } else { "failed" }
        exitCode = $exitCode
        durationMs = $stopwatch.ElapsedMilliseconds
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
    -Profile "startup" `
    -RequirePackageProvenance `
    -EvidencePath (
        Join-Path $resolvedEvidenceRoot "automated-usage-matrix.json"
    )

Write-Host (
    "Release usage gate passed: calculator, generated projects, " +
    "project opening, and automated usage matrix."
)
