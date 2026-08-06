param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [Parameter(Mandatory = $true)]
    [string]$DownloadUrl,
    [string]$OutputPath = ".\Output\Channel\stable.json",
    [switch]$AllowUnsignedDevelopment
)

$ErrorActionPreference = "Stop"
$resolvedInstaller = [IO.Path]::GetFullPath($InstallerPath)
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$productVersion = (
    Get-Content -LiteralPath ".\package.json" -Raw |
    ConvertFrom-Json
).version

if (-not (Test-Path -LiteralPath $resolvedInstaller -PathType Leaf)) {
    throw "Visual installer was not found: $resolvedInstaller"
}
if (
    -not $AllowUnsignedDevelopment -and
    -not $DownloadUrl.StartsWith(
        "https://",
        [StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "Production channel download URL must use HTTPS."
}

$signature = Get-AuthenticodeSignature -LiteralPath $resolvedInstaller
if (-not $AllowUnsignedDevelopment -and $signature.Status -ne "Valid") {
    throw (
        "Production channel requires a valid Authenticode signature. " +
        "Actual status: $($signature.Status)."
    )
}

$channel = [PSCustomObject]@{
    schemaVersion = 1
    product = "RadIA"
    channel = if ($AllowUnsignedDevelopment) {
        "development"
    } else {
        "stable"
    }
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    release = [PSCustomObject]@{
        version = $productVersion
        downloadUrl = $DownloadUrl
        fileName = Split-Path -Leaf $resolvedInstaller
        size = (Get-Item -LiteralPath $resolvedInstaller).Length
        sha256 = (
            Get-FileHash -LiteralPath $resolvedInstaller -Algorithm SHA256
        ).Hash
        signature = [PSCustomObject]@{
            status = [string]$signature.Status
            subject = if ($signature.SignerCertificate) {
                $signature.SignerCertificate.Subject
            } else {
                ""
            }
            thumbprint = if ($signature.SignerCertificate) {
                $signature.SignerCertificate.Thumbprint
            } else {
                ""
            }
        }
        targets = @(
            "Delphi 11 Win32",
            "Delphi 12 Win32",
            "Delphi 13 Win32",
            "Delphi 13 IDE64"
        )
    }
}

$outputDirectory = Split-Path -Parent $resolvedOutput
if ($outputDirectory) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}
$channel |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
Write-Host "Release channel created: $resolvedOutput"
