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

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "         Iniciando Build do Rad IA           " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 0. Validar consistencia da versao publica
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

# 0.1. Validar o catálogo documentado das tools realmente registradas
& ".\scripts\Update-RadIA.RuntimeToolCatalog.ps1" -Check
if ($LASTEXITCODE -ne 0) {
    throw "Runtime tool catalog validation failed."
}

# 1. Detectar instalacoes do Delphi no Registro do Windows
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
                "22.0" { $friendlyName = "Delphi 11 Alexandria" }
                "23.0" { $friendlyName = "Delphi 12 Athens" }
                "37.0" { $friendlyName = "Delphi 13" }
                default { $friendlyName = "Delphi (BDS $ver)" }
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

# 2. Selecionar a versao do Delphi a ser utilizada
$selectedInstall = $null

if ($DelphiVersion) {
    # Tentar encontrar a versao informada pelo usuario
    $selectedInstall = $installations | Where-Object {
        $_.Version -eq $DelphiVersion -or
        $_.Name -like "*$DelphiVersion*"
    } | Select-Object -First 1

    if (-not $selectedInstall) {
        Write-Warning (
            "Versao do Delphi '$DelphiVersion' nao encontrada no registro. " +
            "Tentando prosseguir com o PATH padrao."
        )
    } else {
        Write-Host (
            "Versao do Delphi selecionada via parametro: " +
            "$($selectedInstall.Name) ($($selectedInstall.Version))"
        ) -ForegroundColor Green
    }
}

# Se nao houver versao pre-definida, resolvemos dinamicamente
if (-not $selectedInstall) {
    if ($installations.Count -eq 0) {
        Write-Host (
            "Nenhuma instalacao do Delphi encontrada no Registro do Windows. " +
            "Tentando prosseguir com o PATH padrao."
        ) -ForegroundColor Yellow
    } elseif ($installations.Count -eq 1) {
        $selectedInstall = $installations[0]
        Write-Host (
            "Unica instalacao do Delphi detectada: " +
            "$($selectedInstall.Name) ($($selectedInstall.Version))"
        ) -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Multiplas versoes do Delphi detectadas no sistema:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $installations.Count; $i++) {
            Write-Host (
                "  [$($i + 1)] $($installations[$i].Name) " +
                "($($installations[$i].Version)) em $($installations[$i].RootDir)"
            ) -ForegroundColor Yellow
        }
        Write-Host "  [$($installations.Count + 1)] Cancelar Operacao" -ForegroundColor Red
        Write-Host ""

        $choice = 0
        while ($choice -lt 1 -or $choice -gt ($installations.Count + 1)) {
            $inputVal = Read-Host "Selecione a versao do Delphi desejada (1-$($installations.Count + 1))"
            if ($inputVal -match "^\d+$") {
                $choice = [int]$inputVal
            }
        }

        if ($choice -eq ($installations.Count + 1)) {
            Write-Host "Operacao cancelada pelo usuario." -ForegroundColor Red
            Exit
        }

        $selectedInstall = $installations[$choice - 1]
        Write-Host "Versao selecionada: $($selectedInstall.Name)" -ForegroundColor Green
    }
}

# Se selecionou uma versao, injeta a pasta bin correspondente no PATH para compilar com ela
if ($selectedInstall) {
    $delphiBinDir = Join-Path $selectedInstall.RootDir "bin"
    if (Test-Path $delphiBinDir) {
        Write-Host "Configurando PATH temporario com compilador de: $delphiBinDir" -ForegroundColor Yellow
        $env:PATH = "$delphiBinDir;" + $env:PATH
    }
}

# 3. Obter a versao do compilador dcc32 ativo
Write-Host "Detectando versao do compilador Delphi..." -ForegroundColor Yellow
$dccOut = (dcc32 2>&1 | Out-String)
$compilerVersion = 0.0

