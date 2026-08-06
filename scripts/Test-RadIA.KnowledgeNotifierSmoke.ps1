param(
    [ValidateSet("22.0", "23.0", "37.0")]
    [string]$DelphiVersion = "23.0",
    [ValidateRange(30, 600)]
    [int]$StartupTimeoutSeconds = 180,
    [ValidateRange(30, 600)]
    [int]$ShutdownTimeoutSeconds = 120,
    [switch]$SkipBuildAndTests,
    [switch]$SkipTemplateBuild,
    [switch]$ExerciseDebugger,
    [switch]$ExerciseCorrection,
    [switch]$ExerciseGit
)

$ErrorActionPreference = "Stop"

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
    $menuBar = [RadIAWindowNative]::FindChildByText(
        $mainWindow,
        "Menu bar"
    )
    if ($mainWindow -eq [IntPtr]::Zero -or
        $menuBar -eq [IntPtr]::Zero) {
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
        [hashtable]$Arguments = @{}
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
        $message = $response.result.content[0].text
        throw "Tool $Name returned an error: $message"
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
        [hashtable]$Arguments = @{}
    )

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
        $allowOnce = [RadIAWindowNative]::FindChildByText(
            $consentWindow,
            "Allow once"
        )
        if ($allowOnce -eq [IntPtr]::Zero) {
            throw "The Allow once consent button was not found."
        }
        [void][RadIAWindowNative]::PostMessage(
            $allowOnce,
            0x00F5,
            [IntPtr]0,
            [IntPtr]0
        )
        if (-not $bridgeProcess.WaitForExit(600000)) {
            throw "The MCP bridge did not finish after consent."
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
            throw "The MCP bridge failed: $bridgeError"
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
$rootDirectory = (
    Get-ItemProperty -Path $bdsRegistry -Name "RootDir"
).RootDir
$bdsPath = Join-Path $rootDirectory "bin\bds.exe"
$publicBpl = "C:\Users\Public\Documents\Embarcadero\Studio"
$publicBpl = Join-Path $publicBpl "$DelphiVersion\Bpl"
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
    Remove-Item -LiteralPath $smokeDirectory -Recurse -Force
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
$testExecutableCandidates = @(
    (Join-Path $smokeDirectory (
        "Tests\Output\$DelphiVersion\bin\Win32\Debug\RadIATests.exe"
    )),
    (Join-Path $smokeDirectory (
        "Tests\Output\bin\Win32\Debug\RadIATests.exe"
    )),
    (Join-Path $smokeDirectory (
        "Output\$DelphiVersion\bin\Win32\Debug\RadIATests.exe"
    )),
    (Join-Path $smokeDirectory (
        "Output\bin\Win32\Debug\RadIATests.exe"
    ))
)
$process = Start-Process -FilePath $bdsPath -PassThru
$instanceFile = Join-Path (
    [Environment]::GetFolderPath("ApplicationData")
) "RadIA\mcp.$($process.Id).json"
$journeySucceeded = $false

try {
    Wait-RadIACondition -TimeoutSeconds $StartupTimeoutSeconds -Condition {
        $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        $current -and
            $current.Responding -and
            $current.MainWindowTitle -and
            (Test-Path -LiteralPath $instanceFile)
    } -FailureMessage "Delphi did not become ready for the smoke test."

    Open-RadIAPath -Process $process -Path $projectPath
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
    if (-not (Test-Path -LiteralPath $generatedProjectPath)) {
        throw "The generated VCL project file was not published."
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

    Invoke-RadIAFileMenuCommand -Process $process -AccessKey "S"
    Start-Sleep -Seconds 3
    if (-not (Select-String `
        -LiteralPath $unitPath `
        -SimpleMatch $marker `
        -Quiet
    )) {
        throw "The IDE did not save the modified smoke unit."
    }

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
            Invoke-RadIAFileMenuCommand -Process $process -AccessKey "S"
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
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "RevertPatch" `
                -Arguments @{
                    previewId = $failurePatch.previewId
                }
            )
            Invoke-RadIAFileMenuCommand -Process $process -AccessKey "S"
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
        if ($ExerciseDebugger) {
            $breakpoint = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "AddBreakpoint" `
                -Arguments @{
                    fileName = $projectSourcePath
                    lineNumber = 268
                }
            if ($breakpoint.action -ne "added") {
                throw "The debugger breakpoint was not added."
            }
            $debugStart = Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "StartDebugging"
            if (-not $debugStart.accepted) {
                throw "The debugger did not accept the start request."
            }
            Wait-RadIACondition -TimeoutSeconds 90 -Condition {
                try {
                    $debugState = Invoke-RadIATool `
                        -BridgePath $bridgePath `
                        -InstanceFile $instanceFile `
                        -Name "GetDebuggerState"
                    $debugState.state -in @("stopped", "exception")
                } catch {
                    $false
                }
            } -FailureMessage "The debugger did not stop at the breakpoint."
            $callStack = Invoke-RadIATool `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -Name "GetCallStack" `
                -Arguments @{
                    maxCount = 50
                }
            if (-not $callStack.accessible -or
                $callStack.frames.Count -lt 1) {
                throw "The debugger call stack was not available."
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
                throw "The event-driven debug timeline remained empty."
            }
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "StopDebugging"
            )
            [void](Invoke-RadIAToolWithConsent `
                -BridgePath $bridgePath `
                -InstanceFile $instanceFile `
                -IDEProcess $process `
                -Name "RemoveBreakpoint" `
                -Arguments @{
                    fileName = $projectSourcePath
                    lineNumber = 268
                }
            )
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
                        "Delphi remained open after a failed journey; " +
                        "the original failure is preserved."
                    )
                }
            }
        } else {
            if ($journeySucceeded) {
                throw "Delphi has no main window for smoke-test shutdown."
            }
        }
    }
    $cleanupDeadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((Test-Path -LiteralPath $instanceFile) -and
        [DateTime]::UtcNow -lt $cleanupDeadline) {
        Start-Sleep -Milliseconds 100
    }
    if (Test-Path -LiteralPath $instanceFile) {
        if ($journeySucceeded) {
            throw "The MCP discovery remained after the smoke test."
        }
        Write-Warning (
            "MCP discovery remained after a failed journey; " +
            "the original failure is preserved."
        )
    }
}

Write-Host (
    "Knowledge notifier smoke passed for Delphi " +
    "${DelphiVersion}: edit, save, build, tests, rename and close."
)
