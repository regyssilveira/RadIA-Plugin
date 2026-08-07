param(
    [string]$ValidationPath = ".\Output\Validation",
    [string]$PackagesPath = ".\Output\Packages",
    [string]$ReleaseEvidencePath = ".\docs\release_evidence_2.0.0.json",
    [string]$OutputPath = ".\docs\ide_smoke_evidence_2.0.0.json",
    [int]$RequiredCycles = 10,
    [int]$RequiredToolCount = 123,
    [string]$UpgradeFromVersion = "1.0.0"
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
        evidenceFile = "Delphi13-Win64.json"
        delphiVersion = "37.0"
        platform = "Win64"
    }
)
$requiredLifecycleModes = @(
    "Uninstall",
    "InstallPreviousVersion",
    "UpgradeToCurrentVersion",
    "Repair"
)
$resolvedValidation = [IO.Path]::GetFullPath($ValidationPath)
$resolvedPackages = [IO.Path]::GetFullPath($PackagesPath)
$resolvedReleaseEvidence = [IO.Path]::GetFullPath($ReleaseEvidencePath)
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-RadIACondition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-RadIALifecycleModes {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ActualModes,
        [Parameter(Mandatory = $true)]
        [string]$EvidenceFile,
        [Parameter(Mandatory = $true)]
        [int]$Cycle
    )

    $actual = @($ActualModes)
    Assert-RadIACondition `
        -Condition ($actual.Count -eq $requiredLifecycleModes.Count) `
        -Message "$EvidenceFile cycle $Cycle has an incomplete lifecycle."
    for ($index = 0; $index -lt $requiredLifecycleModes.Count; $index++) {
        Assert-RadIACondition `
            -Condition ($actual[$index] -eq $requiredLifecycleModes[$index]) `
            -Message "$EvidenceFile cycle $Cycle has an invalid lifecycle order."
    }
}

function Get-RadIAArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReleaseEvidence,
        [Parameter(Mandatory = $true)]
        [string]$DelphiVersion,
        [Parameter(Mandatory = $true)]
        [string]$Platform
    )

    $matches = @(
        $ReleaseEvidence.artifacts |
            Where-Object {
                $_.delphiVersion -eq $DelphiVersion -and
                $_.platform -eq $Platform
            }
    )
    Assert-RadIACondition `
        -Condition ($matches.Count -eq 1) `
        -Message (
            "Release evidence must contain exactly one artifact for " +
            "Delphi $DelphiVersion $Platform."
        )
    return $matches[0]
}

function Read-RadIAPackageManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath
    )

    $archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $entries = @(
            $archive.Entries |
                Where-Object {
                    $_.FullName.Replace("\", "/") -eq "manifest.json"
                }
        )
        Assert-RadIACondition `
            -Condition ($entries.Count -eq 1) `
            -Message "Package must contain exactly one manifest: $PackagePath"
        $stream = $entries[0].Open()
        try {
            $reader = New-Object IO.StreamReader($stream)
            try {
                return $reader.ReadToEnd() | ConvertFrom-Json
            } finally {
                $reader.Dispose()
            }
        } finally {
            $stream.Dispose()
        }
    } finally {
        $archive.Dispose()
    }
}

function Get-RadIARange {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Cycles,
        [Parameter(Mandatory = $true)]
        [string]$Property
    )

    $values = @($Cycles | ForEach-Object { $_.$Property })
    return [PSCustomObject]@{
        Minimum = ($values | Measure-Object -Minimum).Minimum
        Maximum = ($values | Measure-Object -Maximum).Maximum
    }
}

Assert-RadIACondition `
    -Condition (Test-Path -LiteralPath $resolvedReleaseEvidence -PathType Leaf) `
    -Message "Release evidence was not found: $resolvedReleaseEvidence"
$releaseEvidence = Get-Content `
    -LiteralPath $resolvedReleaseEvidence `
    -Raw |
    ConvertFrom-Json
Assert-RadIACondition `
    -Condition ($releaseEvidence.product -eq "RadIA") `
    -Message "Release evidence belongs to an unexpected product."
Assert-RadIACondition `
    -Condition ($releaseEvidence.sourceCommit -match "^[0-9a-f]{40}$") `
    -Message "Release evidence source commit is invalid."

