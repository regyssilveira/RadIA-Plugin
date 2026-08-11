[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,

    [string]$EvidencePath = "",

    [string]$DextRoot = $env:DEXT_ROOT,

    [switch]$SkipDext
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$studioRoot = Join-Path `
    ${env:ProgramFiles(x86)} `
    "Embarcadero\Studio\$DelphiVersion"
$compilerPath = Join-Path $studioRoot "bin\dcc32.exe"
$msBuildPath = Join-Path `
    $env:WINDIR `
    "Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
$generatorRoot = Join-Path $repositoryRoot "Tests\GeneratedProjects"
$dextOutputPath = ""
if ($DextRoot) {
    $dextOutputPath = Join-Path `
        ([IO.Path]::GetFullPath($DextRoot)) `
        "Output\$($DelphiVersion)_Win32_Debug"
}
$isolatedLibraryPath = (
    (Join-Path $studioRoot "lib\Win32\release") +
    "%3B" +
    (Join-Path $studioRoot "source\DUnitX") +
    $(if ($dextOutputPath) { "%3B$dextOutputPath" } else { "" })
)
$validationRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("RadIA-Generated-$DelphiVersion-" + [Guid]::NewGuid().ToString("N"))
$previousBds = $env:BDS
$previousBdsBin = $env:BDSBIN
$templateResults = @()
$expectedTemplates = @(
    "CalculatorApp",
    "CalculatorAppTests",
    "ConsoleApp",
    "DUnitXApp",
    "DextControllerApi",
    "DextMinimalApi",
    "FmxApp",
    "LibraryApp",
    "PackageApp",
    "ServiceApp",
    "VclApp"
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class RadIACalculatorSmokeNative {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
}
"@
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Get-RadIACalculatorControl {
    param(
        [IntPtr]$Parent,
        [string]$ClassName,
        [string]$Caption
    )
    $script:calculatorControl = [IntPtr]::Zero
    $callback = [RadIACalculatorSmokeNative+EnumProc] {
        param([IntPtr]$handle, [IntPtr]$data)
        $classText = [Text.StringBuilder]::new(128)
        $captionText = [Text.StringBuilder]::new(256)
        [void][RadIACalculatorSmokeNative]::GetClassName(
            $handle,
            $classText,
            $classText.Capacity
        )
        [void][RadIACalculatorSmokeNative]::GetWindowText(
            $handle,
            $captionText,
            $captionText.Capacity
        )
        if (
            $classText.ToString() -eq $ClassName -and
            $captionText.ToString() -eq $Caption
        ) {
            $script:calculatorControl = $handle
            return $false
        }
        return $true
    }
    [void][RadIACalculatorSmokeNative]::EnumChildWindows(
        $Parent,
        $callback,
        [IntPtr]::Zero
    )
    return $script:calculatorControl
}

function Test-RadIACalculatorInterface {
    param([Parameter(Mandatory = $true)][string]$ExecutablePath)

    $process = Start-Process -FilePath $ExecutablePath -PassThru
    try {
        [void]$process.WaitForInputIdle(10000)
        $process.Refresh()
        if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
            throw "Generated calculator did not expose a main window."
        }
        $root = [Windows.Automation.AutomationElement]::FromHandle(
            $process.MainWindowHandle
        )
        $buttons = $root.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition
        )
        foreach ($caption in @("C", "2", "+", "3", "=")) {
            $button = $buttons | Where-Object {
                $_.Current.ClassName -eq "TButton" -and
                $_.Current.Name -eq $caption
            } | Select-Object -First 1
            if (-not $button) {
                throw "Calculator button was not found: $caption"
            }
            [void][RadIACalculatorSmokeNative]::SendMessage(
                [IntPtr]$button.Current.NativeWindowHandle,
                0x00F5,
                [IntPtr]::Zero,
                [IntPtr]::Zero
            )
            Start-Sleep -Milliseconds 75
        }
        $updatedControls = $root.FindAll(
            [Windows.Automation.TreeScope]::Descendants,
            [Windows.Automation.Condition]::TrueCondition
        )
        $display = $updatedControls | Where-Object {
            $_.Current.ClassName -eq "TEdit"
        } | Select-Object -First 1
        if (-not $display) {
            throw "Calculator display was not found."
        }
        $value = $display.Current.Name
        if ($value -ne "5") {
            throw "Calculator interface did not produce 2 + 3 = 5."
        }
        return [PSCustomObject]@{
            prompt = "crie uma calculadora com operacoes basicas em VCL"
            mainWindow = $true
            testedOperation = "2 + 3 = 5"
            status = "passed"
        }
    }
    finally {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            Wait-Process -Id $process.Id -Timeout 5 -ErrorAction SilentlyContinue
        }
    }
}