if ($dccOut -match "version (\d+\.\d+)") {
    $compilerVersion = [double]$Matches[1]
    Write-Host "Compilador DCC32 Versao: $compilerVersion" -ForegroundColor Green
} else {
    Write-Error "Compilador dcc32 nao encontrado no PATH ou versao invalida."
}

# 4. Validar compatibilidade e mapear versao do compilador para a versao do Delphi (DelphiVer)
if ($compilerVersion -lt 35.0) {
    Write-Host ""
    Write-Host "=========================================================================" -ForegroundColor Red
    Write-Host "ERRO: A versao do compilador Delphi detectada ($compilerVersion) nao e suportada." -ForegroundColor Red
    Write-Host "O Rad IA exige obrigatoriamente o Delphi 11 Alexandria ou superior (DCC32 >= 35.0)" -ForegroundColor Red
    Write-Host "devido ao uso de recursos nativos da API de WebView2 (TEdgeBrowser)." -ForegroundColor Red
    Write-Host "=========================================================================" -ForegroundColor Red
    Write-Host ""
    throw "Versao do Delphi nao suportada."
}

$delphiVer = ""
switch ($compilerVersion) {
    37.0 { $delphiVer = "37.0" } # Delphi 13
    36.0 { $delphiVer = "23.0" } # Delphi 12 Athens
    35.0 { $delphiVer = "22.0" } # Delphi 11 Alexandria
    default {
        $delphiVer = "{0:N1}" -f $compilerVersion
    }
}

Write-Host "Versao do Delphi correspondente (DelphiVer): $delphiVer" -ForegroundColor Green
# 4.1 Ajustar a arquitetura do plugin conforme as escolhas do usuario
if ($IDE64) {
    Write-Host "Compilando para IDE de 64 bits (Win64) conforme parametro -IDE64 informado." -ForegroundColor Yellow
} else {
    Write-Host "Compilando para IDE de 32 bits (Win32) por padrao." -ForegroundColor Yellow
}

