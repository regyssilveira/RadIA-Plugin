param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("22.0", "23.0", "37.0")]
    [string]$DelphiVersion,
    [ValidateRange(1, 50)]
    [int]$Cycles = 10,
    [ValidateRange(30, 1800)]
    [int]$StartupTimeoutSeconds = 180,
    [switch]$IDE64,
    [switch]$SkipPackageHashCheck,
    [switch]$ExerciseDocking,
    [switch]$ExerciseInlineCompletion,
    [switch]$ExercisePackageLifecycle,
    [string]$UpgradeFromPackagePath = "",
    [string]$EvidencePath = "",
    [string]$InlineCompletionEvidencePath = ""
)

if ($EvidencePath -and $SkipPackageHashCheck) {
    throw (
        "Evidence output requires package provenance validation. " +
        "Remove -SkipPackageHashCheck."
    )
}
if ($ExercisePackageLifecycle -and -not $EvidencePath) {
    throw (
        "Package lifecycle validation requires -EvidencePath so every " +
        "cycle is bound to a proven release package."
    )
}
if ($InlineCompletionEvidencePath -and -not $ExerciseInlineCompletion) {
    throw (
        "Inline completion evidence requires " +
        "-ExerciseInlineCompletion."
    )
}
if ($UpgradeFromPackagePath -and -not $ExercisePackageLifecycle) {
    throw (
        "Cross-version upgrade validation requires " +
        "-ExercisePackageLifecycle."
    )
}

function Get-RadIAProcessDescendants {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ParentProcessId,
        [Parameter(Mandatory = $true)]
        [DateTime]$ParentStartedAt
    )

    $earliestChildStart = $ParentStartedAt.AddSeconds(-1)
    $processes = @(
        Get-CimInstance Win32_Process |
            Where-Object {
                $_.CreationDate -ge $earliestChildStart
            } |
            Select-Object ProcessId, ParentProcessId, Name, CreationDate
    )
    $pendingParents = [Collections.Generic.Queue[int]]::new()
    $pendingParents.Enqueue($ParentProcessId)
    $descendants = @()
    while ($pendingParents.Count -gt 0) {
        $currentParent = $pendingParents.Dequeue()
        $children = @(
            $processes |
                Where-Object {
                    $_.ParentProcessId -eq $currentParent
                }
        )
        foreach ($child in $children) {
            $descendants += $child
            $pendingParents.Enqueue([int]$child.ProcessId)
        }
    }
    return $descendants
}

function Get-RadIATargetIDEProcesses {
    param(
        [Parameter(Mandatory)]
        [string]$ExecutablePath
    )

    return @(
        Get-Process bds -ErrorAction SilentlyContinue |
            Where-Object {
                try {
                    [IO.Path]::GetFullPath($_.Path).Equals(
                        [IO.Path]::GetFullPath($ExecutablePath),
                        [StringComparison]::OrdinalIgnoreCase
                    )
                } catch {
                    $false
                }
            }
    )
}

function Invoke-RadIAPackageCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Install", "Repair", "Uninstall")]
        [string]$Mode
    )

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $InstallerPath,
        "-DelphiVersion",
        $script:DelphiVersion,
        "-Mode",
        $Mode
    )
    if ($script:IDE64) {
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
    if ($exitCode -ne 0) {
        throw (
            "Package $Mode failed for Delphi " +
            "$($script:DelphiVersion) $script:platform. Output: $output"
        )
    }
}

function Invoke-RadIALegacyPackageInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath
    )

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $InstallerPath,
        "-DelphiVersion",
        $script:DelphiVersion
    )
    if ($script:IDE64) {
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
    if ($exitCode -ne 0) {
        throw (
            "Legacy package installation failed for Delphi " +
            "$($script:DelphiVersion) $script:platform. Output: $output"
        )
    }
}

function Get-RadIAUpgradePackageEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath
    )

    $resolvedPackage = [IO.Path]::GetFullPath($PackagePath)
    if (-not (Test-Path -LiteralPath $resolvedPackage -PathType Leaf)) {
        throw "Upgrade source package was not found: $resolvedPackage"
    }
    $packageRoot = Join-Path (
        [IO.Path]::GetTempPath()
    ) ("RadIA-IDESmoke-UpgradeEvidence-" + [Guid]::NewGuid().ToString("N"))
    try {
        Expand-Archive `
            -LiteralPath $resolvedPackage `
            -DestinationPath $packageRoot
        $manifestPath = Join-Path $packageRoot "manifest.json"
        $manifest = Get-Content `
            -LiteralPath $manifestPath `
            -Raw |
            ConvertFrom-Json
        $installer = Join-Path `
            $packageRoot `
            "scripts\Install-RadIA.Package.ps1"
        $arguments = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $installer,
            "-DelphiVersion",
            $script:DelphiVersion,
            "-ValidateOnly"
        )
        if ($script:IDE64) {
            $arguments += "-IDE64"
        }
        $output = & powershell.exe @arguments 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "Upgrade source validation failed. Output: $output"
        }
        if (
            $manifest.product -ne "RadIA" -or
            -not $manifest.productVersion -or
            $manifest.productVersion -eq $script:expectedVersion
        ) {
            throw "Upgrade source must be a different valid RadIA version."
        }
        return [pscustomobject]@{
            Path = $resolvedPackage
            Version = [string]$manifest.productVersion
            Sha256 = (
                Get-FileHash `
                    -LiteralPath $resolvedPackage `
                    -Algorithm SHA256
            ).Hash
        }
    } finally {
        if (Test-Path -LiteralPath $packageRoot) {
            Remove-Item -LiteralPath $packageRoot -Recurse -Force
        }
    }
}

