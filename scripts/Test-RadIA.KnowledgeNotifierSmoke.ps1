param(
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion = "23.0",
    [ValidateRange(30, 600)]
    [int]$StartupTimeoutSeconds = 180,
    [ValidateRange(30, 600)]
    [int]$ShutdownTimeoutSeconds = 120,
    [switch]$SkipBuildAndTests,
    [switch]$SkipTemplateBuild,
    [switch]$ExerciseDebugger,
    [switch]$ExerciseCalculatorRuntime,
    [switch]$ExerciseCorrection,
    [switch]$ExerciseTestCorrection,
    [switch]$ExerciseGit,
    [switch]$ExerciseProjectTransition,
    [switch]$ReadOnlyOnly,
    [switch]$IDE64,
    [string]$EvidencePath = ""
)

$ErrorActionPreference = "Stop"
$journeyStartedAt = [DateTime]::UtcNow

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class RadIAWindowNative
{
    public delegate bool EnumWindowsCallback(
        IntPtr windowHandle,
        IntPtr parameter
    );

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(
        EnumWindowsCallback callback,
        IntPtr parameter
    );

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(
        IntPtr parentWindow,
        EnumWindowsCallback callback,
        IntPtr parameter
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(
        IntPtr windowHandle,
        StringBuilder className,
        int maximumCount
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(
        IntPtr windowHandle,
        StringBuilder text,
        int maximumCount
    );

    [DllImport("user32.dll")]
    public static extern int GetDlgCtrlID(IntPtr windowHandle);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr windowHandle);

    [DllImport("user32.dll")]
    public static extern bool IsWindowEnabled(IntPtr windowHandle);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr windowHandle);

    [DllImport("user32.dll")]
    public static extern void keybd_event(
        byte virtualKey,
        byte scanCode,
        uint flags,
        UIntPtr extraInfo
    );

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr windowHandle,
        out uint processId
    );

    [DllImport("user32.dll")]
    public static extern bool PostMessage(
        IntPtr windowHandle,
        uint message,
        IntPtr wordParameter,
        IntPtr longParameter
    );

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(
        IntPtr windowHandle,
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
        IntPtr windowHandle,
        uint message,
        IntPtr wordParameter,
        string longParameter
    );

    public static IntPtr FindMainWindow(uint processId)
    {
        IntPtr result = IntPtr.Zero;
        EnumWindows(
            delegate(IntPtr windowHandle, IntPtr parameter)
            {
                uint ownerProcessId;
                GetWindowThreadProcessId(
                    windowHandle,
                    out ownerProcessId
                );
                if (ownerProcessId != processId ||
                    !IsWindowVisible(windowHandle))
                {
                    return true;
                }
                StringBuilder className = new StringBuilder(128);
                GetClassName(
                    windowHandle,
                    className,
                    className.Capacity
                );
                if (className.ToString() == "TAppBuilder")
                {
                    result = windowHandle;
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
            delegate(IntPtr windowHandle, IntPtr parameter)
            {
                uint ownerProcessId;
                GetWindowThreadProcessId(
                    windowHandle,
                    out ownerProcessId
                );
                if (ownerProcessId != processId ||
                    !IsWindowVisible(windowHandle))
                {
                    return true;
                }
                StringBuilder className = new StringBuilder(128);
                GetClassName(
                    windowHandle,
                    className,
                    className.Capacity
                );
                if (className.ToString() == expectedClassName)
                {
                    result = windowHandle;
                    return false;
                }
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }

    public static IntPtr FindChildByText(
        IntPtr parentWindow,
        string expectedText
    )
    {
        IntPtr result = IntPtr.Zero;
        EnumChildWindows(
            parentWindow,
            delegate(IntPtr windowHandle, IntPtr parameter)
            {
                StringBuilder text = new StringBuilder(256);
                GetWindowText(
                    windowHandle,
                    text,
                    text.Capacity
                );
                if (text.ToString() == expectedText)
                {
                    result = windowHandle;
                    return false;
                }
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }

    public static IntPtr FindChildById(
        IntPtr parentWindow,
        int controlId
    )
    {
        IntPtr result = IntPtr.Zero;
        EnumChildWindows(
            parentWindow,
            delegate(IntPtr windowHandle, IntPtr parameter)
            {
                if (GetDlgCtrlID(windowHandle) == controlId)
                {
                    result = windowHandle;
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

function Wait-RadIACondition {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Condition,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (& $Condition) {
            return
        }
        Start-Sleep -Milliseconds 250
    }
    throw $FailureMessage
}

function Invoke-RadIAFileMenuCommand {
    param(
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$Process,
        [ValidateRange(0, 20)]
        [int]$DownCount = 0,
        [ValidatePattern("^[A-Za-z]?$")]
        [string]$AccessKey = ""
    )

    $mainWindow = [RadIAWindowNative]::FindMainWindow(
        [uint32]$Process.Id
    )
    if ($mainWindow -eq [IntPtr]::Zero) {
        throw "The Delphi main window is not available."
    }
    if ($AccessKey -eq "S") {
        [void][RadIAWindowNative]::SetForegroundWindow($mainWindow)
        Start-Sleep -Milliseconds 200
        [RadIAWindowNative]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero)
        [RadIAWindowNative]::keybd_event(0x53, 0, 0, [UIntPtr]::Zero)
        [RadIAWindowNative]::keybd_event(0x53, 0, 2, [UIntPtr]::Zero)
        [RadIAWindowNative]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 500
        return
    }
    $menuBar = [RadIAWindowNative]::FindChildByText(
        $mainWindow,
        "Menu bar"
    )
    if ($menuBar -eq [IntPtr]::Zero) {
        throw "The Delphi File menu is not available."
    }
    $mousePosition = [IntPtr]((12 -shl 16) -bor 12)
    [void][RadIAWindowNative]::PostMessage(
        $menuBar,
        0x0201,
        [IntPtr]1,
        $mousePosition
    )
    [void][RadIAWindowNative]::PostMessage(
        $menuBar,
        0x0202,
        [IntPtr]0,
        $mousePosition
    )
    Wait-RadIACondition -TimeoutSeconds 5 -Condition {
        [RadIAWindowNative]::FindVisibleWindow(
            [uint32]$Process.Id,
            "TIDEStylePopupMenu"
        ) -ne [IntPtr]::Zero
    } -FailureMessage "The Delphi File menu did not open."

    if ($AccessKey) {
        $virtualKey = [int][char]$AccessKey.ToUpperInvariant()
        [void][RadIAWindowNative]::PostMessage(
            $mainWindow,
            0x0100,
            [IntPtr]$virtualKey,
            [IntPtr]0
        )
        [void][RadIAWindowNative]::PostMessage(
            $mainWindow,
            0x0101,
            [IntPtr]$virtualKey,
            [IntPtr]0
        )
        return
    }
    if ($DownCount -lt 1) {
        throw "A File menu command was not specified."
    }
    for ($index = 1; $index -le $DownCount; $index++) {
        [void][RadIAWindowNative]::PostMessage(
            $mainWindow,
            0x0100,
            [IntPtr]0x28,
            [IntPtr]0
        )
        [void][RadIAWindowNative]::PostMessage(
            $mainWindow,
            0x0101,
            [IntPtr]0x28,
            [IntPtr]0
        )
    }
    [void][RadIAWindowNative]::PostMessage(
        $mainWindow,
        0x0100,
        [IntPtr]0x0D,
        [IntPtr]0
    )
    [void][RadIAWindowNative]::PostMessage(
        $mainWindow,
        0x0101,
        [IntPtr]0x0D,
        [IntPtr]0
    )
}

function Save-RadIAEditorBuffer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BridgePath,
        [Parameter(Mandatory = $true)]
        [string]$InstanceFile,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedPath
    )

    $editor = Invoke-RadIATool `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -Name "GetEditorContent"
    $actualPath = [IO.Path]::GetFullPath($editor.fileName)
    $expectedFullPath = [IO.Path]::GetFullPath($ExpectedPath)
    if (-not $actualPath.Equals(
        $expectedFullPath,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "The active editor does not match the expected save target."
    }
    $utf8WithoutBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($expectedFullPath, $editor.content, $utf8WithoutBom)
}

function Set-RadIAFileDialogPath {
    param(
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Wait-RadIACondition -TimeoutSeconds 10 -Condition {
        [RadIAWindowNative]::FindVisibleWindow(
            [uint32]$Process.Id,
            "#32770"
        ) -ne [IntPtr]::Zero
    } -FailureMessage "The Delphi file dialog did not open."
    $dialog = [RadIAWindowNative]::FindVisibleWindow(
        [uint32]$Process.Id,
        "#32770"
    )
    Wait-RadIACondition -TimeoutSeconds 5 -Condition {
        $hasFileNameEdit =
            [RadIAWindowNative]::FindChildById(
                $dialog,
                1148
            ) -ne [IntPtr]::Zero -or
            [RadIAWindowNative]::FindChildById(
                $dialog,
                1001
            ) -ne [IntPtr]::Zero
        $hasFileNameEdit -and
            (
                [RadIAWindowNative]::FindChildById(
                    $dialog,
                    1
                )
            ) -ne [IntPtr]::Zero
    } -FailureMessage "The Delphi file dialog controls were not found."
    $fileNameEdit = [RadIAWindowNative]::FindChildById(
        $dialog,
        1148
    )
    if ($fileNameEdit -eq [IntPtr]::Zero) {
        $fileNameEdit = [RadIAWindowNative]::FindChildById(
            $dialog,
            1001
        )
    }
    $confirmButton = [RadIAWindowNative]::FindChildById(
        $dialog,
        1
    )
    [void][RadIAWindowNative]::SendMessageText(
        $fileNameEdit,
        0x000C,
        [IntPtr]0,
        $Path
    )
    [void][RadIAWindowNative]::SendMessage(
        $confirmButton,
        0x00F5,
        [IntPtr]0,
        [IntPtr]0
    )
}

function Open-RadIAPath {
    param(
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Invoke-RadIAFileMenuCommand -Process $Process -DownCount 2
    Set-RadIAFileDialogPath -Process $Process -Path $Path
}

function Invoke-RadIATool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BridgePath,
        [Parameter(Mandatory = $true)]
        [string]$InstanceFile,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [hashtable]$Arguments = @{},
        [switch]$ExpectError
    )

    $initialize = @{
        jsonrpc = "2.0"
        id = 1
        method = "initialize"
        params = @{
            protocolVersion = "2025-06-18"
            capabilities = @{}
            clientInfo = @{
                name = "radia-knowledge-notifier-smoke"
                version = "1"
            }
        }
    } | ConvertTo-Json -Depth 8 -Compress
    $initialized = @{
        jsonrpc = "2.0"
        method = "notifications/initialized"
        params = @{}
    } | ConvertTo-Json -Depth 4 -Compress
    $call = @{
        jsonrpc = "2.0"
        id = 2
        method = "tools/call"
        params = @{
            name = $Name
            arguments = $Arguments
        }
    } | ConvertTo-Json -Depth 8 -Compress

    $responses = @()
    $bridgeSucceeded = $false
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        for ($attempt = 1; $attempt -le 10; $attempt++) {
            $responses = @($initialize, $initialized, $call) |
                & $BridgePath $InstanceFile 2>$null
            if ($LASTEXITCODE -eq 0) {
                $bridgeSucceeded = $true
                Break
            }
            Start-Sleep -Milliseconds 250
        }
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if (-not $bridgeSucceeded) {
        throw "The MCP bridge failed while calling $Name."
    }
    $response = @(
        $responses |
            ForEach-Object { $_ | ConvertFrom-Json } |
            Where-Object { $_.id -eq 2 }
    ) | Select-Object -First 1
    if (-not $response) {
        throw "Tool $Name did not return a response."
    }
    if ($response.error) {
        throw "Tool $Name failed: $($response.error.message)"
    }
    if ($response.result.isError) {
        if ($ExpectError) {
            return $response.result
        }
        $message = $response.result.content[0].text
        throw "Tool $Name returned an error: $message"
    }
    if ($ExpectError) {
        throw "Tool $Name unexpectedly succeeded."
    }
    return $response.result.structuredContent
}

function Invoke-RadIAToolWithConsent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BridgePath,
        [Parameter(Mandatory = $true)]
        [string]$InstanceFile,
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [hashtable]$Arguments = @{},
        [ValidateSet("Allow once", "Deny", "Cancel")]
        [string]$ConsentButtonText = "Allow once",
        [switch]$ExpectError
    )

    if ($env:RADIA_IDE_SMOKE_AUTO_CONSENT -eq "1") {
        return Invoke-RadIATool `
            -BridgePath $BridgePath `
            -InstanceFile $InstanceFile `
            -Name $Name `
            -Arguments $Arguments `
            -ExpectError:$ExpectError
    }

    $requestKey = [Guid]::NewGuid().ToString("N")
    $requestRoot = Join-Path (
        [IO.Path]::GetTempPath()
    ) "radia-consent-$requestKey"
    $inputPath = "$requestRoot.in"
    $outputPath = "$requestRoot.out"
    $errorPath = "$requestRoot.err"
    $initialize = @{
        jsonrpc = "2.0"
        id = 1
        method = "initialize"
        params = @{
            protocolVersion = "2025-06-18"
            capabilities = @{}
            clientInfo = @{
                name = "radia-knowledge-notifier-smoke"
                version = "1"
            }
        }
    } | ConvertTo-Json -Depth 8 -Compress
    $initialized = @{
        jsonrpc = "2.0"
        method = "notifications/initialized"
        params = @{}
    } | ConvertTo-Json -Depth 4 -Compress
    $call = @{
        jsonrpc = "2.0"
        id = 2
        method = "tools/call"
        params = @{
            name = $Name
            arguments = $Arguments
        }
    } | ConvertTo-Json -Depth 8 -Compress
    Set-Content `
        -LiteralPath $inputPath `
        -Value @($initialize, $initialized, $call) `
        -Encoding UTF8
    try {
        $bridgeProcess = Start-Process `
            -FilePath $BridgePath `
            -ArgumentList "`"$InstanceFile`"" `
            -RedirectStandardInput $inputPath `
            -RedirectStandardOutput $outputPath `
            -RedirectStandardError $errorPath `
            -PassThru
        Wait-RadIACondition -TimeoutSeconds 30 -Condition {
            $bridgeProcess.HasExited -or
                [RadIAWindowNative]::FindVisibleWindow(
                    [uint32]$IDEProcess.Id,
                    "TRadIAConsentForm"
                ) -ne [IntPtr]::Zero
        } -FailureMessage "The RadIA consent dialog did not open."
        if ($bridgeProcess.HasExited) {
            $bridgeOutput = Get-Content `
                -LiteralPath $outputPath `
                -Raw `
                -ErrorAction SilentlyContinue
            $bridgeError = Get-Content `
                -LiteralPath $errorPath `
                -Raw `
                -ErrorAction SilentlyContinue
            throw (
                "The MCP bridge exited before consent for $Name. " +
                "Output: $bridgeOutput Error: $bridgeError"
            )
        }
        $consentWindow = [RadIAWindowNative]::FindVisibleWindow(
            [uint32]$IDEProcess.Id,
            "TRadIAConsentForm"
        )
        $consentButton = [RadIAWindowNative]::FindChildByText(
            $consentWindow,
            $ConsentButtonText
        )
        if ($consentButton -eq [IntPtr]::Zero) {
            throw "The $ConsentButtonText consent button was not found."
        }
        [void][RadIAWindowNative]::PostMessage(
            $consentButton,
            0x00F5,
            [IntPtr]0,
            [IntPtr]0
        )
        Wait-RadIACondition -TimeoutSeconds 30 -Condition {
            if ($bridgeProcess.HasExited) {
                return $true
            }
            $visibleConsentWindow = [RadIAWindowNative]::FindVisibleWindow(
                [uint32]$IDEProcess.Id,
                "TRadIAConsentForm"
            )
            if ($visibleConsentWindow -eq [IntPtr]::Zero) {
                return $true
            }
            $visibleConsentButton = [RadIAWindowNative]::FindChildByText(
                $visibleConsentWindow,
                $ConsentButtonText
            )
            if ($visibleConsentButton -ne [IntPtr]::Zero -and
                [RadIAWindowNative]::IsWindowEnabled($visibleConsentButton)) {
                [void][RadIAWindowNative]::PostMessage(
                    $visibleConsentButton,
                    0x00F5,
                    [IntPtr]0,
                    [IntPtr]0
                )
            }
            return $false
        } -FailureMessage (
            "The consent dialog did not close after allowing $Name."
        )
        $responseTimeout = if ($Name -in @(
            "BuildProject",
            "RunDUnitXTests",
            "ValidateCreatedProject"
        )) { 600000 } else { 120000 }
        if (-not $bridgeProcess.WaitForExit($responseTimeout)) {
            throw "The MCP bridge timed out while executing $Name."
        }
        $response = @(
            Get-Content -LiteralPath $outputPath |
                ForEach-Object { $_ | ConvertFrom-Json } |
                Where-Object { $_.id -eq 2 }
        ) | Select-Object -First 1
        if ($bridgeProcess.ExitCode -ne 0 -and
            -not $response) {
            $bridgeError = Get-Content `
                -LiteralPath $errorPath `
                -Raw `
                -ErrorAction SilentlyContinue
            throw "The MCP bridge failed while executing $Name`: $bridgeError"
        }
        if ($ExpectError) {
            if (-not $response -or
                (-not $response.error -and -not $response.result.isError)) {
                throw "Tool $Name unexpectedly succeeded."
            }
            return $response
        }
        if (-not $response -or
            $response.error -or
            $response.result.isError) {
            $responseDetails = $response |
                ConvertTo-Json -Depth 10 -Compress
            throw "Tool $Name failed after consent: $responseDetails"
        }
        return $response.result.structuredContent
    } finally {
        if ($bridgeProcess -and -not $bridgeProcess.HasExited) {
            Stop-Process -Id $bridgeProcess.Id -Force
            [void]$bridgeProcess.WaitForExit(5000)
        }
        foreach ($temporaryPath in @(
            $inputPath,
            $outputPath,
            $errorPath
        )) {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }
        }
    }
}

function Invoke-RadIAToolSequenceWithSessionConsent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BridgePath,
        [Parameter(Mandatory = $true)]
        [string]$InstanceFile,
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory = $true)]
        [array]$Operations
    )

    if ($Operations.Count -lt 2) {
        throw "Session consent validation requires at least two operations."
    }

    $requestKey = [Guid]::NewGuid().ToString("N")
    $requestRoot = Join-Path (
        [IO.Path]::GetTempPath()
    ) "radia-session-consent-$requestKey"
    $inputPath = "$requestRoot.in"
    $outputPath = "$requestRoot.out"
    $errorPath = "$requestRoot.err"
    $messages = @(
        @{
            jsonrpc = "2.0"
            id = 1
            method = "initialize"
            params = @{
                protocolVersion = "2025-06-18"
                capabilities = @{}
                clientInfo = @{
                    name = "radia-session-consent-smoke"
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
    for ($operationIndex = 0; $operationIndex -lt $Operations.Count;
        $operationIndex++) {
        $operation = $Operations[$operationIndex]
        $messages += @{
            jsonrpc = "2.0"
            id = $operationIndex + 2
            method = "tools/call"
            params = @{
                name = $operation.Name
                arguments = $operation.Arguments
            }
        } | ConvertTo-Json -Depth 8 -Compress
    }
    Set-Content -LiteralPath $inputPath -Value $messages -Encoding UTF8

    $bridgeProcess = $null
    try {
        $bridgeProcess = Start-Process `
            -FilePath $BridgePath `
            -ArgumentList "`"$InstanceFile`"" `
            -RedirectStandardInput $inputPath `
            -RedirectStandardOutput $outputPath `
            -RedirectStandardError $errorPath `
            -PassThru
        Wait-RadIACondition -TimeoutSeconds 30 -Condition {
            $bridgeProcess.HasExited -or
                [RadIAWindowNative]::FindVisibleWindow(
                    [uint32]$IDEProcess.Id,
                    "TRadIAConsentForm"
                ) -ne [IntPtr]::Zero
        } -FailureMessage "The first session consent dialog did not open."
        if ($bridgeProcess.HasExited) {
            throw "The MCP bridge exited before session consent."
        }

        $consentWindow = [RadIAWindowNative]::FindVisibleWindow(
            [uint32]$IDEProcess.Id,
            "TRadIAConsentForm"
        )
        $allowSessionButton = [RadIAWindowNative]::FindChildByText(
            $consentWindow,
            "Allow session"
        )
        if ($allowSessionButton -eq [IntPtr]::Zero -or
            -not [RadIAWindowNative]::IsWindowEnabled(
                $allowSessionButton
            )) {
            throw "Allow session is unavailable for the compatible sequence."
        }
        [void][RadIAWindowNative]::PostMessage(
            $allowSessionButton,
            0x00F5,
            [IntPtr]0,
            [IntPtr]0
        )
        Wait-RadIACondition -TimeoutSeconds 30 -Condition {
            -not [RadIAWindowNative]::IsWindowVisible($consentWindow)
        } -FailureMessage "The first session consent dialog did not close."
        $sequenceTimeoutSeconds = if (@(
            $Operations.Name |
                Where-Object {
                    $_ -in @(
                        "BuildProject",
                        "RunDUnitXTests",
                        "ValidateCreatedProject"
                    )
                }
        ).Count -gt 0) { 600 } else { 120 }
        Wait-RadIACondition -TimeoutSeconds $sequenceTimeoutSeconds -Condition {
            $bridgeProcess.HasExited -or
                [RadIAWindowNative]::FindVisibleWindow(
                    [uint32]$IDEProcess.Id,
                    "TRadIAConsentForm"
                ) -ne [IntPtr]::Zero
        } -FailureMessage "The consented tool sequence did not finish."

        $redundantWindow = [RadIAWindowNative]::FindVisibleWindow(
            [uint32]$IDEProcess.Id,
            "TRadIAConsentForm"
        )
        if ($redundantWindow -ne [IntPtr]::Zero) {
            $cancelButton = [RadIAWindowNative]::FindChildByText(
                $redundantWindow,
                "Cancel"
            )
            if ($cancelButton -ne [IntPtr]::Zero) {
                [void][RadIAWindowNative]::PostMessage(
                    $cancelButton,
                    0x00F5,
                    [IntPtr]0,
                    [IntPtr]0
                )
            }
            throw "A compatible tool requested redundant session consent."
        }
        if (-not $bridgeProcess.WaitForExit(5000)) {
            throw "The MCP bridge did not exit after the consented sequence."
        }

        $responses = @(
            Get-Content -LiteralPath $outputPath |
                ForEach-Object { $_ | ConvertFrom-Json } |
                Where-Object { $_.id -ge 2 } |
                Sort-Object id
        )
        if ($responses.Count -ne $Operations.Count) {
            throw "The consented sequence returned incomplete responses."
        }
        $results = @()
        foreach ($response in $responses) {
            if ($response.error -or $response.result.isError) {
                $responseDetails = $response |
                    ConvertTo-Json -Depth 10 -Compress
                throw (
                    "The consented sequence failed: " +
                    $responseDetails
                )
            }
            $results += $response.result.structuredContent
        }
        return $results
    } finally {
        if ($bridgeProcess -and -not $bridgeProcess.HasExited) {
            Stop-Process -Id $bridgeProcess.Id -Force
            [void]$bridgeProcess.WaitForExit(5000)
        }
        foreach ($temporaryPath in @(
            $inputPath,
            $outputPath,
            $errorPath
        )) {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }
        }
    }
}

function Complete-RadIADebugSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BridgePath,
        [Parameter(Mandatory = $true)]
        [string]$InstanceFile,
        [Parameter(Mandatory = $true)]
        [Diagnostics.Process]$IDEProcess,
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [int]$LineNumber
    )

    [void](Invoke-RadIAToolWithConsent `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -IDEProcess $IDEProcess `
        -Name "RemoveBreakpoint" `
        -Arguments @{
            fileName = $FileName
            lineNumber = $LineNumber
        }
    )
    $continueResult = Invoke-RadIAToolWithConsent `
        -BridgePath $BridgePath `
        -InstanceFile $InstanceFile `
        -IDEProcess $IDEProcess `
        -Name "ContinueDebugging"
    if (-not $continueResult.accepted) {
        throw (
            "ContinueDebugging was not accepted: " +
            ($continueResult | ConvertTo-Json -Compress)
        )
    }
    Wait-RadIACondition -TimeoutSeconds 90 -Condition {
        try {
            $completedState = Invoke-RadIATool `
                -BridgePath $BridgePath `
                -InstanceFile $InstanceFile `
                -Name "GetDebuggerState"
            $completedState.state -in @(
                "no_process",
                "terminated",
                "nothing"
            )
        } catch {
            $false
        }
    } -FailureMessage (
        "The debug process did not finish after ContinueDebugging."
    )
}

function Get-RadIASourceLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Marker
    )

    $matches = @(
        Select-String `
            -LiteralPath $Path `
            -SimpleMatch $Marker
    )
    if ($matches.Count -ne 1) {
        throw (
            "Expected one source marker '$Marker' in $Path; found " +
            "$($matches.Count)."
        )
    }
    return $matches[0].LineNumber
}

function New-RadIAKnowledgeSmokeProject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot
    )

    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    Copy-Item `
        -LiteralPath (Join-Path $SourceRoot "Source") `
        -Destination (Join-Path $Directory "Source") `
        -Recurse
    Copy-Item `
        -LiteralPath (Join-Path $SourceRoot "Tests") `
        -Destination (Join-Path $Directory "Tests") `
        -Recurse
    $copiedProjectPath = Join-Path $Directory "Tests\RadIATests.dproj"
    $copiedProject = Get-Content `
        -LiteralPath $copiedProjectPath `
        -Raw `
        -Encoding UTF8
    $copiedProject = $copiedProject.Replace(
        "..\Output\",
        "Output\"
    )
    Set-Content `
        -LiteralPath $copiedProjectPath `
        -Value $copiedProject `
        -Encoding UTF8
}

$bdsRegistry = "HKCU:\Software\Embarcadero\BDS\$DelphiVersion"
if ($IDE64 -and $DelphiVersion -ne "37.0") {
    throw "IDE64 is supported only for Delphi 13 (37.0)."
}

function Test-RadIAFileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        return [IO.File]::Exists($Path)
    } catch {
        return $false
    }
}
if ($ExerciseCalculatorRuntime -and -not $ExerciseDebugger) {
    throw "ExerciseCalculatorRuntime requires ExerciseDebugger."
}
$rootDirectory = (
    Get-ItemProperty -Path $bdsRegistry -Name "RootDir"
).RootDir
$idePlatform = if ($IDE64) { "Win64" } else { "Win32" }
$bdsRelativePath = if ($IDE64) { "bin64\bds.exe" } else { "bin\bds.exe" }
$bdsPath = Join-Path $rootDirectory $bdsRelativePath
$publicBpl = "C:\Users\Public\Documents\Embarcadero\Studio"
$publicBpl = Join-Path $publicBpl "$DelphiVersion\Bpl"
if ($IDE64) {
    $publicBpl = Join-Path $publicBpl "Win64"
}
$bridgePath = Join-Path $publicBpl "RadIA.MCP.Bridge.exe"
if (-not (Test-Path -LiteralPath $bdsPath -PathType Leaf)) {
    throw "Delphi executable was not found: $bdsPath"
}
if (-not (Test-Path -LiteralPath $bridgePath -PathType Leaf)) {
    throw "Installed MCP bridge was not found: $bridgePath"
}

$targetProcesses = @(
    Get-Process bds -ErrorAction SilentlyContinue |
        Where-Object {
            try {
                [IO.Path]::GetFullPath($_.Path).Equals(
                    [IO.Path]::GetFullPath($bdsPath),
                    [StringComparison]::OrdinalIgnoreCase
                )
            } catch {
                $false
            }
        }
)
if ($targetProcesses.Count -gt 0) {
    throw "Close all instances of the target Delphi IDE: $bdsPath"
}

$workspaceRoot = [IO.Path]::GetFullPath(
    (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)
$versionSource = Get-Content -LiteralPath (
    Join-Path $workspaceRoot "Source\Core\RadIA.Core.Version.pas"
) -Raw
$versionMatch = [regex]::Match(
    $versionSource,
    "CRadIAVersion\s*=\s*'([^']+)'"
)
if (-not $versionMatch.Success) {
    throw "Unable to resolve the RadIA product version."
}
$productVersion = $versionMatch.Groups[1].Value
$sourceCommit = (& git -C $workspaceRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch "^[0-9a-f]{40}$") {
    throw "The source commit could not be determined."
}
$trackedChanges = @(
    & git -C $workspaceRoot status --porcelain --untracked-files=no
)
$sourceDirty = $trackedChanges.Count -gt 0

function Remove-RadIAKnowledgeSmokeDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force
            return
        } catch {
            if ($attempt -eq 20) {
                throw
            }
            Start-Sleep -Milliseconds 500
        }
    }
}

$smokeDirectory = Join-Path (
    $workspaceRoot
) "Output\Validation\KnowledgeNotifierSmoke"
$resolvedSmokeParent = [IO.Path]::GetFullPath(
    (Join-Path $workspaceRoot "Output\Validation")
)
if (-not $smokeDirectory.StartsWith(
    $resolvedSmokeParent + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "The smoke directory escaped the validation output directory."
}
if (Test-Path -LiteralPath $smokeDirectory) {
    Remove-RadIAKnowledgeSmokeDirectory -Path $smokeDirectory
}
New-RadIAKnowledgeSmokeProject `
    -Directory $smokeDirectory `
    -SourceRoot $workspaceRoot

$projectPath = Join-Path $smokeDirectory "Tests\RadIATests.dproj"
$projectSourcePath = Join-Path $smokeDirectory "Tests\RadIATests.dpr"
$projectContent = Get-Content -LiteralPath $projectPath -Raw
$projectContent = $projectContent.Replace(
    '$(DelphiVer)',
    $DelphiVersion
)
Set-Content -LiteralPath $projectPath -Value $projectContent -Encoding UTF8
$groupPath = Join-Path $smokeDirectory "Tests\RadIAJourney.groupproj"
$groupContent = @"
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{15B352FD-3069-4A91-A775-5A16B2D660EA}</ProjectGuid>
  </PropertyGroup>
  <ItemGroup>
    <Projects Include="RadIATests.dproj">
      <Dependencies/>
    </Projects>
  </ItemGroup>
  <ProjectExtensions>
    <Borland.Personality>Default.Personality</Borland.Personality>
    <Borland.ProjectType/>
    <BorlandProject>
      <BorlandProject>
        <PersonalityInfo>
          <Option Name="Personality">Default.Personality</Option>
          <Option Name="ProjectType"/>
          <Option Name="Version">1.0</Option>
          <Option Name="GUID">{15B352FD-3069-4A91-A775-5A16B2D660EA}</Option>
        </PersonalityInfo>
      </BorlandProject>
    </BorlandProject>
  </ProjectExtensions>
  <Target Name="RadIATests">
    <MSBuild Projects="RadIATests.dproj"/>
  </Target>
  <Target Name="RadIATests:Clean">
    <MSBuild Projects="RadIATests.dproj" Targets="Clean"/>
  </Target>
  <Target Name="RadIATests:Make">
    <MSBuild Projects="RadIATests.dproj" Targets="Make"/>
  </Target>
  <Target Name="Build">
    <CallTarget Targets="RadIATests"/>
  </Target>
  <Target Name="Clean">
    <CallTarget Targets="RadIATests:Clean"/>
  </Target>
  <Target Name="Make">
    <CallTarget Targets="RadIATests:Make"/>
  </Target>
</Project>
"@
Set-Content -LiteralPath $groupPath -Value $groupContent -Encoding UTF8
$gitRoot = Split-Path -Parent $projectPath
if ($ExerciseGit) {
    & git -C $gitRoot init --quiet
    & git -C $gitRoot config user.name "RadIA Smoke"
    & git -C $gitRoot config user.email "radia-smoke@example.invalid"
    & git -C $gitRoot add --all
    & git -C $gitRoot commit --quiet -m "test: create smoke baseline"
    if ($LASTEXITCODE -ne 0) {
        throw "The disposable Git baseline could not be created."
    }
}
$unitPath = Join-Path $smokeDirectory (
    "Tests\Source\RadIA.Tests.TextNormalizer.pas"
)
$renamedUnitPath = Join-Path $smokeDirectory (
    "Tests\Source\RadIA.Tests.TextNormalizerRenamed.pas"
)
$generatedProjectDirectory = Join-Path $smokeDirectory (
    "Tests\GeneratedVclApp"
)
$generatedProjectPath = Join-Path $generatedProjectDirectory (
    "RadIAJourneyApp.dproj"
)
$generatedProjectSourcePath = Join-Path $generatedProjectDirectory (
    "RadIAJourneyApp.dpr"
)
$generatedFormSourcePath = Join-Path $generatedProjectDirectory (
    "MainForm.pas"
)
$generatedCalculatorTestExecutable = Join-Path $generatedProjectDirectory (
    "bin\Win32\Debug\RadIAJourneyAppTests.exe"
)
$transitionProjectDirectory = Join-Path $smokeDirectory (
    "Tests\TransitionVclApp"
)
$transitionProjectSourcePath = Join-Path $transitionProjectDirectory (
    "MainForm.pas"
)
$consentProbeProjectDirectory = Join-Path $smokeDirectory (
    "Tests\ConsentProbeVclApp"
)
$testExecutableCandidates = @(
    (Join-Path $smokeDirectory (
        "Tests\Output\$DelphiVersion\bin\$idePlatform\Debug\RadIATests.exe"
    )),
    (Join-Path $smokeDirectory (
        "Tests\Output\bin\$idePlatform\Debug\RadIATests.exe"
    )),
    (Join-Path $smokeDirectory (
        "Output\$DelphiVersion\bin\$idePlatform\Debug\RadIATests.exe"
    )),
    (Join-Path $smokeDirectory (
        "Output\bin\$idePlatform\Debug\RadIATests.exe"
    ))
)
$process = Start-Process -FilePath $bdsPath -PassThru
$instanceFile = Join-Path (
    [Environment]::GetFolderPath("ApplicationData")
) "RadIA\mcp.$($process.Id).json"
$journeySucceeded = $false
$templateCreated = $false
$designerChanged = $false
$developmentSurfaceCancellationPassed = $false
$developmentSurfaceCodePassed = $false
$developmentSurfaceDesignPassed = $false
$developmentSurfaceErrorPassed = $false
$readOnlyConsentPassed = $false
$reviewChangeRequestPassed = $false
$editorChanged = $false
$buildPassed = $false
$testsPassed = $false
$generatedTestsPassed = $false
$sessionConsentPassed = -not $ExerciseProjectTransition
$correctionPassed = -not $ExerciseCorrection
$testCorrectionPassed = -not $ExerciseTestCorrection
$debugPassed = -not $ExerciseDebugger
$gitPassed = -not $ExerciseGit
$testSummary = $null
$generatedTestSummary = $null
$debugSummary = $null
$gitSummary = $null

try {
    Wait-RadIACondition -TimeoutSeconds $StartupTimeoutSeconds -Condition {
        $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        $current -and
            $current.Responding -and
            $current.MainWindowTitle -and
            (Test-Path -LiteralPath $instanceFile)
    } -FailureMessage "Delphi did not become ready for the smoke test."

    Open-RadIAPath -Process $process -Path $groupPath
    Wait-RadIACondition -TimeoutSeconds 60 -Condition {
        try {
            $activeProject = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetActiveProject"
            $activeProject -and
                [IO.Path]::GetFullPath($activeProject.fileName).Equals(
                    [IO.Path]::GetFullPath($projectPath),
                    [StringComparison]::OrdinalIgnoreCase
                )
        } catch {
            $false
        }
    } -FailureMessage "The copied validation project did not become active."

    $initialIndex = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "IndexProjectKnowledge"
    if ($initialIndex.indexedFiles -lt 2) {
        throw "The initial knowledge index did not include the smoke sources."
    }

    $templatePreview = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "PreviewProjectTemplate" `
        -Arguments @{
            projectName = "RadIAJourneyApp"
            template = "vcl"
            delphiVersion = $DelphiVersion
            platforms = @("Win32")
            destinationPath = $generatedProjectDirectory
            projectSpecification = @{
                schemaVersion = 1
                kind = "calculator"
                creationProfile = "complete"
            }
        }
    if (-not $templatePreview.previewId) {
        throw "The VCL template preview did not return a preview ID."
    }
    $templateResult = Invoke-RadIAToolWithConsent `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -IDEProcess $process `
        -Name "CreateProjectFromTemplate" `
        -Arguments @{
            previewId = $templatePreview.previewId
        }
    if (-not $templateResult.committed) {
        throw "The reviewed VCL project was not committed."
    }
    $templateCreated = $true
    if (-not (Test-Path -LiteralPath $generatedProjectPath)) {
        throw "The generated VCL project file was not published."
    }
    $generatedProjectDefinition = Get-Content `
        -LiteralPath $generatedProjectPath `
        -Raw
    $requiredDebugProperties = @(
        '<DCC_DebugDCUs>true</DCC_DebugDCUs>',
        '<DCC_Optimize>false</DCC_Optimize>',
        '<DCC_GenerateStackFrames>true</DCC_GenerateStackFrames>',
        '<DCC_DebugInformation>2</DCC_DebugInformation>',
        '<DCC_LocalDebugSymbols>true</DCC_LocalDebugSymbols>',
        '<DCC_DebugInfoInExe>true</DCC_DebugInfoInExe>',
        '<DCC_RemoteDebug>true</DCC_RemoteDebug>'
    )
    foreach ($requiredDebugProperty in $requiredDebugProperties) {
        if (-not $generatedProjectDefinition.Contains(
            $requiredDebugProperty
        )) {
            throw (
                "The generated VCL project lacks the Debug property: " +
                $requiredDebugProperty
            )
        }
    }
    if ($ExerciseDebugger) {
        $generatedProjectContent = Get-Content `
            -LiteralPath $generatedProjectSourcePath `
            -Raw
        $runStatement = "  Application.Run;"
        if ([regex]::Matches(
            $generatedProjectContent,
            [regex]::Escape($runStatement)
        ).Count -ne 1) {
            throw "The generated debug target has an unexpected run statement."
        }
        if (-not $ExerciseCalculatorRuntime) {
            $generatedProjectContent = $generatedProjectContent.Replace(
                $runStatement,
                "  Application.Terminate;`r`n" + $runStatement
            )
        }
        $formsUnit = "  Vcl.Forms,"
        if (-not $generatedProjectContent.Contains($formsUnit)) {
            throw "The generated debug target lacks the VCL Forms unit."
        }
        $generatedProjectContent = $generatedProjectContent.Replace(
            $formsUnit,
            "  System.Classes,`r`n" + $formsUnit
        )
        $initializeStatement = "  Application.Initialize;"
        if (-not $generatedProjectContent.Contains($initializeStatement)) {
            throw "The generated debug target lacks Application.Initialize."
        }
        $generatedProjectContent = $generatedProjectContent.Replace(
            $initializeStatement,
            $initializeStatement + "`r`n  TThread.Sleep(2000);"
        )
        Set-Content `
            -LiteralPath $generatedProjectSourcePath `
            -Value $generatedProjectContent `
            -Encoding UTF8
        $generatedFormContent = Get-Content `
            -LiteralPath $generatedFormSourcePath `
            -Raw
        $unitTerminator = "(?s)\r?\nend\.\s*$"
        if (-not [regex]::IsMatch(
            $generatedFormContent,
            $unitTerminator
        )) {
            throw "The generated debug form has an unexpected terminator."
        }
        $generatedFormContent = [regex]::Replace(
            $generatedFormContent,
            $unitTerminator,
            "`r`ninitialization`r`n" +
                "  TThread.Sleep(15000);`r`n`r`nend.`r`n"
        )
        Set-Content `
            -LiteralPath $generatedFormSourcePath `
            -Value $generatedFormContent `
            -Encoding UTF8
    }
    if ($SkipTemplateBuild) {
        $templateOpen = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "OpenCreatedProject" `
            -Arguments @{
                previewId = $templatePreview.previewId
            }
        if (-not $templateOpen.opened) {
            throw "The generated VCL project was not opened."
        }
        $navigationStartedAt = [DateTime]::UtcNow
        $immediateNavigation = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "NavigateToFile" `
            -Arguments @{
                fileName = $generatedFormSourcePath
                line = 1
                column = 1
            }
        if (-not $immediateNavigation.fileName -or
            -not [IO.Path]::GetFullPath(
                $immediateNavigation.fileName
            ).Equals(
                [IO.Path]::GetFullPath($generatedFormSourcePath),
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw (
                "Navigation failed immediately after opening the " +
                "generated project."
            )
        }
        if (([DateTime]::UtcNow - $navigationStartedAt).TotalSeconds -ge 15) {
            throw "Read-only source navigation unexpectedly waited for consent."
        }

        $knowledgeDeadline = [DateTime]::UtcNow.AddSeconds(30)
        do {
            $knowledgeStatus = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetKnowledgeStatus"
            if ($knowledgeStatus.loaded -and $knowledgeStatus.fileCount -gt 0) {
                break
            }
            Start-Sleep -Milliseconds 250
        } while ([DateTime]::UtcNow -lt $knowledgeDeadline)
        if (-not $knowledgeStatus.loaded -or $knowledgeStatus.fileCount -lt 1) {
            throw "The generated project knowledge index did not become ready."
        }
        $generatedDocument = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "GetKnowledgeDocument" `
            -Arguments @{
                fileName = $generatedFormSourcePath
                maxCharacters = 65536
            }
        if ($generatedDocument.chunks.Count -lt 1) {
            throw "The generated form was absent from the ready knowledge index."
        }
    } else {
        $templateValidation = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "ValidateCreatedProject" `
            -Arguments @{
                previewId = $templatePreview.previewId
                timeoutMs = 600000
            }
        if (-not $templateValidation.buildSucceeded) {
            $validationDetails = $templateValidation |
                ConvertTo-Json -Depth 8 -Compress
            throw (
                "The generated VCL project failed validation: " +
                $validationDetails
            )
        }
        if (-not (Test-Path -LiteralPath $generatedCalculatorTestExecutable)) {
            throw (
                "The calculator build did not produce its companion " +
                "DUnitX executable."
            )
        }
        $generatedTestResult = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "RunDUnitXTests" `
            -Arguments @{
                executablePath = $generatedCalculatorTestExecutable
                timeoutMs = 600000
            }
        if ($generatedTestResult.status -ne "succeeded" -or
            -not $generatedTestResult.report.allPassed) {
            $generatedTestDetails = $generatedTestResult |
                ConvertTo-Json -Depth 8 -Compress
            throw (
                "The generated calculator DUnitX suite failed: " +
                $generatedTestDetails
            )
        }
        $generatedTestsPassed = $true
        $generatedTestSummary = [PSCustomObject]@{
            status = $generatedTestResult.status
            executablePath = $generatedCalculatorTestExecutable
            total = $generatedTestResult.report.total
            passed = $generatedTestResult.report.passed
            failed = $generatedTestResult.report.failed
            errors = $generatedTestResult.report.errors
            allPassed = $generatedTestResult.report.allPassed
        }
    }
    $generatedActiveProject = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "GetActiveProject"
    if (-not [IO.Path]::GetFullPath(
        $generatedActiveProject.fileName
    ).Equals(
        [IO.Path]::GetFullPath($generatedProjectPath),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "The generated VCL project did not become active."
    }
    $activeForm = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "GetActiveForm"
    if (-not $activeForm.available -or
        $activeForm.name -ne "RadIAMainForm") {
        throw "The generated VCL form did not become active in the Designer."
    }
    $designNavigation = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "NavigateToDevelopmentSurface" `
        -Arguments @{
            fileName = $generatedFormSourcePath
            intent = "edit-layout"
        }
    if (-not $designNavigation.message) {
        throw "The edit-layout intent did not activate the Form Designer."
    }
    $developmentSurfaceDesignPassed = $true
    $codeNavigation = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "NavigateToDevelopmentSurface" `
        -Arguments @{
            fileName = $generatedFormSourcePath
            intent = "implement-event"
        }
    if (-not $codeNavigation.message) {
        throw "The implement-event intent did not activate the Code editor."
    }
    $developmentSurfaceCodePassed = $true
    [void](Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "NavigateToDevelopmentSurface" `
        -Arguments @{
            fileName = $generatedFormSourcePath
            intent = "unsupported-intent"
        } `
        -ExpectError
    )
    $developmentSurfaceErrorPassed = $true
    $surfaceNavigationStartedAt = [DateTime]::UtcNow
    $surfaceNavigation = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "NavigateToDevelopmentSurface" `
        -Arguments @{
            fileName = $generatedFormSourcePath
            intent = "edit-layout"
        }
    if (-not $surfaceNavigation.message -or
        ([DateTime]::UtcNow - $surfaceNavigationStartedAt).TotalSeconds -ge 15) {
        throw "Read-only surface navigation unexpectedly waited for consent."
    }
    $readOnlyConsentPassed = $true
    $developmentSurfaceCancellationPassed = $true
    if (-not $ReadOnlyOnly) {
    $propertyPreview = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "PrepareComponentProperty" `
        -Arguments @{
            componentName = "RadIAMainForm"
            propertyName = "Caption"
            value = "RadIA Designer Journey"
        }
    $propertyApply = Invoke-RadIAToolWithConsent `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -IDEProcess $process `
        -Name "ApplyComponentProperty" `
        -Arguments @{
            previewId = $propertyPreview.previewId
        }
    if ($propertyApply.proposedValue -ne "RadIA Designer Journey") {
        throw "The reviewed VCL caption was not applied in the Designer."
    }
    $propertyRevert = Invoke-RadIAToolWithConsent `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -IDEProcess $process `
        -Name "RevertComponentProperty" `
        -Arguments @{
            previewId = $propertyPreview.previewId
        }
    if ($propertyRevert.originalValue -ne "RadIAJourneyApp") {
        throw "The VCL caption rollback did not return its original value."
    }
    $componentPreview = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "PrepareAddFormComponent" `
        -Arguments @{
            parentName = "RadIAMainForm"
            className = "TButton"
            componentName = "RadIAJourneyButton"
            left = 24
            top = 24
            width = 140
            height = 32
        }
    if (-not $componentPreview.previewId) {
        throw "The VCL component preview did not return a preview ID."
    }
    $componentApply = Invoke-RadIAToolWithConsent `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -IDEProcess $process `
        -Name "ApplyFormComponentChange" `
        -Arguments @{
            previewId = $componentPreview.previewId
        }
    if ($componentApply.component.name -ne "RadIAJourneyButton" -or
        $componentApply.component.className -ne "TButton") {
        throw "The reviewed TButton was not created in the Form Designer."
    }
    $createdComponents = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "ListFormComponents" `
        -Arguments @{
            maxCount = 100
        }
    $createdButton = @(
        $createdComponents.components |
            Where-Object {
                $_.name -eq "RadIAJourneyButton" -and
                    $_.className -eq "TButton"
            }
    )
    if ($createdButton.Count -ne 1) {
        throw "The created TButton was not visible through the live Designer."
    }
    $componentRevert = Invoke-RadIAToolWithConsent `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -IDEProcess $process `
        -Name "RevertFormComponentChange" `
        -Arguments @{
            previewId = $componentPreview.previewId
        }
    if ($componentRevert.component.name -ne "RadIAJourneyButton") {
        throw "The reviewed TButton rollback was not completed."
    }
    $designerChanged = $true
    $revertedComponents = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "ListFormComponents" `
        -Arguments @{
            maxCount = 100
        }
    if (@(
        $revertedComponents.components |
            Where-Object { $_.name -eq "RadIAJourneyButton" }
    ).Count -ne 0) {
        throw "The reverted TButton remained in the Form Designer."
    }
    Invoke-RadIAFileMenuCommand -Process $process -AccessKey "S"
    Start-Sleep -Seconds 2

    if ($ExerciseDebugger) {
        $generatedBreakpointLine = Get-RadIASourceLine `
            -Path $generatedFormSourcePath `
            -Marker "TThread.Sleep(15000);"
        $breakpoint = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "AddBreakpoint" `
            -Arguments @{
                fileName = $generatedFormSourcePath
                lineNumber = $generatedBreakpointLine
            }
        if ($breakpoint.action -ne "added") {
            throw "The generated-project breakpoint was not added."
        }
        $debugStart = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "StartDebugging"
        if (-not $debugStart.accepted) {
            throw "The generated project did not start under the debugger."
        }
        Wait-RadIACondition -TimeoutSeconds 30 -Condition {
            try {
                $runtimeDebugSession = Invoke-RadIATool `
                    -BridgePath $bridgePath `
                    -InstanceFile $instanceFile `
                    -Name "GetRuntimeDebugSession"
                $runtimeDebugSession.sessionId -and
                    $runtimeDebugSession.processId -gt 0
            } catch {
                $false
            }
        } -FailureMessage (
            "The generated project did not attach a runtime debug session."
        )
        $debugEvent = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "WaitForDebuggerEvent" `
            -Arguments @{
                sessionId = $runtimeDebugSession.sessionId
                sinceSequence = 0
                timeoutMs = 90000
                kinds = @("stopped", "exception")
            }
        if ($debugEvent.reason -ne "matched") {
            $eventDetails = $debugEvent | ConvertTo-Json -Depth 8 -Compress
            throw (
                "The generated project did not stop at the breakpoint: " +
                $eventDetails
            )
        }
        $debugState = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "GetDebuggerState"
        $callStack = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "GetCallStack" `
            -Arguments @{
                maxCount = 50
            }
        if (-not $callStack.accessible -or
            $callStack.frames.Count -lt 1) {
            throw "The generated-project call stack was unavailable."
        }
        $timeline = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "GetDebugTimeline" `
            -Arguments @{
                sinceSequence = 0
                maxCount = 100
            }
        if ($timeline.events.Count -lt 1) {
            throw "The generated-project debug timeline was empty."
        }
        if ($ExerciseCalculatorRuntime) {
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "RemoveBreakpoint" `
                -Arguments @{
                    fileName = $generatedFormSourcePath
                    lineNumber = $generatedBreakpointLine
                }
            )
            $continueResult = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "ContinueDebugging"
            if (-not $continueResult.accepted) {
                throw "The calculator debug session did not continue."
            }
            Wait-RadIACondition -TimeoutSeconds 45 -Condition {
                try {
                    $runtimeWindows = Invoke-RadIATool `
                        -BridgePath $bridgePath `
                        -InstanceFile $instanceFile `
                        -Name "GetRuntimeWindows"
                    $calculatorReady = $false
                    foreach ($runtimeWindow in @($runtimeWindows.windows)) {
                        $candidateTree = Invoke-RadIATool `
                            -BridgePath $bridgePath `
                            -InstanceFile $instanceFile `
                            -Name "GetRuntimeControlTree" `
                            -Arguments @{
                                windowId = $runtimeWindow.windowId
                            }
                        if ($candidateTree.count -ge 18) {
                            $calculatorReady = $true
                            break
                        }
                    }
                    $calculatorReady
                } catch {
                    $false
                }
            } -FailureMessage "The calculator window was not discovered."
            $runtimeWindows = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetRuntimeWindows"
            $calculatorWindow = $null
            $controlTree = $null
            foreach ($runtimeWindow in @($runtimeWindows.windows)) {
                $candidateTree = Invoke-RadIATool `
                    -BridgePath $bridgePath `
                    -InstanceFile $instanceFile `
                    -Name "GetRuntimeControlTree" `
                    -Arguments @{
                        windowId = $runtimeWindow.windowId
                    }
                if ($candidateTree.count -ge 18) {
                    $calculatorWindow = $runtimeWindow
                    $controlTree = $candidateTree
                    break
                }
            }
            if (-not $calculatorWindow -or -not $controlTree) {
                throw "The calculator control tree was not discovered."
            }
            $requiredControls = @("2", "+", "3", "=")
            $controlsByText = @{}
            foreach ($controlText in $requiredControls) {
                $control = @(
                    $controlTree.controls |
                        Where-Object {
                            $_.className -eq "TButton" -and
                            $_.text -eq $controlText
                        }
                ) | Select-Object -First 1
                if (-not $control) {
                    $controlDetails = @($controlTree.controls) |
                        Select-Object className, text, path |
                        ConvertTo-Json -Depth 4 -Compress
                    throw (
                        "Calculator control '$controlText' was not discovered: " +
                        $controlDetails
                    )
                }
                $controlsByText[$controlText] = $control
            }
            $displayControl = @(
                $controlTree.controls |
                    Where-Object {
                        $_.className -eq "TEdit" -and
                        $_.text -eq "0"
                    }
            ) | Select-Object -First 1
            if (-not $displayControl) {
                throw "The calculator display was not discovered."
            }
            $scenarioActions = @()
            foreach ($buttonText in @("2", "+", "3", "=")) {
                $scenarioActions += @{
                    kind = "invoke"
                    targetId = $controlsByText[$buttonText].controlId
                    timeoutMs = 1000
                }
            }
            $scenarioActions += @{
                kind = "wait"
                timeoutMs = 100
            }
            $scenarioActions += @{
                kind = "assert"
                selector = @{
                    className = "TEdit"
                    text = "5"
                    parentPath = $displayControl.path
                }
                value = "5"
                timeoutMs = 1000
            }
            $scenarioPreview = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "PrepareRuntimeScenario" `
                -Arguments @{
                    name = "Validate calculator primary scenario"
                    limits = @{
                        maxActions = 6
                        maxDurationMs = 15000
                        maxRepetitions = 1
                    }
                    actions = $scenarioActions
                }
            $scenarioResult = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "RunRuntimeScenario" `
                -Arguments @{
                    previewId = $scenarioPreview.previewId
                }
            if ($scenarioResult.state -ne "succeeded") {
                throw (
                    "The calculator runtime scenario failed: " +
                    ($scenarioResult | ConvertTo-Json -Depth 8 -Compress)
                )
            }
            $stopResult = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "StopDebugging"
            if (-not $stopResult.accepted) {
                throw "The calculator debug session did not stop."
            }
        } else {
            Complete-RadIADebugSession `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -FileName $generatedFormSourcePath `
                -LineNumber $generatedBreakpointLine
        }
        $debugPassed = $true
        $debugSummary = [PSCustomObject]@{
            target = "generated-vcl-$($idePlatform.ToLowerInvariant())"
            state = $debugState.state
            callStackAccessible = $callStack.accessible
            callStackFrameCount = $callStack.frames.Count
            timelineEventCount = $timeline.events.Count
            runtimeScenarioPassed = $ExerciseCalculatorRuntime.IsPresent
            runtimeControlCount = if ($ExerciseCalculatorRuntime) {
                $controlTree.count
            } else {
                0
            }
        }
    }

    $templateRollback = Invoke-RadIAToolWithConsent `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -IDEProcess $process `
        -Name "RevertCreatedProject" `
        -Arguments @{
            previewId = $templatePreview.previewId
        }
    if (-not $templateRollback.rolledBack) {
        throw "The generated VCL project was not rolled back."
    }
    if (Test-Path -LiteralPath $generatedProjectDirectory) {
        $remainingGeneratedFiles = @(
            Get-ChildItem `
                -LiteralPath $generatedProjectDirectory `
                -File `
                -Recurse `
                -Force
        )
        $unexpectedGeneratedFiles = @(
            $remainingGeneratedFiles |
                Where-Object {
                    $_.Name -ne "RadIAJourneyApp.dproj.local"
                }
        )
        if ($unexpectedGeneratedFiles.Count -gt 0) {
            throw "The generated VCL project files remained after rollback."
        }
    }
    Wait-RadIACondition -TimeoutSeconds 60 -Condition {
        try {
            $activeProject = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetActiveProject"
            $activeProject -and
                [IO.Path]::GetFullPath($activeProject.fileName).Equals(
                    [IO.Path]::GetFullPath($projectPath),
                    [StringComparison]::OrdinalIgnoreCase
                )
        } catch {
            $false
        }
    } -FailureMessage "The validation project did not reactivate."

    if ($ExerciseProjectTransition) {
        $transitionPreview = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "PreviewProjectTemplate" `
            -Arguments @{
                projectName = "RadIATransitionApp"
                template = "vcl"
                delphiVersion = $DelphiVersion
                platforms = @("Win32")
                destinationPath = $transitionProjectDirectory
                projectSpecification = @{
                    schemaVersion = 1
                    kind = "calculator"
                    creationProfile = "essential"
                }
            }
        $consentProbePreview = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "PreviewProjectTemplate" `
            -Arguments @{
                projectName = "RadIAConsentProbeApp"
                template = "vcl"
                delphiVersion = $DelphiVersion
                platforms = @("Win32")
                destinationPath = $consentProbeProjectDirectory
                projectSpecification = @{
                    schemaVersion = 1
                    kind = "blank"
                    creationProfile = "essential"
                }
            }
        $creationResults = @(
            Invoke-RadIAToolSequenceWithSessionConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Operations @(
                @{
                    Name = "CreateProjectFromTemplate"
                    Arguments = @{
                        previewId = $transitionPreview.previewId
                    }
                },
                @{
                    Name = "CreateProjectFromTemplate"
                    Arguments = @{
                        previewId = $consentProbePreview.previewId
                    }
                }
            )
        )
        $transitionCreated = $creationResults[0]
        if (-not $transitionCreated.committed) {
            throw "The replacement project was not created."
        }
        if (-not $creationResults[1].committed) {
            throw "The consent probe project was not created."
        }
        $transitionOpened = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "OpenCreatedProject" `
            -Arguments @{
                previewId = $transitionPreview.previewId
            }
        if (-not $transitionOpened.opened) {
            throw "The replacement project was not opened."
        }
        $executionResults = @(
            Invoke-RadIAToolSequenceWithSessionConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Operations @(
                @{
                    Name = "ValidateCreatedProject"
                    Arguments = @{
                        previewId = $transitionPreview.previewId
                        timeoutMs = 600000
                    }
                },
                @{
                    Name = "BuildProject"
                    Arguments = @{
                        mode = "build"
                        timeoutMs = 600000
                        clearMessages = $true
                    }
                }
            )
        )
        if (-not $executionResults[0].buildSucceeded -or
            -not $executionResults[1].success) {
            throw "The replacement project did not validate."
        }
        $transitionNavigation = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "NavigateToFile" `
            -Arguments @{
                fileName = $transitionProjectSourcePath
                line = 1
                column = 1
            }
        if (-not $transitionNavigation.fileName) {
            throw "Navigation failed after closing one project and opening another."
        }
        $rollbackResults = @(
            Invoke-RadIAToolSequenceWithSessionConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Operations @(
                @{
                    Name = "RevertCreatedProject"
                    Arguments = @{
                        previewId = $consentProbePreview.previewId
                    }
                },
                @{
                    Name = "RevertCreatedProject"
                    Arguments = @{
                        previewId = $transitionPreview.previewId
                    }
                }
            )
        )
        if (-not $rollbackResults[0].rolledBack) {
            throw "The consent probe project was not reverted."
        }
        $transitionRollback = $rollbackResults[1]
        if (-not $transitionRollback.rolledBack) {
            throw "The replacement project was not reverted."
        }
        $sessionConsentPassed = $true
    }

    if (-not $ExerciseProjectTransition) {
        Open-RadIAPath -Process $process -Path $unitPath
    Start-Sleep -Seconds 2
    $activeUnit = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "GetEditorContent"
    if (-not [IO.Path]::GetFullPath($activeUnit.fileName).Equals(
        [IO.Path]::GetFullPath($unitPath),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "The smoke unit did not become active in the editor."
    }

    $marker = "radia-notifier-modified-marker"
    $originalText =
        "initialization`r`n" +
        "  TDUnitX.RegisterTestFixture(TTestTextNormalizer);`r`n" +
        "`r`nend.`r`n"
    $replacementText =
        "initialization`r`n" +
        "  TDUnitX.RegisterTestFixture(TTestTextNormalizer);`r`n" +
        "`r`n// $marker`r`n" +
        "end.`r`n"
    $preparedPatch = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "PreparePatch" `
        -Arguments @{
            targetFile = $unitPath
            baseRevision = $activeUnit.revision
            originalText = $originalText
            replacementText = $replacementText
        }
    $reviewBlocks = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "ListBlockReviews"
    if ($reviewBlocks.blocks.Count -lt 1) {
        throw "The prepared patch did not publish a block review."
    }
    $reviewComment = "Preserve behavior and add regression evidence."
    [void](Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "DecideBlockReview" `
        -Arguments @{
            blockId = $reviewBlocks.blocks[0].id
            decision = "request-changes"
            comment = $reviewComment
        }
    )
    $reviewBlocks = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "ListBlockReviews"
    if ($reviewBlocks.blocks[0].decision -ne "changes-requested" -or
        $reviewBlocks.blocks[0].comment -ne $reviewComment -or
        $reviewBlocks.pendingCount -lt 1) {
        throw "The block review did not retain the requested changes."
    }
    $contentAfterComment = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "GetEditorContent"
    if ($contentAfterComment.content.Contains($marker)) {
        throw "Requesting block changes modified the editor buffer."
    }
    [void](Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "ClearBlockReviews"
    )
    $reviewChangeRequestPassed = $true
    [void](Invoke-RadIAToolWithConsent `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -IDEProcess $process `
        -Name "ApplyPatch" `
        -Arguments @{
            previewId = $preparedPatch.previewId
        }
    )
    Start-Sleep -Seconds 3
    $modifiedSearch = Invoke-RadIATool `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -Name "SearchProjectKnowledge" `
        -Arguments @{
            query = $marker
            maxResults = 10
        }
    if ($modifiedSearch.results.Count -lt 1) {
        throw "The Modified notifier did not refresh the live buffer."
    }

    Save-RadIAEditorBuffer `
        -BridgePath $bridgePath `
        -InstanceFile $instanceFile `
        -ExpectedPath $unitPath
    Start-Sleep -Seconds 3
    if (-not (Select-String `
        -LiteralPath $unitPath `
        -SimpleMatch $marker `
        -Quiet
    )) {
        throw "The IDE did not save the modified smoke unit."
    }
    $editorChanged = $true

    if (-not $SkipBuildAndTests) {
        if ($ExerciseCorrection) {
            $contentBeforeFailure = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetEditorContent"
            $failurePatch = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "PreparePatch" `
                -Arguments @{
                    targetFile = $unitPath
                    baseRevision = $contentBeforeFailure.revision
                    originalText = "// $marker"
                    replacementText = (
                        "// $marker`r`n" +
                        "  RadIAIntentionalCompilerFailure;"
                    )
                }
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "ApplyPatch" `
                -Arguments @{
                    previewId = $failurePatch.previewId
                }
            )
            Save-RadIAEditorBuffer `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -ExpectedPath $unitPath
            Start-Sleep -Seconds 2
            $failedBuild = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if ($failedBuild.success) {
                throw "The intentional compiler failure unexpectedly built."
            }
            if ($failedBuild.messages.Count -lt 1) {
                throw "The failed build did not return compiler diagnostics."
            }
            $correctionPassed = $true
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "RevertPatch" `
                -Arguments @{
                    previewId = $failurePatch.previewId
                }
            )
            Save-RadIAEditorBuffer `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -ExpectedPath $unitPath
            Start-Sleep -Seconds 2
        }
        $buildResult = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "BuildProject" `
            -Arguments @{
                mode = "build"
                timeoutMs = 600000
                clearMessages = $true
            }
        if (-not $buildResult.success) {
            $buildDetails = $buildResult | ConvertTo-Json -Depth 8 -Compress
            throw (
                "The RadIA build tool did not build the smoke project: " +
                $buildDetails
            )
        }
        $buildPassed = $true
        $testExecutablePath = @(
            $testExecutableCandidates |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
        ) | Select-Object -First 1
        if (-not $testExecutablePath) {
            throw "The smoke-test executable was not produced."
        }
        $testBridgePath = Join-Path `
            (Split-Path -Parent $testExecutablePath) `
            "RadIA.MCP.Bridge.exe"
        Copy-Item `
            -LiteralPath $bridgePath `
            -Destination $testBridgePath `
            -Force
        $semanticEngineSource = Join-Path $workspaceRoot (
            "Output\$DelphiVersion\bin\$idePlatform\Debug\" +
            "RadIA.Semantic.Engine.exe"
        )
        if (-not (Test-Path -LiteralPath $semanticEngineSource -PathType Leaf)) {
            throw "The semantic engine required by the DUnitX suite was not found."
        }
        Copy-Item `
            -LiteralPath $semanticEngineSource `
            -Destination (Split-Path -Parent $testExecutablePath) `
            -Force

        if ($ExerciseTestCorrection) {
            Open-RadIAPath -Process $process -Path $unitPath
            Start-Sleep -Seconds 2
            $testContentBeforeFailure = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetEditorContent"
            $testFailurePatch = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "PreparePatch" `
                -Arguments @{
                    targetFile = $unitPath
                    baseRevision = $testContentBeforeFailure.revision
                    originalText = "Assert.AreEqual('', FNormalizer.NormalizeLineBreaks(''));"
                    replacementText = "Assert.AreEqual('intentional failure', FNormalizer.NormalizeLineBreaks(''));"
                }
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "ApplyPatch" `
                -Arguments @{
                    previewId = $testFailurePatch.previewId
                }
            )
            Save-RadIAEditorBuffer `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -ExpectedPath $unitPath
            Start-Sleep -Seconds 2
            $failedTestBuild = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if (-not $failedTestBuild.success) {
                throw "The intentionally failing DUnitX project did not build."
            }
            $failedTestResult = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "RunDUnitXTests" `
                -Arguments @{
                    executablePath = $testExecutablePath
                    timeoutMs = 600000
                    tests = @(
                        "RadIA.Tests.TextNormalizer." +
                        "TTestTextNormalizer.TestNormalizeEmpty"
                    )
                }
            if ($failedTestResult.status -eq "succeeded" -or
                $failedTestResult.report.failed -lt 1) {
                $failedTestDetails = $failedTestResult |
                    ConvertTo-Json -Depth 8 -Compress
                throw (
                    "The intentional DUnitX failure was not reported: " +
                    $failedTestDetails
                )
            }
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "RevertPatch" `
                -Arguments @{
                    previewId = $testFailurePatch.previewId
                }
            )
            Save-RadIAEditorBuffer `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -ExpectedPath $unitPath
            Start-Sleep -Seconds 2
            $repairedTestBuild = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "BuildProject" `
                -Arguments @{
                    mode = "build"
                    timeoutMs = 600000
                    clearMessages = $true
                }
            if (-not $repairedTestBuild.success) {
                throw "The repaired DUnitX project did not rebuild."
            }
            $testCorrectionPassed = $true
        }

        $testResult = Invoke-RadIAToolWithConsent `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -IDEProcess $process `
            -Name "RunDUnitXTests" `
            -Arguments @{
                executablePath = $testExecutablePath
                timeoutMs = 600000
            }
        if ($testResult.status -ne "succeeded") {
            $testDetails = $testResult |
                ConvertTo-Json -Depth 8 -Compress
            throw (
                "The RadIA DUnitX runner did not pass the smoke suite: " +
                $testDetails
            )
        }
        $testsPassed = $true
        $testSummary = [PSCustomObject]@{
            status = $testResult.status
            exitCode = $testResult.exitCode
            durationMs = $testResult.durationMs
            total = $testResult.report.total
            passed = $testResult.report.passed
            failed = $testResult.report.failed
            errors = $testResult.report.errors
            ignored = $testResult.report.ignored
            allPassed = $testResult.report.allPassed
        }
    }
    if ($ExerciseGit) {
            $gitPath = "Source/RadIA.Tests.TextNormalizer.pas"
            $gitStatus = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetGitStatus"
            $gitDiff = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetGitDiff" `
                -Arguments @{
                    paths = @($gitPath)
                }
            if ($gitDiff.diff -notmatch $marker) {
                throw "The reviewed Git diff did not contain the smoke change."
            }
            $gitPreview = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "PreviewGitCommit" `
                -Arguments @{
                    paths = @($gitPath)
                    message = "test: validate RadIA reviewed commit"
                }
            if (-not $gitPreview.previewId -or
                $gitPreview.diff -notmatch $marker) {
                throw "The Git commit preview was not reviewable."
            }
            $gitCommit = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "CommitChanges" `
                -Arguments @{
                    previewId = $gitPreview.previewId
                }
            if (-not $gitCommit.committed -or -not $gitCommit.commit) {
                throw "The reviewed local Git commit was not created."
            }
            $committedMessage = & git -C $gitRoot log -1 --pretty=%s
            if ($committedMessage -ne "test: validate RadIA reviewed commit") {
                throw "The disposable repository has an unexpected commit."
            }
            $gitPassed = $true
            $gitSummary = [PSCustomObject]@{
                commit = $gitCommit.commit
                message = $committedMessage
                diffContainedMarker = $true
            }
    }

    if (-not $ExerciseGit) {
        Invoke-RadIAFileMenuCommand -Process $process -AccessKey "A"
        Set-RadIAFileDialogPath `
            -Process $process `
            -Path $renamedUnitPath
        Start-Sleep -Seconds 4
        $renamedUnit = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "GetEditorContent"
        if (-not [IO.Path]::GetFullPath($renamedUnit.fileName).Equals(
            [IO.Path]::GetFullPath($renamedUnitPath),
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "The IDE did not rename the active smoke unit."
        }

        $renamedDocument = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "GetKnowledgeDocument" `
            -Arguments @{
                fileName = $renamedUnitPath
                maxCharacters = 65536
            }
        if ($renamedDocument.chunks.Count -lt 1) {
            throw "The renamed unit was not present in the knowledge index."
        }

        Invoke-RadIAFileMenuCommand -Process $process -AccessKey "C"
        Start-Sleep -Seconds 3
        $statusAfterClose = Invoke-RadIATool `
            -BridgePath $bridgePath `
            -InstanceFile $instanceFile `
            -Name "GetKnowledgeStatus"
        if (-not $statusAfterClose.loaded) {
            throw "The knowledge index was unavailable after closing the unit."
        }
    }
    }
    }

    $journeySucceeded = $true
} finally {
    $remainingProcess = Get-Process `
        -Id $process.Id `
        -ErrorAction SilentlyContinue
    if ($remainingProcess) {
        if ($remainingProcess.MainWindowHandle -ne [IntPtr]::Zero) {
            [void]$remainingProcess.CloseMainWindow()
            if (-not $remainingProcess.WaitForExit(3000)) {
                $shutdownDeadline = [DateTime]::UtcNow.AddSeconds(
                    $ShutdownTimeoutSeconds
                )
                while (-not $remainingProcess.HasExited -and
                    [DateTime]::UtcNow -lt $shutdownDeadline) {
                    $confirmWindow =
                        [RadIAWindowNative]::FindVisibleWindow(
                            [uint32]$process.Id,
                            "TMessageForm"
                        )
                    if ($confirmWindow -ne [IntPtr]::Zero) {
                        $noButton = [RadIAWindowNative]::FindChildByText(
                            $confirmWindow,
                            "&No"
                        )
                        if ($noButton -ne [IntPtr]::Zero) {
                            [void][RadIAWindowNative]::PostMessage(
                                $noButton,
                                0x00F5,
                                [IntPtr]0,
                                [IntPtr]0
                            )
                        }
                    }
                    $saveDialog =
                        [RadIAWindowNative]::FindVisibleWindow(
                            [uint32]$process.Id,
                            "#32770"
                        )
                    if ($saveDialog -ne [IntPtr]::Zero) {
                        $cancelButton =
                            [RadIAWindowNative]::FindChildById(
                                $saveDialog,
                                2
                            )
                        if ($cancelButton -ne [IntPtr]::Zero) {
                            [void][RadIAWindowNative]::PostMessage(
                                $cancelButton,
                                0x00F5,
                                [IntPtr]0,
                                [IntPtr]0
                            )
                            Start-Sleep -Milliseconds 200
                            [void]$remainingProcess.CloseMainWindow()
                        }
                    }
                    Start-Sleep -Milliseconds 200
                    $remainingProcess.Refresh()
                }
                if (-not $remainingProcess.HasExited) {
                    if ($journeySucceeded) {
                        throw "Delphi did not exit after the smoke test."
                    }
                    Write-Warning (
                        "Terminating the disposable Delphi instance after " +
                        "the failed journey; the original failure is preserved."
                    )
                    Stop-Process -Id $remainingProcess.Id -Force
                    [void]$remainingProcess.WaitForExit(10000)
                }
            }
        } else {
            if ($journeySucceeded) {
                throw "Delphi has no main window for smoke-test shutdown."
            }
        }
    }
    $cleanupDeadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((Test-RadIAFileExists -Path $instanceFile) -and
        [DateTime]::UtcNow -lt $cleanupDeadline) {
        Start-Sleep -Milliseconds 100
    }
    if (Test-RadIAFileExists -Path $instanceFile) {
        if ($journeySucceeded) {
            throw "The MCP discovery remained after the smoke test."
        }
        Write-Warning (
            "MCP discovery remained after a failed journey; " +
            "the original failure is preserved."
        )
    }
}

