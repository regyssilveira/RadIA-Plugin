param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [switch]$IDE64,
    [switch]$ValidateOnly,
    [ValidateSet("Install", "Repair", "Uninstall")]
    [string]$Mode = "Install",
    [switch]$RemoveUserData,
    [switch]$PlanOnly
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
if (
    $manifest.sourceCommit -notmatch "^[0-9a-f]{40}$" -or
    $manifest.sourceDirty -ne $false
) {
    throw "Package source revision evidence is invalid."
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
    "Bin/RadIA.Semantic.Engine.exe",
    "Redist/WebView2Loader.dll",
    "Scripts/Install-RadIA.Package.ps1",
    "Scripts/New-RadIA.DeclarativeExtensionPackage.ps1",
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

function Assert-InstalledFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) {
        throw "Installed file is missing: $Target"
    }
    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        throw "Installed file verification failed: $Target"
    }
}

function Resolve-DelphiRootDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $defaultRoot = "C:\Program Files (x86)\Embarcadero\Studio\$Version"
    $registryPaths = @(
        "HKCU:\Software\Embarcadero\BDS\$Version",
        "HKLM:\Software\Embarcadero\BDS\$Version",
        "HKLM:\Software\WOW6432Node\Embarcadero\BDS\$Version"
    )
    foreach ($registryPath in $registryPaths) {
        $registeredRoot = (
            Get-ItemProperty `
                -Path $registryPath `
                -Name "RootDir" `
                -ErrorAction SilentlyContinue
        ).RootDir
        if ($registeredRoot -and (Test-Path -LiteralPath $registeredRoot)) {
            return $registeredRoot
        }
    }
    return $defaultRoot
}

function Test-FilesDiffer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) {
        return $true
    }
    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash
    return $sourceHash -ne $targetHash
}
if ($RemoveUserData -and $Mode -ne "Uninstall") {
    throw "RemoveUserData is available only in Uninstall mode."
}

$rootDirectory = Resolve-DelphiRootDirectory -Version $DelphiVersion
$ideBin = Join-Path $rootDirectory "bin"
if ($IDE64) {
    $ideBin = Join-Path $rootDirectory "bin64"
}
$loaderTarget = Join-Path $ideBin "WebView2Loader.dll"
$loaderSource = Resolve-PackageFile "Redist\WebView2Loader.dll"

$publicStudio = "C:\Users\Public\Documents\Embarcadero\Studio\$DelphiVersion"
$publicBpl = Join-Path $publicStudio "Bpl"
$publicDcp = Join-Path $publicStudio "Dcp"
$targetBplDirectory = $publicBpl
$targetDcpDirectory = $publicDcp
if ($IDE64) {
    $targetBplDirectory = Join-Path $publicBpl "Win64"
    $targetDcpDirectory = Join-Path $publicDcp "Win64"
}

$targetBpl = Join-Path $targetBplDirectory "RadIA.bpl"
$targetBridge = Join-Path $targetBplDirectory "RadIA.MCP.Bridge.exe"
$targetSemanticEngine = Join-Path `
    $targetBplDirectory `
    "RadIA.Semantic.Engine.exe"
$targetExtensionPackager = Join-Path `
    $targetBplDirectory `
    "New-RadIA.DeclarativeExtensionPackage.ps1"
$targetDcp = Join-Path $targetDcpDirectory "RadIA.dcp"
$targetWeb = Join-Path $publicBpl "Web"
$userRadIA = Join-Path (
    [Environment]::GetFolderPath("ApplicationData")
) "RadIA"
$userWeb = Join-Path $userRadIA "Web"
$webViewCache = Join-Path $userRadIA "WebView2"
$registryPath =
    "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\Known Packages"
if ($IDE64) {
    $registryPath = (
        "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\" +
        "Known Packages x64"
    )
}
$plan = [PSCustomObject]@{
    mode = $Mode
    delphiVersion = $DelphiVersion
    platform = $platform
    package = $targetBpl
    bridge = $targetBridge
    semanticEngine = $targetSemanticEngine
    extensionPackager = $targetExtensionPackager
    dcp = $targetDcp
    publicWeb = $targetWeb
    registryPath = $registryPath
    userData = $userRadIA
    removeUserData = $RemoveUserData.IsPresent
    sharedLoaderPreserved = $loaderTarget
}
if ($PlanOnly) {
    $plan | ConvertTo-Json -Depth 3
    exit 0
}

if ($Mode -ne "Uninstall" -and -not (Test-Path -LiteralPath $ideBin)) {
    throw "Delphi IDE binary directory was not found: $ideBin"
}

$runningIDEs = @(Get-Process bds -ErrorAction SilentlyContinue)
$runningIDEPaths = @(
    $runningIDEs |
        ForEach-Object {
            if ($_.Path) {
                $_.Path
            } else {
                "PID $($_.Id)"
            }
        }
)
if ($runningIDEs.Count -gt 0) {
    throw (
        "Close all Delphi IDE instances before changing RadIA. " +
        "Running bds.exe process(es): " +
        ($runningIDEPaths -join "; ")
    )
}

if ($Mode -eq "Uninstall") {
    if (Test-Path -LiteralPath $registryPath) {
        Remove-ItemProperty `
            -LiteralPath $registryPath `
            -Name $targetBpl `
            -ErrorAction SilentlyContinue
    }
    foreach ($targetFile in @(
        $targetBpl,
        $targetBridge,
        $targetSemanticEngine,
        $targetExtensionPackager,
        $targetDcp
    )) {
        if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
            Remove-Item -LiteralPath $targetFile -Force
        }
    }
    $win32Package = Join-Path $publicBpl "RadIA.bpl"
    $win64Package = Join-Path (Join-Path $publicBpl "Win64") "RadIA.bpl"
    if (
        -not (Test-Path -LiteralPath $win32Package) -and
        -not (Test-Path -LiteralPath $win64Package) -and
        (Test-Path -LiteralPath $targetWeb)
    ) {
        Remove-Item -LiteralPath $targetWeb -Recurse -Force
    }
    if ($RemoveUserData -and (Test-Path -LiteralPath $userRadIA)) {
        $resolvedUserData = [IO.Path]::GetFullPath($userRadIA)
        $expectedUserData = [IO.Path]::GetFullPath(
            (Join-Path (
                [Environment]::GetFolderPath("ApplicationData")
            ) "RadIA")
        )
        if (-not $resolvedUserData.Equals(
            $expectedUserData,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Unexpected RadIA user data target."
        }
        Remove-Item -LiteralPath $resolvedUserData -Recurse -Force
    }
    Write-Host (
        "RadIA was uninstalled from Delphi $DelphiVersion $platform. " +
        "User data removed: $($RemoveUserData.IsPresent)."
    )
    exit 0
}

