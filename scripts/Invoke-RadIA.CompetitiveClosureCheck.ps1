param(
    [Parameter(Mandatory = $true)]
    [string]$LedgerPath,
    [Parameter(Mandatory = $true)]
    [string]$FrontId,
    [Parameter(Mandatory = $true)]
    [string]$CheckId,
    [Parameter(Mandatory = $true)]
    [string]$Executable,
    [string[]]$ArgumentList = @(),
    [string[]]$Targets = @(
        "delphi12-win32",
        "delphi13-win32",
        "delphi13-ide64"
    )
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$resolvedLedger = [IO.Path]::GetFullPath($LedgerPath)
$ledger = Get-Content -LiteralPath $resolvedLedger -Raw | ConvertFrom-Json
$package = Get-Content -LiteralPath (Join-Path $repositoryRoot "package.json") -Raw | ConvertFrom-Json
$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to resolve the repository HEAD: $sourceCommit"
}
if (@(& git -C $repositoryRoot status --porcelain --untracked-files=no).Count -gt 0) {
    throw "Closure checks require a clean worktree."
}
if (($ledger.sourceCommit -ne $sourceCommit) -or ($ledger.productVersion -ne $package.version)) {
    throw "The ledger provenance does not match the current source."
}

$front = @($ledger.fronts | Where-Object { $_.id -eq $FrontId }) | Select-Object -First 1
if (-not $front) {
    throw "Unknown closure front: $FrontId"
}
$check = @($front.checks | Where-Object { $_.id -eq $CheckId }) | Select-Object -First 1
if (-not $check) {
    throw "Unknown closure check '$CheckId' for front '$FrontId'."
}

$commandText = (@($Executable) + @($ArgumentList)) -join " "
$startedAt = [DateTime]::UtcNow
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $output = & $Executable @ArgumentList 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorAction
}
$completedAt = [DateTime]::UtcNow

$evidenceDirectory = Join-Path $repositoryRoot "Output\Validation\CompetitiveClosure\Current"
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$safeName = "$FrontId-$CheckId" -replace "[^A-Za-z0-9_.-]", "-"
$logPath = Join-Path $evidenceDirectory "$safeName.log"
$evidencePath = Join-Path $evidenceDirectory "$safeName.json"
$output | Set-Content -LiteralPath $logPath -Encoding UTF8
$relativeEvidence = [IO.Path]::GetRelativePath($repositoryRoot, $evidencePath)
$relativeLog = [IO.Path]::GetRelativePath($repositoryRoot, $logPath)
$evidence = [ordered]@{
    schemaVersion = 1
    productVersion = $package.version
    sourceCommit = $sourceCommit
    frontId = $FrontId
    checkId = $CheckId
    command = $commandText
    targets = @($Targets)
    startedAtUtc = $startedAt.ToString("o")
    completedAtUtc = $completedAt.ToString("o")
    exitCode = $exitCode
    status = if ($exitCode -eq 0) { "passed" } else { "failed" }
    log = $relativeLog
}
$evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $evidencePath -Encoding UTF8

$check.status = if ($exitCode -eq 0) { "closed" } else { "failed" }
$check.command = $commandText
$check.artifact = $relativeEvidence
$check.targets = @($Targets)
$nonClosedChecks = @($front.checks | Where-Object { $_.status -ne "closed" })
$front.status = if ($nonClosedChecks.Count -eq 0) { "closed" } elseif ($exitCode -eq 0) { "partial" } else { "failed" }
$nonClosedFronts = @($ledger.fronts | Where-Object { $_.status -ne "closed" })
$ledger.status = if ($nonClosedFronts.Count -eq 0) { "closed" } else { "active" }
$ledger | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedLedger -Encoding UTF8

Write-Host $output
Write-Host "Closure evidence: $relativeEvidence"
if ($exitCode -ne 0) {
    throw "Closure check failed with exit code $exitCode."
}
