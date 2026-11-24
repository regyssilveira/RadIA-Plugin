param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Release,
    [switch]$IDE64,
    [string]$DelphiVersion,
    [switch]$Test,
    [switch]$NoCoverage,
    [switch]$Package
)
$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop

function Get-RadIASha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $stream = [IO.File]::OpenRead($Path)
    try {
        $algorithm = [Security.Cryptography.SHA256]::Create()
        try {
            return [BitConverter]::ToString(
                $algorithm.ComputeHash($stream)
            ).Replace("-", "")
        } finally {
            $algorithm.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Copy-RadIAReplaceableFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    try {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
        return
    } catch [IO.IOException] {
        if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
            throw
        }
    }
    $pendingPath = (
        $Destination + ".pending-delete-$PID-" +
        [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
    )
    Move-Item -LiteralPath $Destination -Destination $pendingPath
    try {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    } catch {
        if (-not (Test-Path -LiteralPath $Destination) -and
            (Test-Path -LiteralPath $pendingPath)) {
            Move-Item -LiteralPath $pendingPath -Destination $Destination
        }
        throw
    }
    Remove-Item -LiteralPath $pendingPath -Force -ErrorAction SilentlyContinue
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "         Starting RadIA Build                " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 0. Validate public version consistency
$declaredVersion = (
    Get-Content -LiteralPath ".\package.json" -Raw |
    ConvertFrom-Json
).version
$versionUnitContent = Get-Content `
    -LiteralPath ".\Source\Core\RadIA.Core.Version.pas" `
    -Raw
$expectedVersionConstant = "CRadIAVersion = '$declaredVersion';"
if (-not $versionUnitContent.Contains($expectedVersionConstant)) {
    throw "RadIA.Core.Version.pas does not match package.json."
}
$resourceContent = Get-Content -LiteralPath ".\RadIA.rc" -Raw
$resourceVersion = $declaredVersion.Replace(".", ",") + ",0"
$resourceVersionText = $declaredVersion + ".0"
if (
    -not $resourceContent.Contains("FILEVERSION $resourceVersion") -or
    -not $resourceContent.Contains("PRODUCTVERSION $resourceVersion") -or
    -not $resourceContent.Contains(
        "VALUE `"FileVersion`", `"$resourceVersionText\0`""
    ) -or
    -not $resourceContent.Contains(
        "VALUE `"ProductVersion`", `"$resourceVersionText\0`""
    )
) {
    throw "RadIA.rc does not match package.json."
}

# 0.1. Validate that the documented tool catalog matches registered tools
& ".\scripts\Update-RadIA.RuntimeToolCatalog.ps1" -Check
if ($LASTEXITCODE -ne 0) {
    throw "Runtime tool catalog validation failed."
}

# 1. Detect Delphi installations in the Windows Registry
$installations = @()
$regBDS = "HKCU:\Software\Embarcadero\BDS"
if (Test-Path $regBDS) {
    $bdsKeys = Get-ChildItem $regBDS | Where-Object { $_.PSChildName -match '^\d+\.\d+$' }
    foreach ($key in $bdsKeys) {
        $ver = $key.PSChildName
        $rootDir = (Get-ItemProperty -Path $key.PSPath -Name "RootDir" -ErrorAction SilentlyContinue).RootDir
        if ($rootDir -and (Test-Path $rootDir)) {
            $friendlyName = ""
            switch ($ver) {
                "23.0" { $friendlyName = "Delphi 12 Athens" }
                "37.0" { $friendlyName = "Delphi 13" }
                default { continue }
            }
            $installations += [PSCustomObject]@{
                Version  = $ver
                RootDir  = $rootDir
                Name     = $friendlyName
                Registry = $key.PSPath
            }
        }
    }
}

# 2. Select the Delphi version to use
$selectedInstall = $null

if ($DelphiVersion) {
    if (
        $DelphiVersion -notin @("23.0", "37.0") -and
        $DelphiVersion -notlike "*Delphi 12*" -and
        $DelphiVersion -notlike "*Delphi 13*"
    ) {
        throw (
            "Unsupported Delphi version '$DelphiVersion'. " +
            "RadIA supports Delphi 12 (BDS 23.0) and Delphi 13 (BDS 37.0)."
        )
    }
    # Find the version specified by the user
    $selectedInstall = $installations | Where-Object {
        $_.Version -eq $DelphiVersion -or
        $_.Name -like "*$DelphiVersion*"
    } | Select-Object -First 1

    if (-not $selectedInstall) {
        Write-Warning (
                "Delphi version '$DelphiVersion' was not found in the Registry. " +
                "Attempting to continue with the default PATH."
        )
    } else {
        Write-Host (
            "Delphi version selected by parameter: " +
            "$($selectedInstall.Name) ($($selectedInstall.Version))"
        ) -ForegroundColor Green
    }
}

# If no version is predefined, resolve it dynamically
if (-not $selectedInstall) {
    if ($installations.Count -eq 0) {
        Write-Host (
            "No Delphi installation was found in the Windows Registry. " +
            "Attempting to continue with the default PATH."
        ) -ForegroundColor Yellow
    } elseif ($installations.Count -eq 1) {
        $selectedInstall = $installations[0]
        Write-Host (
            "Only Delphi installation detected: " +
            "$($selectedInstall.Name) ($($selectedInstall.Version))"
        ) -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Multiple Delphi versions detected on this system:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $installations.Count; $i++) {
            Write-Host (
                "  [$($i + 1)] $($installations[$i].Name) " +
                "($($installations[$i].Version)) at $($installations[$i].RootDir)"
            ) -ForegroundColor Yellow
        }
        Write-Host "  [$($installations.Count + 1)] Cancel operation" -ForegroundColor Red
        Write-Host ""

        $choice = 0
        while ($choice -lt 1 -or $choice -gt ($installations.Count + 1)) {
            $inputVal = Read-Host "Selecione a versao do Delphi desejada (1-$($installations.Count + 1))"
            if ($inputVal -match "^\d+$") {
                $choice = [int]$inputVal
            }
        }

        if ($choice -eq ($installations.Count + 1)) {
            Write-Host "Operation canceled by the user." -ForegroundColor Red
            Exit
        }

        $selectedInstall = $installations[$choice - 1]
        Write-Host "Selected version: $($selectedInstall.Name)" -ForegroundColor Green
    }
}

# If a version was selected, add its bin directory to PATH to compile with it
if ($selectedInstall) {
    $delphiBinDir = Join-Path $selectedInstall.RootDir "bin"
    if (Test-Path $delphiBinDir) {
        Write-Host "Temporarily adding compiler directory to PATH: $delphiBinDir" -ForegroundColor Yellow
        $env:PATH = "$delphiBinDir;" + $env:PATH
    }
}

# 3. Get the active dcc32 compiler version
Write-Host "Detecting Delphi compiler version..." -ForegroundColor Yellow
$dccOut = (dcc32 2>&1 | Out-String)
$compilerVersion = 0.0

if ($dccOut -match "version (\d+\.\d+)") {
    $compilerVersion = [double]$Matches[1]
    Write-Host "DCC32 compiler version: $compilerVersion" -ForegroundColor Green
} else {
    Write-Error "Compilador dcc32 nao encontrado no PATH ou versao invalida."
}

# 4. Validate compatibility and map the compiler version to DelphiVer
if ($compilerVersion -notin @(36.0, 37.0)) {
    Write-Host ""
    Write-Host "=========================================================================" -ForegroundColor Red
    Write-Host "ERROR: The detected Delphi compiler version ($compilerVersion) is not supported." -ForegroundColor Red
    Write-Host "RadIA requires Delphi 12 or 13 (DCC32 36.0 or 37.0)." -ForegroundColor Red
    Write-Host "Earlier versions are not part of the supported matrix." -ForegroundColor Red
    Write-Host "=========================================================================" -ForegroundColor Red
    Write-Host ""
    throw "Versao do Delphi nao suportada."
}

$delphiVer = ""
switch ($compilerVersion) {
    37.0 { $delphiVer = "37.0" } # Delphi 13
    36.0 { $delphiVer = "23.0" } # Delphi 12 Athens
    default {
        throw "Unsupported Delphi compiler version: $compilerVersion"
    }
}

Write-Host "Matching Delphi version (DelphiVer): $delphiVer" -ForegroundColor Green
# 4.1 Set the plugin architecture based on the user's selection
if ($IDE64) {
    Write-Host "Compiling for the 64-bit IDE (Win64) as requested by -IDE64." -ForegroundColor Yellow
} else {
    Write-Host "Compiling for the 32-bit IDE (Win32) by default." -ForegroundColor Yellow
}

# Process uninstall (when the -Uninstall switch is provided)
if ($Uninstall) {
    $runningIDEs = @(
        Get-Process bds -ErrorAction SilentlyContinue |
            Where-Object { -not $_.HasExited }
    )
    if ($runningIDEs.Count -gt 0) {
        Write-Host ""
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host "ERROR: The Delphi IDE (bds.exe) is currently open." -ForegroundColor Red
        Write-Host "Please save your work and close all IDE instances" -ForegroundColor Red
        Write-Host (
            "before uninstalling the RadIA plugin " +
            "to avoid locked files."
        ) -ForegroundColor Red
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host ""
        throw "A IDE do Delphi esta aberta."
    }

    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "        Uninstalling Delphi plugin           " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan

    $publicStudioDir = "C:\Users\Public\Documents\Embarcadero\Studio\$delphiVer"
    $publicBplDir = "$publicStudioDir\Bpl"
    $publicDcpDir = "$publicStudioDir\Dcp"

    $targetBplDir = $publicBplDir
    $targetDcpDir = $publicDcpDir
    if ($IDE64) {
        $targetBplDir = "$publicBplDir\Win64"
        $targetDcpDir = "$publicDcpDir\Win64"
    }

    $targetBpl = "$targetBplDir\RadIA.bpl"
    $targetBridge = "$targetBplDir\RadIA.MCP.Bridge.exe"
    $targetSemanticEngine = "$targetBplDir\RadIA.Semantic.Engine.exe"
    $targetExtensionPackager = (
        "$targetBplDir\New-RadIA.DeclarativeExtensionPackage.ps1"
    )
    $targetDcp = "$targetDcpDir\RadIA.dcp"
    $targetWeb = "$publicBplDir\Web"
    $targetRuntimeAdapter = "$targetBplDir\RuntimeAdapter"

    Write-Host "Removing package from the Windows Registry..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Embarcadero\BDS\$delphiVer\Known Packages"
    if ($IDE64) {
        $regPath = (
            "HKCU:\Software\Embarcadero\BDS\$delphiVer\" +
            "Known Packages x64"
        )
    }
    if (Test-Path $regPath) {
        Remove-ItemProperty -Path $regPath -Name $targetBpl -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host "Removing binaries and system resources..." -ForegroundColor Yellow
    if (Test-Path $targetBpl) {
        Remove-Item -Path $targetBpl -Force | Out-Null
    }
    if (Test-Path $targetBridge) {
        Remove-Item -Path $targetBridge -Force | Out-Null
    }
    if (Test-Path $targetSemanticEngine) {
        Remove-Item -Path $targetSemanticEngine -Force | Out-Null
    }
    if (Test-Path $targetExtensionPackager) {
        Remove-Item -Path $targetExtensionPackager -Force | Out-Null
    }
    if (Test-Path $targetDcp) {
        Remove-Item -Path $targetDcp -Force | Out-Null
    }
    $win32Package = Join-Path $publicBplDir "RadIA.bpl"
    $win64Package = Join-Path (Join-Path $publicBplDir "Win64") "RadIA.bpl"
    if (
        -not (Test-Path $win32Package) -and
        -not (Test-Path $win64Package) -and
        (Test-Path $targetWeb)
    ) {
        Remove-Item -Path $targetWeb -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if (Test-Path $targetRuntimeAdapter) {
        Remove-Item `
            -LiteralPath $targetRuntimeAdapter `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue |
            Out-Null
    }

    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " Delphi plugin uninstalled successfully!     " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Exit
}

# 3. Set the package platform and compiler
$platform = "Win32"
$compiler = "dcc32"

if ($IDE64) {
    $platform = "Win64"
    $compiler = "dcc64"
    Write-Host "Configuring compilation for the 64-bit IDE (Win64)..." -ForegroundColor Yellow
} else {
    Write-Host "Configuring compilation for the 32-bit IDE (Win32)..." -ForegroundColor Yellow
}

$configName = "Debug"
if ($Release) {
    $configName = "Release"
}

$outputRoot = ".\Output\$delphiVer"
$dcuPath = "$outputRoot\dcu\$platform\$configName"
$binPath = "$outputRoot\bin\$platform\$configName"
$bplPath = "$outputRoot\bpl\$platform"
$dcpPath = "$outputRoot\dcp\$platform"

# 4. Create the directory structure
Write-Host "Creating output directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $dcuPath, $binPath, $bplPath, $dcpPath | Out-Null

# 5. Clean temporary compiler files from source directories
Write-Host "Cleaning source directories of old compiler output..." -ForegroundColor Yellow
Get-ChildItem `
    -Path . `
    -Recurse `
    -Include *.dcu, *.exe, *.bpl, *.dcp, *.identcache, *.local |
    Where-Object { $_.FullName -notmatch "Output" } |
    Remove-Item -Force

# 6. Compile resources and the main package (RadIA.dpk)
Write-Host "Compiling RadIA.rc resources..." -ForegroundColor Yellow
& brcc32 RadIA.rc

Write-Host "Compiling RadIA.dpk ($platform) in $configName configuration..." -ForegroundColor Yellow
$dccParams = @("-Q", "-LUdesignide", "-LUvclie", "-NU$dcuPath", "-LE$bplPath", "-LN$dcpPath")
if ($Release) {
    $dccParams += @('-$D-', '-$L-', '-O+', '-DRELEASE')
} else {
    $dccParams += @('-$D+', '-$L+', '-O-', '-DDEBUG')
}
& $compiler $dccParams RadIA.dpk
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "=========================================================================" -ForegroundColor Red
    Write-Host "ERROR: Compilation of the main RadIA.dpk package failed." -ForegroundColor Red
    Write-Host "Please fix the compiler errors listed above." -ForegroundColor Red
    Write-Host "=========================================================================" -ForegroundColor Red
    Write-Host ""
    throw "Compilacao do pacote principal falhou."
}

# 6.1 Compile the extension API sample package
Write-Host "Compiling extension sample ($platform)..." -ForegroundColor Yellow
$extensionParams = @(
    "-Q",
    "-U$dcpPath",
    "-NU$dcuPath",
    "-LE$bplPath",
    "-LN$dcpPath"
)
if ($Release) {
    $extensionParams += @('-$D-', '-$L-', '-O+', '-DRELEASE')
} else {
    $extensionParams += @('-$D+', '-$L+', '-O-', '-DDEBUG')
}
& $compiler $extensionParams "Examples\ToolExtension\RadIA.SampleExtension.dpk"
if ($LASTEXITCODE -ne 0) {
    throw "Compilacao do exemplo da API de extensoes falhou."
}

# 6.2 Compile the MCP stdio bridge for external clients
Write-Host "Compiling MCP stdio bridge ($platform)..." -ForegroundColor Yellow
$mcpBridgeParams = @("-Q", "-NU$dcuPath", "-E$binPath")
if ($Release) {
    $mcpBridgeParams += @('-$D-', '-$L-', '-O+', '-DRELEASE')
} else {
    $mcpBridgeParams += @('-$D+', '-$L+', '-O-', '-DDEBUG')
}
& $compiler $mcpBridgeParams "Source\MCP\RadIA.MCP.Bridge.dpr"
if ($LASTEXITCODE -ne 0) {
    throw "Compilacao do bridge MCP stdio falhou."
}

# 6.3 Compile the standalone semantic engine
Write-Host "Compiling semantic engine ($platform)..." -ForegroundColor Yellow
$semanticEngineParams = @("-Q", "-NU$dcuPath", "-E$binPath")
if ($Release) {
    $semanticEngineParams += @('-$D-', '-$L-', '-O+', '-DRELEASE')
} else {
    $semanticEngineParams += @('-$D+', '-$L+', '-O-', '-DDEBUG')
}
& $compiler $semanticEngineParams "Source\Semantic\RadIA.Semantic.Engine.dpr"
if ($LASTEXITCODE -ne 0) {
    throw "Compilacao do motor semantico falhou."
}

# 6.4 Check for DUnitX if tests were explicitly requested
$runTests = $Test
if ($runTests) {
    $dunitxPath = ""
    if ($selectedInstall) {
        $dunitxPath = Join-Path $selectedInstall.RootDir "source\DUnitX"
    }

    if (-not $dunitxPath -or -not (Test-Path $dunitxPath)) {
        Write-Host "WARNING: The DUnitX framework was not found in your Delphi installation." -ForegroundColor Yellow
        Write-Host (
            "       Unit tests will be disabled automatically " +
            "and the installer will continue."
        ) -ForegroundColor Yellow
        $runTests = $false
    }
}

if ($runTests) {
    # 7. Compile the test suite (Tests/RadIATests.dpr)
    Write-Host "Compiling RadIATests.dpr test suite in $configName configuration..." -ForegroundColor Yellow
    Push-Location Tests
    try {
        # DCU and Bin paths are relative to the Tests directory
        $testsDcuPath = "..\Output\$delphiVer\dcu\$platform\$configName"
        $testsBinPath = "..\Output\$delphiVer\bin\$platform\$configName"
        New-Item -ItemType Directory -Force -Path $testsDcuPath, $testsBinPath | Out-Null

        $dccParamsTests = @("-Q", "-LUdesignide", "-LUvclie", "-NU$testsDcuPath", "-E$testsBinPath", "-DTESTS", "-GD")
        if ($Release) {
            $dccParamsTests += @('-$D-', '-$L-', '-O+', '-DRELEASE')
        } else {
            $dccParamsTests += @('-$D+', '-$L+', '-O-', '-DDEBUG')
        }

        # 7.1 Resolve global Delphi Registry search paths to use the same units as the IDE
        if ($selectedInstall) {
            $libRegPath = "HKCU:\Software\Embarcadero\BDS\$delphiVer\Library\$platform"
            if (Test-Path $libRegPath) {
                $librarySettings = Get-ItemProperty `
                    -Path $libRegPath `
                    -Name "Search Path" `
                    -ErrorAction SilentlyContinue
                $searchPath = $librarySettings."Search Path"
                if ($searchPath) {
                    # Replace Delphi macros with their corresponding physical paths
                    $resolvedPath = $searchPath.Replace('$(BDS)', $selectedInstall.RootDir)
                    $commonDirectory = (
                        "C:\Users\Public\Documents\Embarcadero\Studio\$delphiVer"
                    )
                    $resolvedPath = $resolvedPath.Replace(
                        '$(BDSCOMMONDIR)',
                        $commonDirectory
                    )
                    $dccParamsTests += "-U$resolvedPath"
                }
            }

            # Fall back to the source directory if DUnitX is missing from the Registry search path
            $dunitxPath = Join-Path $selectedInstall.RootDir "source\DUnitX"
            if (Test-Path $dunitxPath) {
                $dccParamsTests += "-U$dunitxPath"
                $dccParamsTests += "-U$(Join-Path $dunitxPath 'src')"
            }
        }

        # Use a response file to avoid the Windows command-line length limit.
        # The IDE's global search path can contain thousands of characters.
        $testsResponseFile = Join-Path (Resolve-Path $testsDcuPath) "RadIATests.rsp"
        $testsResponseLines = @($dccParamsTests | ForEach-Object {
            if ($_ -match '\s') {
                '"{0}"' -f $_
            } else {
                $_
            }
        })
        $testsResponseLines += "RadIATests.dpr"
        [System.IO.File]::WriteAllLines(
            $testsResponseFile,
            $testsResponseLines,
            [System.Text.Encoding]::Default
        )

        try {
            & $compiler "@$testsResponseFile"
            if ($LASTEXITCODE -ne 0) {
                throw "Compilacao da suite de testes falhou."
            }
        } finally {
            Remove-Item -LiteralPath $testsResponseFile -Force -ErrorAction SilentlyContinue
        }
    } finally {
        Pop-Location
    }

    # 8. Run unit tests and measure code coverage
    $testsExe = ".\Output\$delphiVer\bin\$platform\$configName\RadIATests.exe"
    $testsMap = ".\Output\$delphiVer\bin\$platform\$configName\RadIATests.map"
    if (Test-Path $testsExe) {
        # Try to locate CodeCoverage.exe dynamically
        $docsPath = [Environment]::GetFolderPath('MyDocuments')
        $studioDocsPath = Join-Path $docsPath "Embarcadero\Studio"
        $codeCoverageExe = $null

        if (Test-Path $studioDocsPath) {
            $codeCoverageExe = Get-ChildItem `
                -Path $studioDocsPath `
                -Filter "CodeCoverage.exe" `
                -Recurse `
                -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName -First 1
        }

        $coverageSupported = -not $IDE64
        if (
            (-not $NoCoverage) -and
            $coverageSupported -and
            $codeCoverageExe -and
            (Test-Path $codeCoverageExe)
        ) {
            Write-Host "Code coverage tool found: $codeCoverageExe" -ForegroundColor Green
            Write-Host (
                "Running unit tests with code coverage instrumentation..."
            ) -ForegroundColor Yellow

            $coverageOutputDir = ".\Output\Coverage"
            if (-not (Test-Path $coverageOutputDir)) {
                New-Item -ItemType Directory -Force -Path $coverageOutputDir | Out-Null
            }

            # Generate search paths for CodeCoverage (Source and subdirectories)
            $sourcePaths = @()
            $sourcePaths += (Get-Item -Path "Source").FullName
            $sourcePaths += Get-ChildItem -Path "Source" -Recurse -Directory | Select-Object -ExpandProperty FullName
            $sourcePaths | Out-File -FilePath "$coverageOutputDir\paths.lst" -Encoding ascii

            # Generate a list of project units with the .pas extension
            $units = Get-ChildItem -Path "Source" -Filter "*.pas" -Recurse | Select-Object -ExpandProperty Name
            $units | Out-File -FilePath "$coverageOutputDir\units.lst" -Encoding ascii

            # Run DelphiCodeCoverage
            $ccArgs = @(
                "-e", $testsExe,
                "-m", $testsMap,
                "-spf", "$coverageOutputDir\paths.lst",
                "-uf", "$coverageOutputDir\units.lst",
                "-od", $coverageOutputDir,
                "-xml",
                "-xmllines",
                "-xmlgenerics",
                "-html",
                "-tec",
                "-a", "^--exclude:ExternalProcess"
            )

            & $codeCoverageExe $ccArgs

            if ($LASTEXITCODE -eq 0) {
                $testResultPath = Join-Path `
                    (Split-Path -Parent $testsExe) `
                    "dunitx-results.xml"
                $mainTestResultPath = Join-Path `
                    (Split-Path -Parent $testsExe) `
                    "dunitx-main-results.xml"
                $externalTestResultPath = Join-Path `
                    (Split-Path -Parent $testsExe) `
                    "dunitx-external-results.xml"
                if (Test-Path -LiteralPath $testResultPath -PathType Leaf) {
                    Copy-Item `
                        -LiteralPath $testResultPath `
                        -Destination $mainTestResultPath `
                        -Force
                }
                Write-Host (
                    "Running external-process tests without instrumentation..."
                ) -ForegroundColor Yellow
                try {
                    & $testsExe "--include:ExternalProcess"
                    if ($LASTEXITCODE -ne 0) {
                        throw "External-process tests returned failures."
                    }
                    if (Test-Path -LiteralPath $testResultPath -PathType Leaf) {
                        Move-Item `
                            -LiteralPath $testResultPath `
                            -Destination $externalTestResultPath `
                            -Force
                    }
                } finally {
                    if (Test-Path -LiteralPath $mainTestResultPath -PathType Leaf) {
                        Copy-Item `
                            -LiteralPath $mainTestResultPath `
                            -Destination $testResultPath `
                            -Force
                    }
                }
                Write-Host "=============================================" -ForegroundColor Green
                Write-Host " Build, tests, and coverage completed!       " -ForegroundColor Green
                Write-Host " Reports saved to: $coverageOutputDir" -ForegroundColor Green
                Write-Host "=============================================" -ForegroundColor Green
            } else {
                throw "Code coverage or the instrumented test suite failed with exit code $LASTEXITCODE."
            }
        } else {
            if (-not $coverageSupported) {
                Write-Host "Coverage is unavailable for IDE64; running tests directly." -ForegroundColor Yellow
            } elseif ($NoCoverage) {
                Write-Host "Coverage disabled by the -NoCoverage switch." -ForegroundColor Yellow
            } else {
                Write-Host (
                    "========================================================================="
                ) -ForegroundColor Yellow
                Write-Host (
                    "WARNING: 'CodeCoverage.exe' was not found " +
                    "on this system."
                ) -ForegroundColor Yellow
                Write-Host "       Test coverage will not be generated." -ForegroundColor Yellow
                Write-Host "       Install 'Delphi Code Coverage' through GetIt or visit:" -ForegroundColor Yellow
                Write-Host "       https://github.com/DelphiCodeCoverage/DelphiCodeCoverage" -ForegroundColor Cyan
                Write-Host (
                    "========================================================================="
                ) -ForegroundColor Yellow
            }

            Write-Host "Running the test suite directly..." -ForegroundColor Yellow
            & $testsExe
            if ($LASTEXITCODE -ne 0) {
                throw "A suite de testes retornou falhas."
            }
            $testResultPath = Join-Path `
                (Split-Path -Parent $testsExe) `
                "dunitx-results.xml"
            $mainTestResultPath = Join-Path `
                (Split-Path -Parent $testsExe) `
                "dunitx-main-results.xml"
            if (Test-Path -LiteralPath $testResultPath -PathType Leaf) {
                Copy-Item `
                    -LiteralPath $testResultPath `
                    -Destination $mainTestResultPath `
                    -Force
            }

            Write-Host "=============================================" -ForegroundColor Green
            Write-Host "    Build and tests completed successfully!  " -ForegroundColor Green
            Write-Host "=============================================" -ForegroundColor Green
        }
    } else {
        Write-Error "O executavel de testes nao foi gerado em: $testsExe"
    }
} else {
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "     Compilation complete (tests skipped)    " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
}