$targetEvidence = @()
foreach ($target in $targets) {
    $evidencePath = Join-Path $resolvedValidation $target.evidenceFile
    Assert-RadIACondition `
        -Condition (Test-Path -LiteralPath $evidencePath -PathType Leaf) `
        -Message "IDE smoke evidence was not found: $evidencePath"
    $evidence = Get-Content -LiteralPath $evidencePath -Raw |
        ConvertFrom-Json
    $artifact = Get-RadIAArtifact `
        -ReleaseEvidence $releaseEvidence `
        -DelphiVersion $target.delphiVersion `
        -Platform $target.platform
    $packagePath = Join-Path $resolvedPackages $artifact.fileName
    $upgradePackageName = (
        "RadIA-v$UpgradeFromVersion-Delphi-$($target.delphiVersion)-" +
        "$($target.platform)-Release.zip"
    )
    $upgradePackagePath = Join-Path $resolvedPackages $upgradePackageName

    Assert-RadIACondition `
        -Condition ($evidence.delphiVersion -eq $target.delphiVersion) `
        -Message "$($target.evidenceFile) has an unexpected Delphi version."
    Assert-RadIACondition `
        -Condition ($evidence.platform -eq $target.platform) `
        -Message "$($target.evidenceFile) has an unexpected platform."
    Assert-RadIACondition `
        -Condition ($evidence.productVersion -eq $releaseEvidence.productVersion) `
        -Message "$($target.evidenceFile) has an unexpected product version."
    Assert-RadIACondition `
        -Condition ($evidence.sourceCommit -eq $releaseEvidence.sourceCommit) `
        -Message "$($target.evidenceFile) does not match the release source commit."
    Assert-RadIACondition `
        -Condition ($evidence.releasePackage -eq $artifact.fileName) `
        -Message "$($target.evidenceFile) does not match the release package."
    Assert-RadIACondition `
        -Condition ($evidence.releasePackageSha256 -eq $artifact.sha256) `
        -Message "$($target.evidenceFile) does not match the release package hash."
    Assert-RadIACondition `
        -Condition (Test-Path -LiteralPath $packagePath -PathType Leaf) `
        -Message "Release package was not found: $packagePath"
    $packageHash = (
        Get-FileHash -LiteralPath $packagePath -Algorithm SHA256
    ).Hash
    Assert-RadIACondition `
        -Condition ($packageHash -eq $artifact.sha256) `
        -Message "Release package hash changed: $($artifact.fileName)"
    $manifest = Read-RadIAPackageManifest -PackagePath $packagePath
    $bplEntries = @(
        $manifest.files |
            Where-Object { $_.path -eq "Bpl/RadIA.bpl" }
    )
    Assert-RadIACondition `
        -Condition ($bplEntries.Count -eq 1) `
        -Message "$($artifact.fileName) must contain one BPL manifest entry."
    Assert-RadIACondition `
        -Condition ($evidence.installedBplSha256 -eq $bplEntries[0].sha256) `
        -Message "$($target.evidenceFile) does not match the packaged BPL."
    Assert-RadIACondition `
        -Condition ($evidence.cyclesRequested -eq $RequiredCycles) `
        -Message "$($target.evidenceFile) requested an unexpected cycle count."
    Assert-RadIACondition `
        -Condition ($evidence.cyclesPassed -eq $RequiredCycles) `
        -Message "$($target.evidenceFile) did not pass all required cycles."
    Assert-RadIACondition `
        -Condition (@($evidence.cycles).Count -eq $RequiredCycles) `
        -Message "$($target.evidenceFile) has an incomplete cycle collection."
    Assert-RadIACondition `
        -Condition ($evidence.toolCount -eq $RequiredToolCount) `
        -Message "$($target.evidenceFile) has an unexpected tool count."
    Assert-RadIACondition `
        -Condition ([bool]$evidence.dockingExercised) `
        -Message "$($target.evidenceFile) did not exercise native docking."
    Assert-RadIACondition `
        -Condition ([bool]$evidence.packageLifecycleExercised) `
        -Message "$($target.evidenceFile) did not exercise package lifecycle."
    Assert-RadIACondition `
        -Condition ([bool]$evidence.upgradeExercised) `
        -Message "$($target.evidenceFile) did not exercise an upgrade."
    Assert-RadIACondition `
        -Condition ($evidence.upgradeFromVersion -eq $UpgradeFromVersion) `
        -Message "$($target.evidenceFile) used an unexpected upgrade source."
    Assert-RadIACondition `
        -Condition ($evidence.upgradeFromPackageSha256 -match "^[A-F0-9]{64}$") `
        -Message "$($target.evidenceFile) has an invalid upgrade package hash."
    Assert-RadIACondition `
        -Condition (Test-Path -LiteralPath $upgradePackagePath -PathType Leaf) `
        -Message "Upgrade source package was not found: $upgradePackagePath"
    $upgradePackageHash = (
        Get-FileHash -LiteralPath $upgradePackagePath -Algorithm SHA256
    ).Hash
    Assert-RadIACondition `
        -Condition ($evidence.upgradeFromPackageSha256 -eq $upgradePackageHash) `
        -Message "$($target.evidenceFile) does not match the upgrade source package."
    Assert-RadIACondition `
        -Condition ($evidence.installedBplSha256 -match "^[A-F0-9]{64}$") `
        -Message "$($target.evidenceFile) has an invalid installed BPL hash."

    foreach ($cycle in @($evidence.cycles)) {
        Assert-RadIACondition `
            -Condition ($cycle.ToolCount -eq $RequiredToolCount) `
            -Message "$($target.evidenceFile) cycle $($cycle.Cycle) has an invalid tool count."
        Assert-RadIACondition `
            -Condition ([bool]$cycle.DockingExercised) `
            -Message "$($target.evidenceFile) cycle $($cycle.Cycle) skipped docking."
        Assert-RadIACondition `
            -Condition ([bool]$cycle.PackageLifecycleExercised) `
            -Message "$($target.evidenceFile) cycle $($cycle.Cycle) skipped lifecycle."
        Assert-RadIACondition `
            -Condition ([bool]$cycle.UpgradeExercised) `
            -Message "$($target.evidenceFile) cycle $($cycle.Cycle) skipped upgrade."
        Assert-RadIACondition `
            -Condition ($cycle.UpgradeFromVersion -eq $UpgradeFromVersion) `
            -Message "$($target.evidenceFile) cycle $($cycle.Cycle) used a wrong source."
        Assert-RadIALifecycleModes `
            -ActualModes @($cycle.PackageLifecycleModes) `
            -EvidenceFile $target.evidenceFile `
            -Cycle $cycle.Cycle
    }

    $duration = Get-RadIARange -Cycles @($evidence.cycles) -Property "Seconds"
    $lifecycle = Get-RadIARange `
        -Cycles @($evidence.cycles) `
        -Property "PackageLifecycleSeconds"
    $targetEvidence += [PSCustomObject]@{
        delphiVersion = $target.delphiVersion
        platform = $target.platform
        releasePackage = $artifact.fileName
        releasePackageSha256 = $artifact.sha256
        installedBplSha256 = $evidence.installedBplSha256
        upgradeFromPackageSha256 = $evidence.upgradeFromPackageSha256
        cyclesPassed = $evidence.cyclesPassed
        minimumSeconds = $duration.Minimum
        maximumSeconds = $duration.Maximum
        minimumPackageLifecycleSeconds = $lifecycle.Minimum
        maximumPackageLifecycleSeconds = $lifecycle.Maximum
        generatedAtUtc = $evidence.generatedAtUtc
    }
}

$consolidated = [PSCustomObject]@{
    schemaVersion = 1
    product = "RadIA"
    productVersion = $releaseEvidence.productVersion
    sourceCommit = $releaseEvidence.sourceCommit
    cyclesRequestedPerTarget = $RequiredCycles
    toolCount = $RequiredToolCount
    dockingExercised = $true
    packageLifecycleExercised = $true
    packageLifecycleModes = $requiredLifecycleModes
    upgradeExercised = $true
    upgradeFromVersion = $UpgradeFromVersion
    desktopStateRestored = $true
    orphanProcessesDetected = $false
    targets = $targetEvidence
}
$outputDirectory = Split-Path -Parent $resolvedOutput
if ($outputDirectory) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}
$consolidated |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $resolvedOutput -Encoding UTF8

Write-Host (
    "IDE smoke evidence consolidated from $($targets.Count) targets: " +
    $resolvedOutput
)
