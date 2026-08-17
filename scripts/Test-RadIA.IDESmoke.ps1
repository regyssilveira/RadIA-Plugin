param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [ValidateRange(1, 50)]
    [int]$Cycles = 10,
    [ValidateRange(30, 1800)]
    [int]$StartupTimeoutSeconds = 180,
    [ValidateRange(1, 100)]
    [int]$WebViewTransitionCount = 25,
    [switch]$IDE64,
    [switch]$SkipPackageHashCheck,
    [switch]$ExerciseDocking,
    [switch]$ExerciseWebViewLifecycle,
    [switch]$ExerciseTerminal,
    [switch]$ExerciseInlineCompletion,
    [switch]$ExerciseInlineReview,
    [switch]$ExerciseAgentRuntime,
    [switch]$ExerciseDeclarativeWorkflow,
    [switch]$ExerciseKnowledge,
    [switch]$ExerciseFirstValue,
    [switch]$ExercisePackageLifecycle,
    [string]$UpgradeFromPackagePath = "",
    [string]$EvidencePath = "",
    [string]$TerminalEvidencePath = "",
    [string]$WebViewLifecycleEvidencePath = "",
    [string]$InlineCompletionEvidencePath = "",
    [string]$InlineReviewEvidencePath = "",
    [string]$AgentRuntimeEvidencePath = "",
    [string]$DeclarativeWorkflowEvidencePath = "",
    [string]$KnowledgeEvidencePath = "",
    [string]$FirstValueEvidencePath = "",
    [string]$FireDACScenarioId = "",
    [string]$FireDACProjectPath = "",
    [string]$FireDACEvidencePath = "",
    [string]$FireDACDatabasePath = "",
    [string]$FireDACTestExecutablePath = ""
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
if ($InlineReviewEvidencePath -and -not $ExerciseInlineReview) {
    throw "Inline review evidence requires -ExerciseInlineReview."
}
if ($TerminalEvidencePath -and -not $ExerciseTerminal) {
    throw "Terminal evidence requires -ExerciseTerminal."
}
if ($WebViewLifecycleEvidencePath -and -not $ExerciseWebViewLifecycle) {
    throw (
        "WebView lifecycle evidence requires " +
        "-ExerciseWebViewLifecycle."
    )
}
if ($ExerciseWebViewLifecycle -and -not $ExerciseDocking) {
    throw "WebView lifecycle validation requires -ExerciseDocking."
}
if ($AgentRuntimeEvidencePath -and -not $ExerciseAgentRuntime) {
    throw (
        "Agent runtime evidence requires -ExerciseAgentRuntime."
    )
}
if ($DeclarativeWorkflowEvidencePath -and
    -not $ExerciseDeclarativeWorkflow) {
    throw (
        "Declarative workflow evidence requires " +
        "-ExerciseDeclarativeWorkflow."
    )
}
if ($KnowledgeEvidencePath -and -not $ExerciseKnowledge) {
    throw "Knowledge evidence requires -ExerciseKnowledge."
}
if ($FirstValueEvidencePath -and -not $ExerciseFirstValue) {
    throw "First-value evidence requires -ExerciseFirstValue."
}
if ($UpgradeFromPackagePath -and -not $ExercisePackageLifecycle) {
    throw (
        "Cross-version upgrade validation requires " +
        "-ExercisePackageLifecycle."
    )
}
if ($FireDACScenarioId -and -not $FireDACProjectPath) {
    throw "A FireDAC IDE scenario requires -FireDACProjectPath."
}
if ($FireDACEvidencePath -and -not $FireDACScenarioId) {
    throw "FireDAC evidence requires -FireDACScenarioId."
}
if ($FireDACDatabasePath -and -not $FireDACScenarioId) {
    throw "A FireDAC database fixture requires -FireDACScenarioId."
}
if ($FireDACTestExecutablePath -and -not $FireDACScenarioId) {
    throw "A FireDAC test executable requires -FireDACScenarioId."
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
    public static extern bool ShowWindow(IntPtr handle, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(
        IntPtr handle,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags
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

if ($ExerciseKnowledge -or $ExerciseInlineCompletion -or
    $ExerciseInlineReview -or $FireDACScenarioId) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class RadIAKnowledgeSmokeNative
{
    public delegate bool EnumCallback(IntPtr handle, IntPtr parameter);

    [StructLayout(LayoutKind.Sequential)]
    public struct Point
    {
        public int X;
        public int Y;
    }

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
    public static extern bool ShowWindow(IntPtr handle, int command);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr handle, ref Point point);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr handle, out Rect rectangle);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags,
        uint dx,
        uint dy,
        uint data,
        UIntPtr extraInfo
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(
        IntPtr handle,
        StringBuilder className,
        int maximumCount
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(
        IntPtr handle,
        StringBuilder text,
        int maximumCount
    );

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr handle,
        out uint processId
    );

    [DllImport("user32.dll")]
    public static extern bool PostMessage(
        IntPtr handle,
        uint message,
        IntPtr wordParameter,
        IntPtr longParameter
    );

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(
        IntPtr handle,
        uint message,
        IntPtr wordParameter,
        IntPtr longParameter
    );

    [DllImport(
        "user32.dll",
        CharSet = CharSet.Unicode,
        EntryPoint = "SendMessageW"
    )]
    public static extern IntPtr SendMessageText(
        IntPtr handle,
        uint message,
        IntPtr wordParameter,
        string text
    );

    [DllImport("user32.dll")]
    public static extern int GetDlgCtrlID(IntPtr handle);

    [DllImport("user32.dll")]
    public static extern bool RedrawWindow(
        IntPtr handle,
        IntPtr updateRectangle,
        IntPtr updateRegion,
        uint flags
    );

    public static void RepaintDescendants(IntPtr parent)
    {
        const uint invalidate = 0x0001;
        const uint updateNow = 0x0100;
        const uint allChildren = 0x0080;
        RedrawWindow(
            parent,
            IntPtr.Zero,
            IntPtr.Zero,
            invalidate | updateNow | allChildren
        );
    }

    public static IntPtr FindVisibleChildByClass(
        IntPtr parent,
        string expectedClassName
    )
    {
        IntPtr result = IntPtr.Zero;
        EnumChildWindows(
            parent,
            delegate(IntPtr handle, IntPtr parameter)
            {
                StringBuilder className = new StringBuilder(128);
                GetClassName(handle, className, className.Capacity);
                if (IsWindowVisible(handle) &&
                    className.ToString() == expectedClassName)
                {
                    result = handle;
                    return false;
                }
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }

    public static IntPtr FindLargestVisibleProcessDescendantByClass(
        uint processId,
        string expectedClassName
    )
    {
        IntPtr result = IntPtr.Zero;
        long largestArea = 0;
        EnumWindows(
            delegate(IntPtr topLevelHandle, IntPtr parameter)
            {
                uint ownerProcessId;
                GetWindowThreadProcessId(
                    topLevelHandle,
                    out ownerProcessId
                );
                if (ownerProcessId != processId)
                {
                    return true;
                }
                EnumChildWindows(
                    topLevelHandle,
                    delegate(IntPtr handle, IntPtr childParameter)
                    {
                        StringBuilder className = new StringBuilder(128);
                        GetClassName(
                            handle,
                            className,
                            className.Capacity
                        );
                        Rect rectangle;
                        if (IsWindowVisible(handle) &&
                            className.ToString() == expectedClassName &&
                            GetWindowRect(handle, out rectangle))
                        {
                            long width = Math.Max(
                                0,
                                rectangle.Right - rectangle.Left
                            );
                            long height = Math.Max(
                                0,
                                rectangle.Bottom - rectangle.Top
                            );
                            long area = width * height;
                            if (area > largestArea)
                            {
                                largestArea = area;
                                result = handle;
                            }
                        }
                        return true;
                    },
                    IntPtr.Zero
                );
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }

    public static IntPtr FindVisibleWindow(
        uint processId,
        string expectedClassName
    )
    {
        IntPtr result = IntPtr.Zero;
        EnumWindows(
            delegate(IntPtr handle, IntPtr parameter)
            {
                uint ownerProcessId;
                GetWindowThreadProcessId(handle, out ownerProcessId);
                if (ownerProcessId != processId ||
                    !IsWindowVisible(handle))
                {
                    return true;
                }
                StringBuilder className = new StringBuilder(128);
                GetClassName(handle, className, className.Capacity);
                if (className.ToString() == expectedClassName)
                {
                    result = handle;
                    return false;
                }
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }

    public static IntPtr FindChildByText(
        IntPtr parent,
        string expectedText
    )
    {
        IntPtr result = IntPtr.Zero;
        EnumChildWindows(
            parent,
            delegate(IntPtr handle, IntPtr parameter)
            {
                StringBuilder text = new StringBuilder(256);
                GetWindowText(handle, text, text.Capacity);
                if (text.ToString() == expectedText)
                {
                    result = handle;
                    return false;
                }
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }

    public static IntPtr FindChildById(IntPtr parent, int expectedId)
    {
        IntPtr result = IntPtr.Zero;
        EnumChildWindows(
            parent,
            delegate(IntPtr handle, IntPtr parameter)
            {
                if (GetDlgCtrlID(handle) == expectedId)
                {
                    result = handle;
                    return false;
                }
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }
}
"@
}

function Save-RadIAActiveEditor {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$IDEProcess
    )

    $mainWindow = [RadIAKnowledgeSmokeNative]::FindVisibleWindow(
        [uint32]$IDEProcess.Id,
        "TAppBuilder"
    )
    $menuBar = [RadIAKnowledgeSmokeNative]::FindChildByText(
        $mainWindow,
        "Menu bar"
    )
    if ($mainWindow -eq [IntPtr]::Zero -or
        $menuBar -eq [IntPtr]::Zero) {
        throw "The Delphi File menu is not available for save."
    }
    $mousePosition = [IntPtr]((12 -shl 16) -bor 12)
    [void][RadIAKnowledgeSmokeNative]::PostMessage(
        $menuBar,
        0x0201,
        [IntPtr]1,
        $mousePosition
    )
    [void][RadIAKnowledgeSmokeNative]::PostMessage(
        $menuBar,
        0x0202,
        [IntPtr]0,
        $mousePosition
    )
    Start-Sleep -Milliseconds 250
    $saveKey = [int][char]'S'
    [void][RadIAKnowledgeSmokeNative]::PostMessage(
        $mainWindow,
        0x0100,
        [IntPtr]$saveKey,
        [IntPtr]0
    )
    [void][RadIAKnowledgeSmokeNative]::PostMessage(
        $mainWindow,
        0x0101,
        [IntPtr]$saveKey,
        [IntPtr]0
    )
    Start-Sleep -Seconds 2
}

function Select-RadIAEditorCharacters {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory)]
        [ValidateRange(1, 4096)]
        [int]$CharacterCount
    )

    $mainWindow = [RadIAKnowledgeSmokeNative]::FindVisibleWindow(
        [uint32]$IDEProcess.Id,
        "TAppBuilder"
    )
    if ($mainWindow -eq [IntPtr]::Zero) {
        throw "The Delphi editor window is not available for selection."
    }
    [void][RadIAKnowledgeSmokeNative]::ShowWindow($mainWindow, 9)
    [void][RadIAKnowledgeSmokeNative]::SetForegroundWindow($mainWindow)
    [System.Windows.Forms.SendKeys]::SendWait(
        "+{RIGHT " + $CharacterCount + "}"
    )
    Start-Sleep -Seconds 1
}

function Set-RadIAEditorCaretPosition {
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 1000000)]
        [int]$Line,
        [Parameter(Mandatory)]
        [ValidateRange(1, 1000000)]
        [int]$Column
    )

    [System.Windows.Forms.SendKeys]::SendWait("^{HOME}")
    if ($Line -gt 1) {
        [System.Windows.Forms.SendKeys]::SendWait("{DOWN " + ($Line - 1) + "}")
    }
    if ($Column -gt 1) {
        [System.Windows.Forms.SendKeys]::SendWait("{RIGHT " + ($Column - 1) + "}")
    }
    Start-Sleep -Milliseconds 250
}

function Open-RadIAEditorFile {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $IDEProcess.Refresh()
    $mainWindow = [RadIAKnowledgeSmokeNative]::FindVisibleWindow(
        [uint32]$IDEProcess.Id,
        "TAppBuilder"
    )
    $menuBar = [RadIAKnowledgeSmokeNative]::FindChildByText(
        $mainWindow,
        "Menu bar"
    )
    if ($mainWindow -eq [IntPtr]::Zero -or
        $menuBar -eq [IntPtr]::Zero) {
        throw "The Delphi File menu is not available for editor smoke."
    }
    $mousePosition = [IntPtr]((12 -shl 16) -bor 12)
    [void][RadIAKnowledgeSmokeNative]::PostMessage(
        $menuBar,
        0x0201,
        [IntPtr]1,
        $mousePosition
    )
    [void][RadIAKnowledgeSmokeNative]::PostMessage(
        $menuBar,
        0x0202,
        [IntPtr]0,
        $mousePosition
    )
    Start-Sleep -Milliseconds 250
    foreach ($key in @(0x28, 0x28, 0x0D)) {
        [void][RadIAKnowledgeSmokeNative]::PostMessage(
            $mainWindow,
            0x0100,
            [IntPtr]$key,
            [IntPtr]0
        )
        [void][RadIAKnowledgeSmokeNative]::PostMessage(
            $mainWindow,
            0x0101,
            [IntPtr]$key,
            [IntPtr]0
        )
    }
    $dialogDeadline = [DateTime]::UtcNow.AddSeconds(10)
    $dialog = [IntPtr]::Zero
    do {
        $dialog = [RadIAKnowledgeSmokeNative]::FindVisibleWindow(
            [uint32]$IDEProcess.Id,
            "#32770"
        )
        if ($dialog -eq [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 100
        }
    } while (
        $dialog -eq [IntPtr]::Zero -and
        [DateTime]::UtcNow -lt $dialogDeadline
    )
    if ($dialog -eq [IntPtr]::Zero) {
        throw "The Delphi file dialog did not open for editor smoke."
    }
    $fileNameEdit = [RadIAKnowledgeSmokeNative]::FindChildById(
        $dialog,
        1148
    )
    if ($fileNameEdit -eq [IntPtr]::Zero) {
        $fileNameEdit = [RadIAKnowledgeSmokeNative]::FindChildById(
            $dialog,
            1001
        )
    }
    $confirmButton = [RadIAKnowledgeSmokeNative]::FindChildById($dialog, 1)
    if ($fileNameEdit -eq [IntPtr]::Zero -or
        $confirmButton -eq [IntPtr]::Zero) {
        throw "The Delphi file dialog controls were not found."
    }
    [void][RadIAKnowledgeSmokeNative]::SendMessageText(
        $fileNameEdit,
        0x000C,
        [IntPtr]0,
        $Path
    )
    [void][RadIAKnowledgeSmokeNative]::SendMessage(
        $confirmButton,
        0x00F5,
        [IntPtr]0,
        [IntPtr]0
    )
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

function Wait-RadIATerminalDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$EvidencePath,
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path -LiteralPath $EvidencePath -PathType Leaf) {
            break
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
        throw "The RadIA terminal did not publish visual evidence."
    }
    $diagnostic = Get-Content `
        -LiteralPath $EvidencePath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    if (
        $diagnostic.opened -ne $true -or
        $diagnostic.requiredControlsVisible -ne $true -or
        $diagnostic.commandInputAvailable -ne $true -or
        $diagnostic.outputAvailable -ne $true -or
        $diagnostic.paletteAvailable -ne $true -or
        $diagnostic.accessibleLabelsAvailable -ne $true
    ) {
        throw "The terminal visual surface is incomplete."
    }
    if ($diagnostic.tabStopCount -lt 11) {
        throw (
            "The terminal exposes only $($diagnostic.tabStopCount) " +
            "keyboard tab stops; " +
            "at least 11 are required."
        )
    }
    if ($diagnostic.paletteItemCount -lt 1) {
        throw "The terminal command palette is empty."
    }
    if ($diagnostic.profileCount -lt 2) {
        throw "The terminal exposes fewer than two profiles."
    }
    if ($diagnostic.width -lt 300 -or $diagnostic.height -lt 200) {
        throw "The terminal opened with unusable geometry."
    }
    return [PSCustomObject]@{
        Opened = $diagnostic.opened
        Width = $diagnostic.width
        Height = $diagnostic.height
        RequiredControlsVisible = $diagnostic.requiredControlsVisible
        CommandInputAvailable = $diagnostic.commandInputAvailable
        OutputAvailable = $diagnostic.outputAvailable
        PaletteAvailable = $diagnostic.paletteAvailable
        PaletteItemCount = $diagnostic.paletteItemCount
        ProfileCount = $diagnostic.profileCount
        AccessibleLabelsAvailable = (
            $diagnostic.accessibleLabelsAvailable
        )
        TabStopCount = $diagnostic.tabStopCount
    }
}

function Invoke-RadIAWebViewHostTransitions {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$DockInfo,
        [Parameter(Mandatory)]
        [int]$TransitionCount
    )

    $originalWidth = $DockInfo.Right - $DockInfo.Left
    $originalHeight = $DockInfo.Bottom - $DockInfo.Top
    if ($originalWidth -lt 300 -or $originalHeight -lt 200) {
        throw "The WebView dock host has unusable initial geometry."
    }
    $noMoveNoOrderNoActivate = 0x0002 -bor 0x0004 -bor 0x0010
    for ($index = 1; $index -le $TransitionCount; $index++) {
        [void][RadIADockingSmokeNative]::ShowWindow(
            $DockInfo.Handle,
            0
        )
        [void][RadIADockingSmokeNative]::ShowWindow(
            $DockInfo.Handle,
            5
        )
        $width = $originalWidth + $(if ($index % 2 -eq 0) { 24 } else { -24 })
        $height = $originalHeight + $(if ($index % 3 -eq 0) { 18 } else { -18 })
        if (-not [RadIADockingSmokeNative]::SetWindowPos(
            $DockInfo.Handle,
            [IntPtr]::Zero,
            0,
            0,
            $width,
            $height,
            $noMoveNoOrderNoActivate
        )) {
            throw "WebView dock-host resize failed at transition $index."
        }
        Start-Sleep -Milliseconds 40
    }
    if (-not [RadIADockingSmokeNative]::SetWindowPos(
        $DockInfo.Handle,
        [IntPtr]::Zero,
        0,
        0,
        $originalWidth,
        $originalHeight,
        $noMoveNoOrderNoActivate
    )) {
        throw "The WebView dock-host geometry could not be restored."
    }
    return $TransitionCount
}

function Wait-RadIAWebViewLifecycleDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$EvidencePath,
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path -LiteralPath $EvidencePath -PathType Leaf) {
            $diagnostic = Get-Content `
                -LiteralPath $EvidencePath `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json
            if ($diagnostic.status -eq "passed") {
                return $diagnostic
            }
            throw "The WebView lifecycle smoke reported a failure."
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "The RadIA WebView did not publish lifecycle evidence."
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
    $alternativesPattern = (
        "Inline alternatives painted: count=2, selected=1"
    )
    $acceptancePattern = (
        "Inline completion acceptance: previewClean=True, " +
        "accepted=True, singleUndo=True, undoRestored=True, " +
        "rejectedClean=True, file=$FileName"
    )
    $paintDeadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $logContent = ""
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $logContent = Get-Content -LiteralPath $LogPath -Raw
        }
        $prepared = $logContent.Contains($preparedPattern)
        $painted = $logContent.Contains($paintedPattern)
        $alternativesPainted = $logContent.Contains(
            $alternativesPattern
        )
        $acceptedAndRestored = $logContent.Contains(
            $acceptancePattern
        )
        if (-not (
            $prepared -and
            $painted -and
            $alternativesPainted -and
            $acceptedAndRestored
        )) {
            Start-Sleep -Milliseconds 100
        }
    } while (
        -not (
            $prepared -and
            $painted -and
            $alternativesPainted -and
            $acceptedAndRestored
        ) -and
        [DateTime]::UtcNow -lt $paintDeadline
    )
    if (-not $prepared) {
        throw "The local inline suggestion was not prepared."
    }
    if (-not $painted) {
        throw "The Ghost Text overlay did not reach the OTA paint cycle."
    }
    if (-not $alternativesPainted) {
        throw "The inline alternatives panel was not painted."
    }
    if (-not $acceptedAndRestored) {
        throw (
            "Inline completion acceptance, single undo, or rejection " +
            "did not pass on the real editor buffer."
        )
    }
    return [pscustomobject]@{
        Prepared = $true
        Painted = $true
        AlternativesPainted = $true
        AlternativeCount = 2
        PreviewClean = $true
        Accepted = $true
        SingleUndo = $true
        UndoRestored = $true
        RejectedClean = $true
        LineCount = 2
        FileName = $FileName
    }
}

function Wait-RadIAInlineReviewDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$EvidencePath
    )

    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $diagnostic = $null
        if (Test-Path -LiteralPath $EvidencePath -PathType Leaf) {
            $diagnostic = Get-Content `
                -LiteralPath $EvidencePath `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json
        }
        if (-not (
            $diagnostic.published -and
            $diagnostic.painted -and
            $diagnostic.revisionMatched
        )) {
            Start-Sleep -Milliseconds 100
        }
    } while (
        -not (
            $diagnostic.published -and
            $diagnostic.painted -and
            $diagnostic.revisionMatched
        ) -and
        [DateTime]::UtcNow -lt $deadline
    )
    if (-not $diagnostic.published) {
        throw "The inline review was not published in the real editor."
    }
    if (-not $diagnostic.painted) {
        throw "The inline review did not reach the OTA paint cycle."
    }
    if (-not $diagnostic.revisionMatched) {
        throw "The inline review was not anchored to the active revision."
    }
    return [pscustomobject]@{
        Published = $true
        Painted = $true
        RevisionMatched = $true
        ReviewCount = $diagnostic.reviewCount
    }
}

function Invoke-RadIAEditorRepaint {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$IDEProcess,
        [switch]$PreserveCursor
    )

    $IDEProcess.Refresh()
    if ($IDEProcess.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "The Delphi editor window is unavailable for repaint."
    }
    [void][RadIAKnowledgeSmokeNative]::ShowWindow(
        $IDEProcess.MainWindowHandle,
        9
    )
    [void][RadIAKnowledgeSmokeNative]::SetForegroundWindow(
        $IDEProcess.MainWindowHandle
    )
    Start-Sleep -Milliseconds 250
    $editorDeadline = [DateTime]::UtcNow.AddSeconds(10)
    $editorHandle = [IntPtr]::Zero
    do {
        $editorHandle = (
            [RadIAKnowledgeSmokeNative]::FindLargestVisibleProcessDescendantByClass(
                [uint32]$IDEProcess.Id,
                "TEditControl"
            )
        )
        if ($editorHandle -eq [IntPtr]::Zero) {
            $editorHandle = [RadIAKnowledgeSmokeNative]::FindVisibleChildByClass(
                $IDEProcess.MainWindowHandle,
                "TEditControl"
            )
        }
        if ($editorHandle -eq [IntPtr]::Zero) {
            Start-Sleep -Milliseconds 250
        }
    } while (
        $editorHandle -eq [IntPtr]::Zero -and
        [DateTime]::UtcNow -lt $editorDeadline
    )
    if ($editorHandle -eq [IntPtr]::Zero) {
        throw "The visible Delphi editor control was not found for repaint."
    }
    if (-not $PreserveCursor) {
        $editorRectangle = New-Object RadIAKnowledgeSmokeNative+Rect
        if (-not [RadIAKnowledgeSmokeNative]::GetWindowRect(
            $editorHandle,
            [ref]$editorRectangle
        )) {
            throw "The Delphi editor rectangle was not available for repaint."
        }
        $editorX = [int](
            ($editorRectangle.Left + $editorRectangle.Right) / 2
        )
        $editorY = [int](
            ($editorRectangle.Top + $editorRectangle.Bottom) / 2
        )
        [void][RadIAKnowledgeSmokeNative]::SetCursorPos($editorX, $editorY)
        [RadIAKnowledgeSmokeNative]::mouse_event(
            0x0002,
            0,
            0,
            0,
            [UIntPtr]::Zero
        )
        [RadIAKnowledgeSmokeNative]::mouse_event(
            0x0004,
            0,
            0,
            0,
            [UIntPtr]::Zero
        )
        Start-Sleep -Milliseconds 250
    }
    [RadIAKnowledgeSmokeNative]::RepaintDescendants(
        $editorHandle
    )
    Start-Sleep -Milliseconds 250
    [System.Windows.Forms.SendKeys]::SendWait("{DOWN}{UP}")
    Start-Sleep -Milliseconds 250
}

function Invoke-RadIABlockMarkerClick {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory)]
        [object]$Diagnostic
    )

    if ($Diagnostic.blockMarkerScreenX -lt 1 -or
        $Diagnostic.blockMarkerScreenY -lt 1) {
        throw "The gutter marker did not expose a clickable hit target."
    }
    $IDEProcess.Refresh()
    [void][RadIAKnowledgeSmokeNative]::SetForegroundWindow(
        $IDEProcess.MainWindowHandle
    )
    [void][RadIAKnowledgeSmokeNative]::SetCursorPos(
        [int]$Diagnostic.blockMarkerScreenX,
        [int]$Diagnostic.blockMarkerScreenY
    )
    [RadIAKnowledgeSmokeNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [RadIAKnowledgeSmokeNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 250
}

function Invoke-RadIABlockLineClick {
    param(
        [Parameter(Mandatory)]
        [Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory)]
        [object]$Diagnostic
    )

    if ($Diagnostic.blockMarkerScreenX -lt 1 -or
        $Diagnostic.blockMarkerScreenY -lt 1) {
        throw "The gutter marker did not expose its source line."
    }
    $IDEProcess.Refresh()
    [void][RadIAKnowledgeSmokeNative]::SetForegroundWindow(
        $IDEProcess.MainWindowHandle
    )
    [void][RadIAKnowledgeSmokeNative]::SetCursorPos(
        [int]$Diagnostic.blockMarkerScreenX + 200,
        [int]$Diagnostic.blockMarkerScreenY
    )
    [RadIAKnowledgeSmokeNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [RadIAKnowledgeSmokeNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 250
}

function Get-RadIABlockReviewState {
    param(
        [Parameter(Mandatory)]
        [string]$BridgePath,
        [Parameter(Mandatory)]
        [string]$InstanceFile
    )

    $requests = @(
        (
            '{"jsonrpc":"2.0","id":1,"method":"initialize",' +
            '"params":{"protocolVersion":"2025-06-18",' +
            '"capabilities":{},"clientInfo":{' +
            '"name":"radia-block-state-smoke","version":"1"}}}'
        ),
        (
            '{"jsonrpc":"2.0","method":' +
            '"notifications/initialized","params":{}}'
        ),
        (
            '{"jsonrpc":"2.0","id":9,"method":"tools/call",' +
            '"params":{"name":"ListBlockReviews","arguments":{}}}'
        )
    )
    $responses = @(
        $requests |
            & $BridgePath $InstanceFile |
            ForEach-Object { $_ | ConvertFrom-Json }
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Block review state inspection failed."
    }
    return ($responses |
        Where-Object { $_.id -eq 9 }).result.structuredContent
}

function Invoke-RadIASmokeRequestsWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$BridgePath,
        [Parameter(Mandatory)]
        [string]$InstanceFile,
        [Parameter(Mandatory)]
        [object[]]$Requests,
        [Parameter(Mandatory)]
        [string]$Operation
    )

    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            $responseLines = @(
                $Requests | & $BridgePath $InstanceFile 2>$null
            )
            if ($LASTEXITCODE -eq 0) {
                return @(
                    $responseLines |
                        ForEach-Object { $_ | ConvertFrom-Json }
                )
            }
        } catch {
            # The IDE can rotate its named-pipe listener between clients.
        }
        Start-Sleep -Milliseconds 250
    }
    throw "$Operation failed after retrying the live IDE connection."
}

function Wait-RadIABlockReviewDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$EvidencePath
    )

    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $diagnostic = $null
        if (Test-Path -LiteralPath $EvidencePath -PathType Leaf) {
            $diagnostic = Get-Content `
                -LiteralPath $EvidencePath `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json
        }
        if (-not ($diagnostic.blockPublished -and $diagnostic.blockPainted)) {
            Start-Sleep -Milliseconds 100
        }
    } while (
        -not ($diagnostic.blockPublished -and $diagnostic.blockPainted) -and
        [DateTime]::UtcNow -lt $deadline
    )
    if (-not $diagnostic.blockPublished) {
        throw "The block review was not published in the real editor."
    }
    if (-not $diagnostic.blockPainted) {
        throw "The block review marker did not reach the OTA gutter paint cycle."
    }
    return [pscustomobject]@{
        Published = $true
        Painted = $true
        BlockCount = $diagnostic.blockCount
        MarkerX = $diagnostic.blockMarkerX
        MarkerY = $diagnostic.blockMarkerY
        EditorWindowHandle = $diagnostic.editorWindowHandle
        Raw = $diagnostic
    }
}

function Wait-RadIAAgentRuntimeDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,
        [Parameter(Mandatory)]
        [string]$CheckpointDirectory
    )

    $requiredPatterns = @(
        "Agent diagnostic checkpoint: status=awaitingApproval, steps=0",
        "Agent diagnostic checkpoint: status=paused, steps=1",
        "Agent diagnostic checkpoint: status=completed, steps=1",
        (
            "Agent runtime diagnostic passed: persisted=true, " +
            "resumed=true, compaction=true, recovery=true, " +
            "rollback=true, " +
            "tool=GetIDEState"
        )
    )
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $logContent = ""
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $logContent = Get-Content -LiteralPath $LogPath -Raw
        }
        $missingPatterns = @(
            $requiredPatterns |
                Where-Object { -not $logContent.Contains($_) }
        )
        if ($missingPatterns.Count -gt 0) {
            Start-Sleep -Milliseconds 100
        }
    } while (
        $missingPatterns.Count -gt 0 -and
        [DateTime]::UtcNow -lt $deadline
    )
    if ($missingPatterns.Count -gt 0) {
        throw (
            "The agent runtime diagnostic did not complete: " +
            ($missingPatterns -join "; ")
        )
    }
    $checkpointPath = Join-Path `
        $CheckpointDirectory `
        "radia-agent-runtime-smoke.json"
    if (-not (Test-Path -LiteralPath $checkpointPath -PathType Leaf)) {
        throw "The persisted agent diagnostic checkpoint was not found."
    }
    $checkpoint = Get-Content `
        -LiteralPath $checkpointPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    $steps = @($checkpoint.steps)
    if (
        $checkpoint.status -ne "completed" -or
        $steps.Count -ne 1 -or
        $steps[0].toolName -ne "GetIDEState" -or
        $steps[0].success -ne $true -or
        $steps[0].risk -ne "readOnly"
    ) {
        throw "The persisted agent diagnostic checkpoint is incomplete."
    }
    return [pscustomobject]@{
        AwaitingApproval = $true
        Paused = $true
        Resumed = $true
        Completed = $true
        Persisted = $true
        ToolName = "GetIDEState"
        StepCount = 1
    }
}

function Wait-RadIADeclarativeWorkflowDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )

    $evidencePath = Join-Path `
        $OutputDirectory `
        "declarative-workflow.json"
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (
        -not (Test-Path -LiteralPath $evidencePath -PathType Leaf) -and
        [DateTime]::UtcNow -lt $deadline
    ) {
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        throw "The declarative workflow diagnostic did not complete."
    }
    $evidence = Get-Content `
        -LiteralPath $evidencePath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json
    if (
        $evidence.schemaVersion -ne 1 -or
        $evidence.manifestLoaded -ne $true -or
        $evidence.workflowRegistered -ne $true -or
        $evidence.workflowExecuted -ne $true -or
        $evidence.workflowName -ne "RadIADiagnosticInspection" -or
        $evidence.risk -ne "readOnly" -or
        $evidence.idempotent -ne $true -or
        $evidence.stepCount -ne 2 -or
        $evidence.firstStepPresent -ne $true -or
        $evidence.secondStepPresent -ne $true
    ) {
        throw "The declarative workflow diagnostic is incomplete."
    }
    return $evidence
}

function Invoke-RadIASmokeTool {
    param(
        [Parameter(Mandatory)]
        [string]$BridgePath,
        [Parameter(Mandatory)]
        [string]$InstanceFile,
        [Parameter(Mandatory)]
        [string]$Name,
        [hashtable]$Arguments = @{}
    )

    $requests = @(
        @{
            jsonrpc = "2.0"
            id = 1
            method = "initialize"
            params = @{
                protocolVersion = "2025-06-18"
                capabilities = @{}
                clientInfo = @{
                    name = "radia-knowledge-smoke"
                    version = "1"
                }
            }
        },
        @{
            jsonrpc = "2.0"
            method = "notifications/initialized"
            params = @{}
        },
        @{
            jsonrpc = "2.0"
            id = 2
            method = "tools/call"
            params = @{
                name = $Name
                arguments = $Arguments
            }
        }
    ) | ForEach-Object {
        $_ | ConvertTo-Json -Depth 8 -Compress
    }
    $responses = @()
    $bridgeSucceeded = $false
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        $responseLines = @()
        try {
            $responseLines = @(
                $requests |
                    & $BridgePath $InstanceFile 2>$null
            )
        } catch {
            $responseLines = @()
        }
        if ($LASTEXITCODE -eq 0) {
            $responses = @(
                $responseLines |
                    ForEach-Object { $_ | ConvertFrom-Json }
            )
            $bridgeSucceeded = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $bridgeSucceeded) {
        throw "MCP bridge failed while calling $Name after 10 attempts."
    }
    $response = $responses |
        Where-Object { $_.id -eq 2 }
    if ($response.error) {
        throw (
            "Smoke tool $Name failed: " +
            ($response.error | ConvertTo-Json -Compress)
        )
    }
    if ($response.result.isError) {
        throw (
            "Smoke tool $Name returned an error result: " +
            ($response.result.content | ConvertTo-Json -Compress)
        )
    }
    return $response.result.structuredContent
}

function Wait-RadIAConsentWindowState {
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory)][bool]$Visible,
        [ValidateRange(1, 120)][int]$TimeoutSeconds = 30
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $window = [RadIAKnowledgeSmokeNative]::FindVisibleWindow(
            [uint32]$IDEProcess.Id,
            "TRadIAConsentForm"
        )
        if (($window -ne [IntPtr]::Zero) -eq $Visible) {
            return $window
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "The RadIA consent dialog did not reach the expected state."
}

function Invoke-RadIASmokeToolWithConsent {
    param(
        [Parameter(Mandatory)][string]$BridgePath,
        [Parameter(Mandatory)][string]$InstanceFile,
        [Parameter(Mandatory)][Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Arguments = @{},
        [ValidateSet("Allow once", "Deny", "Cancel")]
        [string]$ConsentButtonText = "Allow once",
        [switch]$ExpectError
    )

    $requestKey = [Guid]::NewGuid().ToString("N")
    $requestRoot = Join-Path ([IO.Path]::GetTempPath()) (
        "radia-firedac-consent-$requestKey"
    )
    $inputPath = "$requestRoot.in"
    $outputPath = "$requestRoot.out"
    $errorPath = "$requestRoot.err"
    $initializeRequest = @{
        jsonrpc = "2.0"
        id = 1
        method = "initialize"
        params = @{
            protocolVersion = "2025-06-18"
            capabilities = @{}
            clientInfo = @{
                name = "radia-firedac-smoke"
                version = "1"
            }
        }
    } | ConvertTo-Json -Depth 8 -Compress
    $initializedRequest = @{
        jsonrpc = "2.0"
        method = "notifications/initialized"
        params = @{}
    } | ConvertTo-Json -Depth 4 -Compress
    $callRequest = @{
        jsonrpc = "2.0"
        id = 2
        method = "tools/call"
        params = @{
            name = $Name
            arguments = $Arguments
        }
    } | ConvertTo-Json -Depth 8 -Compress
    $requests = @($initializeRequest, $initializedRequest, $callRequest)
    Set-Content `
        -LiteralPath $inputPath `
        -Value $requests `
        -Encoding UTF8
    $bridgeProcess = $null
    try {
        $bridgeProcess = Start-Process `
            -FilePath $BridgePath `
            -ArgumentList "`"$InstanceFile`"" `
            -RedirectStandardInput $inputPath `
            -RedirectStandardOutput $outputPath `
            -RedirectStandardError $errorPath `
            -PassThru
        $consentWindow = Wait-RadIAConsentWindowState `
            -IDEProcess $IDEProcess `
            -Visible $true
        $consentButton = [RadIAKnowledgeSmokeNative]::FindChildByText(
            $consentWindow,
            $ConsentButtonText
        )
        if ($consentButton -eq [IntPtr]::Zero) {
            throw "The $ConsentButtonText consent button was not found."
        }
        [void][RadIAKnowledgeSmokeNative]::SendMessage(
            $consentButton,
            0x00F5,
            [IntPtr]0,
            [IntPtr]0
        )
        [void](Wait-RadIAConsentWindowState `
            -IDEProcess $IDEProcess `
            -Visible $false)
        if (-not $bridgeProcess.WaitForExit(120000)) {
            throw "The MCP bridge timed out while executing $Name."
        }
        $response = @(
            Get-Content -LiteralPath $outputPath |
                ForEach-Object { $_ | ConvertFrom-Json } |
                Where-Object { $_.id -eq 2 }
        ) | Select-Object -First 1
        if ($ExpectError) {
            if (-not $response -or
                (-not $response.error -and -not $response.result.isError)) {
                throw "Tool $Name unexpectedly succeeded."
            }
            return $response
        }
        if (-not $response -or $response.error -or
            $response.result.isError) {
            $details = $response | ConvertTo-Json -Depth 8 -Compress
            throw "Tool $Name failed after consent: $details"
        }
        return $response.result.structuredContent
    } finally {
        if ($bridgeProcess -and -not $bridgeProcess.HasExited) {
            Stop-Process -Id $bridgeProcess.Id -Force
            [void]$bridgeProcess.WaitForExit(5000)
        }
        foreach ($temporaryPath in @($inputPath, $outputPath, $errorPath)) {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }
        }
    }
}

function Get-RadIAStringSha256 {
    param([Parameter(Mandatory)][string]$Value)

    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        return (
            [BitConverter]::ToString($algorithm.ComputeHash($bytes))
        ).Replace("-", "").ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Invoke-RadIAFireDACReadOnlyScenario {
    param(
        [Parameter(Mandatory)][string]$BridgePath,
        [Parameter(Mandatory)][string]$InstanceFile,
        [Parameter(Mandatory)][Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory)][string]$ScenarioId,
        [Parameter(Mandatory)][string]$DelphiVersion,
        [Parameter(Mandatory)][string]$Platform,
        [string]$ProjectPath = "",
        [string]$DatabasePath = "",
        [string]$TestExecutablePath = "",
        [string]$EvidencePath = ""
    )

    $consentObserved = $false
    $consentDecision = "not-required"
    $databaseFingerprintBefore = ""
    $databaseFingerprintAfter = ""
    $artifactState = "not-applicable"
    $buildPassed = $false
    $buildFailed = $false
    $rollbackSucceeded = $false
    $smartDiffReviewed = $false
    $stalePreviewRejected = $false
    $laterChangePreserved = $false
    $migrationGatePassed = $false
    $migrationGateFailed = $false
    $projectSwitched = $false
    $projectReopened = $false
    $noStaleLocation = $false
    $analysisInFlight = $false
    $analysisProcessId = 0
    $analysisInputPath = ""
    $analysisOutputPath = ""
    $analysisErrorPath = ""
    $cleanAnalysisShutdown = $false
    $noAnalysisAccessViolation = $false
    $noOrphanAnalysisThread = $false
    $testsPassed = $false
    $results = @()
    switch ($ScenarioId) {
        "firedac-inventory-navigation" {
            $inventory = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectFireDACProject"
            $report = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetFireDACProjectReport"
            if ($inventory.connectionCount -lt 1) {
                throw "FireDAC inventory did not find the fixture connection."
            }
            if (@($inventory.components).Count -lt 2) {
                throw "FireDAC inventory did not return navigable components."
            }
            $results = @($inventory, $report)
        }
        "firedac-selected-sql-analysis" {
            if (-not $ProjectPath) {
                throw "The selected SQL scenario requires its project fixture."
            }
            $targetFile = Join-Path `
                (Split-Path -Parent $ProjectPath) `
                "RadIA.FireDAC.E2E.Data.pas"
            $selectedSql = "select id from customer where id = :Id"
            $sourceLines = @(
                (Get-Content -LiteralPath $targetFile -Raw).
                    Replace("`r`n", "`n").
                    Replace("`r", "`n").
                    Split("`n")
            )
            $sqlLine = 0
            $sqlColumn = 0
            for ($index = 0; $index -lt $sourceLines.Count; $index++) {
                $columnIndex = $sourceLines[$index].IndexOf(
                    $selectedSql,
                    [StringComparison]::Ordinal
                )
                if ($columnIndex -ge 0) {
                    $sqlLine = $index + 1
                    $sqlColumn = $columnIndex + 1
                    break
                }
            }
            if ($sqlLine -lt 1 -or $sqlColumn -lt 1) {
                throw "The SQL fixture text was not found."
            }
            $navigation = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "NavigateToFile" `
                -Arguments @{
                    fileName = $targetFile
                    line = $sqlLine
                    column = $sqlColumn
                }
            Invoke-RadIAEditorRepaint -IDEProcess $IDEProcess
            Set-RadIAEditorCaretPosition `
                -Line $sqlLine `
                -Column $sqlColumn
            Select-RadIAEditorCharacters `
                -IDEProcess $IDEProcess `
                -CharacterCount $selectedSql.Length
            $selection = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorSelection"
            if ($selection.content -ne $selectedSql) {
                $actualSelection = ConvertTo-Json $selection.content -Compress
                throw (
                    "The real editor SQL selection did not match the fixture. " +
                    "Actual selection: $actualSelection"
                )
            }
            $analysis = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "AnalyzeFireDACQuery" `
                -Arguments @{
                    sql = $selection.content
                }
            $serialized = $analysis | ConvertTo-Json -Depth 8 -Compress
            if ($analysis.sqlExecuted -ne $false) {
                throw "FireDAC query analysis reported SQL execution."
            }
            if ($serialized.Contains($selectedSql)) {
                throw "FireDAC query analysis echoed the SQL payload."
            }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            $results = @($navigation, $selection, $analysis)
        }
        "firedac-credential-redaction" {
            $configuration = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectFireDACConfiguration"
            $serialized = $configuration |
                ConvertTo-Json -Depth 8 -Compress
            if ($configuration.credentialsCollected -ne $false) {
                throw "FireDAC configuration reported credential collection."
            }
            if ($serialized.Contains("radia-e2e-secret")) {
                throw "FireDAC configuration leaked the fixture credential."
            }
            $results = @($configuration)
        }
        "firedac-unsafe-transaction" {
            $audit = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "AuditFireDACTransactions"
            $serialized = $audit | ConvertTo-Json -Depth 8 -Compress
            if (-not $serialized.Contains("firedac.transaction.rollback-missing")) {
                throw "FireDAC transaction audit did not find the missing rollback."
            }
            $results = @($audit)
        }
        "firedac-shared-thread-connection" {
            $analysis = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "AnalyzeFireDACThreadSafety"
            $serialized = $analysis | ConvertTo-Json -Depth 8 -Compress
            if (-not $serialized.Contains("firedac.thread.shared-component")) {
                throw "FireDAC thread analysis did not find shared access."
            }
            $plan = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PrepareFireDACThreadSafetyPlan" `
                -Arguments @{
                    componentType = "TFDConnection"
                    sharedConnection = $true
                    sharedDataset = $true
                    uiAccessFromWorker = $true
                    ownerScope = "shared"
                }
            $results = @($analysis, $plan)
        }
        "firedac-sqlite-grid-csv" {
            if (-not $DatabasePath) {
                throw "The SQLite grid scenario requires a database fixture."
            }
            $databaseFingerprintBefore = (
                Get-FileHash -LiteralPath $DatabasePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
            $schema = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectLocalSQLiteDatabase" `
                -Arguments @{ filePath = $DatabasePath }
            $preview = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "PreviewLocalSQLiteQuery" `
                -Arguments @{
                    filePath = $DatabasePath
                    sql = (
                        "select id, name, access_token from customer " +
                        "order by id"
                    )
                    maxRows = 2
                }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            $databaseFingerprintAfter = (
                Get-FileHash -LiteralPath $DatabasePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
            $serialized = $preview | ConvertTo-Json -Depth 8 -Compress
            if ($schema.readOnly -ne $true -or $schema.objectCount -lt 1) {
                throw "The SQLite schema inspection was not read-only and bounded."
            }
            if ($preview.rowCount -ne 2 -or $preview.truncated -ne $true) {
                throw "The SQLite preview did not return a paginated grid."
            }
            if ($preview.exportSanitized -ne $true -or
                "access_token" -notin @($preview.redactedColumns)) {
                throw "The SQLite preview did not sanitize its CSV export."
            }
            if ($serialized.Contains("radia-secret")) {
                throw "The SQLite preview leaked a fixture secret."
            }
            if ($databaseFingerprintBefore -ne $databaseFingerprintAfter) {
                throw "The read-only SQLite preview changed the database."
            }
            $results = @($schema, $preview)
        }
        "firedac-sqlite-dml-rejection" {
            if (-not $DatabasePath) {
                throw "The SQLite DML scenario requires a database fixture."
            }
            $databaseFingerprintBefore = (
                Get-FileHash -LiteralPath $DatabasePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
            $rejection = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "PreviewLocalSQLiteQuery" `
                -Arguments @{
                    filePath = $DatabasePath
                    sql = "delete from customer"
                    maxRows = 2
                } `
                -ExpectError
            $consentObserved = $true
            $consentDecision = "allowed-once"
            $databaseFingerprintAfter = (
                Get-FileHash -LiteralPath $DatabasePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
            $serialized = $rejection | ConvertTo-Json -Depth 8 -Compress
            if (-not $serialized.Contains("unsafe_sql")) {
                throw "The SQLite preview did not reject mutating SQL."
            }
            if ($databaseFingerprintBefore -ne $databaseFingerprintAfter) {
                throw "Rejected SQLite DML changed the database."
            }
            $results = @($rejection)
        }
        "firedac-repository-preview-denied" {
            $preview = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GenerateFireDACRepositoryPreview" `
                -Arguments @{
                    unitName = "RadIA.E2E.CustomerRepository"
                    entityName = "Customer"
                    tableName = "customer"
                    relativeDirectory = "Generated"
                    registerInProject = $false
                }
            if (-not $preview.previewId -or $preview.state -ne "prepared") {
                throw "The FireDAC repository preview was not prepared."
            }
            if (Test-Path -LiteralPath $preview.fileName -PathType Leaf) {
                throw "The FireDAC repository preview created a file."
            }
            $denial = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyGeneratedArtifact" `
                -Arguments @{ previewId = $preview.previewId } `
                -ConsentButtonText "Deny" `
                -ExpectError
            $consentObserved = $true
            $consentDecision = "denied"
            if (Test-Path -LiteralPath $preview.fileName -PathType Leaf) {
                throw "Denied FireDAC repository application created a file."
            }
            $results = @($preview, $denial)
        }
        "firedac-repository-applied" {
            if (-not $TestExecutablePath) {
                throw "The applied repository scenario requires DUnitX."
            }
            $preview = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GenerateFireDACRepositoryPreview" `
                -Arguments @{
                    unitName = "RadIA.E2E.CustomerRepository"
                    entityName = "Customer"
                    tableName = "customer"
                    relativeDirectory = "Generated"
                    registerInProject = $true
                }
            $applied = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyGeneratedArtifact" `
                -Arguments @{ previewId = $preview.previewId }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            if ($applied.state -ne "applied" -or
                -not (Test-Path -LiteralPath $applied.fileName -PathType Leaf)) {
                throw "The FireDAC repository artifact was not applied."
            }
            $artifactState = "applied"
            $build = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($build.success -ne $true) {
                $details = $build | ConvertTo-Json -Depth 8 -Compress
                throw "The applied FireDAC repository did not build: $details"
            }
            $buildPassed = $true
            $tests = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RunDUnitXTests" `
                -Arguments @{
                    executablePath = $TestExecutablePath
                    timeoutMs = 600000
                }
            if ($tests.status -ne "succeeded" -or
                $tests.report.allPassed -ne $true) {
                $details = $tests | ConvertTo-Json -Depth 8 -Compress
                throw "DUnitX did not pass after repository apply: $details"
            }
            $testsPassed = $true
            $results = @($preview, $applied, $build, $tests)
        }
        "firedac-build-failure-rollback" {
            if (-not $ProjectPath) {
                throw "The rollback scenario requires its project fixture."
            }
            $preview = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GenerateFireDACRepositoryPreview" `
                -Arguments @{
                    unitName = "RadIA.E2E.CustomerRepository"
                    entityName = "Customer"
                    tableName = "customer"
                    relativeDirectory = "Generated"
                    registerInProject = $true
                }
            $applied = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyGeneratedArtifact" `
                -Arguments @{ previewId = $preview.previewId }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            if ($applied.state -ne "applied" -or
                -not (Test-Path -LiteralPath $applied.fileName -PathType Leaf)) {
                throw "The rollback fixture artifact was not applied."
            }
            $artifactState = "applied"
            $build = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($build.success -ne $false -or @($build.messages).Count -lt 1) {
                throw "The intentional FireDAC build failure was not observed."
            }
            $buildFailed = $true
            $reverted = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RevertGeneratedArtifact" `
                -Arguments @{ previewId = $preview.previewId }
            if ($reverted.state -ne "reverted" -or
                (Test-Path -LiteralPath $applied.fileName -PathType Leaf)) {
                throw "The failed FireDAC build did not roll back the artifact."
            }
            $artifactState = "reverted"
            $rollbackSucceeded = $true
            $programPath = [IO.Path]::ChangeExtension($ProjectPath, ".dpr")
            $programContent = Get-Content -LiteralPath $programPath -Raw
            $programContent = $programContent.Replace(
                "  RadIAIntentionalCompilerFailure;`r`n",
                ""
            )
            Set-Content `
                -LiteralPath $programPath `
                -Value $programContent `
                -Encoding UTF8 `
                -NoNewline
            $cleanupBuild = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($cleanupBuild.success -ne $true) {
                throw "The rollback fixture did not recover its build state."
            }
            $results = @(
                $preview,
                $applied,
                $build,
                $reverted,
                $cleanupBuild
            )
        }
        "firedac-parameter-smart-diff" {
            if (-not $ProjectPath -or -not $TestExecutablePath) {
                throw "The parameter fix scenario requires project and DUnitX fixtures."
            }
            $targetFile = Join-Path `
                (Split-Path -Parent $ProjectPath) `
                "RadIA.FireDAC.E2E.Data.pas"
            Open-RadIAEditorFile `
                -IDEProcess $IDEProcess `
                -Path $targetFile
            Start-Sleep -Seconds 2
            $editor = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorContent"
            if (-not $editor.fileName -or -not $editor.revision) {
                throw "The parameter fix target did not open in the editor."
            }
            $validation = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "ValidateFireDACParameters" `
                -Arguments @{
                    sql = "select id from customer where id = :Id"
                    bindings = @(
                        @{
                            name = "Id"
                            dataType = "ftLargeint"
                            direction = "input"
                            size = 0
                            nullable = "false"
                            valueState = "value"
                            assignmentKind = "AsString"
                        }
                    )
                }
            $validationJson = $validation | ConvertTo-Json -Depth 8 -Compress
            if (-not $validationJson.Contains(
                "firedac.parameter.assignment-type-mismatch"
            )) {
                throw "The parameter validator did not prove the accessor mismatch."
            }
            $fixArguments = @{
                findingId = (
                    "firedac.parameter.accessor-mismatch:" +
                    "RadIA.FireDAC.E2E.Data.pas:Id"
                )
                confidence = "proven"
                targetFile = $targetFile
                baseRevision = $editor.revision
                queryVariable = "FQuery"
                parameterName = "Id"
                fromAccessor = "AsString"
                toAccessor = "AsLargeInt"
            }
            $preview = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PrepareFireDACParameterFix" `
                -Arguments $fixArguments
            Start-Sleep -Seconds 1
            $stableEditor = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorContent"
            if (-not $stableEditor.revision.Equals(
                $preview.baseRevision,
                [StringComparison]::OrdinalIgnoreCase
            )) {
                throw "The FireDAC parameter editor revision did not stabilize."
            }
            if ($preview.originalText -ne
                "FQuery.ParamByName('Id').AsString" -or
                $preview.replacementText -ne
                "FQuery.ParamByName('Id').AsLargeInt") {
                throw "The FireDAC parameter smart diff was not minimal."
            }
            $smartDiffReviewed = $true
            $applied = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyFireDACFix" `
                -Arguments @{ previewId = $preview.previewId }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            if ($applied.mutationApplied -ne $true) {
                throw "The FireDAC parameter fix was not applied."
            }
            $updated = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorContent"
            if (-not $updated.content.Contains(
                "FQuery.ParamByName('Id').AsLargeInt"
            )) {
                throw "The editor does not contain the applied parameter fix."
            }
            $build = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($build.success -ne $true) {
                throw "The FireDAC parameter fix did not build."
            }
            $buildPassed = $true
            $tests = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RunDUnitXTests" `
                -Arguments @{
                    executablePath = $TestExecutablePath
                    timeoutMs = 600000
                }
            if ($tests.status -ne "succeeded" -or
                $tests.report.allPassed -ne $true) {
                throw "DUnitX did not pass after the FireDAC parameter fix."
            }
            $testsPassed = $true
            $artifactState = "applied"
            $results = @($validation, $preview, $applied, $build, $tests)
        }
        "firedac-stale-preview-rejection" {
            if (-not $ProjectPath) {
                throw "The stale preview scenario requires a project fixture."
            }
            $targetFile = Join-Path `
                (Split-Path -Parent $ProjectPath) `
                "RadIA.FireDAC.E2E.Data.pas"
            Open-RadIAEditorFile `
                -IDEProcess $IDEProcess `
                -Path $targetFile
            Start-Sleep -Seconds 2
            $editor = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorContent"
            $fireDACPreview = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PrepareFireDACParameterFix" `
                -Arguments @{
                    findingId = (
                        "firedac.parameter.accessor-mismatch:" +
                        "RadIA.FireDAC.E2E.Data.pas:Id"
                    )
                    confidence = "proven"
                    targetFile = $targetFile
                    baseRevision = $editor.revision
                    queryVariable = "FQuery"
                    parameterName = "Id"
                    fromAccessor = "AsString"
                    toAccessor = "AsLargeInt"
                }
            $laterMarker = "// Later reviewed user change"
            $laterPatch = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PreparePatch" `
                -Arguments @{
                    targetFile = $targetFile
                    baseRevision = $fireDACPreview.baseRevision
                    originalText = "implementation"
                    replacementText = "implementation`r`n`r`n$laterMarker"
                }
            $laterApplied = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyPatch" `
                -Arguments @{ previewId = $laterPatch.previewId }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            $changedEditor = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorContent"
            if (-not $changedEditor.content.Contains($laterMarker)) {
                throw "The later editor change was not applied."
            }
            $rejection = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyFireDACFix" `
                -Arguments @{ previewId = $fireDACPreview.previewId } `
                -ExpectError
            $rejectionText = [string]$rejection.result.content[0].text
            if (-not $rejectionText.Contains("precondition_failed")) {
                throw "The stale FireDAC preview was not rejected by fingerprint."
            }
            $stalePreviewRejected = $true
            $changedEditor = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorContent"
            if (-not $changedEditor.content.Contains($laterMarker) -or
                $changedEditor.content.Contains(
                    "FQuery.ParamByName('Id').AsLargeInt"
                )) {
                throw "The stale preview overwrote the later editor change."
            }
            $laterChangePreserved = $true
            $reverted = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RevertPatch" `
                -Arguments @{ previewId = $laterPatch.previewId }
            $restoredEditor = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetEditorContent"
            if (-not $restoredEditor.revision.Equals(
                    $fireDACPreview.baseRevision,
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                throw "The stale preview fixture was not restored."
            }
            $artifactState = "unchanged"
            $results = @(
                $fireDACPreview,
                $laterPatch,
                $laterApplied,
                $rejection,
                $reverted
            )
        }
        "firedac-ado-migration-batch" {
            if (-not $ProjectPath -or -not $TestExecutablePath) {
                throw "The migration scenario requires project and DUnitX fixtures."
            }
            $inventory = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InventoryLegacyDataAccess"
            $adoFinding = @(
                $inventory.findings |
                    Where-Object {
                        $_.technology -eq "ADO" -and
                        $_.canPrepare -eq $true
                    }
            ) | Select-Object -First 1
            if (-not $adoFinding) {
                throw "The migration inventory did not find a preparable ADO usage."
            }
            $plan = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PlanLegacyMigrationBatches"
            $batch = @(
                $plan.batches |
                    Where-Object {
                        $_.technology -eq "ADO" -and
                        $_.canPrepare -eq $true
                    }
            ) | Select-Object -First 1
            if (-not $batch.batchId) {
                throw "The migration planner did not create a preparable ADO batch."
            }
            $prepared = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PrepareLegacyMigrationBatch" `
                -Arguments @{ batchId = $batch.batchId }
            $applied = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyLegacyMigrationBatch" `
                -Arguments @{ batchId = $batch.batchId }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            if ($applied.state -ne "applied") {
                throw "The ADO migration batch was not applied."
            }
            $fireDAC = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectFireDACProject"
            $fireDACJson = $fireDAC | ConvertTo-Json -Depth 10 -Compress
            if (-not $fireDACJson.Contains("TFDQuery")) {
                throw "The applied migration did not produce a FireDAC query."
            }
            $build = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($build.success -ne $true) {
                throw "The migrated ADO batch did not build."
            }
            $buildPassed = $true
            $tests = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RunDUnitXTests" `
                -Arguments @{
                    executablePath = $TestExecutablePath
                    timeoutMs = 600000
                }
            if ($tests.status -ne "succeeded" -or
                $tests.report.allPassed -ne $true) {
                throw "DUnitX did not pass after the ADO migration batch."
            }
            $testsPassed = $true
            $gate = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RecordLegacyMigrationGate" `
                -Arguments @{
                    batchId = $batch.batchId
                    fireDACPassed = $true
                    buildPassed = $true
                    testsPassed = $true
                    fireDACEvidence = Get-RadIAStringSha256 $fireDACJson
                    buildEvidence = Get-RadIAStringSha256 (
                        $build | ConvertTo-Json -Depth 8 -Compress
                    )
                    testEvidence = Get-RadIAStringSha256 (
                        $tests | ConvertTo-Json -Depth 8 -Compress
                    )
                }
            if ($gate.state -ne "validated") {
                throw "The ADO migration gate was not validated."
            }
            $migrationGatePassed = $true
            $artifactState = "validated"
            $results = @(
                $inventory,
                $plan,
                $prepared,
                $applied,
                $fireDAC,
                $build,
                $tests,
                $gate
            )
        }
        "firedac-migration-gate-rollback" {
            if (-not $ProjectPath -or -not $TestExecutablePath) {
                throw "The migration rollback requires project and DUnitX fixtures."
            }
            $targetFile = Join-Path `
                (Split-Path -Parent $ProjectPath) `
                "RadIA.FireDAC.E2E.Data.pas"
            $originalFileHash = (
                Get-FileHash -LiteralPath $targetFile -Algorithm SHA256
            ).Hash
            $inventory = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InventoryLegacyDataAccess"
            $plan = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PlanLegacyMigrationBatches"
            $batch = @(
                $plan.batches |
                    Where-Object {
                        $_.technology -eq "ADO" -and
                        $_.canPrepare -eq $true
                    }
            ) | Select-Object -First 1
            if (-not $batch.batchId) {
                throw "The rollback planner did not create an ADO batch."
            }
            $prepared = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PrepareLegacyMigrationBatch" `
                -Arguments @{ batchId = $batch.batchId }
            $applied = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyLegacyMigrationBatch" `
                -Arguments @{ batchId = $batch.batchId }
            $consentObserved = $true
            $consentDecision = "allowed-once"
            if ($applied.state -ne "applied") {
                throw "The rollback migration batch was not applied."
            }
            $fireDAC = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectFireDACProject"
            $fireDACJson = $fireDAC | ConvertTo-Json -Depth 10 -Compress
            if (-not $fireDACJson.Contains("TFDQuery")) {
                throw "The rollback batch did not reach its FireDAC gate."
            }
            $programPath = [IO.Path]::ChangeExtension($ProjectPath, ".dpr")
            $programContent = Get-Content -LiteralPath $programPath -Raw
            $failurePatch = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PreparePatch" `
                -Arguments @{
                    targetFile = $programPath
                    baseRevision = Get-RadIAStringSha256 $programContent
                    originalText = "begin`r`nend."
                    replacementText = (
                        "begin`r`n" +
                        "  RadIAIntentionalCompilerFailure;`r`n" +
                        "end."
                    )
                }
            $failureApplied = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "ApplyPatch" `
                -Arguments @{ previewId = $failurePatch.previewId }
            Save-RadIAActiveEditor -IDEProcess $IDEProcess
            $failedBuild = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($failedBuild.success -ne $false) {
                throw "The migration rollback build gate did not fail."
            }
            $buildFailed = $true
            $failureReverted = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RevertPatch" `
                -Arguments @{ previewId = $failurePatch.previewId }
            Save-RadIAActiveEditor -IDEProcess $IDEProcess
            $recoveryBuild = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($recoveryBuild.success -ne $true) {
                throw "The reverted compiler failure did not recover the build."
            }
            $tests = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RunDUnitXTests" `
                -Arguments @{
                    executablePath = $TestExecutablePath
                    timeoutMs = 600000
                }
            if ($tests.status -ne "succeeded" -or
                $tests.report.allPassed -ne $true) {
                throw "DUnitX did not pass before the migration rollback gate."
            }
            $testsPassed = $true
            $gate = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RecordLegacyMigrationGate" `
                -Arguments @{
                    batchId = $batch.batchId
                    fireDACPassed = $true
                    buildPassed = $false
                    testsPassed = $true
                    fireDACEvidence = Get-RadIAStringSha256 $fireDACJson
                    buildEvidence = Get-RadIAStringSha256 (
                        $failedBuild | ConvertTo-Json -Depth 8 -Compress
                    )
                    testEvidence = Get-RadIAStringSha256 (
                        $tests | ConvertTo-Json -Depth 8 -Compress
                    )
                }
            if ($gate.state -ne "reverted") {
                throw "The failed migration gate did not revert its batch."
            }
            $restoredFileHash = (
                Get-FileHash -LiteralPath $targetFile -Algorithm SHA256
            ).Hash
            $restoredContent = Get-Content -LiteralPath $targetFile -Raw
            if (-not $restoredFileHash.Equals(
                    $originalFileHash,
                    [StringComparison]::OrdinalIgnoreCase
                ) -or
                -not $restoredContent.Contains("TADOQuery") -or
                $restoredContent.Contains("TFDQuery")) {
                throw "The failed gate did not restore the legacy source."
            }
            $migrationGateFailed = $true
            $rollbackSucceeded = $true
            $artifactState = "reverted"
            $results = @(
                $inventory,
                $plan,
                $prepared,
                $applied,
                $fireDAC,
                $failurePatch,
                $failureApplied,
                $failedBuild,
                $failureReverted,
                $recoveryBuild,
                $tests,
                $gate
            )
        }
        "firedac-project-context-reset" {
            if (-not $ProjectPath) {
                throw "The project context scenario requires its project fixture."
            }
            $initialProject = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetActiveProject"
            $initialInventory = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectFireDACProject"
            $initialReport = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetFireDACProjectReport"
            $initialJson = @($initialInventory, $initialReport) |
                ConvertTo-Json -Depth 10 -Compress
            $fixtureUnit = Join-Path `
                (Split-Path -Parent $ProjectPath) `
                "RadIA.FireDAC.E2E.Data.pas"
            $fixtureUnitName = Split-Path -Leaf $fixtureUnit
            if (-not $initialJson.Contains($fixtureUnitName)) {
                throw "The initial FireDAC context did not expose its fixture unit."
            }
            $transitionDirectory = Join-Path `
                (Split-Path -Parent $ProjectPath) `
                "Transition"
            $transitionPreview = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "PreviewProjectTemplate" `
                -Arguments @{
                    projectName = "RadIAFireDACTransition"
                    template = "vcl"
                    delphiVersion = $DelphiVersion
                    platforms = @("Win32")
                    destinationPath = $transitionDirectory
                    projectSpecification = @{
                        schemaVersion = 1
                        kind = "blank"
                        creationProfile = "essential"
                    }
                }
            $transitionCreated = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "CreateProjectFromTemplate" `
                -Arguments @{ previewId = $transitionPreview.previewId }
            if ($transitionCreated.committed -ne $true) {
                throw "The transition project was not created."
            }
            $transitionOpened = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "OpenCreatedProject" `
                -Arguments @{ previewId = $transitionPreview.previewId }
            if ($transitionOpened.opened -ne $true) {
                throw "The transition project was not opened."
            }
            $transitionProject = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetActiveProject"
            if ($transitionProject.fileName -eq $initialProject.fileName) {
                throw "The active project did not switch."
            }
            $projectSwitched = $true
            $transitionInventory = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectFireDACProject"
            $transitionReport = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetFireDACProjectReport"
            $transitionJson = @($transitionInventory, $transitionReport) |
                ConvertTo-Json -Depth 10 -Compress
            if ($transitionJson.Contains($fixtureUnitName)) {
                throw "The transition project retained a stale FireDAC location."
            }
            $noStaleLocation = $true
            $transitionReverted = Invoke-RadIASmokeToolWithConsent `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -IDEProcess $IDEProcess `
                -Name "RevertCreatedProject" `
                -Arguments @{ previewId = $transitionPreview.previewId }
            if ($transitionReverted.rolledBack -ne $true) {
                throw "The transition project was not reverted."
            }
            $reopenedProject = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetActiveProject"
            if (-not [IO.Path]::GetFullPath(
                    $reopenedProject.fileName
                ).Equals(
                    [IO.Path]::GetFullPath($ProjectPath),
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                throw "The original FireDAC project was not reopened."
            }
            $reopenedInventory = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "InspectFireDACProject"
            $reopenedJson = $reopenedInventory |
                ConvertTo-Json -Depth 10 -Compress
            if (-not $reopenedJson.Contains($fixtureUnitName)) {
                throw "The reopened FireDAC context did not restore its location."
            }
            $projectReopened = $true
            $consentObserved = $true
            $consentDecision = "allowed-once"
            $artifactState = "unchanged"
            $results = @(
                $initialProject,
                $initialInventory,
                $initialReport,
                $transitionPreview,
                $transitionCreated,
                $transitionOpened,
                $transitionProject,
                $transitionInventory,
                $transitionReport,
                $transitionReverted,
                $reopenedProject,
                $reopenedInventory
            )
        }
        "firedac-shutdown-during-analysis" {
            $requestKey = [Guid]::NewGuid().ToString("N")
            $requestRoot = Join-Path `
                ([IO.Path]::GetTempPath()) `
                "radia-firedac-shutdown-$requestKey"
            $analysisInputPath = "$requestRoot.in"
            $analysisOutputPath = "$requestRoot.out"
            $analysisErrorPath = "$requestRoot.err"
            $analysisRequests = @(
                @{
                    jsonrpc = "2.0"
                    id = 1
                    method = "initialize"
                    params = @{
                        protocolVersion = "2025-06-18"
                        capabilities = @{}
                        clientInfo = @{
                            name = "radia-firedac-shutdown"
                            version = "1"
                        }
                    }
                } | ConvertTo-Json -Depth 8 -Compress
                @{
                    jsonrpc = "2.0"
                    method = "notifications/initialized"
                    params = @{}
                } | ConvertTo-Json -Depth 4 -Compress
            )
            for ($requestId = 2; $requestId -le 33; $requestId++) {
                $toolName = if (($requestId % 2) -eq 0) {
                    "InspectFireDACProject"
                } else {
                    "AnalyzeFireDACThreadSafety"
                }
                $analysisRequests += @{
                    jsonrpc = "2.0"
                    id = $requestId
                    method = "tools/call"
                    params = @{
                        name = $toolName
                        arguments = @{}
                    }
                } | ConvertTo-Json -Depth 6 -Compress
            }
            Set-Content `
                -LiteralPath $analysisInputPath `
                -Value $analysisRequests `
                -Encoding UTF8
            $analysisProcess = Start-Process `
                -FilePath $BridgePath `
                -ArgumentList "`"$InstanceFile`"" `
                -RedirectStandardInput $analysisInputPath `
                -RedirectStandardOutput $analysisOutputPath `
                -RedirectStandardError $analysisErrorPath `
                -WindowStyle Hidden `
                -PassThru
            Start-Sleep -Milliseconds 100
            if ($analysisProcess.HasExited) {
                throw "The FireDAC analysis completed before shutdown began."
            }
            $analysisInFlight = $true
            $analysisProcessId = $analysisProcess.Id
            $artifactState = "unchanged"
            $results = @(
                [PSCustomObject]@{
                    analysisInFlight = $true
                    requestedAnalysisCount = 32
                }
            )
        }
        default {
            throw "FireDAC IDE scenario is not connected yet: $ScenarioId"
        }
    }

    $fingerprints = @(
        $results | ForEach-Object {
            Get-RadIAStringSha256 `
                -Value ($_ | ConvertTo-Json -Depth 10 -Compress)
        }
    )
    $evidence = [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "fireDACAdvisorIDE"
        scenarioId = $ScenarioId
        delphiVersion = $DelphiVersion
        platform = $Platform
        status = "passed"
        consentObserved = $consentObserved
        consentDecision = $consentDecision
        databaseFingerprintBefore = $databaseFingerprintBefore
        databaseFingerprintAfter = $databaseFingerprintAfter
        artifactState = $artifactState
        buildPassed = $buildPassed
        buildFailed = $buildFailed
        rollbackSucceeded = $rollbackSucceeded
        smartDiffReviewed = $smartDiffReviewed
        stalePreviewRejected = $stalePreviewRejected
        laterChangePreserved = $laterChangePreserved
        migrationGatePassed = $migrationGatePassed
        migrationGateFailed = $migrationGateFailed
        projectSwitched = $projectSwitched
        projectReopened = $projectReopened
        noStaleLocation = $noStaleLocation
        analysisInFlight = $analysisInFlight
        analysisProcessId = $analysisProcessId
        analysisInputPath = $analysisInputPath
        analysisOutputPath = $analysisOutputPath
        analysisErrorPath = $analysisErrorPath
        cleanAnalysisShutdown = $cleanAnalysisShutdown
        noAnalysisAccessViolation = $noAnalysisAccessViolation
        noOrphanAnalysisThread = $noOrphanAnalysisThread
        testsPassed = $testsPassed
        resultFingerprints = $fingerprints
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    }
    if ($EvidencePath) {
        $resolvedEvidence = [IO.Path]::GetFullPath($EvidencePath)
        $outputRoot = [IO.Path]::GetFullPath(
            (Join-Path $script:repositoryRoot "Output")
        )
        if (-not $resolvedEvidence.StartsWith(
            $outputRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "FireDAC IDE evidence must remain inside Output."
        }
        New-Item `
            -ItemType Directory `
            -Path (Split-Path -Parent $resolvedEvidence) `
            -Force |
            Out-Null
        $evidence | ConvertTo-Json -Depth 6 |
            Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8
    }
    return $evidence
}

function Invoke-RadIAKnowledgeDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$BridgePath,
        [Parameter(Mandatory)]
        [string]$InstanceFile,
        [Parameter(Mandatory)]
        [string]$ProjectPath
    )

    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    $activeProject = $null
    do {
        try {
            $activeProject = Invoke-RadIASmokeTool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetActiveProject"
        } catch {
            $activeProject = $null
        }
        if (-not $activeProject.fileName) {
            Start-Sleep -Seconds 1
        }
    } while (
        -not $activeProject.fileName -and
        [DateTime]::UtcNow -lt $deadline
    )
    if (-not $activeProject.fileName) {
        throw "No active project was found for the knowledge smoke."
    }
    if (-not [IO.Path]::GetFullPath($activeProject.fileName).Equals(
        [IO.Path]::GetFullPath($ProjectPath),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "The knowledge smoke project did not become active."
    }

    $index = Invoke-RadIASmokeTool `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -Name "IndexProjectKnowledge"
    if (
        $index.indexedFiles -lt 2 -or
        $index.projectId -ne $activeProject.fileName -or
        $null -eq $index.durationMs
    ) {
        throw "The semantic knowledge index is incomplete."
    }
    $search = Invoke-RadIASmokeTool `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -Name "SearchProjectKnowledge" `
        -Arguments @{
            query = "locate source declaration"
            maxResults = 10
        }
    $semanticHits = @(
        $search.results |
            Where-Object {
                $_.vectorScore -gt 0 -and
                $_.embeddingProvider -eq "local-hash-v1"
            }
    )
    if (
        $search.count -lt 1 -or
        $semanticHits.Count -lt 1 -or
        $search.projectId -ne $index.projectId -or
        $null -eq $search.durationMs
    ) {
        throw "The local semantic search did not return a vector hit."
    }
    $hit = $semanticHits[0]
    if (
        -not $hit.fileName -or
        -not $hit.revision -or
        -not $hit.explanation -or
        $hit.startLine -lt 1 -or
        $hit.navigation.tool -ne "NavigateToFile"
    ) {
        throw "The semantic result does not contain traceable provenance."
    }
    $status = Invoke-RadIASmokeTool `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -Name "GetKnowledgeStatus"
    if (
        $status.projectId -ne $index.projectId -or
        $status.loaded -ne $true -or
        $status.fileCount -lt 2 -or
        $status.chunkCount -lt 2 -or
        $status.estimatedIndexBytes -lt 1
    ) {
        throw "The knowledge status does not prove the isolated index."
    }
    $document = Invoke-RadIASmokeTool `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -Name "GetKnowledgeDocument" `
        -Arguments @{
            fileName = $hit.fileName
            maxCharacters = 8192
        }
    if (
        $document.projectId -ne $index.projectId -or
        $document.chunks.Count -lt 1
    ) {
        throw "The cited knowledge document could not be retrieved."
    }
    return [PSCustomObject]@{
        ProjectId = $index.projectId
        IndexedFiles = $index.indexedFiles
        IndexDurationMs = $index.durationMs
        SearchDurationMs = $search.durationMs
        ResultCount = $search.count
        SemanticHitCount = $semanticHits.Count
        Provider = "local-hash-v1"
        FileName = $hit.fileName
        StartLine = $hit.startLine
        Explanation = $hit.explanation
        NavigationTool = $hit.navigation.tool
        EstimatedIndexBytes = $status.estimatedIndexBytes
        ChunkCount = $status.chunkCount
        DocumentRetrieved = $true
        WorkspaceIsolated = $true
    }
}

function Invoke-RadIAFirstValueDiagnostic {
    param(
        [Parameter(Mandatory)]
        [string]$BridgePath,
        [Parameter(Mandatory)]
        [string]$InstanceFile,
        [Parameter(Mandatory)]
        [int]$ExpectedToolCount
    )

    $health = Invoke-RadIASmokeTool `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -Name "GetInstallationHealth"
    if (
        -not $health.status -or
        $null -eq $health.readinessScore -or
        $health.readinessScore -lt 0 -or
        $health.readinessScore -gt 100 -or
        $health.toolCount -ne $ExpectedToolCount
    ) {
        throw "The installation health summary is incomplete."
    }
    if (
        $health.mcpBridgeAvailable -ne $true -or
        $health.interactiveTerminal -ne $true -or
        $health.webAssetsAvailable -ne $true -or
        $health.firstToolReady -ne $true -or
        $health.checks.terminal -ne $true -or
        $health.checks.chat -ne $true -or
        $health.checks.firstTool -ne $true
    ) {
        throw "The installed first-value infrastructure is not ready."
    }
    if (-not $health.executor -or -not $health.nextAction) {
        throw "The installation doctor did not provide a next action."
    }
    $ideState = Invoke-RadIASmokeTool `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -Name "GetIDEState"
    if (-not $ideState.versionName -or -not $ideState.platform) {
        throw "The first read-only IDE tool did not return IDE state."
    }
    return [PSCustomObject]@{
        Status = $health.status
        ReadinessScore = $health.readinessScore
        ProviderConfigured = $health.providerConfigured
        Executor = $health.executor
        CliRequired = $health.cliRequired
        CliDetected = $health.cliDetected
        McpBridgeAvailable = $health.mcpBridgeAvailable
        McpConfigured = $health.mcpConfigured
        McpRequired = $health.mcpRequired
        TerminalReady = $health.interactiveTerminal
        ChatReady = $health.webAssetsAvailable
        FirstToolReady = $health.firstToolReady
        NextAction = $health.nextAction
        FirstToolName = "GetIDEState"
        IDEVersion = $ideState.versionName
        IDEPlatform = $ideState.platform
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
    if ($script:InlineLogHadWindowVisible) {
        Set-ItemProperty `
            -LiteralPath $script:InlineLogRegistryPath `
            -Name "WindowVisible" `
            -Value $script:InlineLogOriginalWindowVisible
    } else {
        Remove-ItemProperty `
            -LiteralPath $script:InlineLogRegistryPath `
            -Name "WindowVisible" `
            -ErrorAction SilentlyContinue
    }
    if (-not $script:InlineLogHadRegistryKey) {
        Remove-Item `
            -LiteralPath $script:InlineLogRegistryPath `
            -ErrorAction SilentlyContinue
    }
}

function Restore-RadIAKnowledgeSettings {
    if (-not $script:KnowledgeSettingsInitialized) {
        return
    }
    if ($script:KnowledgeHadSemanticEnabled) {
        Set-ItemProperty `
            -LiteralPath $script:KnowledgeRegistryPath `
            -Name "KnowledgeSemanticEnabled" `
            -Value $script:KnowledgeOriginalSemanticEnabled
    } else {
        Remove-ItemProperty `
            -LiteralPath $script:KnowledgeRegistryPath `
            -Name "KnowledgeSemanticEnabled" `
            -ErrorAction SilentlyContinue
    }
    if ($script:KnowledgeHadWindowVisible) {
        Set-ItemProperty `
            -LiteralPath $script:KnowledgeRegistryPath `
            -Name "WindowVisible" `
            -Value $script:KnowledgeOriginalWindowVisible
    } else {
        Remove-ItemProperty `
            -LiteralPath $script:KnowledgeRegistryPath `
            -Name "WindowVisible" `
            -ErrorAction SilentlyContinue
    }
    if (-not $script:KnowledgeHadRegistryKey) {
        Remove-Item `
            -LiteralPath $script:KnowledgeRegistryPath `
            -ErrorAction SilentlyContinue
    }
}

function Get-RadIACleanSourceCommit {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,
        [Parameter(Mandatory)]
        [string]$EvidenceName
    )

    & git -C $RepositoryRoot diff --quiet
    $sourceDirty = $LASTEXITCODE -ne 0
    & git -C $RepositoryRoot diff --cached --quiet
    $sourceDirty = $sourceDirty -or ($LASTEXITCODE -ne 0)
    if ($sourceDirty) {
        throw "$EvidenceName evidence requires a clean tracked source."
    }
    $sourceCommit = (
        & git -C $RepositoryRoot rev-parse HEAD
    ).Trim()
    if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch "^[0-9a-f]{40}$") {
        throw "The source commit could not be resolved."
    }
    return $sourceCommit
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
$toolManifestPath = Join-Path $repositoryRoot "docs\reference\runtime_tools.json"
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
$inlineReviewActivationUnitPath = ""
$inlineSmokeLogPath = ""
$terminalSmokeRoot = ""
$webViewSmokeRoot = ""
$agentSmokeCheckpointDirectory = ""
$script:InlineLogSettingsInitialized = $false
$script:KnowledgeSettingsInitialized = $false

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
    if (Get-Command `
        Restore-RadIAKnowledgeSettings `
        -ErrorAction SilentlyContinue) {
        Restore-RadIAKnowledgeSettings
    }
    Write-Error (
        $_.Exception.Message + [Environment]::NewLine +
        $_.ScriptStackTrace
    )
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
if ($FireDACScenarioId) {
    $shutdownTimeoutMs = 120000
}
if ($ExerciseKnowledge) {
    $shutdownTimeoutMs = 60000
}
if ($ExerciseKnowledge) {
    $script:KnowledgeRegistryPath = (
        "HKCU:\Software\Embarcadero\BDS\" +
        "$DelphiVersion\RadIA"
    )
    $script:KnowledgeHadRegistryKey = Test-Path `
        -LiteralPath $script:KnowledgeRegistryPath
    if (-not $script:KnowledgeHadRegistryKey) {
        New-Item `
            -Path $script:KnowledgeRegistryPath `
            -Force |
            Out-Null
    }
    $knowledgeProperties = Get-ItemProperty `
        -LiteralPath $script:KnowledgeRegistryPath
    $semanticProperty = $knowledgeProperties.PSObject.Properties[
        "KnowledgeSemanticEnabled"
    ]
    $knowledgeWindowProperty = (
        $knowledgeProperties.PSObject.Properties["WindowVisible"]
    )
    $script:KnowledgeHadSemanticEnabled = $null -ne $semanticProperty
    $script:KnowledgeOriginalSemanticEnabled = $null
    if ($script:KnowledgeHadSemanticEnabled) {
        $script:KnowledgeOriginalSemanticEnabled = (
            $semanticProperty.Value
        )
    }
    $script:KnowledgeHadWindowVisible = (
        $null -ne $knowledgeWindowProperty
    )
    $script:KnowledgeOriginalWindowVisible = $null
    if ($script:KnowledgeHadWindowVisible) {
        $script:KnowledgeOriginalWindowVisible = (
            $knowledgeWindowProperty.Value
        )
    }
    New-ItemProperty `
        -LiteralPath $script:KnowledgeRegistryPath `
        -Name "KnowledgeSemanticEnabled" `
        -PropertyType DWord `
        -Value 1 `
        -Force |
        Out-Null
    New-ItemProperty `
        -LiteralPath $script:KnowledgeRegistryPath `
        -Name "WindowVisible" `
        -PropertyType DWord `
        -Value 0 `
        -Force |
        Out-Null
    $script:KnowledgeSettingsInitialized = $true
    $knowledgeSmokeProjectPath = Join-Path `
        $repositoryRoot `
        "Tests\RadIATests.dproj"
    if (-not (
        Test-Path -LiteralPath $knowledgeSmokeProjectPath -PathType Leaf
    )) {
        throw "The knowledge smoke project was not found."
    }
}
if ($ExerciseTerminal) {
    $terminalSmokeRoot = Join-Path (
        "$repositoryRoot\Output\Validation\IDESmokeDiagnostics"
    ) (
        "Terminal-$DelphiVersion-$platform-" +
        [Guid]::NewGuid().ToString("N")
    )
    New-Item `
        -ItemType Directory `
        -Path $terminalSmokeRoot `
        -Force |
        Out-Null
}
if ($ExerciseWebViewLifecycle) {
    $webViewSmokeRoot = Join-Path (
        "$repositoryRoot\Output\Validation\IDESmokeDiagnostics"
    ) (
        "WebView-$DelphiVersion-$platform-" +
        [Guid]::NewGuid().ToString("N")
    )
    New-Item `
        -ItemType Directory `
        -Path $webViewSmokeRoot `
        -Force |
        Out-Null
}
if ($ExerciseInlineCompletion -or $ExerciseInlineReview -or
    $ExerciseAgentRuntime -or
    $ExerciseDeclarativeWorkflow) {
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
    $inlineLogWindowVisible = $inlineLogProperties.PSObject.Properties[
        "WindowVisible"
    ]
    $script:InlineLogHadEnabled = $null -ne $inlineLogEnabled
    $script:InlineLogHadPath = $null -ne $inlineLogPath
    $script:InlineLogHadWindowVisible = (
        $null -ne $inlineLogWindowVisible
    )
    $script:InlineLogOriginalEnabled = $null
    $script:InlineLogOriginalPath = $null
    $script:InlineLogOriginalWindowVisible = $null
    if ($script:InlineLogHadEnabled) {
        $script:InlineLogOriginalEnabled = $inlineLogEnabled.Value
    }
    if ($script:InlineLogHadPath) {
        $script:InlineLogOriginalPath = $inlineLogPath.Value
    }
    if ($script:InlineLogHadWindowVisible) {
        $script:InlineLogOriginalWindowVisible = (
            $inlineLogWindowVisible.Value
        )
    }
    $inlineSmokeRoot = Join-Path (
        "$repositoryRoot\Output\Validation\IDESmokeDiagnostics"
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
    if ($ExerciseInlineCompletion -or $ExerciseInlineReview) {
        $inlineSmokeProjectPath = Join-Path `
            $repositoryRoot `
            "Tests\RadIATests.dproj"
        $inlineSmokeUnitPath = Join-Path `
            $repositoryRoot `
            "Tests\Source\RadIA.Tests.TextNormalizer.pas"
        $inlineReviewActivationUnitPath = Join-Path `
            $repositoryRoot `
            "Tests\Source\RadIA.Tests.AgentExecutors.pas"
        if (-not (
            Test-Path -LiteralPath $inlineSmokeProjectPath -PathType Leaf
        ) -or -not (
            Test-Path -LiteralPath $inlineSmokeUnitPath -PathType Leaf
        ) -or -not (
            Test-Path `
                -LiteralPath $inlineReviewActivationUnitPath `
                -PathType Leaf
        )) {
            throw "Inline editor smoke sources were not found."
        }
    }
    if ($ExerciseAgentRuntime) {
        $agentSmokeCheckpointDirectory = Join-Path `
            $inlineSmokeRoot `
            "AgentCheckpoints"
        New-Item `
            -ItemType Directory `
            -Path $agentSmokeCheckpointDirectory `
            -Force |
            Out-Null
    }
    if ($ExerciseDeclarativeWorkflow) {
        $declarativeWorkflowOutputDirectory = Join-Path `
            $inlineSmokeRoot `
            "DeclarativeWorkflow"
        New-Item `
            -ItemType Directory `
            -Path $declarativeWorkflowOutputDirectory `
            -Force |
            Out-Null
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
    New-ItemProperty `
        -LiteralPath $script:InlineLogRegistryPath `
        -Name "WindowVisible" `
        -PropertyType DWord `
        -Value 0 `
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
        ) "Output\Evidence\release_evidence_$expectedVersion.json"
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
    $webViewTransitions = 0
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
        $launchArguments = @(
            $inlineSmokeProjectPath,
            $inlineSmokeUnitPath
        )
    } elseif ($ExerciseInlineReview) {
        $launchArguments = @($inlineSmokeProjectPath)
    }
    if ($ExerciseKnowledge) {
        $launchArguments = @($knowledgeSmokeProjectPath)
    }
    if ($FireDACScenarioId) {
        $launchArguments = @($FireDACProjectPath)
    }
    $terminalSmokePath = ""
    if ($ExerciseTerminal) {
        $terminalSmokePath = Join-Path `
            $terminalSmokeRoot `
            "cycle-$cycle.json"
    }
    $webViewSmokePath = ""
    if ($ExerciseWebViewLifecycle) {
        $webViewSmokePath = Join-Path `
            $webViewSmokeRoot `
            "cycle-$cycle.json"
    }
    $inlineSmokeEnvironment = $env:RADIA_IDE_SMOKE_INLINE_COMPLETION
    $inlineReviewSmokeEnvironment = $env:RADIA_IDE_SMOKE_INLINE_REVIEW
    $inlineReviewSmokePath = ""
    if ($ExerciseInlineReview) {
        $inlineReviewSmokePath = Join-Path `
            $inlineSmokeRoot `
            "review-cycle-$cycle.json"
    }
    $terminalSmokeEnvironment = $env:RADIA_IDE_SMOKE_TERMINAL
    $webViewSmokeEnvironment = (
        $env:RADIA_IDE_SMOKE_WEBVIEW_LIFECYCLE
    )
    $agentSmokeEnvironment = $env:RADIA_IDE_SMOKE_AGENT_RUNTIME
    $workflowSmokeEnvironment = (
        $env:RADIA_IDE_SMOKE_DECLARATIVE_WORKFLOW
    )
    try {
        if ($ExerciseInlineCompletion) {
            $env:RADIA_IDE_SMOKE_INLINE_COMPLETION = "1"
        }
        if ($ExerciseInlineReview) {
            $env:RADIA_IDE_SMOKE_INLINE_REVIEW = $inlineReviewSmokePath
        }
        if ($ExerciseTerminal) {
            $env:RADIA_IDE_SMOKE_TERMINAL = $terminalSmokePath
        }
        if ($ExerciseWebViewLifecycle) {
            $env:RADIA_IDE_SMOKE_WEBVIEW_LIFECYCLE = $webViewSmokePath
        }
        if ($ExerciseAgentRuntime) {
            $env:RADIA_IDE_SMOKE_AGENT_RUNTIME = (
                $agentSmokeCheckpointDirectory
            )
        }
        if ($ExerciseDeclarativeWorkflow) {
            $env:RADIA_IDE_SMOKE_DECLARATIVE_WORKFLOW = (
                $declarativeWorkflowOutputDirectory
            )
        }
        if ($launchArguments.Count -gt 0) {
            $process = Start-Process `
                -FilePath $bdsPath `
                -ArgumentList $launchArguments `
                -PassThru
        } else {
            $process = Start-Process `
                -FilePath $bdsPath `
                -PassThru
        }
    } finally {
        $env:RADIA_IDE_SMOKE_INLINE_COMPLETION = $inlineSmokeEnvironment
        $env:RADIA_IDE_SMOKE_INLINE_REVIEW = $inlineReviewSmokeEnvironment
        $env:RADIA_IDE_SMOKE_TERMINAL = $terminalSmokeEnvironment
        $env:RADIA_IDE_SMOKE_WEBVIEW_LIFECYCLE = (
            $webViewSmokeEnvironment
        )
        $env:RADIA_IDE_SMOKE_AGENT_RUNTIME = $agentSmokeEnvironment
        $env:RADIA_IDE_SMOKE_DECLARATIVE_WORKFLOW = (
            $workflowSmokeEnvironment
        )
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
        if ($ExerciseInlineCompletion -or $ExerciseInlineReview) {
            $currentProcess = Get-Process -Id $process.Id -ErrorAction Stop
            $currentProcess.Refresh()
            if ($currentProcess.MainWindowHandle -ne [IntPtr]::Zero) {
                [void][RadIAKnowledgeSmokeNative]::ShowWindow(
                    $currentProcess.MainWindowHandle,
                    9
                )
                [void][RadIAKnowledgeSmokeNative]::SetForegroundWindow(
                    $currentProcess.MainWindowHandle
                )
                Start-Sleep -Milliseconds 500
            }
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
        $fireDACDiagnostic = $null
        if ($FireDACScenarioId) {
            $fireDACDiagnostic = Invoke-RadIAFireDACReadOnlyScenario `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -ScenarioId $FireDACScenarioId `
                -DelphiVersion $DelphiVersion `
                -Platform $platform `
                -ProjectPath $FireDACProjectPath `
                -DatabasePath $FireDACDatabasePath `
                -TestExecutablePath $FireDACTestExecutablePath `
                -EvidencePath $FireDACEvidencePath
        }
        $terminalDiagnostic = $null
        if ($ExerciseTerminal) {
            $terminalDiagnostic = Wait-RadIATerminalDiagnostic `
                -EvidencePath $terminalSmokePath `
                -TimeoutSeconds 60
        }
        $webViewDiagnostic = $null
        if ($ExerciseWebViewLifecycle) {
            $webViewDiagnostic = Wait-RadIAWebViewLifecycleDiagnostic `
                -EvidencePath $webViewSmokePath `
                -TimeoutSeconds 90
            $webViewTransitions = Invoke-RadIAWebViewHostTransitions `
                -DockInfo $dockInfo `
                -TransitionCount $WebViewTransitionCount
        }
        $inlineDiagnostic = $null
        if ($ExerciseInlineCompletion -or $ExerciseInlineReview) {
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
                ),
                (
                    '{"jsonrpc":"2.0","id":5,"method":"tools/call",' +
                    '"params":{"name":"GetCursorPosition","arguments":{}}}'
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
                $positionResponse = $editorResponses |
                    Where-Object { $_.id -eq 5 }
                $editorPosition = $positionResponse.result.structuredContent
                if (-not $editorContent.fileName) {
                    Start-Sleep -Seconds 2
                }
            } while (
                -not $editorContent.fileName -and
                [DateTime]::UtcNow -lt $editorDeadline
            )
            if (-not $editorContent.fileName) {
                throw "No active editor was found for inline diagnostics."
            }
            if (-not $editorPosition.line) {
                throw "No active cursor was found for inline diagnostics."
            }
            Start-Sleep -Milliseconds 500
        }
        if ($ExerciseInlineCompletion) {
            Invoke-RadIAEditorRepaint -IDEProcess $process
            $inlineDiagnostic = Wait-RadIAInlineCompletionDiagnostic `
                -LogPath $inlineSmokeLogPath `
                -FileName (
                    [IO.Path]::GetFileName($editorContent.fileName)
                )
        }
        if ($ExerciseInlineReview) {
            $reviewUnitIsActive = (
                $editorContent.fileName -and
                [IO.Path]::GetFullPath($editorContent.fileName).Equals(
                    [IO.Path]::GetFullPath($inlineSmokeUnitPath),
                    [StringComparison]::OrdinalIgnoreCase
                )
            )
            if (-not $reviewUnitIsActive) {
                Open-RadIAEditorFile `
                    -IDEProcess $process `
                    -Path $inlineSmokeUnitPath
                Start-Sleep -Seconds 2
            }
            $editorContent = Invoke-RadIASmokeTool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetEditorContent"
            $editorPosition = Invoke-RadIASmokeTool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetCursorPosition"
            $reviewFileMatches = (
                $editorContent.fileName -and
                [IO.Path]::GetFullPath($editorContent.fileName).Equals(
                    [IO.Path]::GetFullPath($inlineSmokeUnitPath),
                    [StringComparison]::OrdinalIgnoreCase
                )
            )
            if (-not $reviewFileMatches -or
                -not $editorPosition.line) {
                throw "The review smoke did not activate the expected unit."
            }
        }
        $inlineReviewDiagnostic = $null
        $blockReviewDiagnostic = $null
        if ($ExerciseInlineReview) {
            $publishArguments = @{
                fileName = $editorContent.fileName
                baseRevision = $editorContent.revision
                startLine = $editorPosition.line
                endLine = $editorPosition.line
                severity = "warning"
                message = "RadIA real IDE inline review smoke."
            } | ConvertTo-Json -Compress
            $publishRequests = @(
                (
                    '{"jsonrpc":"2.0","id":1,"method":"initialize",' +
                    '"params":{"protocolVersion":"2025-06-18",' +
                    '"capabilities":{},"clientInfo":{' +
                    '"name":"radia-review-smoke","version":"1"}}}'
                ),
                (
                    '{"jsonrpc":"2.0","method":' +
                    '"notifications/initialized","params":{}}'
                ),
                (
                    '{"jsonrpc":"2.0","id":5,"method":"tools/call",' +
                    '"params":{"name":"PublishInlineReview",' +
                    '"arguments":' + $publishArguments + '}}'
                )
            )
            $publishResponses = @()
            $publishSucceeded = $false
            for ($attempt = 1; $attempt -le 10; $attempt++) {
                $publishResponseLines = @()
                $publishExitCode = 1
                try {
                    $publishResponseLines = @(
                        $publishRequests |
                            & $bridgePath $instanceFile 2>$null
                    )
                    $publishExitCode = $LASTEXITCODE
                } catch {
                    $publishResponseLines = @()
                }
                if ($publishExitCode -eq 0) {
                    $publishResponses = @(
                        $publishResponseLines |
                            ForEach-Object { $_ | ConvertFrom-Json }
                    )
                    $publishSucceeded = $true
                    break
                }
                Start-Sleep -Milliseconds 250
            }
            if (-not $publishSucceeded) {
                throw "Inline review publication failed in cycle $cycle."
            }
            $publishResponse = $publishResponses |
                Where-Object { $_.id -eq 5 }
            if (-not $publishResponse.result.structuredContent.reviewId) {
                throw "The inline review tool returned no review identifier."
            }
            Open-RadIAEditorFile `
                -IDEProcess $process `
                -Path $inlineReviewActivationUnitPath
            Start-Sleep -Seconds 1
            Open-RadIAEditorFile `
                -IDEProcess $process `
                -Path $inlineSmokeUnitPath
            Start-Sleep -Seconds 2
            $reactivatedContent = Invoke-RadIASmokeTool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetEditorContent"
            if (-not $reactivatedContent.revision.Equals(
                $editorContent.revision,
                [StringComparison]::OrdinalIgnoreCase
            )) {
                throw "Native review reactivation changed the editor revision."
            }
            Invoke-RadIAEditorRepaint `
                -IDEProcess $process `
                -PreserveCursor
            $inlineReviewDiagnostic = Wait-RadIAInlineReviewDiagnostic `
                -EvidencePath $inlineReviewSmokePath
            $reviewId = $publishResponse.result.structuredContent.reviewId
            $rejectArguments = @{
                reviewId = $reviewId
                reason = "RadIA real IDE inline review smoke completed."
            } | ConvertTo-Json -Compress
            $staleArguments = @{
                fileName = $editorContent.fileName
                baseRevision = ("0" * 64)
                startLine = $editorPosition.line
                endLine = $editorPosition.line
                severity = "warning"
                message = "RadIA stale inline review smoke."
            } | ConvertTo-Json -Compress
            $reviewLifecycleRequests = @(
                (
                    '{"jsonrpc":"2.0","id":1,"method":"initialize",' +
                    '"params":{"protocolVersion":"2025-06-18",' +
                    '"capabilities":{},"clientInfo":{' +
                    '"name":"radia-review-lifecycle-smoke",' +
                    '"version":"1"}}}'
                ),
                (
                    '{"jsonrpc":"2.0","method":' +
                    '"notifications/initialized","params":{}}'
                ),
                (
                    '{"jsonrpc":"2.0","id":6,"method":"tools/call",' +
                    '"params":{"name":"RejectInlineReview",' +
                    '"arguments":' + $rejectArguments + '}}'
                ),
                (
                    '{"jsonrpc":"2.0","id":7,"method":"tools/call",' +
                    '"params":{"name":"PublishInlineReview",' +
                    '"arguments":' + $staleArguments + '}}'
                )
            )
            $reviewLifecycleResponses = @()
            $reviewLifecycleSucceeded = $false
            for ($attempt = 1; $attempt -le 10; $attempt++) {
                $reviewLifecycleResponseLines = @()
                $reviewLifecycleExitCode = 1
                try {
                    $reviewLifecycleResponseLines = @(
                        $reviewLifecycleRequests |
                            & $bridgePath $instanceFile 2>$null
                    )
                    $reviewLifecycleExitCode = $LASTEXITCODE
                } catch {
                    $reviewLifecycleResponseLines = @()
                }
                if ($reviewLifecycleExitCode -eq 0) {
                    $reviewLifecycleResponses = @(
                        $reviewLifecycleResponseLines |
                            ForEach-Object { $_ | ConvertFrom-Json }
                    )
                    $reviewLifecycleSucceeded = $true
                    break
                }
                Start-Sleep -Milliseconds 250
            }
            if (-not $reviewLifecycleSucceeded) {
                throw "Inline review lifecycle failed in cycle $cycle."
            }
            $rejectResponse = $reviewLifecycleResponses |
                Where-Object { $_.id -eq 6 }
            $staleResponse = $reviewLifecycleResponses |
                Where-Object { $_.id -eq 7 }
            if ($rejectResponse.result.isError -or
                -not $rejectResponse.result.structuredContent.success) {
                throw "Inline review rejection failed in cycle $cycle."
            }
            if (-not $staleResponse.result.isError) {
                throw "A stale inline review was accepted in cycle $cycle."
            }
            $inlineReviewDiagnostic |
                Add-Member -NotePropertyName Rejected -NotePropertyValue $true
            $inlineReviewDiagnostic |
                Add-Member `
                    -NotePropertyName StaleRevisionRejected `
                    -NotePropertyValue $true

            $lineBreak = if ($editorContent.content.Contains("`r`n")) {
                "`r`n"
            } else {
                "`n"
            }
            $blockLines = @($editorContent.content -split "`r?`n", -1)
            $blockLineIndex = [Math]::Min(
                $blockLines.Count - 1,
                [Math]::Max(0, [int]$editorPosition.line - 1)
            )
            $blockLines[$blockLineIndex] =
                $blockLines[$blockLineIndex] +
                " // RadIA block review gutter smoke."
            $blockReplacement = $blockLines -join $lineBreak
            $blockArguments = @{
                targetFile = $editorContent.fileName
                baseRevision = $editorContent.revision
                originalText = $editorContent.content
                replacementText = $blockReplacement
            } | ConvertTo-Json -Compress
            $blockRequests = @(
                (
                    '{"jsonrpc":"2.0","id":1,"method":"initialize",' +
                    '"params":{"protocolVersion":"2025-06-18",' +
                    '"capabilities":{},"clientInfo":{' +
                    '"name":"radia-block-review-smoke","version":"1"}}}'
                ),
                (
                    '{"jsonrpc":"2.0","method":' +
                    '"notifications/initialized","params":{}}'
                ),
                (
                    '{"jsonrpc":"2.0","id":8,"method":"tools/call",' +
                    '"params":{"name":"PreparePatch","arguments":' +
                    $blockArguments + '}}'
                )
            )
            $blockResponses = Invoke-RadIASmokeRequestsWithRetry `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Requests $blockRequests `
                -Operation "Block review preparation in cycle $cycle"
            $blockResponse = $blockResponses |
                Where-Object { $_.id -eq 8 }
            if ($blockResponse.result.isError) {
                throw "PreparePatch did not publish the block review."
            }
            Invoke-RadIAEditorRepaint `
                -IDEProcess $process `
                -PreserveCursor
            $blockReviewDiagnostic = Wait-RadIABlockReviewDiagnostic `
                -EvidencePath $inlineReviewSmokePath
            Invoke-RadIABlockLineClick `
                -IDEProcess $process `
                -Diagnostic $blockReviewDiagnostic.Raw
            [System.Windows.Forms.SendKeys]::SendWait("^%{ENTER}")
            Start-Sleep -Milliseconds 500
            $keyboardState = Get-RadIABlockReviewState `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile
            if (@($keyboardState.blocks).Count -lt 1 -or
                $keyboardState.blocks[0].decision -ne "accepted") {
                throw "The block review keyboard decision was not accepted."
            }
            $blockReviewDiagnostic |
                Add-Member `
                    -NotePropertyName KeyboardAccepted `
                    -NotePropertyValue $true

            $republishResponses = Invoke-RadIASmokeRequestsWithRetry `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Requests $blockRequests `
                -Operation "Block review republication in cycle $cycle"
            if (($republishResponses |
                    Where-Object { $_.id -eq 8 }).result.isError) {
                throw "Block review republication failed in cycle $cycle."
            }
            Invoke-RadIAEditorRepaint -IDEProcess $process
            $mouseDiagnostic = Wait-RadIABlockReviewDiagnostic `
                -EvidencePath $inlineReviewSmokePath
            Invoke-RadIABlockMarkerClick `
                -IDEProcess $process `
                -Diagnostic $mouseDiagnostic.Raw
            [System.Windows.Forms.SendKeys]::SendWait("r")
            Start-Sleep -Milliseconds 500
            $mouseState = Get-RadIABlockReviewState `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile
            if (@($mouseState.blocks).Count -lt 1 -or
                $mouseState.blocks[0].decision -ne "rejected") {
                throw "The gutter mouse decision was not rejected."
            }
            $blockReviewDiagnostic |
                Add-Member `
                    -NotePropertyName MouseRejected `
                    -NotePropertyValue $true
        }
        $agentRuntimeDiagnostic = $null
        if ($ExerciseAgentRuntime) {
            $agentRuntimeDiagnostic = Wait-RadIAAgentRuntimeDiagnostic `
                -LogPath $inlineSmokeLogPath `
                -CheckpointDirectory $agentSmokeCheckpointDirectory
        }
        $declarativeWorkflowDiagnostic = $null
        if ($ExerciseDeclarativeWorkflow) {
            $declarativeWorkflowDiagnostic = (
                Wait-RadIADeclarativeWorkflowDiagnostic `
                    -OutputDirectory $declarativeWorkflowOutputDirectory
            )
        }
        $knowledgeDiagnostic = $null
        if ($ExerciseKnowledge) {
            $knowledgeDiagnostic = Invoke-RadIAKnowledgeDiagnostic `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -ProjectPath $knowledgeSmokeProjectPath
        }
        $firstValueDiagnostic = $null
        if ($ExerciseFirstValue) {
            $firstValueDiagnostic = Invoke-RadIAFirstValueDiagnostic `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -ExpectedToolCount $expectedToolNames.Count
        }

        $descendants = @(
            Get-RadIAProcessDescendants `
                -ParentProcessId $process.Id `
                -ParentStartedAt $process.StartTime
        )
        $analysisBridgeProcess = $null
        if ($FireDACScenarioId -eq "firedac-shutdown-during-analysis") {
            $analysisBridgeProcess = Get-Process `
                -Id $fireDACDiagnostic.analysisProcessId `
                -ErrorAction SilentlyContinue
            if (-not $analysisBridgeProcess -or
                $analysisBridgeProcess.HasExited) {
                throw "The FireDAC analysis was not active at shutdown."
            }
        }
        $currentProcess = Get-Process -Id $process.Id -ErrorAction Stop
        if (-not $currentProcess.CloseMainWindow()) {
            throw "Delphi rejected the shutdown request in cycle $cycle."
        }
        if ($ExerciseKnowledge -or $ExerciseInlineCompletion -or
            $ExerciseInlineReview -or $FireDACScenarioId) {
            $shutdownDeadline = [DateTime]::UtcNow.AddMilliseconds(
                $shutdownTimeoutMs
            )
            do {
                $currentProcess.Refresh()
                if ($currentProcess.HasExited) {
                    break
                }
                $confirmWindow = (
                    [RadIAKnowledgeSmokeNative]::FindVisibleWindow(
                        [uint32]$currentProcess.Id,
                        "TMessageForm"
                    )
                )
                if ($confirmWindow -ne [IntPtr]::Zero) {
                    $noButton = (
                        [RadIAKnowledgeSmokeNative]::FindChildByText(
                            $confirmWindow,
                            "&No"
                        )
                    )
                    if ($noButton -eq [IntPtr]::Zero) {
                        $noButton = (
                            [RadIAKnowledgeSmokeNative]::FindChildByText(
                                $confirmWindow,
                                "&Não"
                            )
                        )
                    }
                    if ($noButton -ne [IntPtr]::Zero) {
                        [void][RadIAKnowledgeSmokeNative]::PostMessage(
                            $noButton,
                            0x00F5,
                            [IntPtr]0,
                            [IntPtr]0
                        )
                    }
                }
                Start-Sleep -Milliseconds 200
            } while ([DateTime]::UtcNow -lt $shutdownDeadline)
            if (-not $currentProcess.HasExited) {
                throw "Delphi did not exit cleanly in cycle $cycle."
            }
        } elseif (-not $currentProcess.WaitForExit($shutdownTimeoutMs)) {
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
        if ($analysisBridgeProcess) {
            if (-not $analysisBridgeProcess.WaitForExit(30000)) {
                throw "The FireDAC analysis bridge did not stop after shutdown."
            }
            $analysisOutput = Get-Content `
                -LiteralPath $fireDACDiagnostic.analysisOutputPath `
                -Raw `
                -ErrorAction SilentlyContinue
            $analysisError = Get-Content `
                -LiteralPath $fireDACDiagnostic.analysisErrorPath `
                -Raw `
                -ErrorAction SilentlyContinue
            $analysisShutdownText = "$analysisOutput`n$analysisError"
            if ($analysisShutdownText -match
                '(?i)access violation|eaccessviolation|0xc0000005') {
                throw "The FireDAC shutdown analysis reported an access violation."
            }
            $fireDACDiagnostic.cleanAnalysisShutdown = $true
            $fireDACDiagnostic.noAnalysisAccessViolation = $true
            $fireDACDiagnostic.noOrphanAnalysisThread = $true
            $analysisTemporaryPaths = @(
                $fireDACDiagnostic.analysisInputPath,
                $fireDACDiagnostic.analysisOutputPath,
                $fireDACDiagnostic.analysisErrorPath
            )
            foreach ($propertyName in @(
                "analysisProcessId",
                "analysisInputPath",
                "analysisOutputPath",
                "analysisErrorPath"
            )) {
                $fireDACDiagnostic.PSObject.Properties.Remove($propertyName)
            }
            $fireDACDiagnostic |
                ConvertTo-Json -Depth 10 |
                Set-Content `
                    -LiteralPath $FireDACEvidencePath `
                    -Encoding UTF8
            foreach ($temporaryPath in $analysisTemporaryPaths) {
                if (Test-Path -LiteralPath $temporaryPath) {
                    Remove-Item -LiteralPath $temporaryPath -Force
                }
            }
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
            ShutdownClean = $true
            Seconds = $elapsed
            DockingExercised = [bool]$ExerciseDocking
            DockPositionRestored = (
                [bool]$ExerciseDocking -and
                $cycle -ge 2
            )
            TerminalExercised = [bool]$ExerciseTerminal
            WebViewLifecycleExercised = (
                [bool]$ExerciseWebViewLifecycle
            )
            WebViewHostTransitions = $(
                if ($ExerciseWebViewLifecycle) {
                    $webViewTransitions
                } else {
                    0
                }
            )
            WebViewStateRestored = (
                [bool]$ExerciseWebViewLifecycle -and
                $webViewDiagnostic.draftRestored -and
                $webViewDiagnostic.advancedRestored
            )
            WebViewRecoveryGeneration = $(
                if ($webViewDiagnostic) {
                    $webViewDiagnostic.generation
                } else {
                    0
                }
            )
            TerminalOpened = (
                [bool]$ExerciseTerminal -and
                $terminalDiagnostic.Opened
            )
            TerminalWidth = $terminalDiagnostic.Width
            TerminalHeight = $terminalDiagnostic.Height
            TerminalRequiredControlsVisible = (
                [bool]$ExerciseTerminal -and
                $terminalDiagnostic.RequiredControlsVisible
            )
            TerminalCommandInputAvailable = (
                [bool]$ExerciseTerminal -and
                $terminalDiagnostic.CommandInputAvailable
            )
            TerminalOutputAvailable = (
                [bool]$ExerciseTerminal -and
                $terminalDiagnostic.OutputAvailable
            )
            TerminalPaletteAvailable = (
                [bool]$ExerciseTerminal -and
                $terminalDiagnostic.PaletteAvailable
            )
            TerminalPaletteItemCount = $terminalDiagnostic.PaletteItemCount
            TerminalProfileCount = $terminalDiagnostic.ProfileCount
            TerminalAccessibleLabelsAvailable = (
                [bool]$ExerciseTerminal -and
                $terminalDiagnostic.AccessibleLabelsAvailable
            )
            TerminalTabStopCount = $terminalDiagnostic.TabStopCount
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
            InlineCompletionAlternativesPainted = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.AlternativesPainted
            )
            InlineCompletionAlternativeCount = if (
                [bool]$ExerciseInlineCompletion
            ) {
                $inlineDiagnostic.AlternativeCount
            } else {
                0
            }
            InlineCompletionLineCount = $inlineLineCount
            InlineCompletionPreviewClean = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.PreviewClean
            )
            InlineCompletionAccepted = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.Accepted
            )
            InlineCompletionSingleUndo = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.SingleUndo
            )
            InlineCompletionUndoRestored = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.UndoRestored
            )
            InlineCompletionRejectedClean = (
                [bool]$ExerciseInlineCompletion -and
                $inlineDiagnostic.RejectedClean
            )
            InlineReviewExercised = [bool]$ExerciseInlineReview
            InlineReviewPublished = (
                [bool]$ExerciseInlineReview -and
                $inlineReviewDiagnostic.Published
            )
            InlineReviewPainted = (
                [bool]$ExerciseInlineReview -and
                $inlineReviewDiagnostic.Painted
            )
            InlineReviewRevisionMatched = (
                [bool]$ExerciseInlineReview -and
                $inlineReviewDiagnostic.RevisionMatched
            )
            InlineReviewCount = $inlineReviewDiagnostic.ReviewCount
            InlineReviewRejected = (
                [bool]$ExerciseInlineReview -and
                $inlineReviewDiagnostic.Rejected
            )
            InlineReviewStaleRevisionRejected = (
                [bool]$ExerciseInlineReview -and
                $inlineReviewDiagnostic.StaleRevisionRejected
            )
            BlockReviewPublished = (
                [bool]$ExerciseInlineReview -and
                $blockReviewDiagnostic.Published
            )
            BlockReviewGutterPainted = (
                [bool]$ExerciseInlineReview -and
                $blockReviewDiagnostic.Painted
            )
            BlockReviewCount = $blockReviewDiagnostic.BlockCount
            BlockReviewKeyboardAccepted = (
                [bool]$ExerciseInlineReview -and
                $blockReviewDiagnostic.KeyboardAccepted
            )
            BlockReviewMouseRejected = (
                [bool]$ExerciseInlineReview -and
                $blockReviewDiagnostic.MouseRejected
            )
            AgentRuntimeExercised = [bool]$ExerciseAgentRuntime
            AgentRuntimeAwaitingApproval = (
                [bool]$ExerciseAgentRuntime -and
                $agentRuntimeDiagnostic.AwaitingApproval
            )
            AgentRuntimePaused = (
                [bool]$ExerciseAgentRuntime -and
                $agentRuntimeDiagnostic.Paused
            )
            AgentRuntimeResumed = (
                [bool]$ExerciseAgentRuntime -and
                $agentRuntimeDiagnostic.Resumed
            )
            AgentRuntimeCompleted = (
                [bool]$ExerciseAgentRuntime -and
                $agentRuntimeDiagnostic.Completed
            )
            AgentRuntimePersisted = (
                [bool]$ExerciseAgentRuntime -and
                $agentRuntimeDiagnostic.Persisted
            )
            AgentRuntimeToolName = $agentRuntimeDiagnostic.ToolName
            AgentRuntimeStepCount = $agentRuntimeDiagnostic.StepCount
            DeclarativeWorkflowExercised = (
                [bool]$ExerciseDeclarativeWorkflow
            )
            DeclarativeWorkflowManifestLoaded = (
                [bool]$ExerciseDeclarativeWorkflow -and
                $declarativeWorkflowDiagnostic.manifestLoaded
            )
            DeclarativeWorkflowRegistered = (
                [bool]$ExerciseDeclarativeWorkflow -and
                $declarativeWorkflowDiagnostic.workflowRegistered
            )
            DeclarativeWorkflowExecuted = (
                [bool]$ExerciseDeclarativeWorkflow -and
                $declarativeWorkflowDiagnostic.workflowExecuted
            )
            DeclarativeWorkflowName = (
                $declarativeWorkflowDiagnostic.workflowName
            )
            DeclarativeWorkflowRisk = (
                $declarativeWorkflowDiagnostic.risk
            )
            DeclarativeWorkflowStepCount = (
                $declarativeWorkflowDiagnostic.stepCount
            )
            KnowledgeExercised = [bool]$ExerciseKnowledge
            KnowledgeProjectId = $knowledgeDiagnostic.ProjectId
            KnowledgeIndexedFiles = $knowledgeDiagnostic.IndexedFiles
            KnowledgeIndexDurationMs = (
                $knowledgeDiagnostic.IndexDurationMs
            )
            KnowledgeSearchDurationMs = (
                $knowledgeDiagnostic.SearchDurationMs
            )
            KnowledgeResultCount = $knowledgeDiagnostic.ResultCount
            KnowledgeSemanticHitCount = (
                $knowledgeDiagnostic.SemanticHitCount
            )
            KnowledgeProvider = $knowledgeDiagnostic.Provider
            KnowledgeFileName = $knowledgeDiagnostic.FileName
            KnowledgeStartLine = $knowledgeDiagnostic.StartLine
            KnowledgeExplanation = $knowledgeDiagnostic.Explanation
            KnowledgeNavigationTool = (
                $knowledgeDiagnostic.NavigationTool
            )
            KnowledgeEstimatedIndexBytes = (
                $knowledgeDiagnostic.EstimatedIndexBytes
            )
            KnowledgeChunkCount = $knowledgeDiagnostic.ChunkCount
            KnowledgeDocumentRetrieved = (
                [bool]$ExerciseKnowledge -and
                $knowledgeDiagnostic.DocumentRetrieved
            )
            KnowledgeWorkspaceIsolated = (
                [bool]$ExerciseKnowledge -and
                $knowledgeDiagnostic.WorkspaceIsolated
            )
            FirstValueExercised = [bool]$ExerciseFirstValue
            FirstValueStatus = $firstValueDiagnostic.Status
            FirstValueReadinessScore = (
                $firstValueDiagnostic.ReadinessScore
            )
            FirstValueProviderConfigured = (
                $firstValueDiagnostic.ProviderConfigured
            )
            FirstValueExecutor = $firstValueDiagnostic.Executor
            FirstValueCliRequired = $firstValueDiagnostic.CliRequired
            FirstValueCliDetected = $firstValueDiagnostic.CliDetected
            FirstValueMcpBridgeAvailable = (
                $firstValueDiagnostic.McpBridgeAvailable
            )
            FirstValueMcpConfigured = (
                $firstValueDiagnostic.McpConfigured
            )
            FirstValueMcpRequired = $firstValueDiagnostic.McpRequired
            FirstValueTerminalReady = $firstValueDiagnostic.TerminalReady
            FirstValueChatReady = $firstValueDiagnostic.ChatReady
            FirstValueFirstToolReady = (
                $firstValueDiagnostic.FirstToolReady
            )
            FirstValueNextAction = $firstValueDiagnostic.NextAction
            FirstValueFirstToolName = (
                $firstValueDiagnostic.FirstToolName
            )
            FirstValueIDEVersion = $firstValueDiagnostic.IDEVersion
            FirstValueIDEPlatform = $firstValueDiagnostic.IDEPlatform
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
}
if ($ExerciseInlineReview) {
    Write-Host (
        "Inline and block review publication, OTA line and gutter " +
        "painting, rejection, and stale revision protection passed."
    )
}
if ($ExerciseTerminal) {
    Write-Host (
        "Native terminal window, controls, input, output, and keyboard " +
        "tab stops passed."
    )
}
if ($ExerciseWebViewLifecycle) {
    Write-Host (
        "WebView failure recovery and in-memory state restoration passed."
    )
}
if ($ExerciseAgentRuntime) {
    Write-Host (
        "Agent runtime pause, persistence, resume, and completion passed."
    )
}
if ($ExerciseDeclarativeWorkflow) {
    Write-Host (
        "Declarative workflow hot-load and audited execution passed."
    )
}
if ($ExerciseKnowledge) {
    Write-Host (
        "Private local semantic knowledge and provenance passed."
    )
}
if ($ExerciseInlineCompletion -or $ExerciseInlineReview -or
    $ExerciseAgentRuntime -or
    $ExerciseDeclarativeWorkflow) {
    Restore-RadIAInlineCompletionLogSettings
}
if ($ExerciseKnowledge) {
    Restore-RadIAKnowledgeSettings
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
        terminalExercised = [bool]$ExerciseTerminal
        webViewLifecycleExercised = [bool]$ExerciseWebViewLifecycle
        webViewTransitionCount = $(
            if ($ExerciseWebViewLifecycle) {
                $WebViewTransitionCount
            } else {
                0
            }
        )
        inlineCompletionExercised = [bool]$ExerciseInlineCompletion
        inlineReviewExercised = [bool]$ExerciseInlineReview
        agentRuntimeExercised = [bool]$ExerciseAgentRuntime
        declarativeWorkflowExercised = (
            [bool]$ExerciseDeclarativeWorkflow
        )
        knowledgeExercised = [bool]$ExerciseKnowledge
        firstValueExercised = [bool]$ExerciseFirstValue
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
if ($WebViewLifecycleEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "WebView lifecycle"
    $resolvedWebViewEvidencePath = [IO.Path]::GetFullPath(
        $WebViewLifecycleEvidencePath
    )
    $webViewEvidenceDirectory = Split-Path -Parent (
        $resolvedWebViewEvidencePath
    )
    if ($webViewEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $webViewEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        productVersion = $expectedVersion
        sourceCommit = $sourceCommit
        delphiVersion = $DelphiVersion
        platform = $platform
        cyclesRequested = $Cycles
        cyclesPassed = $results.Count
        recoveryPassed = @(
            $results | Where-Object { $_.WebViewStateRestored }
        ).Count -eq $Cycles
        shutdownPassed = @(
            $results | Where-Object { $_.ShutdownClean }
        ).Count -eq $Cycles
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        cycles = $results
    } |
        ConvertTo-Json -Depth 6 |
        Set-Content `
            -LiteralPath $resolvedWebViewEvidencePath `
            -Encoding UTF8
    Write-Host (
        "WebView lifecycle evidence created: " +
        $resolvedWebViewEvidencePath
    )
}
if ($TerminalEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "Terminal"
    $resolvedTerminalEvidencePath = [IO.Path]::GetFullPath(
        $TerminalEvidencePath
    )
    $terminalEvidenceDirectory = Split-Path -Parent (
        $resolvedTerminalEvidencePath
    )
    if ($terminalEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $terminalEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "interactiveTerminalVisualSmoke"
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
            -LiteralPath $resolvedTerminalEvidencePath `
            -Encoding UTF8
    Write-Host (
        "Terminal evidence created: " +
        $resolvedTerminalEvidencePath
    )
}
if ($KnowledgeEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "Knowledge"
    $resolvedKnowledgeEvidencePath = [IO.Path]::GetFullPath(
        $KnowledgeEvidencePath
    )
    $knowledgeEvidenceDirectory = Split-Path -Parent (
        $resolvedKnowledgeEvidencePath
    )
    if ($knowledgeEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $knowledgeEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "privateSemanticKnowledgeSmoke"
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
            -LiteralPath $resolvedKnowledgeEvidencePath `
            -Encoding UTF8
    Write-Host (
        "Knowledge evidence created: " +
        $resolvedKnowledgeEvidencePath
    )
}
if ($FirstValueEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "First value"
    $resolvedFirstValueEvidencePath = [IO.Path]::GetFullPath(
        $FirstValueEvidencePath
    )
    $firstValueEvidenceDirectory = Split-Path -Parent (
        $resolvedFirstValueEvidencePath
    )
    if ($firstValueEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $firstValueEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "installationFirstValueSmoke"
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
            -LiteralPath $resolvedFirstValueEvidencePath `
            -Encoding UTF8
    Write-Host (
        "First-value evidence created: " +
        $resolvedFirstValueEvidencePath
    )
}
if ($DeclarativeWorkflowEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "Declarative workflow"
    $resolvedWorkflowEvidencePath = [IO.Path]::GetFullPath(
        $DeclarativeWorkflowEvidencePath
    )
    $workflowEvidenceDirectory = Split-Path -Parent (
        $resolvedWorkflowEvidencePath
    )
    if ($workflowEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $workflowEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "declarativeWorkflowSmoke"
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
            -LiteralPath $resolvedWorkflowEvidencePath `
            -Encoding UTF8
    Write-Host (
        "Declarative workflow evidence created: " +
        $resolvedWorkflowEvidencePath
    )
}
if ($InlineCompletionEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "Inline completion"
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
if ($InlineReviewEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "Inline review"
    $resolvedReviewEvidencePath = [IO.Path]::GetFullPath(
        $InlineReviewEvidencePath
    )
    $reviewEvidenceDirectory = Split-Path -Parent $resolvedReviewEvidencePath
    if ($reviewEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $reviewEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "inlineReviewVisualSmoke"
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
            -LiteralPath $resolvedReviewEvidencePath `
            -Encoding UTF8
    Write-Host (
        "Inline review evidence created: " +
        $resolvedReviewEvidencePath
    )
}
if ($AgentRuntimeEvidencePath) {
    $sourceCommit = Get-RadIACleanSourceCommit `
        -RepositoryRoot $repositoryRoot `
        -EvidenceName "Agent runtime"
    $resolvedAgentEvidencePath = [IO.Path]::GetFullPath(
        $AgentRuntimeEvidencePath
    )
    $agentEvidenceDirectory = Split-Path -Parent $resolvedAgentEvidencePath
    if ($agentEvidenceDirectory) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $agentEvidenceDirectory |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "agentRuntimeJourneySmoke"
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
            -LiteralPath $resolvedAgentEvidencePath `
            -Encoding UTF8
    Write-Host (
        "Agent runtime evidence created: " +
        $resolvedAgentEvidencePath
    )
}
