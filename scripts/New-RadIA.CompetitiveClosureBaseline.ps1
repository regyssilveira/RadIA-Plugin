param(
    [string]$OutputPath = "",
    [string]$ManifestPath = ""
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repositoryRoot ".planning\competitive_closure_manifest.json"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repositoryRoot "Output\Validation\CompetitiveClosure\CurrentBaseline.json"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$package = Get-Content -LiteralPath (Join-Path $repositoryRoot "package.json") -Raw | ConvertFrom-Json
$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to resolve the repository HEAD: $sourceCommit"
}
$dirtyLines = @(& git -C $repositoryRoot status --porcelain --untracked-files=no)
$sourceDirty = $dirtyLines.Count -gt 0

$fronts = @()
foreach ($manifestFront in $manifest.fronts) {
    $checks = @()
    foreach ($checkId in $manifestFront.requiredChecks) {
        $checks += [ordered]@{
            id = $checkId
            status = "not-tested"
            command = ""
            artifact = ""
            targets = @()
        }
    }
    $fronts += [ordered]@{
        id = $manifestFront.id
        title = $manifestFront.title
        status = "not-tested"
        checks = $checks
    }
}

$baseline = [ordered]@{
    schemaVersion = 1
    goalId = $manifest.goalId
    productVersion = $package.version
    sourceCommit = $sourceCommit
    sourceDirty = $sourceDirty
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    status = "active"
    fronts = $fronts
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$baseline | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Competitive closure baseline created: $resolvedOutput"
if ($sourceDirty) {
    Write-Warning "The baseline is intentionally unverified because the worktree is dirty."
}
