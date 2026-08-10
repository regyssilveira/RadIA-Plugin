param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,
    [string]$OutputPath,
    [string]$SigningCertificateThumbprint,
    [string]$PublisherId,
    [string]$PublisherName,
    [string]$ResourcesPath
)

$ErrorActionPreference = "Stop"
$resolvedManifest = [IO.Path]::GetFullPath($ManifestPath)
if (-not [IO.File]::Exists($resolvedManifest)) {
    throw "Manifest not found: $resolvedManifest"
}
if ([IO.Path]::GetExtension($resolvedManifest) -ne ".json") {
    throw "Manifest must be a JSON file."
}

$utf8 = [Text.UTF8Encoding]::new($false)
$manifestText = [IO.File]::ReadAllText($resolvedManifest, [Text.Encoding]::UTF8)
$manifest = $manifestText | ConvertFrom-Json
if ($manifest.schemaVersion -notin @(1, 2, 3, 4, 5, 6)) {
    throw "Only declarative extension schema versions 1 through 6 can be packaged."
}
if ([string]$manifest.id -notmatch "^[A-Z][A-Za-z0-9]*$") {
    throw "Extension ID must use alphanumeric PascalCase."
}
if ([string]$manifest.version -notmatch "^\d+\.\d+\.\d+$") {
    throw "Extension version must use major.minor.patch."
}

$manifestName = "$($manifest.id).radia.json"
$manifestBytes = $utf8.GetBytes($manifestText)
if ($manifestBytes.Length -gt 1MB) {
    throw "Manifest exceeds the 1 MiB size limit."
}
$sha256 = [Security.Cryptography.SHA256]::Create()
try {
    $hash = (
        [BitConverter]::ToString(
            $sha256.ComputeHash($manifestBytes)
        ) -replace "-", ""
    ).ToLowerInvariant()
}
finally {
    $sha256.Dispose()
}