$loaderNeedsUpdate = Test-FilesDiffer `
    -Source $loaderSource `
    -Target $loaderTarget
if ($loaderNeedsUpdate -and $Mode -ne "Uninstall") {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $administrator =
        [Security.Principal.WindowsBuiltInRole]::Administrator
    if (-not $principal.IsInRole($administrator)) {
        throw (
            "WebView2Loader.dll must be installed or updated. Run this installer " +
            "from an elevated PowerShell session."
        )
    }
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
    -LiteralPath (Resolve-PackageFile "Bin\RadIA.Semantic.Engine.exe") `
    -Destination $targetSemanticEngine `
    -Force
Copy-Item `
    -LiteralPath (
        Resolve-PackageFile `
            "Scripts\New-RadIA.DeclarativeExtensionPackage.ps1"
    ) `
    -Destination $targetExtensionPackager `
    -Force
Copy-Item `
    -LiteralPath (Resolve-PackageFile "Dcp\RadIA.dcp") `
    -Destination (Join-Path $targetDcpDirectory "RadIA.dcp") `
    -Force

$sourceWeb = Resolve-PackageFile "Web"
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

if ($loaderNeedsUpdate) {
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

if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
New-ItemProperty `
    -Path $registryPath `
    -Name $targetBpl `
    -Value "Rad IA - AI Assistant for Delphi IDE" `
    -PropertyType String `
    -Force |
    Out-Null
$disabledRegistryPath = (
    "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\Disabled Packages"
)
if ($IDE64) {
    $disabledRegistryPath = (
        "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\" +
        "Disabled Packages x64"
    )
}
if (Test-Path $disabledRegistryPath) {
    Remove-ItemProperty `
        -LiteralPath $disabledRegistryPath `
        -Name $targetBpl `
        -ErrorAction SilentlyContinue
}
$registeredPackageProperties = (
    Get-ItemProperty `
        -LiteralPath $registryPath `
        -Name $targetBpl `
        -ErrorAction Stop
)
$registeredPackage = $registeredPackageProperties.PSObject.Properties[
    $targetBpl
].Value
if ($registeredPackage -ne "Rad IA - AI Assistant for Delphi IDE") {
    throw "Installed package registration verification failed: $targetBpl"
}

Assert-InstalledFile `
    -Source (Resolve-PackageFile "Bpl\RadIA.bpl") `
    -Target $targetBpl
Assert-InstalledFile `
    -Source (Resolve-PackageFile "Bin\RadIA.MCP.Bridge.exe") `
    -Target $targetBridge
Assert-InstalledFile `
    -Source (Resolve-PackageFile "Bin\RadIA.Semantic.Engine.exe") `
    -Target $targetSemanticEngine
Assert-InstalledFile `
    -Source (
        Resolve-PackageFile `
            "Scripts\New-RadIA.DeclarativeExtensionPackage.ps1"
    ) `
    -Target $targetExtensionPackager
Assert-InstalledFile `
    -Source (Resolve-PackageFile "Dcp\RadIA.dcp") `
    -Target $targetDcp
$webManifestFiles = @(
    $manifest.files |
        Where-Object { $_.path -like "Web/*" }
)
foreach ($webManifestFile in $webManifestFiles) {
    $relativeWebPath = $webManifestFile.path.Substring(4).Replace(
        "/",
        [IO.Path]::DirectorySeparatorChar
    )
    Assert-InstalledFile `
        -Source (Join-Path $sourceWeb $relativeWebPath) `
        -Target (Join-Path $resolvedWeb $relativeWebPath)
    Assert-InstalledFile `
        -Source (Join-Path $sourceWeb $relativeWebPath) `
        -Target (Join-Path $userWeb $relativeWebPath)
}
Assert-InstalledFile -Source $loaderSource -Target $loaderTarget

if ($Mode -eq "Repair") {
    Write-Host "RadIA was repaired successfully for Delphi $DelphiVersion $platform."
} else {
    Write-Host "RadIA was installed successfully for Delphi $DelphiVersion $platform."
}
