<#
.SYNOPSIS
    Runs the local RadIA release pipeline with publication disabled by default.
.DESCRIPTION
    Reuses the existing repository gates, builds release packages and the visual
    installer, and binds all evidence to the current clean commit. DryRun never
    creates tags, pushes commits, installs packages, or changes GitHub releases.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Publish,
    [switch]$PlanOnly,
    [string]$ReleaseTag = "",
    [string]$SonarReportTaskFile = ".\.scannerwork\report-task.txt",
    [string]$SonarHostUrl = ""
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$distributionRoot = Join-Path $repositoryRoot "Output\Distribution"
$sonarEvidencePath = Join-Path $distributionRoot "SonarQualityGate.json"
$releaseEvidencePath = Join-Path $distributionRoot "ReleaseEvidence.json"
$installerEvidencePath = Join-Path `
    $distributionRoot `
    "VisualInstallerEvidence.json"
$productVersion = (
    Get-Content `
        -LiteralPath (Join-Path $repositoryRoot "package.json") `
        -Raw |
        ConvertFrom-Json
).version
$expectedTag = "v$productVersion"
$mode = if ($Publish) { "publish" } else { "dry-run" }

if ($DryRun -and $Publish) {
    throw "DryRun and Publish cannot be requested together."
}
if ($ReleaseTag -and ($ReleaseTag -ne $expectedTag)) {
    throw "Release tag $ReleaseTag does not match product version $productVersion."
}
if (-not $ReleaseTag) {
    $ReleaseTag = $expectedTag
}

$steps = @(
    "verify-clean-source",
    "lint-and-web-tests",
    "supported-targets",
    "sonarqube-exact-revision",
    "build-three-release-packages",
    $(if ($Publish) {
        "mandatory-release-usage"
    } else {
        "mandatory-release-usage-plan"
    }),
    "package-provenance",
    "visual-installer",
    "cross-evidence-provenance",
    "stage-public-installer"
)
if ($Publish) {
    $steps += "publish-existing-tag"
}
if ($PlanOnly) {
    [PSCustomObject]@{
        schemaVersion = 1
        mode = $mode
        productVersion = $productVersion
        releaseTag = $ReleaseTag
        mutatesRemote = [bool]$Publish
        steps = $steps
    } | ConvertTo-Json -Depth 4
    exit 0
}