# Processar Desinstalacao (se a flag -Uninstall for fornecida)
if ($Uninstall) {
    if (Get-Process bds -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host "ERRO: A IDE do Delphi (bds.exe) esta aberta no momento." -ForegroundColor Red
        Write-Host "Por favor, salve seu trabalho e feche todas as instancias da IDE" -ForegroundColor Red
        Write-Host (
            "antes de executar a desinstalacao do plugin Rad IA " +
            "para evitar arquivos travados."
        ) -ForegroundColor Red
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host ""
        throw "A IDE do Delphi esta aberta."
    }

    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "       Desinstalando Plugin do Delphi        " -ForegroundColor Cyan
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
    $targetDcp = "$targetDcpDir\RadIA.dcp"
    $targetWeb = "$publicBplDir\Web"

    Write-Host "Removendo pacote do Registro do Windows..." -ForegroundColor Yellow
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

    Write-Host "Removendo binarios e recursos do sistema..." -ForegroundColor Yellow
    if (Test-Path $targetBpl) {
        Remove-Item -Path $targetBpl -Force | Out-Null
    }
    if (Test-Path $targetBridge) {
        Remove-Item -Path $targetBridge -Force | Out-Null
    }
    if (Test-Path $targetDcp) {
        Remove-Item -Path $targetDcp -Force | Out-Null
    }
    if (Test-Path $targetWeb) {
        Remove-Item -Path $targetWeb -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " Plugin desinstalado com sucesso do Delphi!  " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Exit
}

# 3. Definir plataforma e compilador do pacote
$platform = "Win32"
$compiler = "dcc32"

if ($IDE64) {
    $platform = "Win64"
    $compiler = "dcc64"
    Write-Host "Configurando compilacao para IDE de 64 bits (Win64)..." -ForegroundColor Yellow
} else {
    Write-Host "Configurando compilacao para IDE de 32 bits (Win32)..." -ForegroundColor Yellow
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

# 4. Criar estrutura de pastas
Write-Host "Criando diretorios de output..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $dcuPath, $binPath, $bplPath, $dcpPath | Out-Null

# 5. Limpeza de arquivos temporarios de compilacao em pastas de fontes
Write-Host "Limpando diretorios de codigo-fonte de compilacoes antigas..." -ForegroundColor Yellow
Get-ChildItem `
    -Path . `
    -Recurse `
    -Include *.dcu, *.exe, *.bpl, *.dcp, *.identcache, *.local |
    Where-Object { $_.FullName -notmatch "Output" } |
    Remove-Item -Force

# 6. Compilar Recursos e Pacote Principal (RadIA.dpk)
Write-Host "Compilando recursos RadIA.rc..." -ForegroundColor Yellow
& brcc32 RadIA.rc

Write-Host "Compilando RadIA.dpk ($platform) em modo $configName..." -ForegroundColor Yellow
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
    Write-Host "ERRO: A compilacao do pacote principal RadIA.dpk falhou." -ForegroundColor Red
    Write-Host "Por favor, corrija os erros de compilacao listados acima." -ForegroundColor Red
    Write-Host "=========================================================================" -ForegroundColor Red
    Write-Host ""
    throw "Compilacao do pacote principal falhou."
}

# 6.1 Compilar pacote de exemplo da API de extensoes
Write-Host "Compilando exemplo de extensao ($platform)..." -ForegroundColor Yellow
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

# 6.2 Compilar bridge MCP stdio para clientes externos
Write-Host "Compilando bridge MCP stdio ($platform)..." -ForegroundColor Yellow
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

# 6.3 Verificar disponibilidade do DUnitX caso os testes tenham sido explicitamente solicitados
$runTests = $Test
if ($runTests) {
    $dunitxPath = ""
    if ($selectedInstall) {
        $dunitxPath = Join-Path $selectedInstall.RootDir "source\DUnitX"
    }

    if (-not $dunitxPath -or -not (Test-Path $dunitxPath)) {
        Write-Host "AVISO: O framework DUnitX nao foi detectado na sua instalacao do Delphi." -ForegroundColor Yellow
        Write-Host (
            "       Os testes unitarios serao desativados automaticamente " +
            "e o instalador prosseguira."
        ) -ForegroundColor Yellow
        $runTests = $false
    }
}

if ($runTests) {
    # 7. Compilar Suite de Testes (Tests/RadIATests.dpr)
    Write-Host "Compilando suite de testes RadIATests.dpr em modo $configName..." -ForegroundColor Yellow
    Push-Location Tests
    try {
        # DCU e Bin caminhos relativos de dentro da pasta Tests
        $testsDcuPath = "..\Output\$delphiVer\dcu\$platform\$configName"
        $testsBinPath = "..\Output\$delphiVer\bin\$platform\$configName"
        New-Item -ItemType Directory -Force -Path $testsDcuPath, $testsBinPath | Out-Null

        $dccParamsTests = @("-Q", "-LUdesignide", "-LUvclie", "-NU$testsDcuPath", "-E$testsBinPath", "-DTESTS", "-GD")
        if ($Release) {
            $dccParamsTests += @('-$D-', '-$L-', '-O+', '-DRELEASE')
        } else {
            $dccParamsTests += @('-$D+', '-$L+', '-O-', '-DDEBUG')
        }

        # 7.1 Resolver Search Paths globais do Delphi no Registro para que compile com as mesmas units da IDE
        if ($selectedInstall) {
            $libRegPath = "HKCU:\Software\Embarcadero\BDS\$delphiVer\Library\$platform"
            if (Test-Path $libRegPath) {
                $librarySettings = Get-ItemProperty `
                    -Path $libRegPath `
                    -Name "Search Path" `
                    -ErrorAction SilentlyContinue
                $searchPath = $librarySettings."Search Path"
                if ($searchPath) {
                    # Substitui as macro-variaveis do Delphi pelo caminho fisico correspondente
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

            # Fallback de seguranca caso o DUnitX nao esteja no Search Path do registro mas exista na pasta source
            $dunitxPath = Join-Path $selectedInstall.RootDir "source\DUnitX"
            if (Test-Path $dunitxPath) {
                $dccParamsTests += "-U$dunitxPath"
                $dccParamsTests += "-U$(Join-Path $dunitxPath 'src')"
            }
        }

        # Usa response file para evitar o limite de tamanho da linha de comando do Windows.
        # O Search Path global da IDE pode conter milhares de caracteres.
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

    # 8. Executar os Testes Unitarios e Cobertura de Codigo
    $testsExe = ".\Output\$delphiVer\bin\$platform\$configName\RadIATests.exe"
    $testsMap = ".\Output\$delphiVer\bin\$platform\$configName\RadIATests.map"
    if (Test-Path $testsExe) {
        # Tentar localizar o CodeCoverage.exe dinamicamente
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
            Write-Host "Ferramenta de cobertura de codigo detectada em: $codeCoverageExe" -ForegroundColor Green
            Write-Host (
                "Executando testes unitarios com instrumentacao " +
                "de cobertura de codigo..."
            ) -ForegroundColor Yellow

            $coverageOutputDir = ".\Output\Coverage"
            if (-not (Test-Path $coverageOutputDir)) {
                New-Item -ItemType Directory -Force -Path $coverageOutputDir | Out-Null
            }

            # Gerar lista de paths de busca para o CodeCoverage (Source e subdiretorios)
            $sourcePaths = @()
            $sourcePaths += (Get-Item -Path "Source").FullName
            $sourcePaths += Get-ChildItem -Path "Source" -Recurse -Directory | Select-Object -ExpandProperty FullName
            $sourcePaths | Out-File -FilePath "$coverageOutputDir\paths.lst" -Encoding ascii

            # Gerar lista de units do projeto com a extensao .pas
            $units = Get-ChildItem -Path "Source" -Filter "*.pas" -Recurse | Select-Object -ExpandProperty Name
            $units | Out-File -FilePath "$coverageOutputDir\units.lst" -Encoding ascii

            # Executar DelphiCodeCoverage
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
                Write-Host (
                    "Executando testes de processos externos fora da instrumentacao..."
                ) -ForegroundColor Yellow
                & $testsExe "--include:ExternalProcess"
                if ($LASTEXITCODE -ne 0) {
                    throw "External-process tests returned failures."
                }
                Write-Host "=============================================" -ForegroundColor Green
                Write-Host "    Build, Testes e Cobertura Concluidos!    " -ForegroundColor Green
                Write-Host " Relatorios salvos em: $coverageOutputDir" -ForegroundColor Green
                Write-Host "=============================================" -ForegroundColor Green
            } else {
                throw "Code coverage or the instrumented test suite failed with exit code $LASTEXITCODE."
            }
        } else {
            if (-not $coverageSupported) {
                Write-Host "Coverage is unavailable for IDE64; running tests directly." -ForegroundColor Yellow
            } elseif ($NoCoverage) {
                Write-Host "Cobertura desativada pela flag -NoCoverage." -ForegroundColor Yellow
            } else {
                Write-Host (
                    "========================================================================="
                ) -ForegroundColor Yellow
                Write-Host (
                    "AVISO: A ferramenta 'CodeCoverage.exe' nao foi encontrada " +
                    "no seu sistema."
                ) -ForegroundColor Yellow
                Write-Host "       A cobertura de testes nao sera gerada." -ForegroundColor Yellow
                Write-Host "       Instale o 'Delphi Code Coverage' via GetIt ou consulte:" -ForegroundColor Yellow
                Write-Host "       https://github.com/DelphiCodeCoverage/DelphiCodeCoverage" -ForegroundColor Cyan
                Write-Host (
                    "========================================================================="
                ) -ForegroundColor Yellow
            }

            Write-Host "Executando suite de testes de forma direta..." -ForegroundColor Yellow
            & $testsExe
            if ($LASTEXITCODE -ne 0) {
                throw "A suite de testes retornou falhas."
            }

            Write-Host "=============================================" -ForegroundColor Green
            Write-Host "    Build e Testes Concluidos com Sucesso!   " -ForegroundColor Green
            Write-Host "=============================================" -ForegroundColor Green
        }
    } else {
        Write-Error "O executavel de testes nao foi gerado em: $testsExe"
    }
} else {
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "      Compilacao Concluida (Testes Omitidos) " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
}