# 9. Create a reproducible distribution package
if ($Package) {
    $sourceCommit = (& git rev-parse HEAD).Trim()
    if (($LASTEXITCODE -ne 0) -or
        ($sourceCommit -notmatch '^[0-9a-f]{40}$')) {
        throw "Unable to resolve the source Git commit for packaging."
    }
    $trackedChanges = @(& git status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the tracked Git worktree for packaging."
    }
    if ($trackedChanges.Count -gt 0) {
        throw (
            "Release packaging requires a clean tracked Git worktree. " +
            "Commit or restore tracked changes first."
        )
    }
    $productVersion = (
        Get-Content -LiteralPath ".\package.json" -Raw |
        ConvertFrom-Json
    ).version
    $packageName = (
        "RadIA-v$productVersion-Delphi-$delphiVer-" +
        "$platform-$configName"
    )
    $packagesRoot = [IO.Path]::GetFullPath(".\Output\Packages")
    $stagingRoot = [IO.Path]::GetFullPath(
        (Join-Path $packagesRoot "staging\$packageName")
    )
    if (-not $stagingRoot.StartsWith(
        $packagesRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unexpected package staging path."
    }
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }

    $packageDirectories = @(
        $stagingRoot,
        (Join-Path $stagingRoot "Bpl"),
        (Join-Path $stagingRoot "Dcp"),
        (Join-Path $stagingRoot "Bin"),
        (Join-Path $stagingRoot "Web"),
        (Join-Path $stagingRoot "RuntimeAdapter"),
        (Join-Path $stagingRoot "Redist"),
        (Join-Path $stagingRoot "Docs"),
        (Join-Path $stagingRoot "Scripts"),
        (Join-Path $stagingRoot "Examples\ToolExtension")
    )
    New-Item -ItemType Directory -Force -Path $packageDirectories |
        Out-Null

    Copy-Item `
        -LiteralPath "$bplPath\RadIA.bpl" `
        -Destination (Join-Path $stagingRoot "Bpl\RadIA.bpl")
    Copy-Item `
        -LiteralPath "$dcpPath\RadIA.dcp" `
        -Destination (Join-Path $stagingRoot "Dcp\RadIA.dcp")
    Copy-Item `
        -LiteralPath "$binPath\RadIA.MCP.Bridge.exe" `
        -Destination (Join-Path $stagingRoot "Bin\RadIA.MCP.Bridge.exe")
    Copy-Item `
        -LiteralPath "$binPath\RadIA.Semantic.Engine.exe" `
        -Destination (Join-Path $stagingRoot "Bin\RadIA.Semantic.Engine.exe")
    Copy-Item `
        -Path ".\Source\UI\Web\*" `
        -Destination (Join-Path $stagingRoot "Web") `
        -Recurse
    $runtimeAdapterSources = @(
        ".\Source\Core\RadIA.Core.RuntimeAutomation.pas",
        ".\Source\Core\RadIA.Core.RuntimeVclAdapter.pas",
        ".\Source\Runtime\RadIA.Runtime.VclAdapter.pas",
        ".\Source\Runtime\RadIA.Runtime.VclServer.pas"
    )
    foreach ($runtimeAdapterSource in $runtimeAdapterSources) {
        Copy-Item `
            -LiteralPath $runtimeAdapterSource `
            -Destination (Join-Path $stagingRoot "RuntimeAdapter")
    }
    Copy-Item `
        -LiteralPath ".\Redist\$platform\WebView2Loader.dll" `
        -Destination (Join-Path $stagingRoot "Redist\WebView2Loader.dll")
    $trackedDocumentation = @(& git ls-files -- "docs/*.md")
    if ($LASTEXITCODE -ne 0 -or $trackedDocumentation.Count -eq 0) {
        throw "Unable to resolve tracked documentation for packaging."
    }
    foreach ($documentationFile in $trackedDocumentation) {
        Copy-Item `
            -LiteralPath $documentationFile `
            -Destination (Join-Path $stagingRoot "Docs")
    }
    Copy-Item `
        -LiteralPath ".\scripts\Install-RadIA.Package.ps1" `
        -Destination (Join-Path $stagingRoot "Scripts\Install-RadIA.Package.ps1")
    Copy-Item `
        -LiteralPath ".\scripts\New-RadIA.DeclarativeExtensionPackage.ps1" `
        -Destination (
            Join-Path $stagingRoot `
                "Scripts\New-RadIA.DeclarativeExtensionPackage.ps1"
        )
    Copy-Item `
        -Path ".\Examples\ToolExtension\*" `
        -Destination (Join-Path $stagingRoot "Examples\ToolExtension") `
        -Recurse
    Copy-Item -LiteralPath ".\LICENSE" -Destination $stagingRoot
    Copy-Item -LiteralPath ".\README.md" -Destination $stagingRoot

    $manifestFiles = @(
        Get-ChildItem -LiteralPath $stagingRoot -Recurse -File |
        Sort-Object FullName |
        ForEach-Object {
            [PSCustomObject]@{
                path = $_.FullName.Substring(
                    $stagingRoot.Length + 1
                ).Replace("\", "/")
                sha256 = Get-RadIASha256 -Path $_.FullName
                size = $_.Length
            }
        }
    )
    $manifest = [PSCustomObject]@{
        schemaVersion = 1
        product = "RadIA"
        productVersion = $productVersion
        delphiVersion = $delphiVer
        platform = $platform
        configuration = $configName
        sourceCommit = $sourceCommit
        sourceDirty = $false
        files = $manifestFiles
    }
    $manifest |
        ConvertTo-Json -Depth 5 |
        Set-Content `
            -LiteralPath (Join-Path $stagingRoot "manifest.json") `
            -Encoding UTF8

    $packageValidationArgs = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $stagingRoot "Scripts\Install-RadIA.Package.ps1"),
        "-DelphiVersion",
        $delphiVer,
        "-ValidateOnly"
    )
    if ($IDE64) {
        $packageValidationArgs += "-IDE64"
    }
    & powershell.exe $packageValidationArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Package validation failed."
    }

    $packageFile = Join-Path $packagesRoot "$packageName.zip"
    if (Test-Path -LiteralPath $packageFile) {
        Remove-Item -LiteralPath $packageFile -Force
    }
    Compress-Archive `
        -Path (Join-Path $stagingRoot "*") `
        -DestinationPath $packageFile `
        -CompressionLevel Optimal
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    $checksumLines = @(
        Get-ChildItem `
            -LiteralPath $packagesRoot `
            -Filter "RadIA-v$productVersion-*.zip" |
        Sort-Object Name |
        ForEach-Object {
            $hash = Get-RadIASha256 -Path $_.FullName
            "$hash *$($_.Name)"
        }
    )
    Set-Content `
        -LiteralPath (Join-Path $packagesRoot "SHA256SUMS.txt") `
        -Value $checksumLines `
        -Encoding ASCII
    Write-Host "Package created at: $packageFile" -ForegroundColor Green
}

# 10. Automated installation (when the -Install switch is provided)
if ($Install) {
    $runningIDEs = @(
        Get-Process bds -ErrorAction SilentlyContinue |
            Where-Object { -not $_.HasExited }
    )
    if ($runningIDEs.Count -gt 0) {
        Write-Host ""
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host "ERROR: The Delphi IDE (bds.exe) is currently open." -ForegroundColor Red
        Write-Host "Please save your work and close all IDE instances" -ForegroundColor Red
        Write-Host "before installing the RadIA plugin to avoid locked files" -ForegroundColor Red
        Write-Host "or memory-loading issues." -ForegroundColor Red
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host ""
        throw "A IDE do Delphi esta aberta."
    }

    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "          Installing Delphi plugin           " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan

    $publicStudioDir = "C:\Users\Public\Documents\Embarcadero\Studio\$delphiVer"
    $publicBplDir = "$publicStudioDir\Bpl"
    $publicDcpDir = "$publicStudioDir\Dcp"

    $targetBplDir = $publicBplDir
    $targetDcpDir = $publicDcpDir
    if ($IDE64) {
        $targetBplDir = "$publicBplDir\Win64"
        $targetDcpDir = "$publicDcpDir\Win64"
    }

    Write-Host "Creating public directories if needed..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $targetBplDir, $targetDcpDir | Out-Null

    $targetBpl = "$targetBplDir\RadIA.bpl"
    $targetBridge = "$targetBplDir\RadIA.MCP.Bridge.exe"
    $targetSemanticEngine = "$targetBplDir\RadIA.Semantic.Engine.exe"
    $targetExtensionPackager = (
        "$targetBplDir\New-RadIA.DeclarativeExtensionPackage.ps1"
    )
    $targetDcp = "$targetDcpDir\RadIA.dcp"

    # 9.1 Ensure WebView2Loader.dll exists in the IDE directory for the selected architecture
    $rootDir = "C:\Program Files (x86)\Embarcadero\Studio\$delphiVer"
    if ($selectedInstall) {
        $rootDir = $selectedInstall.RootDir
    }
    $ideBinDir = Join-Path $rootDir "bin"
    $ideBin64Dir = Join-Path $rootDir "bin64"
    $dllName = "WebView2Loader.dll"

    # Copy the 32-bit DLL only for the Delphi 13 Win32 IDE target.
    if (-not $IDE64) {
        if (-not (Test-Path "$ideBinDir\$dllName")) {
            Write-Host "WebView2Loader.dll (32-bit) was not found in $ideBinDir." -ForegroundColor Yellow
            $redist32 = ".\Redist\Win32\$dllName"
            if (Test-Path $redist32) {
                Write-Host (
                    "Requesting elevated privileges to copy WebView2Loader.dll " +
                    "(32-bit) to the IDE bin directory..."
                ) -ForegroundColor Yellow
                $copyCommand = (
                    "-Command Copy-Item -Path '$redist32' " +
                    "-Destination '$ideBinDir\$dllName' -Force"
                )
                Start-Process powershell `
                    -Verb RunAs `
                    -ArgumentList $copyCommand `
                    -Wait
            }
        }
    } else {
        if (-not (Test-Path "$ideBin64Dir\$dllName")) {
            Write-Host "WebView2Loader.dll (64-bit) was not found in $ideBin64Dir." -ForegroundColor Yellow
            $redist64 = ".\Redist\Win64\$dllName"
            if (Test-Path $redist64) {
                Write-Host (
                    "Requesting elevated privileges to copy WebView2Loader.dll " +
                    "(64-bit) to the IDE bin64 directory..."
                ) -ForegroundColor Yellow
                $copyCommand = (
                    "-Command Copy-Item -Path '$redist64' " +
                    "-Destination '$ideBin64Dir\$dllName' -Force"
                )
                Start-Process powershell `
                    -Verb RunAs `
                    -ArgumentList $copyCommand `
                    -Wait
            }
        }
    }

    Write-Host "Copying binaries and resources to the IDE directories..." -ForegroundColor Yellow
    Copy-RadIAReplaceableFile `
        -Source ".\Output\$delphiVer\bpl\$platform\RadIA.bpl" `
        -Destination $targetBpl
    Copy-Item `
        -Path ".\Output\$delphiVer\bin\$platform\$configName\RadIA.MCP.Bridge.exe" `
        -Destination $targetBridge `
        -Force
    Copy-Item `
        -Path ".\Output\$delphiVer\bin\$platform\$configName\RadIA.Semantic.Engine.exe" `
        -Destination $targetSemanticEngine `
        -Force
    Copy-Item `
        -LiteralPath ".\scripts\New-RadIA.DeclarativeExtensionPackage.ps1" `
        -Destination $targetExtensionPackager `
        -Force
    Copy-Item -Path ".\Output\$delphiVer\dcp\$platform\RadIA.dcp" -Destination $targetDcp -Force

    $sourceWeb = Join-Path (Get-Location) "Source\UI\Web"
    $targetWeb = "$publicBplDir\Web"
    $targetRuntimeAdapter = "$targetBplDir\RuntimeAdapter"
    $userRadIADir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) "RadIA"
    $userWeb = Join-Path $userRadIADir "Web"
    $userWebView2 = Join-Path $userRadIADir "WebView2"

    Write-Host "Copying local Web resources..." -ForegroundColor Yellow
    if (-not (Test-Path $sourceWeb)) {
        throw "Web resources directory not found: $sourceWeb"
    }

    $resolvedPublicWebRoot = [System.IO.Path]::GetFullPath($targetWeb)
    $resolvedPublicBplRoot = [System.IO.Path]::GetFullPath($publicBplDir)
    if ($resolvedPublicWebRoot.StartsWith($resolvedPublicBplRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path $resolvedPublicWebRoot) {
            Remove-Item -LiteralPath $resolvedPublicWebRoot -Recurse -Force
        }
    } else {
        throw "Unexpected public Web path: $resolvedPublicWebRoot"
    }
    New-Item -ItemType Directory -Force -Path $resolvedPublicWebRoot | Out-Null
    Copy-Item -Path "$sourceWeb\*" -Destination $resolvedPublicWebRoot -Force -Recurse

    $runtimeAdapterSources = @(
        ".\Source\Core\RadIA.Core.RuntimeAutomation.pas",
        ".\Source\Core\RadIA.Core.RuntimeVclAdapter.pas",
        ".\Source\Runtime\RadIA.Runtime.VclAdapter.pas",
        ".\Source\Runtime\RadIA.Runtime.VclServer.pas"
    )
    if (Test-Path -LiteralPath $targetRuntimeAdapter) {
        Remove-Item -LiteralPath $targetRuntimeAdapter -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $targetRuntimeAdapter | Out-Null
    foreach ($runtimeAdapterSource in $runtimeAdapterSources) {
        Copy-Item `
            -LiteralPath $runtimeAdapterSource `
            -Destination $targetRuntimeAdapter `
            -Force
    }

    Write-Host "Updating the user's local Web resource cache..." -ForegroundColor Yellow
    $resolvedUserWebRoot = [System.IO.Path]::GetFullPath($userWeb)
    $resolvedUserRadIARoot = [System.IO.Path]::GetFullPath($userRadIADir)
    if ($resolvedUserWebRoot.StartsWith($resolvedUserRadIARoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path $resolvedUserWebRoot) {
            Remove-Item -LiteralPath $resolvedUserWebRoot -Recurse -Force
        }
    } else {
        throw "Unexpected local Web path: $resolvedUserWebRoot"
    }
    New-Item -ItemType Directory -Force -Path $resolvedUserWebRoot | Out-Null
    Copy-Item -Path "$sourceWeb\*" -Destination $resolvedUserWebRoot -Force -Recurse

    $resolvedUserWebView2Root = [System.IO.Path]::GetFullPath($userWebView2)
    if ($resolvedUserWebView2Root.StartsWith($resolvedUserRadIARoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path $resolvedUserWebView2Root) {
            Write-Host "Clearing the local WebView2 cache..." -ForegroundColor Yellow
            Remove-Item -LiteralPath $resolvedUserWebView2Root -Recurse -Force
        }
    } else {
        throw "Unexpected WebView2 cache path: $resolvedUserWebView2Root"
    }

    Write-Host "Registering package in the Windows Registry..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Embarcadero\BDS\$delphiVer\Known Packages"
    if ($IDE64) {
        $regPath = (
            "HKCU:\Software\Embarcadero\BDS\$delphiVer\" +
            "Known Packages x64"
        )
    }

    # Ensure the Registry key exists before writing to it
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    New-ItemProperty `
        -Path $regPath `
        -Name $targetBpl `
        -Value "Rad IA - AI Assistant for Delphi IDE" `
        -PropertyType String `
        -Force |
        Out-Null

    $disabledRegPath = "HKCU:\Software\Embarcadero\BDS\$delphiVer\Disabled Packages"
    if ($IDE64) {
        $disabledRegPath = (
            "HKCU:\Software\Embarcadero\BDS\$delphiVer\" +
            "Disabled Packages x64"
        )
    }
    if (Test-Path $disabledRegPath) {
        Remove-ItemProperty `
            -LiteralPath $disabledRegPath `
            -Name $targetBpl `
            -ErrorAction SilentlyContinue
    }

    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " Delphi plugin installed successfully!       " -ForegroundColor Green
    Write-Host " RadIA will be available the next time the IDE" -ForegroundColor Green
    Write-Host " starts.                                     " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
}

