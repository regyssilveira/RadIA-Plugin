param(
    [string]$PackagesPath = ".\Output\Packages",
    [string]$OutputPath = ".\Output\Installer",
    [string]$EvidencePath = "",
    [string]$CertificateThumbprint = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"
$productVersion = (
    Get-Content -LiteralPath ".\package.json" -Raw |
    ConvertFrom-Json
).version
$resolvedPackages = [IO.Path]::GetFullPath($PackagesPath)
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$compiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$installerName = "RadIA-v$productVersion-Setup"
$installerPath = Join-Path $resolvedOutput "$installerName.exe"
$sourceCommit = ""
$temporaryRoot = Join-Path (
    [IO.Path]::GetTempPath()
) ("RadIA-VisualInstaller-" + [Guid]::NewGuid().ToString("N"))

$targets = @(
    @{
        Version = "23.0"
        Platform = "Win32"
        Define = "PackageRoot23"
        IDE64 = $false
    },
    @{
        Version = "37.0"
        Platform = "Win32"
        Define = "PackageRoot37Win32"
        IDE64 = $false
    },
    @{
        Version = "37.0"
        Platform = "Win64"
        Define = "PackageRoot37Win64"
        IDE64 = $true
    }
)

function Find-SignTool {
    $roots = Get-ChildItem `
        -LiteralPath "C:\Program Files (x86)\Windows Kits\10\bin" `
        -Directory `
        -ErrorAction Stop |
        Sort-Object Name -Descending
    foreach ($root in $roots) {
        $candidate = Join-Path $root.FullName "x64\signtool.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    throw "Windows SDK SignTool was not found."
}

function Test-Package {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Target,
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $installer = Join-Path $Root "Scripts\Install-RadIA.Package.ps1"
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $installer,
        "-DelphiVersion",
        $Target.Version,
        "-ValidateOnly"
    )
    if ($Target.IDE64) {
        $arguments += "-IDE64"
    }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw (
            "Package validation failed for Delphi " +
            "$($Target.Version) $($Target.Platform)."
        )
    }
}

if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw "Inno Setup 6 compiler was not found: $compiler"
}

try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
    $defines = @(
        "/DProductVersion=$productVersion",
        "/DOutputDirectory=$resolvedOutput",
        "/DOutputBaseFilename=$installerName"
    )
    foreach ($target in $targets) {
        $packageName = (
            "RadIA-v$productVersion-Delphi-$($target.Version)-" +
            "$($target.Platform)-Release.zip"
        )
        $packagePath = Join-Path $resolvedPackages $packageName
        if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
            throw "Release package is missing: $packageName"
        }
        $targetRoot = Join-Path $temporaryRoot (
            "$($target.Version)-$($target.Platform)"
        )
        Expand-Archive `
            -LiteralPath $packagePath `
            -DestinationPath $targetRoot
        Test-Package -Target $target -Root $targetRoot
        $manifest = Get-Content `
            -LiteralPath (Join-Path $targetRoot "manifest.json") `
            -Raw |
            ConvertFrom-Json
        if (
            $manifest.productVersion -ne $productVersion -or
            $manifest.sourceCommit -notmatch "^[0-9a-f]{40}$" -or
            $manifest.sourceDirty -ne $false
        ) {
            throw "Package source provenance is invalid: $packageName"
        }
        if (-not $sourceCommit) {
            $sourceCommit = $manifest.sourceCommit
        } elseif ($sourceCommit -ne $manifest.sourceCommit) {
            throw "Visual installer packages do not share one source commit."
        }
        $defines += "/D$($target.Define)=$targetRoot"
    }

    & $compiler @defines ".\installer\RadIA.iss"
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compilation failed."
    }
    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        throw "Visual installer was not created: $installerPath"
    }

    if ($CertificateThumbprint) {
        $signTool = Find-SignTool
        & $signTool sign `
            /sha1 $CertificateThumbprint.Replace(" ", "") `
            /fd SHA256 `
            /tr $TimestampUrl `
            /td SHA256 `
            $installerPath
        if ($LASTEXITCODE -ne 0) {
            throw "Authenticode signing failed."
        }
        $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
        if ($signature.Status -ne "Valid") {
            throw "Installer signature is not valid: $($signature.Status)"
        }
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
    $evidence = [PSCustomObject]@{
        schemaVersion = 1
        product = "RadIA"
        productVersion = $productVersion
        sourceCommit = $sourceCommit
        fileName = Split-Path -Leaf $installerPath
        size = (Get-Item -LiteralPath $installerPath).Length
        sha256 = (
            Get-FileHash -LiteralPath $installerPath -Algorithm SHA256
        ).Hash
        signatureStatus = [string]$signature.Status
        signerSubject = if ($signature.SignerCertificate) {
            $signature.SignerCertificate.Subject
        } else {
            ""
        }
        signerThumbprint = if ($signature.SignerCertificate) {
            $signature.SignerCertificate.Thumbprint
        } else {
            ""
        }
        timestampSubject = if ($signature.TimeStamperCertificate) {
            $signature.TimeStamperCertificate.Subject
        } else {
            ""
        }
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    }
    $resolvedEvidence = $EvidencePath
    if (-not $resolvedEvidence) {
        $resolvedEvidence = Join-Path (
            $resolvedOutput
        ) "VisualInstallerEvidence.json"
    } else {
        $resolvedEvidence = [IO.Path]::GetFullPath($resolvedEvidence)
    }
    $evidenceDirectory = Split-Path -Parent $resolvedEvidence
    if ($evidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $evidenceDirectory |
            Out-Null
    }
    $evidence |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8
    Write-Host "Visual installer created: $installerPath"
    Write-Host "Signature status: $($signature.Status)"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