function Invoke-RadIAPackageLifecycle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,
        [string]$UpgradePackagePath = ""
    )

    $packageRoot = Join-Path (
        [IO.Path]::GetTempPath()
    ) ("RadIA-IDESmoke-Lifecycle-" + [Guid]::NewGuid().ToString("N"))
    $upgradeRoot = ""
    try {
        Expand-Archive `
            -LiteralPath $PackagePath `
            -DestinationPath $packageRoot
        $installer = Join-Path `
            $packageRoot `
            "scripts\Install-RadIA.Package.ps1"
        Invoke-RadIAPackageCommand `
            -InstallerPath $installer `
            -Mode "Uninstall"
        if ($UpgradePackagePath) {
            $upgradeRoot = Join-Path (
                [IO.Path]::GetTempPath()
            ) (
                "RadIA-IDESmoke-UpgradeSource-" +
                [Guid]::NewGuid().ToString("N")
            )
            Expand-Archive `
                -LiteralPath $UpgradePackagePath `
                -DestinationPath $upgradeRoot
            Invoke-RadIALegacyPackageInstall `
                -InstallerPath (
                    Join-Path `
                        $upgradeRoot `
                        "scripts\Install-RadIA.Package.ps1"
                )
        }
        Invoke-RadIAPackageCommand `
            -InstallerPath $installer `
            -Mode "Install"
        Invoke-RadIAPackageCommand `
            -InstallerPath $installer `
            -Mode "Repair"
    } finally {
        if ($upgradeRoot -and (Test-Path -LiteralPath $upgradeRoot)) {
            Remove-Item -LiteralPath $upgradeRoot -Recurse -Force
        }
        if (Test-Path -LiteralPath $packageRoot) {
            Remove-Item -LiteralPath $packageRoot -Recurse -Force
        }
    }
}

$ErrorActionPreference = "Stop"

if ($ExerciseDocking) {
    if ($Cycles -lt 2) {
        throw "Docking validation requires at least two IDE cycles."
    }
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class RadIADockingSmokeNative
{
    public delegate bool EnumCallback(IntPtr handle, IntPtr parameter);

    [StructLayout(LayoutKind.Sequential)]
    public struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(
        EnumCallback callback,
        IntPtr parameter
    );

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(
        IntPtr parent,
        EnumCallback callback,
        IntPtr parameter
    );

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr handle,
        out uint processId
    );

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(
        IntPtr handle,
        out Rect rectangle
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr GetProp(
        IntPtr handle,
        string propertyName
    );

    public static IntPtr FindDockWindow(int processId)
    {
        IntPtr result = IntPtr.Zero;
        EnumCallback callback = delegate(IntPtr handle, IntPtr parameter)
        {
            uint ownerProcessId;
            GetWindowThreadProcessId(handle, out ownerProcessId);
            if (ownerProcessId == processId &&
                GetProp(handle, "RadIADockableForm") != IntPtr.Zero)
            {
                result = handle;
                return false;
            }
            return true;
        };
        EnumWindows(callback, IntPtr.Zero);
        if (result == IntPtr.Zero)
        {
            EnumWindows(
                delegate(IntPtr handle, IntPtr parameter)
                {
                    uint ownerProcessId;
                    GetWindowThreadProcessId(handle, out ownerProcessId);
                    if (ownerProcessId == processId)
                    {
                        EnumChildWindows(handle, callback, IntPtr.Zero);
                    }
                    return result == IntPtr.Zero;
                },
                IntPtr.Zero
            );
        }
        return result;
    }

}
"@
}

function Get-RadIADockInfo {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$Process
    )

    $handle = [RadIADockingSmokeNative]::FindDockWindow($Process.Id)
    if ($handle -eq [IntPtr]::Zero) {
        return $null
    }
    $rectangle = New-Object RadIADockingSmokeNative+Rect
    if (-not [RadIADockingSmokeNative]::GetWindowRect(
        $handle,
        [ref]$rectangle
    )) {
        return $null
    }
    return [pscustomobject]@{
        Handle = $handle
        Left = $rectangle.Left
        Top = $rectangle.Top
        Right = $rectangle.Right
        Bottom = $rectangle.Bottom
        Width = $rectangle.Right - $rectangle.Left
        Height = $rectangle.Bottom - $rectangle.Top
    }
}

function Wait-RadIADockInfo {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$Process,
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $dockInfo = Get-RadIADockInfo -Process $Process
        if ($dockInfo) {
            return $dockInfo
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "The RadIA native dockable form did not open."
}

function Wait-RadIAInlineCompletionDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $preparedPattern = (
        "Ghost text prepared: lines=2, file=$FileName"
    )
    $paintedPattern = (
        "Ghost text painted: lines=2, file=$FileName"
    )
    $paintDeadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $logContent = ""
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $logContent = Get-Content -LiteralPath $LogPath -Raw
        }
        $prepared = $logContent.Contains($preparedPattern)
        $painted = $logContent.Contains($paintedPattern)
        if (-not ($prepared -and $painted)) {
            Start-Sleep -Milliseconds 100
        }
    } while (
        -not ($prepared -and $painted) -and
        [DateTime]::UtcNow -lt $paintDeadline
    )
    if (-not $prepared) {
        throw "The local inline suggestion was not prepared."
    }
    if (-not $painted) {
        throw "The Ghost Text overlay did not reach the OTA paint cycle."
    }
    return [pscustomobject]@{
        Prepared = $true
        Painted = $true
        LineCount = 2
        FileName = $FileName
    }
}

function Restore-RadIADockingVisibility {
    if (-not $script:ExerciseDocking) {
        return
    }
    if ($script:DockingHadWindowVisible) {
        Set-ItemProperty `
            -LiteralPath $script:DockingRegistryPath `
            -Name "WindowVisible" `
            -Value $script:DockingOriginalWindowVisible
    } else {
        Remove-ItemProperty `
            -LiteralPath $script:DockingRegistryPath `
            -Name "WindowVisible" `
            -ErrorAction SilentlyContinue
    }
    if (-not $script:DockingHadRegistryKey) {
        Remove-Item `
            -LiteralPath $script:DockingRegistryPath `
            -ErrorAction SilentlyContinue
    }
}

function Restore-RadIAInlineCompletionLogSettings {
    if (-not $script:InlineLogSettingsInitialized) {
        return
    }
    if ($script:InlineLogHadEnabled) {
        Set-ItemProperty `
            -LiteralPath $script:InlineLogRegistryPath `
            -Name "LogEnabled" `
            -Value $script:InlineLogOriginalEnabled
    } else {
        Remove-ItemProperty `
            -LiteralPath $script:InlineLogRegistryPath `
            -Name "LogEnabled" `
            -ErrorAction SilentlyContinue
    }
    if ($script:InlineLogHadPath) {
        Set-ItemProperty `
            -LiteralPath $script:InlineLogRegistryPath `
            -Name "LogPath" `
            -Value $script:InlineLogOriginalPath
    } else {
        Remove-ItemProperty `
            -LiteralPath $script:InlineLogRegistryPath `
            -Name "LogPath" `
            -ErrorAction SilentlyContinue
    }
    if (-not $script:InlineLogHadRegistryKey) {
        Remove-Item `
            -LiteralPath $script:InlineLogRegistryPath `
            -ErrorAction SilentlyContinue
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$versionUnitPath = Join-Path `
    $repositoryRoot `
    "Source\Core\RadIA.Core.Version.pas"
$versionSource = Get-Content `
    -LiteralPath $versionUnitPath `
    -Raw `
    -Encoding utf8
$versionMatch = [regex]::Match(
    $versionSource,
    "CRadIAVersion\s*=\s*'([^']+)';"
)
if (-not $versionMatch.Success) {
    throw "RadIA version constant was not found: $versionUnitPath"
}
$expectedVersion = $versionMatch.Groups[1].Value
$toolManifestPath = Join-Path $repositoryRoot "docs\runtime_tools.json"
$toolManifest = Get-Content -LiteralPath $toolManifestPath -Raw -Encoding utf8 |
    ConvertFrom-Json
$expectedToolNames = @(
    $toolManifest.groups |
        ForEach-Object { $_.tools } |
        Sort-Object -Unique
)
$platform = "Win32"
$binName = "bin"
$shutdownTimeoutMs = 30000
$releasePackageHash = ""
$releasePackageName = ""
$releaseSourceCommit = ""
$upgradePackageEvidence = $null
$upgradePackagePath = ""
$upgradeFromVersion = ""
$upgradeFromPackageSha256 = ""
$inlineSmokeUnitPath = ""
$inlineSmokeLogPath = ""
$script:InlineLogSettingsInitialized = $false

trap {
    if (Get-Command `
        Restore-RadIADockingVisibility `
        -ErrorAction SilentlyContinue) {
        Restore-RadIADockingVisibility
    }
    if (Get-Command `
        Restore-RadIAInlineCompletionLogSettings `
        -ErrorAction SilentlyContinue) {
        Restore-RadIAInlineCompletionLogSettings
    }
    Write-Error $_
    exit 1
}

if ($ExerciseDocking) {
    $script:DockingRegistryPath = (
        "HKCU:\Software\Embarcadero\BDS\" +
        "$DelphiVersion\RadIA"
    )
    $script:DockingHadRegistryKey = Test-Path `
        -LiteralPath $script:DockingRegistryPath
    if (-not $script:DockingHadRegistryKey) {
        New-Item `
            -Path $script:DockingRegistryPath `
            -Force |
            Out-Null
    }
    $dockProperties = Get-ItemProperty `
        -LiteralPath $script:DockingRegistryPath
    $dockWindowVisible = $dockProperties.PSObject.Properties[
        "WindowVisible"
    ]
    $script:DockingHadWindowVisible = $null -ne $dockWindowVisible
    $script:DockingOriginalWindowVisible = $null
    if ($script:DockingHadWindowVisible) {
        $script:DockingOriginalWindowVisible = $dockWindowVisible.Value
    }
    New-ItemProperty `
        -LiteralPath $script:DockingRegistryPath `
        -Name "WindowVisible" `
        -PropertyType DWord `
        -Value 1 `
        -Force |
        Out-Null
}
if ($IDE64) {
    $platform = "Win64"
    $binName = "bin64"
    $shutdownTimeoutMs = 60000
}
if ($ExerciseInlineCompletion) {
    $script:InlineLogRegistryPath = (
        "HKCU:\Software\Embarcadero\BDS\" +
        "$DelphiVersion\RadIA"
    )
    $script:InlineLogHadRegistryKey = Test-Path `
        -LiteralPath $script:InlineLogRegistryPath
    if (-not $script:InlineLogHadRegistryKey) {
        New-Item `
            -Path $script:InlineLogRegistryPath `
            -Force |
            Out-Null
    }
    $inlineLogProperties = Get-ItemProperty `
        -LiteralPath $script:InlineLogRegistryPath
    $inlineLogEnabled = $inlineLogProperties.PSObject.Properties[
        "LogEnabled"
    ]
    $inlineLogPath = $inlineLogProperties.PSObject.Properties[
        "LogPath"
    ]
    $script:InlineLogHadEnabled = $null -ne $inlineLogEnabled
    $script:InlineLogHadPath = $null -ne $inlineLogPath
    $script:InlineLogOriginalEnabled = $null
    $script:InlineLogOriginalPath = $null
    if ($script:InlineLogHadEnabled) {
        $script:InlineLogOriginalEnabled = $inlineLogEnabled.Value
    }
    if ($script:InlineLogHadPath) {
        $script:InlineLogOriginalPath = $inlineLogPath.Value
    }
    $inlineSmokeRoot = Join-Path (
        "$repositoryRoot\Output\Validation\InlineCompletionSmoke"
    ) (
        "$DelphiVersion-$platform-" +
        [Guid]::NewGuid().ToString("N")
    )
    $inlineSmokeLogDirectory = Join-Path $inlineSmokeRoot "Logs"
    New-Item `
        -ItemType Directory `
        -Path $inlineSmokeLogDirectory `
        -Force |
        Out-Null
    $inlineSmokeLogPath = Join-Path `
        $inlineSmokeLogDirectory `
        "radia.log"
    $inlineSmokeUnitPath = Join-Path `
        $repositoryRoot `
        "Tests\Source\RadIA.Tests.TextNormalizer.pas"
    if (-not (Test-Path -LiteralPath $inlineSmokeUnitPath -PathType Leaf)) {
        throw "Inline completion smoke sources were not found."
    }
    New-ItemProperty `
        -LiteralPath $script:InlineLogRegistryPath `
        -Name "LogEnabled" `
        -PropertyType DWord `
        -Value 1 `
        -Force |
        Out-Null
    New-ItemProperty `
        -LiteralPath $script:InlineLogRegistryPath `
        -Name "LogPath" `
        -PropertyType String `
        -Value $inlineSmokeLogDirectory `
        -Force |
        Out-Null
    $script:InlineLogSettingsInitialized = $true
}

$bdsRegistry = "HKCU:\Software\Embarcadero\BDS\$DelphiVersion"
$rootDirectory = (
    Get-ItemProperty `
        -Path $bdsRegistry `
        -Name "RootDir" `
        -ErrorAction Stop
).RootDir
$bdsPath = Join-Path $rootDirectory "$binName\bds.exe"
if (-not (Test-Path -LiteralPath $bdsPath -PathType Leaf)) {
    throw "Delphi executable was not found: $bdsPath"
}

$publicBpl = Join-Path (
    "C:\Users\Public\Documents\Embarcadero\Studio\$DelphiVersion\Bpl"
) $(if ($IDE64) { "Win64" } else { "" })
$bridgePath = Join-Path $publicBpl "RadIA.MCP.Bridge.exe"
$radIABpl = Join-Path $publicBpl "RadIA.bpl"
if (-not (Test-Path -LiteralPath $bridgePath -PathType Leaf)) {
    throw "Installed MCP bridge was not found: $bridgePath"
}
if (-not (Test-Path -LiteralPath $radIABpl -PathType Leaf)) {
    throw "Installed RadIA package was not found: $radIABpl"
}
$installedPackageHash = (
    Get-FileHash -LiteralPath $radIABpl -Algorithm SHA256
).Hash
if (-not $SkipPackageHashCheck) {
    if (-not $EvidencePath) {
        $builtPackagePath = Join-Path (
            "$repositoryRoot\Output\$DelphiVersion\bpl\$platform"
        ) "RadIA.bpl"
        if (-not (Test-Path -LiteralPath $builtPackagePath -PathType Leaf)) {
            throw "Built RadIA package was not found: $builtPackagePath"
        }
        $builtPackageHash = (
            Get-FileHash -LiteralPath $builtPackagePath -Algorithm SHA256
        ).Hash
        if ($installedPackageHash -ne $builtPackageHash) {
            throw (
                "Installed RadIA package does not match the current build. " +
                "Close Delphi and reinstall before running the IDE smoke."
            )
        }
    } else {
        $releaseEvidencePath = Join-Path (
            $repositoryRoot
        ) "docs\release_evidence_$expectedVersion.json"
        if (-not (Test-Path -LiteralPath $releaseEvidencePath -PathType Leaf)) {
            throw "Release evidence was not found: $releaseEvidencePath"
        }
        $releaseEvidence = Get-Content `
            -LiteralPath $releaseEvidencePath `
            -Raw |
            ConvertFrom-Json
        $releaseArtifact = @(
            $releaseEvidence.artifacts |
                Where-Object {
                    $_.delphiVersion -eq $DelphiVersion -and
                    $_.platform -eq $platform
                }
        )
        if ($releaseArtifact.Count -ne 1) {
            throw "Release evidence does not contain exactly one target artifact."
        }
        $releasePackageName = $releaseArtifact[0].fileName
        $releasePackagePath = Join-Path (
            "$repositoryRoot\Output\Packages"
        ) $releasePackageName
        if (-not (Test-Path -LiteralPath $releasePackagePath -PathType Leaf)) {
            throw "Proven release package was not found: $releasePackagePath"
        }
        $releasePackageHash = (
            Get-FileHash -LiteralPath $releasePackagePath -Algorithm SHA256
        ).Hash
        if ($releasePackageHash -ne $releaseArtifact[0].sha256) {
            throw "Release package hash does not match published evidence."
        }
        $releaseExtractPath = Join-Path (
            [IO.Path]::GetTempPath()
        ) ("RadIA-IDESmoke-Provenance-" + [Guid]::NewGuid().ToString("N"))
        try {
            Expand-Archive `
                -LiteralPath $releasePackagePath `
                -DestinationPath $releaseExtractPath
            $releaseManifest = Get-Content `
                -LiteralPath (Join-Path $releaseExtractPath "manifest.json") `
                -Raw |
                ConvertFrom-Json
            $releaseBplEntry = @(
                $releaseManifest.files |
                    Where-Object { $_.path -eq "Bpl/RadIA.bpl" }
            )
            if ($releaseBplEntry.Count -ne 1) {
                throw "Release manifest does not contain exactly one RadIA BPL."
            }
            if (
                $releaseManifest.sourceCommit -ne $releaseEvidence.sourceCommit -or
                $releaseManifest.sourceDirty -ne $false
            ) {
                throw "Release package source does not match published evidence."
            }
            $releaseBplHash = (
                Get-FileHash `
                    -LiteralPath (Join-Path $releaseExtractPath "Bpl\RadIA.bpl") `
                    -Algorithm SHA256
            ).Hash
            if (
                $releaseBplHash -ne $releaseBplEntry[0].sha256 -or
                $installedPackageHash -ne $releaseBplHash
            ) {
                throw "Installed RadIA BPL does not match the proven release package."
            }
            $releaseSourceCommit = $releaseManifest.sourceCommit
        } finally {
            if (Test-Path -LiteralPath $releaseExtractPath) {
                Remove-Item -LiteralPath $releaseExtractPath -Recurse -Force
            }
        }
    }
}
$targetProcesses = @(Get-RadIATargetIDEProcesses -ExecutablePath $bdsPath)
if ($targetProcesses.Count -gt 0) {
    throw "Close all instances of the target Delphi IDE: $bdsPath"
}
if ($UpgradeFromPackagePath) {
    $script:expectedVersion = $expectedVersion
    $upgradePackageEvidence = Get-RadIAUpgradePackageEvidence `
        -PackagePath $UpgradeFromPackagePath
    $upgradePackagePath = $upgradePackageEvidence.Path
    $upgradeFromVersion = $upgradePackageEvidence.Version
    $upgradeFromPackageSha256 = $upgradePackageEvidence.Sha256
}

$results = @()
$dockedGeometry = $null
for ($cycle = 1; $cycle -le $Cycles; $cycle++) {
    $startedAt = [DateTime]::UtcNow
    $packageLifecycleSeconds = 0
    $packageLifecycleModes = @()
    if ($ExercisePackageLifecycle) {
        if ($upgradePackageEvidence) {
            $packageLifecycleModes = @(
                "Uninstall",
                "InstallPreviousVersion",
                "UpgradeToCurrentVersion",
                "Repair"
            )
        } else {
            $packageLifecycleModes = @(
                "Uninstall",
                "Install",
                "Repair"
            )
        }
        $packageLifecycleStartedAt = [DateTime]::UtcNow
        Invoke-RadIAPackageLifecycle `
            -PackagePath $releasePackagePath `
            -UpgradePackagePath $upgradePackagePath
        $packageLifecycleSeconds = [Math]::Round(
            (
                [DateTime]::UtcNow -
                $packageLifecycleStartedAt
            ).TotalSeconds,
            2
        )
    }
    $launchArguments = @()
    if ($ExerciseInlineCompletion) {
        $launchArguments = @($inlineSmokeUnitPath)
    }
    $inlineSmokeEnvironment = $env:RADIA_IDE_SMOKE_INLINE_COMPLETION
    try {
        if ($ExerciseInlineCompletion) {
            $env:RADIA_IDE_SMOKE_INLINE_COMPLETION = "1"
        }
        $process = Start-Process `
            -FilePath $bdsPath `
            -ArgumentList $launchArguments `
            -PassThru
    } finally {
        $env:RADIA_IDE_SMOKE_INLINE_COMPLETION = $inlineSmokeEnvironment
    }
    $instanceFile = Join-Path (
        [Environment]::GetFolderPath("ApplicationData")
    ) "RadIA\mcp.$($process.Id).json"
    try {
        $startupDeadline = [DateTime]::UtcNow.AddSeconds(
            $StartupTimeoutSeconds
        )
        while ([DateTime]::UtcNow -lt $startupDeadline) {
            $currentProcess = Get-Process `
                -Id $process.Id `
                -ErrorAction SilentlyContinue
            if (-not $currentProcess) {
                throw "Delphi exited during startup in cycle $cycle."
            }
            if ($currentProcess.Responding -and
                $currentProcess.MainWindowTitle -and
                (Test-Path -LiteralPath $instanceFile)) {
                break
            }
            Start-Sleep -Milliseconds 250
        }
        if (-not (Test-Path -LiteralPath $instanceFile)) {
            throw "MCP discovery was not created in cycle $cycle."
        }
        if ($ExerciseDocking) {
            $currentProcess = Get-Process -Id $process.Id -ErrorAction Stop
            $dockInfo = Wait-RadIADockInfo `
                -Process $currentProcess `
                -TimeoutSeconds 60
            if ($cycle -eq 1) {
                $dockedGeometry = $dockInfo
            } elseif ($cycle -eq 2) {
                $tolerance = 40
                $positionRestored = (
                    [Math]::Abs(
                        $dockInfo.Left - $dockedGeometry.Left
                    ) -le $tolerance -and
                    [Math]::Abs(
                        $dockInfo.Top - $dockedGeometry.Top
                    ) -le $tolerance -and
                    [Math]::Abs(
                        $dockInfo.Right - $dockedGeometry.Right
                    ) -le $tolerance -and
                    [Math]::Abs(
                        $dockInfo.Bottom - $dockedGeometry.Bottom
                    ) -le $tolerance
                )
                if (-not $positionRestored) {
                    throw (
                        "The RadIA dock position was not restored " +
                        "after restarting Delphi."
                    )
                }
            }
        }

        $requests = @(
            (
                '{"jsonrpc":"2.0","id":1,"method":"initialize",' +
                '"params":{"protocolVersion":"2025-06-18",' +
                '"capabilities":{},"clientInfo":{' +
                '"name":"radia-ide-smoke","version":"1"}}}'
            ),
            (
                '{"jsonrpc":"2.0","method":' +
                '"notifications/initialized","params":{}}'
            ),
            (
                '{"jsonrpc":"2.0","id":2,"method":"tools/list",' +
                '"params":{}}'
            ),
            (
                '{"jsonrpc":"2.0","id":3,"method":"tools/call",' +
                '"params":{"name":"GetIDEState","arguments":{}}}'
            )
        )
        $responses = $requests | & $bridgePath $instanceFile
        if ($LASTEXITCODE -ne 0) {
            throw "MCP bridge failed in cycle $cycle."
        }
        $parsed = @(
            $responses |
                ForEach-Object { $_ | ConvertFrom-Json }
        )
        $initialize = $parsed | Where-Object { $_.id -eq 1 }
        $runtimeToolNames = @(
            (
                $parsed |
                    Where-Object { $_.id -eq 2 }
            ).result.tools |
                ForEach-Object { $_.name } |
                Sort-Object -Unique
        )
        $ideState = (
            $parsed |
                Where-Object { $_.id -eq 3 }
        ).result.structuredContent
        $missingTools = @(
            $expectedToolNames |
                Where-Object { $_ -notin $runtimeToolNames }
        )
        if ($initialize.result.serverInfo.version -ne $expectedVersion) {
            throw "Unexpected RadIA version in cycle $cycle."
        }
        if ($missingTools.Count -gt 0) {
            throw (
                "Runtime catalog is missing built-in tools in cycle " +
                "$cycle`: $($missingTools -join ', ')"
            )
        }
        if ($ideState.platform -ne $platform) {
            throw "Unexpected IDE platform in cycle $cycle."
        }
        if (-not $ideState.versionName) {
            throw "IDE version name was empty in cycle $cycle."
        }
        $inlineDiagnostic = $null
        if ($ExerciseInlineCompletion) {
            $editorRequests = @(
                (
                    '{"jsonrpc":"2.0","id":1,"method":"initialize",' +
                    '"params":{"protocolVersion":"2025-06-18",' +
                    '"capabilities":{},"clientInfo":{' +
                    '"name":"radia-inline-smoke","version":"1"}}}'
                ),
                (
                    '{"jsonrpc":"2.0","method":' +
                    '"notifications/initialized","params":{}}'
                ),
                (
                    '{"jsonrpc":"2.0","id":4,"method":"tools/call",' +
                    '"params":{"name":"GetEditorContent","arguments":{}}}'
                )
            )
            $editorDeadline = [DateTime]::UtcNow.AddSeconds(90)
            $editorContent = $null
            Start-Sleep -Seconds 5
            do {
                $editorResponses = @(
                    $editorRequests |
                        & $bridgePath $instanceFile |
                        ForEach-Object { $_ | ConvertFrom-Json }
                )
                if ($LASTEXITCODE -ne 0) {
                    throw "MCP editor inspection failed in cycle $cycle."
                }
                $editorResponse = $editorResponses |
                    Where-Object { $_.id -eq 4 }
                $editorContent = $editorResponse.result.structuredContent
                if (-not $editorContent.fileName) {
                    Start-Sleep -Seconds 2
                }
            } while (
                -not $editorContent.fileName -and
                [DateTime]::UtcNow -lt $editorDeadline
            )
            if (-not $editorContent.fileName) {
                throw "No active editor was found for Ghost Text."
            }
            $inlineDiagnostic = Wait-RadIAInlineCompletionDiagnostic `
                -LogPath $inlineSmokeLogPath `
                -FileName (
                    [IO.Path]::GetFileName($editorContent.fileName)
                )
        }

        $descendants = @(
            Get-RadIAProcessDescendants `
                -ParentProcessId $process.Id `
                -ParentStartedAt $process.StartTime
        )
        $currentProcess = Get-Process -Id $process.Id -ErrorAction Stop
        if (-not $currentProcess.CloseMainWindow()) {
            throw "Delphi rejected the shutdown request in cycle $cycle."
        }
        if (-not $currentProcess.WaitForExit($shutdownTimeoutMs)) {
            throw "Delphi did not exit cleanly in cycle $cycle."
        }
        $rootDeadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            $targetProcesses = @(
                Get-RadIATargetIDEProcesses -ExecutablePath $bdsPath
            )
            if ($targetProcesses.Count -gt 0) {
                Start-Sleep -Milliseconds 100
            }
        } while (
            ($targetProcesses.Count -gt 0) -and
            ([DateTime]::UtcNow -lt $rootDeadline)
        )
        if ($targetProcesses.Count -gt 0) {
            $targetProcessIds = @(
                $targetProcesses |
                    ForEach-Object { $_.Id }
            )
            throw (
                "Delphi process remained after cycle $cycle`: " +
                ($targetProcessIds -join ", ")
            )
        }
        $cleanupDeadline = [DateTime]::UtcNow.AddSeconds(5)
        while ((Test-Path -LiteralPath $instanceFile) -and
            ([DateTime]::UtcNow -lt $cleanupDeadline)) {
            Start-Sleep -Milliseconds 100
        }
        if (Test-Path -LiteralPath $instanceFile) {
            throw "MCP discovery remained after cycle $cycle."
        }
        $descendantIds = @(
            $descendants |
                ForEach-Object { [int]$_.ProcessId }
        )
        $orphanDeadline = [DateTime]::UtcNow.AddSeconds(10)
        $remainingDescendants = @()
        do {
            $remainingDescendants = @(
                $descendantIds |
                    Where-Object {
                        Get-Process -Id $_ -ErrorAction SilentlyContinue
                    }
            )
            if ($remainingDescendants.Count -gt 0) {
                Start-Sleep -Milliseconds 100
            }
        } while (
            ($remainingDescendants.Count -gt 0) -and
            ([DateTime]::UtcNow -lt $orphanDeadline)
        )
        if ($remainingDescendants.Count -gt 0) {
            $orphanNames = @(
                $descendants |
                    Where-Object {
                        $_.ProcessId -in $remainingDescendants
                    } |
                    ForEach-Object {
                        "$($_.Name):$($_.ProcessId)"
                    }
            )
            throw (
                "IDE descendants remained after cycle $cycle`: " +
                ($orphanNames -join ", ")
            )
        }

        $elapsed = [Math]::Round(
            ([DateTime]::UtcNow - $startedAt).TotalSeconds,
            2
        )
        $inlineLineCount = 0
        if ($inlineDiagnostic) {
            $inlineLineCount = $inlineDiagnostic.LineCount
        }
        $results += [pscustomobject]@{
            Cycle = $cycle
            ProcessId = $process.Id
            Version = $ideState.versionName
            Platform = $ideState.platform
            ToolCount = $runtimeToolNames.Count
            DescendantCount = $descendants.Count
            Seconds = $elapsed
            DockingExercised = [bool]$ExerciseDocking
            DockPositionRestored = (
                [bool]$ExerciseDocking -and
                $cycle -ge 2
            )
            PackageLifecycleExercised = [bool]$ExercisePackageLifecycle
            PackageLifecycleModes = $packageLifecycleModes
            PackageLifecycleSeconds = $packageLifecycleSeconds
            UpgradeExercised = [bool]$upgradePackageEvidence
            UpgradeFromVersion = $upgradeFromVersion
            InlineCompletionExercised = [bool]$ExerciseInlineCompletion
            InlineCompletionPrepared = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.Prepared
            )
            InlineCompletionPainted = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.Painted
            )
            InlineCompletionLineCount = $inlineLineCount
        }
        Write-Host (
            "Cycle $cycle/$Cycles passed for Delphi " +
            "$DelphiVersion $platform with " +
            "$($runtimeToolNames.Count) tools in $elapsed s."
        )
    } finally {
        $remainingProcess = Get-Process `
            -Id $process.Id `
            -ErrorAction SilentlyContinue
        if ($remainingProcess) {
            Write-Warning (
                "Delphi PID $($process.Id) remains open for inspection."
            )
        }
    }
}

