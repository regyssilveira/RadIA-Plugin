param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,
    [string]$OutputPath
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
if ($manifest.schemaVersion -ne 1) {
    throw "Only declarative extension schema version 1 can be packaged."
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

$package = [ordered]@{
    schemaVersion = 1
    id = [string]$manifest.id
    version = [string]$manifest.version
    manifest = $manifestName
    files = @(
        [ordered]@{
            path = $manifestName
            size = $manifestBytes.Length
            sha256 = $hash
        }
    )
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