function Test-DextEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Urls
    )

    $serverProcess = Start-Process `
        -FilePath $ExecutablePath `
        -PassThru `
        -WindowStyle Hidden
    try {
        foreach ($url in $Urls) {
            $lastError = $null
            $responded = $false
            for ($attempt = 1; $attempt -le 30; $attempt++) {
                if ($serverProcess.HasExited) {
                    throw "Generated DEXT server exited before responding: $ExecutablePath"
                }
                try {
                    $response = Invoke-WebRequest `
                        -Uri $url `
                        -UseBasicParsing `
                        -TimeoutSec 2
                    if ($response.StatusCode -eq 200) {
                        $responded = $true
                        break
                    }
                    $lastError = "Unexpected HTTP status $($response.StatusCode)."
                }
                catch {
                    $lastError = $_.Exception.Message
                }
                Start-Sleep -Milliseconds 200
            }
            if (-not $responded) {
                throw "Generated DEXT endpoint did not respond: $url. $lastError"
            }
        }
    }
    finally {
        if (-not $serverProcess.HasExited) {
            Stop-Process -Id $serverProcess.Id -Force
            Wait-Process -Id $serverProcess.Id -Timeout 5 -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
    throw "Delphi compiler not found: $compilerPath"
}
if (-not (Test-Path -LiteralPath $msBuildPath -PathType Leaf)) {
    throw "MSBuild not found: $msBuildPath"
}
if (-not $SkipDext -and -not $DextRoot) {
    throw "DEXT_ROOT or -DextRoot is required to validate DEXT templates."
}
if (
    -not $SkipDext -and
    -not (Test-Path -LiteralPath $dextOutputPath -PathType Container)
) {
    throw "DEXT output not found for Delphi ${DelphiVersion}: $dextOutputPath"
}

New-Item -ItemType Directory -Path $validationRoot | Out-Null
try {
    Push-Location $generatorRoot
    try {
        & $compilerPath `
            -B `
            -Q `
            "-E$validationRoot" `
            "-N0$validationRoot" `
            "RadIAGenerateProjects.dpr"
        if ($LASTEXITCODE -ne 0) {
            throw "Generated-project fixture compiler failed."
        }
    }
    finally {
        Pop-Location
    }

    $generatorPath = Join-Path `
        $validationRoot `
        "RadIAGenerateProjects.exe"
    & $generatorPath $validationRoot $DelphiVersion
    if ($LASTEXITCODE -ne 0) {
        throw "Generated-project fixture creation failed."
    }

    $env:BDS = $studioRoot
    $env:BDSBIN = Join-Path $studioRoot "bin"
    $projects = @(
        Get-ChildItem `
            -LiteralPath $validationRoot `
            -Recurse `
            -Filter "*.dproj"
    )
    if ($projects.Count -ne 11) {
        throw "Expected eleven generated projects, found $($projects.Count)."
    }
    $projectNames = @($projects | ForEach-Object { $_.BaseName })
    foreach ($expectedTemplate in $expectedTemplates) {
        if ($projectNames -notcontains $expectedTemplate) {
            throw "Generated project is missing: $expectedTemplate"
        }
    }

    foreach ($project in $projects) {
        if ($SkipDext -and $project.BaseName.StartsWith("Dext")) {
            $templateResults += [PSCustomObject]@{
                template = $project.BaseName
                projectFile = $project.Name
                platform = "Win32"
                configuration = "Debug"
                durationMs = 0
                status = "not-required"
            }
            continue
        }
        Write-Host "Building generated project: $($project.BaseName)"
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        & $msBuildPath `
            $project.FullName `
            "/t:Build" `
            "/p:Config=Debug" `
            "/p:Platform=Win32" `
            "/p:DCC_UnitSearchPath=" `
            "/p:DelphiLibraryPath=$isolatedLibraryPath" `
            "/v:minimal" `
            "/nologo"
        $stopwatch.Stop()
        if ($LASTEXITCODE -ne 0) {
            throw "Generated project failed: $($project.FullName)"
        }
        if ($project.BaseName -eq "CalculatorApp") {
            $companionTestExecutable = Join-Path `
                $validationRoot `
                "CalculatorApp\bin\Win32\Debug\CalculatorAppTests.exe"
            if (-not (Test-Path -LiteralPath $companionTestExecutable)) {
                throw (
                    "Calculator application build did not compile its " +
                    "companion DUnitX project."
                )
            }
        }
        $templateResults += [PSCustomObject]@{
            template = $project.BaseName
            projectFile = $project.Name
            platform = "Win32"
            configuration = "Debug"
            durationMs = $stopwatch.ElapsedMilliseconds
            status = "passed"
        }
    }

    if (-not $SkipDext) {
        Test-DextEndpoint `
        -ExecutablePath (
            Join-Path `
                $validationRoot `
                "DextMinimalApi\bin\Win32\Debug\DextMinimalApi.exe"
        ) `
        -Urls @("http://localhost:8081/health")
        Test-DextEndpoint `
        -ExecutablePath (
            Join-Path `
                $validationRoot `
                "DextControllerApi\bin\Win32\Debug\DextControllerApi.exe"
        ) `
        -Urls @(
            "http://localhost:8082/health",
            "http://localhost:8082/swagger.json"
        )
    }

    $calculatorInterface = Test-RadIACalculatorInterface `
        -ExecutablePath (
            Join-Path `
                $validationRoot `
                "CalculatorApp\bin\Win32\Debug\CalculatorApp.exe"
        )
    $calculatorTestExecutable = Join-Path `
        $validationRoot `
        "CalculatorApp\bin\Win32\Debug\CalculatorAppTests.exe"
    & $calculatorTestExecutable `
        "--hidebanner" `
        "--xmlfile:$validationRoot\calculator-tests.xml"
    if ($LASTEXITCODE -ne 0) {
        throw "Generated calculator unit tests failed."
    }
    $calculatorUnitTests = [PSCustomObject]@{
        executable = "CalculatorAppTests.exe"
        report = "calculator-tests.xml"
        status = "passed"
    }

    if ($EvidencePath) {
        $resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
        $evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
        if ($evidenceDirectory) {
            New-Item `
                -ItemType Directory `
                -Path $evidenceDirectory `
                -Force |
                Out-Null
        }
        $sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
        if (
            $LASTEXITCODE -ne 0 -or
            $sourceCommit -notmatch "^[0-9a-f]{40}$"
        ) {
            throw "Unable to resolve the source commit."
        }
        $productVersion = (
            Get-Content `
                -LiteralPath (Join-Path $repositoryRoot "package.json") `
                -Raw |
                ConvertFrom-Json
        ).version
        [PSCustomObject]@{
            schemaVersion = 1
            evidenceKind = "generatedProjectTemplateTarget"
            product = "RadIA"
            productVersion = $productVersion
            sourceCommit = $sourceCommit
            delphiVersion = $DelphiVersion
            compilerProductVersion = (
                Get-Item -LiteralPath $compilerPath
            ).VersionInfo.ProductVersion
            platform = "Win32"
            templateCount = $templateResults.Count
            status = "passed"
            generatedAtUtc = [DateTime]::UtcNow.ToString("o")
            templates = $templateResults
            calculatorInterface = $calculatorInterface
            calculatorUnitTests = $calculatorUnitTests
        } |
            ConvertTo-Json -Depth 5 |
            Set-Content `
                -LiteralPath $resolvedEvidencePath `
                -Encoding UTF8
    }

    Write-Host (
        "All eleven generated projects passed on Delphi $DelphiVersion."
    ) -ForegroundColor Green
}
finally {
    $env:BDS = $previousBds
    $env:BDSBIN = $previousBdsBin
    $resolvedValidationRoot = [System.IO.Path]::GetFullPath(
        $validationRoot
    )
    $resolvedTempRoot = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::GetTempPath()
    )
    $safePrefix = Join-Path `
        $resolvedTempRoot `
        "RadIA-Generated-"
    if (
        $resolvedValidationRoot.StartsWith(
            $safePrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $resolvedValidationRoot)
    ) {
        Remove-Item `
            -LiteralPath $resolvedValidationRoot `
            -Recurse `
            -Force
    }
}