$packageFiles = @(
    [ordered]@{
        path = $manifestName
        size = $manifestBytes.Length
        sha256 = $hash
        sourcePath = $resolvedManifest
    }
)
$totalContentBytes = $manifestBytes.Length
if (-not [string]::IsNullOrWhiteSpace($ResourcesPath)) {
    $resolvedResources = [IO.Path]::GetFullPath($ResourcesPath)
    if (-not [IO.Directory]::Exists($resolvedResources)) {
        throw "Resources directory not found: $resolvedResources"
    }
    $resourceRoot = $resolvedResources.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $resourceFiles = @(
        Get-ChildItem -LiteralPath $resourceRoot -Recurse -File |
            Sort-Object FullName
    )
    foreach ($resourceFile in $resourceFiles) {
        if (($resourceFile.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Resource reparse points are not allowed: $($resourceFile.FullName)"
        }
        $relativePath = $resourceFile.FullName.Substring(
            $resourceRoot.Length
        ).TrimStart('\', '/').Replace('\', '/')
        if ($relativePath -notmatch '^(references|templates|knowledge|assets)/') {
            throw "Resource must be inside references, templates, knowledge, or assets: $relativePath"
        }
        if (
            $relativePath.Length -gt 240 -or
            $relativePath -match '(^|/)\.\.?(/|$)' -or
            $relativePath.Contains(':')
        ) {
            throw "Unsafe resource path: $relativePath"
        }
        if ($resourceFile.Length -gt 1MB) {
            throw "Resource exceeds the 1 MiB size limit: $relativePath"
        }
        $resourceHash = (
            Get-FileHash -LiteralPath $resourceFile.FullName -Algorithm SHA256
        ).Hash.ToLowerInvariant()
        $packageFiles += [ordered]@{
            path = $relativePath
            size = $resourceFile.Length
            sha256 = $resourceHash
            sourcePath = $resourceFile.FullName
        }
        $totalContentBytes += $resourceFile.Length
    }
}
if ($packageFiles.Count -gt 129) {
    throw "A package supports at most 128 resources plus its manifest."
}
if ($totalContentBytes -gt 16MB) {
    throw "Package content exceeds the 16 MiB total size limit."
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDirectory = [IO.Path]::GetDirectoryName($resolvedManifest)
    $OutputPath = [IO.Path]::Combine(
        $outputDirectory,
        "$($manifest.id)-$($manifest.version).radiaext"
    )
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
if ([IO.Path]::GetExtension($resolvedOutput) -ne ".radiaext") {
    throw "Output file must use the .radiaext extension."
}
$resolvedOutputDirectory = [IO.Path]::GetDirectoryName($resolvedOutput)
[IO.Directory]::CreateDirectory($resolvedOutputDirectory) | Out-Null

$hasResources = $packageFiles.Count -gt 1
$packageSchemaVersion = if ($hasResources) { 3 } else { 1 }
$publisher = $null
if (-not [string]::IsNullOrWhiteSpace($SigningCertificateThumbprint)) {
    if (-not $hasResources) {
        $packageSchemaVersion = 2
    }
    if ($PublisherId -notmatch "^[A-Za-z0-9][A-Za-z0-9.-]{1,63}$") {
        throw "PublisherId must contain 2-64 letters, digits, dots, or hyphens."
    }
    if (
        [string]::IsNullOrWhiteSpace($PublisherName) -or
        $PublisherName.Length -gt 100
    ) {
        throw "PublisherName must contain 1-100 characters."
    }
    $normalizedThumbprint = $SigningCertificateThumbprint -replace "\s", ""
    $certificatePath = "Cert:\CurrentUser\My\$normalizedThumbprint"
    $certificate = Get-Item -LiteralPath $certificatePath -ErrorAction Stop
    if (-not $certificate.HasPrivateKey) {
        throw "The signing certificate does not have a private key."
    }
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey(
        $certificate
    )
    if ($null -eq $rsa) {
        throw "The signing certificate does not contain an RSA key."
    }
    try {
        if ($rsa.KeySize -lt 2048) {
            throw "The signing certificate must use RSA with at least 2048 bits."
        }
        $parameters = $rsa.ExportParameters($false)
        $modulus = [Convert]::ToBase64String($parameters.Modulus)
        $exponent = [Convert]::ToBase64String($parameters.Exponent)
        $keyMaterial = "$modulus`:$exponent"
        $keyMaterialBytes = $utf8.GetBytes($keyMaterial)
        $fingerprintHash = [Security.Cryptography.SHA256]::Create()
        try {
            $fingerprint = (
                [BitConverter]::ToString(
                    $fingerprintHash.ComputeHash($keyMaterialBytes)
                ) -replace "-", ""
            ).ToLowerInvariant()
        }
        finally {
            $fingerprintHash.Dispose()
        }
        $signatureLines = @(
                "schemaVersion=$packageSchemaVersion",
                "id=$([string]$manifest.id)",
                "version=$([string]$manifest.version)",
                "manifest=$manifestName",
                "size=$($manifestBytes.Length)",
                "sha256=$hash",
                "publisherId=$PublisherId",
                "publisherName=$PublisherName",
                "modulus=$modulus",
                "exponent=$exponent"
        )
        if ($hasResources) {
            foreach ($packageFile in $packageFiles) {
                $signatureLines += (
                    "file=$($packageFile.path)|$($packageFile.size)|" +
                    "$($packageFile.sha256)"
                )
            }
        }
        $signaturePayload = [string]::Join("`n", $signatureLines)
        $signature = [Convert]::ToBase64String(
            $rsa.SignData(
                $utf8.GetBytes($signaturePayload),
                [Security.Cryptography.HashAlgorithmName]::SHA256,
                [Security.Cryptography.RSASignaturePadding]::Pkcs1
            )
        )
        $publisher = [ordered]@{
            algorithm = "RSA-SHA256"
            id = $PublisherId
            name = $PublisherName
            modulus = $modulus
            exponent = $exponent
            signature = $signature
        }
    }
    finally {
        $rsa.Dispose()
    }
}
elseif (
    -not [string]::IsNullOrWhiteSpace($PublisherId) -or
    -not [string]::IsNullOrWhiteSpace($PublisherName)
) {
    throw "Publisher metadata requires SigningCertificateThumbprint."
}

$package = [ordered]@{
    schemaVersion = $packageSchemaVersion
    id = [string]$manifest.id
    version = [string]$manifest.version
    manifest = $manifestName
    files = @($packageFiles | ForEach-Object {
        [ordered]@{
            path = $_.path
            size = $_.size
            sha256 = $_.sha256
        }
    })
}
if ($null -ne $publisher) {
    $package.publisher = $publisher
}

$temporaryDirectory = [IO.Path]::Combine(
    [IO.Path]::GetTempPath(),
    "RadIA-ExtensionPackage-" + [Guid]::NewGuid().ToString("N")
)
[IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
try {
    [IO.File]::WriteAllBytes(
        [IO.Path]::Combine($temporaryDirectory, $manifestName),
        $manifestBytes
    )
    foreach ($packageFile in $packageFiles | Select-Object -Skip 1) {
        $destination = [IO.Path]::Combine(
            $temporaryDirectory,
            $packageFile.path.Replace('/', [IO.Path]::DirectorySeparatorChar)
        )
        [IO.Directory]::CreateDirectory(
            [IO.Path]::GetDirectoryName($destination)
        ) | Out-Null
        [IO.File]::Copy($packageFile.sourcePath, $destination, $true)
    }
    $metadataBytes = $utf8.GetBytes(
        ($package | ConvertTo-Json -Depth 5)
    )
    [IO.File]::WriteAllBytes(
        [IO.Path]::Combine($temporaryDirectory, "package.json"),
        $metadataBytes
    )
    if ([IO.File]::Exists($resolvedOutput)) {
        [IO.File]::Delete($resolvedOutput)
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory(
        $temporaryDirectory,
        $resolvedOutput,
        [IO.Compression.CompressionLevel]::Optimal,
        $false
    )
}
finally {
    if ([IO.Directory]::Exists($temporaryDirectory)) {
        [IO.Directory]::Delete($temporaryDirectory, $true)
    }
}

Write-Host "Extension package created: $resolvedOutput" -ForegroundColor Green
Write-Host "Manifest SHA-256: $hash" -ForegroundColor Green
if ($null -ne $publisher) {
    Write-Host "Publisher fingerprint: $fingerprint" -ForegroundColor Green
}
else {
    Write-Warning "Package is unsigned and provides integrity only."
}
