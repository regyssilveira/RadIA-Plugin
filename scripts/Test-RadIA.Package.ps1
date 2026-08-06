param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [switch]$IDE64
)

$ErrorActionPreference = "Stop"
$resolvedPackage = [IO.Path]::GetFullPath($PackagePath)
if (-not (Test-Path -LiteralPath $resolvedPackage -PathType Leaf)) {
    throw "Package file was not found: $resolvedPackage"
}

$testRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ("radia-package-tests-" + [Guid]::NewGuid().ToString("N"))
$expectedPlatform = "Win32"
if ($IDE64) {
    $expectedPlatform = "Win64"
}

function New-TestPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $target = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $target | Out-Null
    Expand-Archive -LiteralPath $resolvedPackage -DestinationPath $target
    return $target
}

function Invoke-PackageValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,
        [Parameter(Mandatory = $true)]
        [bool]$ShouldSucceed,
        [string]$ExpectedMessage = "",
        [switch]$UseOppositePlatform
    )

    $installer = Join-Path $PackageRoot "Scripts\Install-RadIA.Package.ps1"
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $installer,
        "-DelphiVersion",
        $DelphiVersion,
        "-ValidateOnly"
    )
    $useIDE64 = $IDE64.IsPresent
    if ($UseOppositePlatform) {
        $useIDE64 = -not $useIDE64
    }
    if ($useIDE64) {
        $arguments += "-IDE64"
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell.exe @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    $succeeded = $exitCode -eq 0
    if ($succeeded -ne $ShouldSucceed) {
        throw (
            "Unexpected validation result. Success=$succeeded. " +
            "Output: $output"
        )
    }
    if ($ExpectedMessage -and -not $output.Contains($ExpectedMessage)) {
        throw (
            "Expected message was not emitted: $ExpectedMessage. " +
            "Output: $output"
        )
    }
}

function Read-PackagePlan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Install", "Repair", "Uninstall")]
        [string]$Mode,
        [switch]$RemoveUserData
    )

    $installer = Join-Path $PackageRoot "Scripts\Install-RadIA.Package.ps1"
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $installer,
        "-DelphiVersion",
        $DelphiVersion,
        "-Mode",
        $Mode,
        "-PlanOnly"
    )
    if ($IDE64) {
        $arguments += "-IDE64"
    }
    if ($RemoveUserData) {
        $arguments += "-RemoveUserData"
    }
    $output = & powershell.exe @arguments | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Package plan failed: $output"
    }
    return $output | ConvertFrom-Json
}

function Read-Manifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $manifestPath = Join-Path $PackageRoot "manifest.json"
    return Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
}

function Write-Manifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot,
        [Parameter(Mandatory = $true)]
        [object]$Manifest
    )

    $manifestPath = Join-Path $PackageRoot "manifest.json"
    $Manifest |
        ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $positiveRoot = New-TestPackage -Name "positive"
    Invoke-PackageValidation `
        -PackageRoot $positiveRoot `
        -ShouldSucceed $true `
        -ExpectedMessage (
            "Package validation succeeded for Delphi " +
            "$DelphiVersion $expectedPlatform."
        )

    $repairPlan = Read-PackagePlan `
        -PackageRoot $positiveRoot `
        -Mode "Repair"
    if (
        $repairPlan.mode -ne "Repair" -or
        $repairPlan.removeUserData -or
        -not $repairPlan.sharedLoaderPreserved
    ) {
        throw "Repair plan does not preserve shared components and user data."
    }

    $uninstallPlan = Read-PackagePlan `
        -PackageRoot $positiveRoot `
        -Mode "Uninstall"
    if (
        $uninstallPlan.mode -ne "Uninstall" -or
        $uninstallPlan.removeUserData
    ) {
        throw "Default uninstall plan must preserve user data."
    }

    $purgePlan = Read-PackagePlan `
        -PackageRoot $positiveRoot `
        -Mode "Uninstall" `
        -RemoveUserData
    if (-not $purgePlan.removeUserData) {
        throw "Explicit user-data removal is absent from the plan."
    }

    $extraFileRoot = New-TestPackage -Name "extra-file"
    Set-Content `
        -LiteralPath (Join-Path $extraFileRoot "unexpected.txt") `
        -Value "unexpected" `
        -Encoding ASCII
    Invoke-PackageValidation `
        -PackageRoot $extraFileRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "Package contains an unmanifested file"

    $corruptFileRoot = New-TestPackage -Name "corrupt-file"
    Add-Content `
        -LiteralPath (Join-Path $corruptFileRoot "Bpl\RadIA.bpl") `
        -Value "corruption" `
        -Encoding ASCII
    Invoke-PackageValidation `
        -PackageRoot $corruptFileRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "Package size check failed"

    $versionRoot = New-TestPackage -Name "wrong-version"
    $versionManifest = Read-Manifest -PackageRoot $versionRoot
    $versionManifest.delphiVersion = "invalid"
    Write-Manifest -PackageRoot $versionRoot -Manifest $versionManifest
    Invoke-PackageValidation `
        -PackageRoot $versionRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "This package targets Delphi invalid"

    $platformRoot = New-TestPackage -Name "wrong-platform"
    Invoke-PackageValidation `
        -PackageRoot $platformRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "This package targets $expectedPlatform" `
        -UseOppositePlatform

    $dirtySourceRoot = New-TestPackage -Name "dirty-source"
    $dirtySourceManifest = Read-Manifest -PackageRoot $dirtySourceRoot
    $dirtySourceManifest.sourceDirty = $true
    Write-Manifest `
        -PackageRoot $dirtySourceRoot `
        -Manifest $dirtySourceManifest
    Invoke-PackageValidation `
        -PackageRoot $dirtySourceRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "Package source revision evidence is invalid"

    $invalidCommitRoot = New-TestPackage -Name "invalid-commit"
    $invalidCommitManifest = Read-Manifest -PackageRoot $invalidCommitRoot
    $invalidCommitManifest.sourceCommit = "not-a-commit"
    Write-Manifest `
        -PackageRoot $invalidCommitRoot `
        -Manifest $invalidCommitManifest
    Invoke-PackageValidation `
        -PackageRoot $invalidCommitRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "Package source revision evidence is invalid"

    $traversalRoot = New-TestPackage -Name "path-traversal"
    $traversalManifest = Read-Manifest -PackageRoot $traversalRoot
    $traversalManifest.files[0].path = "../outside.bin"
    Write-Manifest -PackageRoot $traversalRoot -Manifest $traversalManifest
    Invoke-PackageValidation `
        -PackageRoot $traversalRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "Package path escapes the package root"

    $duplicateRoot = New-TestPackage -Name "duplicate-path"
    $duplicateManifest = Read-Manifest -PackageRoot $duplicateRoot
    $duplicateManifest.files += $duplicateManifest.files[0]
    Write-Manifest -PackageRoot $duplicateRoot -Manifest $duplicateManifest
    Invoke-PackageValidation `
        -PackageRoot $duplicateRoot `
        -ShouldSucceed $false `
        -ExpectedMessage "Package manifest contains a duplicate path"

    Write-Host (
        "All package validation tests passed for Delphi " +
        "$DelphiVersion $expectedPlatform."
    )
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith(
        $resolvedTemp,
        [StringComparison]::OrdinalIgnoreCase
    ) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
