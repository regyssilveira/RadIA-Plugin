param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [ValidateRange(1, 50)]
    [int]$Cycles = 10,
    [ValidateRange(30, 1800)]
    [int]$StartupTimeoutSeconds = 180,
    [switch]$IDE64,
    [switch]$SkipPackageHashCheck,
    [switch]$ExerciseDocking,
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
    [string]$InlineCompletionEvidencePath = "",
    [string]$InlineReviewEvidencePath = "",
    [string]$AgentRuntimeEvidencePath = "",
    [string]$DeclarativeWorkflowEvidencePath = "",
    [string]$KnowledgeEvidencePath = "",
    [string]$FirstValueEvidencePath = ""
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
    $ExerciseInlineReview) {
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
        $acceptedAndRestored = $logContent.Contains(
            $acceptancePattern
        )
        if (-not ($prepared -and $painted -and $acceptedAndRestored)) {
            Start-Sleep -Milliseconds 100
        }
    } while (
        -not ($prepared -and $painted -and $acceptedAndRestored) -and
        [DateTime]::UtcNow -lt $paintDeadline
    )
    if (-not $prepared) {
        throw "The local inline suggestion was not prepared."
    }
    if (-not $painted) {
        throw "The Ghost Text overlay did not reach the OTA paint cycle."
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
        [Diagnostics.Process]$IDEProcess
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
        $editorHandle = [RadIAKnowledgeSmokeNative]::FindVisibleChildByClass(
            $IDEProcess.MainWindowHandle,
            "TEditControl"
        )
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
    $editorRectangle = New-Object RadIAKnowledgeSmokeNative+Rect
    if (-not [RadIAKnowledgeSmokeNative]::GetWindowRect(
        $editorHandle,
        [ref]$editorRectangle
    )) {
        throw "The Delphi editor rectangle was not available for repaint."
    }
    $editorX = [int](($editorRectangle.Left + $editorRectangle.Right) / 2)
    $editorY = [int](($editorRectangle.Top + $editorRectangle.Bottom) / 2)
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
    return $response.result.structuredContent
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
$terminalSmokeRoot = ""
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
        if (-not (
            Test-Path -LiteralPath $inlineSmokeProjectPath -PathType Leaf
        ) -or -not (
            Test-Path -LiteralPath $inlineSmokeUnitPath -PathType Leaf
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
    $terminalSmokePath = ""
    if ($ExerciseTerminal) {
        $terminalSmokePath = Join-Path `
            $terminalSmokeRoot `
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
        $terminalDiagnostic = $null
        if ($ExerciseTerminal) {
            $terminalDiagnostic = Wait-RadIATerminalDiagnostic `
                -EvidencePath $terminalSmokePath `
                -TimeoutSeconds 60
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
            $navigation = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "NavigateToFile" `
                -Arguments @{
                    fileName = $editorContent.fileName
                    line = $editorPosition.line
                    column = $editorPosition.column
                }
            if (-not $navigation.success) {
                throw "The inline smoke could not activate the editor file."
            }
            Start-Sleep -Milliseconds 500
        }
        if ($ExerciseInlineCompletion) {
            $inlineDiagnostic = Wait-RadIAInlineCompletionDiagnostic `
                -LogPath $inlineSmokeLogPath `
                -FileName (
                    [IO.Path]::GetFileName($editorContent.fileName)
                )
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
            Invoke-RadIAEditorRepaint -IDEProcess $process
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
            Invoke-RadIAEditorRepaint -IDEProcess $process
            $blockReviewDiagnostic = Wait-RadIABlockReviewDiagnostic `
                -EvidencePath $inlineReviewSmokePath
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
        $currentProcess = Get-Process -Id $process.Id -ErrorAction Stop
        if (-not $currentProcess.CloseMainWindow()) {
            throw "Delphi rejected the shutdown request in cycle $cycle."
        }
        if ($ExerciseKnowledge -or $ExerciseInlineCompletion -or
            $ExerciseInlineReview) {
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
            TerminalExercised = [bool]$ExerciseTerminal
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
