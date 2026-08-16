param(
    [Parameter(Mandatory = $true)]
    [string]$LedgerPath,
    [string]$ManifestPath = "",
    [string]$RepositoryRoot = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $resolved = [IO.Path]::GetFullPath($PathValue)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "$Description was not found: $resolved"
    }
    return $resolved
}

function Get-RequiredProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw "$Context is missing required property '$Name'."
    }
    return $property.Value
}

function Assert-ExactSet {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Expected,
        [Parameter(Mandatory = $true)]
        [string[]]$Actual,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $missing = @($Expected | Where-Object { $_ -notin $Actual })
    $unexpected = @($Actual | Where-Object { $_ -notin $Expected })
    if (($missing.Count -gt 0) -or ($unexpected.Count -gt 0)) {
        throw (
            "$Description does not match the manifest. " +
            "Missing=[$($missing -join ', ')]; Unexpected=[$($unexpected -join ', ')]."
        )
    }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Join-Path $PSScriptRoot ".."
}
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $RepositoryRoot ".planning\competitive_closure_manifest.json"
}

$resolvedLedger = Resolve-ExistingFile -PathValue $LedgerPath -Description "Closure ledger"
$resolvedManifest = Resolve-ExistingFile -PathValue $ManifestPath -Description "Closure manifest"
$packagePath = Resolve-ExistingFile `
    -PathValue (Join-Path $RepositoryRoot "package.json") `
    -Description "Package manifest"

$manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
$ledger = Get-Content -LiteralPath $resolvedLedger -Raw | ConvertFrom-Json
$package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json

if ((Get-RequiredProperty $manifest "schemaVersion" "Closure manifest") -ne 1) {
    throw "Unsupported closure manifest schema version."
}
if ((Get-RequiredProperty $ledger "schemaVersion" "Closure ledger") -ne 1) {
    throw "Unsupported closure ledger schema version."
}
if ((Get-RequiredProperty $ledger "goalId" "Closure ledger") -ne $manifest.goalId) {
    throw "Closure ledger goalId does not match the manifest."
}
if ((Get-RequiredProperty $ledger "productVersion" "Closure ledger") -ne $package.version) {
    throw "Closure ledger productVersion does not match package.json."
}
if (Get-RequiredProperty $ledger "sourceDirty" "Closure ledger") {
    throw "Closure ledger cannot be accepted from a dirty worktree."
}

$headCommit = (& git -C $RepositoryRoot rev-parse HEAD 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to resolve the repository HEAD: $headCommit"
}
if ((Get-RequiredProperty $ledger "sourceCommit" "Closure ledger") -ne $headCommit) {
    throw "Closure ledger sourceCommit does not match the current HEAD."
}

$allowedStatuses = @("closed", "partial", "failed", "not-supported", "not-applicable", "not-tested")
$fronts = @(Get-RequiredProperty $ledger "fronts" "Closure ledger")
$expectedFrontIds = @($manifest.fronts | ForEach-Object { $_.id })
    $actualFrontIds = @($fronts | ForEach-Object { $_.id })
if (($actualFrontIds | Select-Object -Unique).Count -ne $actualFrontIds.Count) {
    throw "Closure ledger contains duplicate front identifiers."
}
Assert-ExactSet -Expected $expectedFrontIds -Actual $actualFrontIds -Description "Closure fronts"

foreach ($manifestFront in $manifest.fronts) {
    $front = @($fronts | Where-Object { $_.id -eq $manifestFront.id })[0]
    $status = Get-RequiredProperty $front "status" "Front '$($manifestFront.id)'"
    if ($status -notin $allowedStatuses) {
        throw "Front '$($manifestFront.id)' has invalid status '$status'."
    }
    $checks = @(Get-RequiredProperty $front "checks" "Front '$($manifestFront.id)'")
    $expectedCheckIds = @($manifestFront.requiredChecks)
    $actualCheckIds = @($checks | ForEach-Object { $_.id })
    if (($actualCheckIds | Select-Object -Unique).Count -ne $actualCheckIds.Count) {
        throw "Front '$($manifestFront.id)' contains duplicate check identifiers."
    }
    Assert-ExactSet `
        -Expected $expectedCheckIds `
        -Actual $actualCheckIds `
        -Description "Checks for front '$($manifestFront.id)'"

    foreach ($check in $checks) {
        $checkStatus = Get-RequiredProperty $check "status" "Check '$($check.id)'"
        if ($checkStatus -notin $allowedStatuses) {
            throw "Check '$($check.id)' has invalid status '$checkStatus'."
        }
        if ($checkStatus -eq "closed") {
            $artifact = Get-RequiredProperty $check "artifact" "Check '$($check.id)'"
            $command = Get-RequiredProperty $check "command" "Check '$($check.id)'"
            if ([string]::IsNullOrWhiteSpace($artifact) -or [string]::IsNullOrWhiteSpace($command)) {
                throw "Closed check '$($check.id)' requires command and artifact evidence."
            }
            $targets = @(Get-RequiredProperty $check "targets" "Check '$($check.id)'")
            Assert-ExactSet `
                -Expected @($manifest.supportedTargets) `
                -Actual @($targets) `
                -Description "Targets for closed check '$($check.id)'"
        }
    }

    if ($status -eq "closed") {
        $nonClosedChecks = @($checks | Where-Object { $_.status -ne "closed" })
        if ($nonClosedChecks.Count -gt 0) {
            throw "Front '$($manifestFront.id)' is closed with required checks that are not closed."
        }
    }
}

$ledgerStatus = Get-RequiredProperty $ledger "status" "Closure ledger"
$nonClosedFronts = @($fronts | Where-Object { $_.status -ne "closed" })
if (($ledgerStatus -eq "closed") -and ($nonClosedFronts.Count -gt 0)) {
    throw "Closure ledger is closed while one or more fronts are not closed."
}
if (($ledgerStatus -ne "active") -and ($ledgerStatus -ne "closed")) {
    throw "Closure ledger status must be active or closed."
}

Write-Host (
    "Competitive closure ledger is valid: status=$ledgerStatus; " +
    "fronts=$($fronts.Count); commit=$headCommit."
)