$minimumSeconds = ($results | Measure-Object Seconds -Minimum).Minimum
$maximumSeconds = ($results | Measure-Object Seconds -Maximum).Maximum
Write-Host (
    "All $Cycles IDE smoke cycles passed for Delphi " +
    "$DelphiVersion $platform. Range: " +
    "$minimumSeconds-$maximumSeconds s."
)
if ($ExerciseDocking) {
    Write-Host (
        "Native TOTADockForm visibility and desktop-state " +
        "restoration passed."
    )
    Restore-RadIADockingVisibility
}
if ($ExerciseInlineCompletion) {
    Write-Host (
        "Local multiline Ghost Text preparation and OTA painting passed."
    )
    Restore-RadIAInlineCompletionLogSettings
}
if ($EvidencePath) {
    $resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
    $evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
    if ($evidenceDirectory) {
        New-Item -ItemType Directory -Force -Path $evidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        productVersion = $expectedVersion
        sourceCommit = $releaseSourceCommit
        delphiVersion = $DelphiVersion
        platform = $platform
        releasePackage = $releasePackageName
        releasePackageSha256 = $releasePackageHash
        installedBplSha256 = $installedPackageHash
        toolCount = $expectedToolNames.Count
        cyclesRequested = $Cycles
        cyclesPassed = $results.Count
        dockingExercised = [bool]$ExerciseDocking
        inlineCompletionExercised = [bool]$ExerciseInlineCompletion
        packageLifecycleExercised = [bool]$ExercisePackageLifecycle
        upgradeExercised = [bool]$upgradePackageEvidence
        upgradeFromVersion = $upgradeFromVersion
        upgradeFromPackageSha256 = $upgradeFromPackageSha256
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        cycles = $results
    } |
        ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8
    Write-Host "IDE smoke evidence created: $resolvedEvidencePath"
}
if ($InlineCompletionEvidencePath) {
    & git -C $repositoryRoot diff --quiet
    $sourceDirty = $LASTEXITCODE -ne 0
    & git -C $repositoryRoot diff --cached --quiet
    $sourceDirty = $sourceDirty -or ($LASTEXITCODE -ne 0)
    if ($sourceDirty) {
        throw "Inline completion evidence requires a clean tracked source."
    }
    $sourceCommit = (
        & git -C $repositoryRoot rev-parse HEAD
    ).Trim()
    if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch "^[0-9a-f]{40}$") {
        throw "The source commit could not be resolved."
    }
    $resolvedInlineEvidencePath = [IO.Path]::GetFullPath(
        $InlineCompletionEvidencePath
    )
    $inlineEvidenceDirectory = Split-Path -Parent $resolvedInlineEvidencePath
    if ($inlineEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $inlineEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "inlineCompletionVisualSmoke"
        productVersion = $expectedVersion
        sourceCommit = $sourceCommit
        sourceDirty = $false
        delphiVersion = $DelphiVersion
        platform = $platform
        installedBplSha256 = $installedPackageHash
        toolCount = $expectedToolNames.Count
        cyclesRequested = $Cycles
        cyclesPassed = $results.Count
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        cycles = $results
    } |
        ConvertTo-Json -Depth 6 |
        Set-Content `
            -LiteralPath $resolvedInlineEvidencePath `
            -Encoding UTF8
    Write-Host (
        "Inline completion evidence created: " +
        $resolvedInlineEvidencePath
    )
}