Push-Location $repositoryRoot
try {
    $sourceCommit = (& git rev-parse HEAD).Trim()
    if ($sourceCommit -notmatch "^[0-9a-f]{40}$") {
        throw "Unable to resolve the release source commit."
    }
    $changes = @(& git status --porcelain)
    if ($changes.Count -gt 0) {
        throw "Release orchestration requires a completely clean worktree."
    }
    if ($Publish) {
        $branch = (& git branch --show-current).Trim()
        if ($branch -ne "main") {
            throw "Publication is allowed only from the main branch."
        }
        $tagCommit = (& git rev-list -n 1 $ReleaseTag).Trim()
        if (($LASTEXITCODE -ne 0) -or ($tagCommit -ne $sourceCommit)) {
            throw "Release tag $ReleaseTag must exist at the current HEAD."
        }
    }

    & npm run lint
    if ($LASTEXITCODE -ne 0) { throw "ESLint failed." }
    & npm run test:web
    if ($LASTEXITCODE -ne 0) { throw "Web tests failed." }
    & npm run test:docs
    if ($LASTEXITCODE -ne 0) { throw "Documentation tests failed." }
    & ".\scripts\Test-RadIA.SupportedTargets.ps1"

    if (Test-Path -LiteralPath $distributionRoot) {
        Get-ChildItem -LiteralPath $distributionRoot -Force |
            Remove-Item -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path $distributionRoot | Out-Null
    }
    $sonarArguments = @{
        ReportTaskFile = $SonarReportTaskFile
        EvidencePath = $sonarEvidencePath
    }
    if ($SonarHostUrl) {
        $sonarArguments.HostUrl = $SonarHostUrl
    }
    & ".\scripts\Test-RadIA.SonarQualityGate.ps1" @sonarArguments

    & ".\build.ps1" -DelphiVersion "23.0" -Release -Package
    & ".\build.ps1" -DelphiVersion "37.0" -Release -Package
    & ".\build.ps1" -DelphiVersion "37.0" -IDE64 -Release -Package
    if ($Publish) {
        & ".\scripts\Test-RadIA.ReleaseUsage.ps1" `
            -EvidenceRoot (Join-Path $distributionRoot "ReleaseUsage")
    } else {
        $usagePlanPath = Join-Path $distributionRoot "ReleaseUsagePlan.json"
        & ".\scripts\Test-RadIA.ReleaseUsage.ps1" -PlanOnly |
            Set-Content -LiteralPath $usagePlanPath -Encoding UTF8
    }
    & ".\scripts\New-RadIA.ReleaseEvidence.ps1" `
        -OutputPath $releaseEvidencePath
    & ".\scripts\New-RadIA.VisualInstaller.ps1" `
        -EvidencePath $installerEvidencePath
    & ".\scripts\Test-RadIA.VisualInstaller.ps1" `
        -EvidencePath $installerEvidencePath

    $sonarEvidence = Get-Content -LiteralPath $sonarEvidencePath -Raw |
        ConvertFrom-Json
    $releaseEvidence = Get-Content -LiteralPath $releaseEvidencePath -Raw |
        ConvertFrom-Json
    $installerEvidence = Get-Content -LiteralPath $installerEvidencePath -Raw |
        ConvertFrom-Json
    foreach ($evidence in @(
        $sonarEvidence,
        $releaseEvidence,
        $installerEvidence
    )) {
        if (($evidence.sourceCommit -ne $sourceCommit) -or
            ($evidence.productVersion -ne $productVersion)) {
            throw "Release evidence does not match the current commit and version."
        }
    }
    if (($sonarEvidence.status -ne "passed") -or
        ($sonarEvidence.sourceDirty -ne $false)) {
        throw "SonarQube evidence is not publishable."
    }

    $installerName = "RadIA-v$productVersion-Setup.exe"
    $installerPath = Join-Path $repositoryRoot "Output\Installer\$installerName"
    $stagedInstaller = Join-Path $distributionRoot $installerName
    Copy-Item -LiteralPath $installerPath -Destination $stagedInstaller
    $stagedHash = (Get-FileHash $stagedInstaller -Algorithm SHA256).Hash
    if ($stagedHash -ne $installerEvidence.sha256) {
        throw "Staged installer does not match its validated evidence."
    }

    $summaryPath = Join-Path $distributionRoot "ReleaseOrchestration.json"
    [PSCustomObject]@{
        schemaVersion = 1
        mode = $mode
        productVersion = $productVersion
        releaseTag = $ReleaseTag
        sourceCommit = $sourceCommit
        installerFileName = $installerName
        installerSha256 = $stagedHash
        publicationPerformed = $false
        completedAtUtc = [DateTime]::UtcNow.ToString("o")
    } | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath $summaryPath -Encoding UTF8

    if ($Publish) {
        & gh release view $ReleaseTag 2>$null
        if ($LASTEXITCODE -ne 0) {
            & gh release create `
                $ReleaseTag `
                $stagedInstaller `
                --verify-tag `
                --title "RadIA $productVersion" `
                --generate-notes `
                --latest
        } else {
            & gh release upload $ReleaseTag $stagedInstaller --clobber
        }
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub release publication failed."
        }
        $summary = Get-Content -LiteralPath $summaryPath -Raw |
            ConvertFrom-Json
        $summary.publicationPerformed = $true
        $summary | ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath $summaryPath -Encoding UTF8
    }

    Write-Host (
        "RadIA release orchestration completed in $mode mode for " +
        "$sourceCommit."
    ) -ForegroundColor Green
} finally {
    Pop-Location
}
