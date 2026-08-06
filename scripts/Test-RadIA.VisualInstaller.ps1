param(
    [string]$InstallerPath = ".\Output\Installer\RadIA-v2.0.0-Setup.exe",
    [string]$EvidencePath = ".\Output\Installer\VisualInstallerEvidence.json",
    [switch]$RequireSignature
)

$ErrorActionPreference = "Stop"
$resolvedInstaller = [IO.Path]::GetFullPath($InstallerPath)
$resolvedEvidence = [IO.Path]::GetFullPath($EvidencePath)
$productVersion = (
    Get-Content -LiteralPath ".\package.json" -Raw |
    ConvertFrom-Json
).version

if (-not (Test-Path -LiteralPath $resolvedInstaller -PathType Leaf)) {
    throw "Visual installer was not found: $resolvedInstaller"
}
if (-not (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf)) {
    throw "Visual installer evidence was not found: $resolvedEvidence"
}

$installer = Get-Item -LiteralPath $resolvedInstaller
$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw |
    ConvertFrom-Json
$hash = (
    Get-FileHash -LiteralPath $resolvedInstaller -Algorithm SHA256
).Hash
$signature = Get-AuthenticodeSignature -LiteralPath $resolvedInstaller

if (
    $evidence.schemaVersion -ne 1 -or
    $evidence.product -ne "RadIA" -or
    $evidence.productVersion -ne $productVersion -or
    $evidence.sourceCommit -notmatch "^[0-9a-f]{40}$"
) {
    throw "Visual installer evidence identity is invalid."
}
if (
    $evidence.fileName -ne $installer.Name -or
    $evidence.size -ne $installer.Length -or
    $evidence.sha256 -ne $hash
) {
    throw "Visual installer evidence does not match the executable."
}
if ($evidence.signatureStatus -ne [string]$signature.Status) {
    throw "Visual installer signature evidence is stale."
}
if ($RequireSignature -and $signature.Status -ne "Valid") {
    throw (
        "A valid Authenticode signature is required. Actual status: " +
        "$($signature.Status)."
    )
}
if ($signature.Status -eq "Valid") {
    if (
        $evidence.signerThumbprint -ne
        $signature.SignerCertificate.Thumbprint
    ) {
        throw "Visual installer signer evidence is invalid."
    }
    if (-not $signature.TimeStamperCertificate) {
        throw "Signed visual installer does not contain a trusted timestamp."
    }
}

Write-Host (
    "Visual installer validation succeeded. Version=$productVersion; " +
    "Signature=$($signature.Status); SHA256=$hash."
)