# 9. Criar pacote de distribuicao reproduzivel
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
        -Path ".\Source\UI\Web\*" `
        -Destination (Join-Path $stagingRoot "Web") `
        -Recurse
    Copy-Item `
        -LiteralPath ".\Redist\$platform\WebView2Loader.dll" `
        -Destination (Join-Path $stagingRoot "Redist\WebView2Loader.dll")
    Get-ChildItem -LiteralPath ".\docs" -File -Filter "*.md" |
        Copy-Item -Destination (Join-Path $stagingRoot "Docs")
    Copy-Item `
        -LiteralPath ".\scripts\Install-RadIA.Package.ps1" `
        -Destination (Join-Path $stagingRoot "Scripts\Install-RadIA.Package.ps1")
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
                sha256 = (
                    Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
                ).Hash
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
            $hash = (
                Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
            ).Hash
            "$hash *$($_.Name)"
        }
    )
    Set-Content `
        -LiteralPath (Join-Path $packagesRoot "SHA256SUMS.txt") `
        -Value $checksumLines `
        -Encoding ASCII
    Write-Host "Pacote criado em: $packageFile" -ForegroundColor Green
}

# 10. Instalacao automatizada (se a flag -Install for fornecida)
if ($Install) {
    if (Get-Process bds -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host "ERRO: A IDE do Delphi (bds.exe) esta aberta no momento." -ForegroundColor Red
        Write-Host "Por favor, salve seu trabalho e feche todas as instancias da IDE" -ForegroundColor Red
        Write-Host "antes de executar a instalacao do plugin Rad IA para evitar arquivos travados" -ForegroundColor Red
        Write-Host "ou problemas de carregamento na memoria." -ForegroundColor Red
        Write-Host "=========================================================================" -ForegroundColor Red
        Write-Host ""
        throw "A IDE do Delphi esta aberta."
    }

    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "         Instalando Plugin no Delphi         " -ForegroundColor Cyan
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

    Write-Host "Criando pastas publicas se nao existirem..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $targetBplDir, $targetDcpDir | Out-Null

    $targetBpl = "$targetBplDir\RadIA.bpl"
    $targetBridge = "$targetBplDir\RadIA.MCP.Bridge.exe"
    $targetDcp = "$targetDcpDir\RadIA.dcp"

    # 9.1 Garantir existencia de WebView2Loader.dll na pasta da IDE correspondente a arquitetura
    $rootDir = "C:\Program Files (x86)\Embarcadero\Studio\$delphiVer"
    if ($selectedInstall) {
        $rootDir = $selectedInstall.RootDir
    }
    $ideBinDir = Join-Path $rootDir "bin"
    $ideBin64Dir = Join-Path $rootDir "bin64"
    $dllName = "WebView2Loader.dll"

    # Copiar a DLL de 32-bit apenas se a IDE for de 32-bit (Delphi 12 ou anterior, sem flag IDE64)
    if (-not $IDE64) {
        if (-not (Test-Path "$ideBinDir\$dllName")) {
            Write-Host "WebView2Loader.dll (32-bit) nao encontrada em $ideBinDir." -ForegroundColor Yellow
            $redist32 = ".\Redist\Win32\$dllName"
            if (Test-Path $redist32) {
                Write-Host (
                    "Solicitando privilegios para copiar WebView2Loader.dll " +
                    "(32-bit) para a pasta bin da IDE..."
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
            Write-Host "WebView2Loader.dll (64-bit) nao encontrada em $ideBin64Dir." -ForegroundColor Yellow
            $redist64 = ".\Redist\Win64\$dllName"
            if (Test-Path $redist64) {
                Write-Host (
                    "Solicitando privilegios para copiar WebView2Loader.dll " +
                    "(64-bit) para a pasta bin64 da IDE..."
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

    Write-Host "Copiando binarios e recursos para as pastas da IDE..." -ForegroundColor Yellow
    Copy-Item -Path ".\Output\$delphiVer\bpl\$platform\RadIA.bpl" -Destination $targetBpl -Force
    Copy-Item `
        -Path ".\Output\$delphiVer\bin\$platform\$configName\RadIA.MCP.Bridge.exe" `
        -Destination $targetBridge `
        -Force
    Copy-Item -Path ".\Output\$delphiVer\dcp\$platform\RadIA.dcp" -Destination $targetDcp -Force

    $sourceWeb = Join-Path (Get-Location) "Source\UI\Web"
    $targetWeb = "$publicBplDir\Web"
    $userRadIADir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) "RadIA"
    $userWeb = Join-Path $userRadIADir "Web"
    $userWebView2 = Join-Path $userRadIADir "WebView2"

    Write-Host "Copiando pasta de recursos Web locais..." -ForegroundColor Yellow
    if (-not (Test-Path $sourceWeb)) {
        throw "Pasta de recursos Web nao encontrada: $sourceWeb"
    }

    $resolvedPublicWebRoot = [System.IO.Path]::GetFullPath($targetWeb)
    $resolvedPublicBplRoot = [System.IO.Path]::GetFullPath($publicBplDir)
    if ($resolvedPublicWebRoot.StartsWith($resolvedPublicBplRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path $resolvedPublicWebRoot) {
            Remove-Item -LiteralPath $resolvedPublicWebRoot -Recurse -Force
        }
    } else {
        throw "Caminho Web publico inesperado: $resolvedPublicWebRoot"
    }
    New-Item -ItemType Directory -Force -Path $resolvedPublicWebRoot | Out-Null
    Copy-Item -Path "$sourceWeb\*" -Destination $resolvedPublicWebRoot -Force -Recurse

    Write-Host "Atualizando cache local de recursos Web do usuario..." -ForegroundColor Yellow
    $resolvedUserWebRoot = [System.IO.Path]::GetFullPath($userWeb)
    $resolvedUserRadIARoot = [System.IO.Path]::GetFullPath($userRadIADir)
    if ($resolvedUserWebRoot.StartsWith($resolvedUserRadIARoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path $resolvedUserWebRoot) {
            Remove-Item -LiteralPath $resolvedUserWebRoot -Recurse -Force
        }
    } else {
        throw "Caminho Web local inesperado: $resolvedUserWebRoot"
    }
    New-Item -ItemType Directory -Force -Path $resolvedUserWebRoot | Out-Null
    Copy-Item -Path "$sourceWeb\*" -Destination $resolvedUserWebRoot -Force -Recurse

    $resolvedUserWebView2Root = [System.IO.Path]::GetFullPath($userWebView2)
    if ($resolvedUserWebView2Root.StartsWith($resolvedUserRadIARoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path $resolvedUserWebView2Root) {
            Write-Host "Limpando cache WebView2 local..." -ForegroundColor Yellow
            Remove-Item -LiteralPath $resolvedUserWebView2Root -Recurse -Force
        }
    } else {
        throw "Caminho de cache WebView2 inesperado: $resolvedUserWebView2Root"
    }

    Write-Host "Registrando pacote no Registro do Windows..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Embarcadero\BDS\$delphiVer\Known Packages"
    if ($IDE64) {
        $regPath = (
            "HKCU:\Software\Embarcadero\BDS\$delphiVer\" +
            "Known Packages x64"
        )
    }

    # Garante que a chave existe no registro antes de gravar
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

    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " Plugin instalado com sucesso no Delphi!     " -ForegroundColor Green
    Write-Host " O Rad IA estara disponivel no proximo startup" -ForegroundColor Green
    Write-Host " da IDE.                                     " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
}

