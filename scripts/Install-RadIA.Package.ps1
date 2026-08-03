param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("22.0", "23.0", "37.0")]
    [string]$DelphiVersion,
    [switch]$IDE64,
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$packageRoot = [IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestFile = Join-Path $packageRoot "manifest.json"

function Resolve-PackageFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ([IO.Path]::IsPathRooted($RelativePath)) {
        throw "Package path must be relative: $RelativePath"
    }
    $resolvedPath = [IO.Path]::GetFullPath(
        (Join-Path $packageRoot $RelativePath)
    )
    if (-not $resolvedPath.StartsWith(
        $packageRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Package path escapes the package root: $RelativePath"
    }
    return $resolvedPath
}

if (-not (Test-Path -LiteralPath $manifestFile)) {
    throw "Package manifest was not found."
}

$manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.product -ne "RadIA") {
    throw "Package manifest identity is invalid."
}
$platform = "Win32"
if ($IDE64) {
    $platform = "Win64"
}
if ($manifest.delphiVersion -ne $DelphiVersion) {
    throw "This package targets Delphi $($manifest.delphiVersion)."
}
if ($manifest.platform -ne $platform) {
    throw "This package targets $($manifest.platform)."
}

$manifestPaths = @{}
foreach ($file in $manifest.files) {
    $normalizedPath = $file.path.Replace("\", "/")
    if ($manifestPaths.ContainsKey($normalizedPath)) {
        throw "Package manifest contains a duplicate path: $normalizedPath"
    }
    $manifestPaths[$normalizedPath] = $true
    $sourceFile = Resolve-PackageFile -RelativePath $normalizedPath
    if (-not (Test-Path -LiteralPath $sourceFile)) {
        throw "Package file is missing: $normalizedPath"
    }
    $actualSize = (Get-Item -LiteralPath $sourceFile).Length
    if ($actualSize -ne $file.size) {
        throw "Package size check failed: $normalizedPath"
    }
    $actualHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
    if ($actualHash -ne $file.sha256) {
        throw "Package integrity check failed: $normalizedPath"
    }
}

$packageFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File
foreach ($packageFile in $packageFiles) {
    $relativePath = $packageFile.FullName.Substring(
        $packageRoot.Length + 1
    ).Replace("\", "/")
    if ($relativePath -eq "manifest.json") {
        continue
    }
    if (-not $manifestPaths.ContainsKey($relativePath)) {
        throw "Package contains an unmanifested file: $relativePath"
    }
}

$requiredFiles = @(
    "Bpl/RadIA.bpl",
    "Dcp/RadIA.dcp",
    "Bin/RadIA.MCP.Bridge.exe",
    "Redist/WebView2Loader.dll",
    "Scripts/Install-RadIA.Package.ps1",
    "Web/chat.html",
    "Web/chat.js",
    "Web/chat.css"
)
foreach ($requiredFile in $requiredFiles) {
    if (-not $manifestPaths.ContainsKey($requiredFile)) {
        throw "Required package file is absent from the manifest: $requiredFile"
    }
}

if ($ValidateOnly) {
    Write-Host (
        "Package validation succeeded for Delphi " +
        "$DelphiVersion $platform."
    )
    exit 0
}

$rootDirectory = "C:\Program Files (x86)\Embarcadero\Studio\$DelphiVersion"
$bdsRegistry = "HKCU:\Software\Embarcadero\BDS\$DelphiVersion"
if (Test-Path $bdsRegistry) {
    $registeredRoot = (
        Get-ItemProperty `
            -Path $bdsRegistry `
            -Name "RootDir" `
            -ErrorAction SilentlyContinue
    ).RootDir
    if ($registeredRoot -and (Test-Path -LiteralPath $registeredRoot)) {
        $rootDirectory = $registeredRoot
    }
}
$ideBin = Join-Path $rootDirectory "bin"
if ($IDE64) {
    $ideBin = Join-Path $rootDirectory "bin64"
}
if (-not (Test-Path -LiteralPath $ideBin)) {
    throw "Delphi IDE binary directory was not found: $ideBin"
}
if (Get-Process bds -ErrorAction SilentlyContinue) {
    throw "Close all Delphi IDE instances before installing RadIA."
}
$loaderTarget = Join-Path $ideBin "WebView2Loader.dll"
$loaderSource = Resolve-PackageFile "Redist\WebView2Loader.dll"
if (-not (Test-Path -LiteralPath $loaderTarget)) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $administrator =
        [Security.Principal.WindowsBuiltInRole]::Administrator
    if (-not $principal.IsInRole($administrator)) {
        throw (
            "WebView2Loader.dll is absent. Run this installer " +
            "from an elevated PowerShell session."
        )
    }
}

$publicStudio = "C:\Users\Public\Documents\Embarcadero\Studio\$DelphiVersion"
$publicBpl = Join-Path $publicStudio "Bpl"
$publicDcp = Join-Path $publicStudio "Dcp"
$targetBplDirectory = $publicBpl
$targetDcpDirectory = $publicDcp
if ($IDE64) {
    $targetBplDirectory = Join-Path $publicBpl "Win64"
    $targetDcpDirectory = Join-Path $publicDcp "Win64"
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $targetBplDirectory, $targetDcpDirectory |
    Out-Null

Copy-Item `
    -LiteralPath (Resolve-PackageFile "Bpl\RadIA.bpl") `
    -Destination (Join-Path $targetBplDirectory "RadIA.bpl") `
    -Force
Copy-Item `
    -LiteralPath (Resolve-PackageFile "Bin\RadIA.MCP.Bridge.exe") `
    -Destination (Join-Path $targetBplDirectory "RadIA.MCP.Bridge.exe") `
    -Force
Copy-Item `
    -LiteralPath (Resolve-PackageFile "Dcp\RadIA.dcp") `
    -Destination (Join-Path $targetDcpDirectory "RadIA.dcp") `
    -Force

$sourceWeb = Resolve-PackageFile "Web"
$targetWeb = Join-Path $publicBpl "Web"
$resolvedWeb = [IO.Path]::GetFullPath($targetWeb)
$resolvedBpl = [IO.Path]::GetFullPath($publicBpl)
if (-not $resolvedWeb.StartsWith(
    $resolvedBpl + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Unexpected public Web target."
}
if (Test-Path -LiteralPath $resolvedWeb) {
    Remove-Item -LiteralPath $resolvedWeb -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $resolvedWeb | Out-Null
Copy-Item `
    -Path (Join-Path $sourceWeb "*") `
    -Destination $resolvedWeb `
    -Recurse `
    -Force

$userRadIA = Join-Path (
    [Environment]::GetFolderPath("ApplicationData")
) "RadIA"
$userWeb = [IO.Path]::GetFullPath(
    (Join-Path $userRadIA "Web")
)
$resolvedUserRadIA = [IO.Path]::GetFullPath($userRadIA)
if (-not $userWeb.StartsWith(
    $resolvedUserRadIA + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Unexpected user Web target."
}
if (Test-Path -LiteralPath $userWeb) {
    Remove-Item -LiteralPath $userWeb -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $userWeb | Out-Null
Copy-Item `
    -Path (Join-Path $sourceWeb "*") `
    -Destination $userWeb `
    -Recurse `
    -Force

$webViewCache = [IO.Path]::GetFullPath(
    (Join-Path $userRadIA "WebView2")
)
if (-not $webViewCache.StartsWith(
    $resolvedUserRadIA + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Unexpected WebView2 cache target."
}
if (Test-Path -LiteralPath $webViewCache) {
    Remove-Item -LiteralPath $webViewCache -Recurse -Force
}

if (-not (Test-Path -LiteralPath $loaderTarget)) {
    try {
        Copy-Item `
            -LiteralPath $loaderSource `
            -Destination $loaderTarget `
            -Force
    } catch {
        throw (
            "WebView2Loader.dll could not be installed. " +
            "Run this script from an elevated PowerShell session."
        )
    }
}

$registryPath =
    "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\Known Packages"
if ($IDE64) {
    $registryPath = (
        "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\" +
        "Known Packages x64"
    )
}
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
$targetBpl = Join-Path $targetBplDirectory "RadIA.bpl"
New-ItemProperty `
    -Path $registryPath `
    -Name $targetBpl `
    -Value "Rad IA - AI Assistant for Delphi IDE" `
    -PropertyType String `
    -Force |
    Out-Null

Write-Host "RadIA was installed successfully for Delphi $DelphiVersion $platform."