if ($EvidencePath) {
    $resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
    $evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
    if ($evidenceDirectory) {
        New-Item -ItemType Directory -Path $evidenceDirectory -Force |
            Out-Null
    }
    [PSCustomObject]@{
        schemaVersion = 1
        evidenceKind = "continuousDelphiJourney"
        product = "RadIA"
        productVersion = $productVersion
        sourceCommit = $sourceCommit
        sourceDirty = $sourceDirty
        delphiVersion = $DelphiVersion
        platform = $idePlatform
        installedBplSha256 = (
            Get-FileHash -LiteralPath (
                Join-Path $publicBpl "RadIA.bpl"
            ) -Algorithm SHA256
        ).Hash
        startedAtUtc = $journeyStartedAt.ToString("o")
        completedAtUtc = [DateTime]::UtcNow.ToString("o")
        durationMs = [int](
            ([DateTime]::UtcNow - $journeyStartedAt).TotalMilliseconds
        )
        status = "passed"
        phases = [PSCustomObject]@{
            projectCreated = $templateCreated
            formDesigned = $designerChanged
            developmentSurfaceDesign = $developmentSurfaceDesignPassed
            developmentSurfaceCode = $developmentSurfaceCodePassed
            developmentSurfaceError = $developmentSurfaceErrorPassed
            readOnlyConsentPassed = $readOnlyConsentPassed
            developmentSurfaceCancellation = (
                $developmentSurfaceCancellationPassed
            )
            reviewChangeRequest = $reviewChangeRequestPassed
            sourceEdited = $editorChanged
            compilerFailureObservedAndFixed = $correctionPassed
            testFailureObservedAndFixed = $testCorrectionPassed
            buildPassed = $buildPassed
            testsPassed = $testsPassed
            generatedTestsPassed = $generatedTestsPassed
            sessionConsentPassed = $sessionConsentPassed
            projectContextSwitched = $sessionConsentPassed
            sessionContextIsolated = $sessionConsentPassed
            pendingActionIsolated = $sessionConsentPassed
            debuggerPassed = $debugPassed
            reviewedCommitCreated = $gitPassed
            shutdownPassed = $journeySucceeded
        }
        tests = $testSummary
        generatedProjectTests = $generatedTestSummary
        debugger = $debugSummary
        git = $gitSummary
    } |
        ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $resolvedEvidencePath -Encoding UTF8
}

$completedPhases = @("create", "design", "edit", "correction", "shutdown")
if (-not $SkipBuildAndTests) {
    $completedPhases += @("build", "tests")
}

if ($ExerciseDebugger) {
    $completedPhases += "debug"
}
if ($ExerciseTestCorrection) {
    $completedPhases += "DUnitX correction"
}
if ($ExerciseGit) {
    $completedPhases += "Git"
}
Write-Host (
    "Continuous Delphi journey passed for Delphi " +
    "$DelphiVersion ${idePlatform}: $($completedPhases -join ', ')."
)
