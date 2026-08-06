param(
    [string]$PackagesPath = ".\Output\Packages",
    [string]$OutputPath = ".\Output\ReleaseEvidence.json"
)

$ErrorActionPreference = "Stop"

$expectedTargets = @(
    @{ delphiVersion = "22.0"; platform = "Win32" },
    @{ delphiVersion = "23.0"; platform = "Win32" },
    @{ delphiVersion = "37.0"; platform = "Win32" },
    @{ delphiVersion = "37.0"; platform = "Win64" }
)
$resolvedPackages = [IO.Path]::GetFullPath($PackagesPath)
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$expectedProductVersion = (
    Get-Content -LiteralPath ".\package.json" -Raw |
    ConvertFrom-Json
).version
$temporaryRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ("RadIA-ReleaseEvidence-" + [Guid]::NewGuid().ToString("N"))
$artifacts = @()
$sourceCommit = ""
$productVersion = ""

function Read-PackageManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageFile,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    Expand-Archive -LiteralPath $PackageFile -DestinationPath $TargetPath
    $manifestPath = Join-Path $TargetPath "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Package manifest is missing: $PackageFile"
    }
    return Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
}

try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    foreach ($target in $expectedTargets) {
        $packageName = (
            "RadIA-v$expectedProductVersion-Delphi-$($target.delphiVersion)-" +
            "$($target.platform)-Release.zip"
        )
        $packagePath = Join-Path $resolvedPackages $packageName
        if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
            throw "Release package is missing: $packageName."
        }
        $package = Get-Item -LiteralPath $packagePath
        $extractPath = Join-Path $temporaryRoot (
            "$($target.delphiVersion)-$($target.platform)"
        )
        $manifest = Read-PackageManifest `
            -PackageFile $package.FullName `
            -TargetPath $extractPath
        $installer = Join-Path $extractPath "Scripts\Install-RadIA.Package.ps1"
        $validationArguments = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $installer,
            "-DelphiVersion",
            $target.delphiVersion,
            "-ValidateOnly"
        )
        if ($target.platform -eq "Win64") {
            $validationArguments += "-IDE64"
        }
        & powershell.exe $validationArguments
        if ($LASTEXITCODE -ne 0) {
            throw "Package integrity validation failed: $($package.Name)."
        }
        if (
            $manifest.delphiVersion -ne $target.delphiVersion -or
            $manifest.platform -ne $target.platform -or
            $manifest.configuration -ne "Release"
        ) {
            throw "Package target metadata does not match $($package.Name)."
        }
        if (
            $manifest.sourceCommit -notmatch "^[0-9a-f]{40}$" -or
            $manifest.sourceDirty -ne $false
        ) {
            throw "Package source evidence is invalid: $($package.Name)."
        }
        if (-not $sourceCommit) {
            $sourceCommit = $manifest.sourceCommit
            $productVersion = $manifest.productVersion
        }
        if (
            $manifest.sourceCommit -ne $sourceCommit -or
            $manifest.productVersion -ne $productVersion
        ) {
            throw "Release packages do not share one commit and version."
        }
        $artifacts += [PSCustomObject]@{
            fileName = $package.Name
            delphiVersion = $manifest.delphiVersion
            platform = $manifest.platform
            size = $package.Length
            sha256 = (
                Get-FileHash -LiteralPath $package.FullName -Algorithm SHA256
            ).Hash
        }
    }
    if (($artifacts.sha256 | Select-Object -Unique).Count -ne 4) {
        throw "Release package hashes must be independently unique."
    }
    $evidence = [PSCustomObject]@{
        schemaVersion = 1
        product = "RadIA"
        productVersion = $productVersion
        sourceCommit = $sourceCommit
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        artifacts = $artifacts
    }
    $outputDirectory = Split-Path -Parent $resolvedOutput
    if ($outputDirectory) {
        New-Item -ItemType Directory -Force -Path $outputDirectory |
            Out-Null
    }
    $evidence |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
    Write-Host "Release evidence created: $resolvedOutput"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
