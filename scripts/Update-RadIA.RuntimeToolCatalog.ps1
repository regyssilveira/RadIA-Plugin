[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot "docs\reference\runtime_tools.json"
$catalogPath = Join-Path $repositoryRoot "docs\reference\runtime_tool_catalog.md"
$englishCatalogPath = Join-Path $repositoryRoot "docs\reference\runtime_tool_catalog.en.md"
$referencePath = Join-Path $repositoryRoot "docs\reference\internal_tools_reference.md"
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 |
    ConvertFrom-Json
$seenTools = @{}
$toolCount = 0
$englishPurposeOverrides = @{
    StartDebugging = (
        "Validates and queues the active project under the debugger " +
        "without blocking the MCP request."
    )
    PauseDebugging = "Pauses the current debug process."
    ContinueDebugging = "Continues the current stopped debug process."
    StepInto = "Executes the next source statement and steps into calls."
    StepOver = "Executes the next source statement without entering calls."
    StepOut = "Continues until the current routine returns."
    StopDebugging = "Terminates the current debug process."
}
$portugueseGroupNames = @{
    "Workspace" = "Workspace e editor"
    "Delphi environment" = "Ambiente Delphi"
    "Semantic code generation" = "Geração semântica de código"
    "Semantic index queries" = "Consultas ao índice semântico"
    "Curated Delphi guidance" = "Orientação Delphi curada"
    "DFM and Pascal consistency" = "Consistência entre DFM e Pascal"
    "Designer visual diff" = "Diff visual do Designer"
    "Agent result recovery" = "Recuperação de resultados do agente"
    "Project health" = "Saúde do projeto"
    "Installation health" = "Saúde da instalação"
    "IDE navigation and project graph" = "Navegação na IDE e grafo do projeto"
    "Patches" = "Patches"
    "Multi-file patches" = "Patches em múltiplos arquivos"
    "Block reviews" = "Revisões por bloco"
    "Development transactions" = "Transações de desenvolvimento"
    "Project templates" = "Templates de projeto"
    "Project files" = "Arquivos de projeto"
    "Safe productivity artifacts" = "Artefatos de produtividade seguros"
    "Inline reviews" = "Revisões inline"
    "Build" = "Build"
    "Form Designer inspection" = "Inspeção do Form Designer"
    "Form Designer layout" = "Layout do Form Designer"
    "Form Designer properties" = "Propriedades do Form Designer"
    "Form Designer components" = "Componentes do Form Designer"
    "Form Designer events" = "Eventos do Form Designer"
    "Debugger inspection" = "Inspeção do debugger"
    "Debugger control" = "Controle do debugger"
    "Debugger breakpoints" = "Breakpoints do debugger"
    "Debugger sessions and watches" = "Sessões do debugger e watches"
    "Project knowledge" = "Conhecimento do projeto"
    "DUnitX test runner" = "Execução de testes DUnitX"
    "Code coverage evidence" = "Evidências de cobertura de código"
    "Debugger event timeline" = "Linha do tempo de eventos do debugger"
    "Runtime debugger correlation" = "Correlação do debugger em runtime"
    "Runtime window discovery" = "Descoberta de janelas em runtime"
    "Bounded runtime scenarios" = "Cenários limitados de runtime"
    "Runtime visual capture" = "Captura visual runtime"
    "Runtime diagnostic evidence" = "Evidências de diagnóstico em runtime"
    "Versioned runtime regressions" = "Regressões versionadas de runtime"
    "Reviewable local Git commits" = "Commits Git locais revisáveis"
    "FastMM5 memory diagnostics" = "Diagnóstico de memória com FastMM5"
    "Reversible memory instrumentation" = "Instrumentação reversível de memória"
    "FastMM5 log evidence" = "Evidências de logs do FastMM5"
    "Composed memory diagnostic sessions" = "Sessões compostas de diagnóstico de memória"
    "Memory evidence correction workflow" = "Correção orientada por evidências de memória"
    "Legacy data migration" = "Migração de acesso a dados legado"
    "Delphi mentor" = "Mentor Delphi"
}

function Read-PascalStringArgument {
    param(
        [string]$Content,
        [ref]$Position
    )

    $parts = [System.Collections.Generic.List[string]]::new()
    while ($Position.Value -lt $Content.Length) {
        while (($Position.Value -lt $Content.Length) -and
            [char]::IsWhiteSpace($Content[$Position.Value])) {
            $Position.Value++
        }

        if ($Content[$Position.Value] -ne "'") {
            throw "Expected a Pascal string literal at offset $($Position.Value)."
        }

        $Position.Value++
        $part = [System.Text.StringBuilder]::new()
        while ($Position.Value -lt $Content.Length) {
            if ($Content[$Position.Value] -ne "'") {
                [void]$part.Append($Content[$Position.Value])
                $Position.Value++
                continue
            }
            if (($Position.Value + 1 -lt $Content.Length) -and
                ($Content[$Position.Value + 1] -eq "'")) {
                [void]$part.Append("'")
                $Position.Value += 2
                continue
            }
            $Position.Value++
            break
        }
        $parts.Add($part.ToString())

        while (($Position.Value -lt $Content.Length) -and
            [char]::IsWhiteSpace($Content[$Position.Value])) {
            $Position.Value++
        }
        if ($Content[$Position.Value] -ne "+") {
            break
        }
        $Position.Value++
    }

    return $parts -join ""
}

function Get-EnglishPurpose {
    param(
        [string]$Content,
        [string]$ToolName
    )

    if ($englishPurposeOverrides.ContainsKey($ToolName)) {
        return $englishPurposeOverrides[$ToolName]
    }

    $marker = "'$ToolName',"
    $position = $Content.IndexOf($marker, [StringComparison]::Ordinal)
    if ($position -lt 0) {
        $nameAssignment = "LName := '$ToolName';"
        $position = $Content.IndexOf($nameAssignment, [StringComparison]::Ordinal)
        if ($position -lt 0) {
            throw "Tool descriptor not found in source: $ToolName"
        }
        $descriptionMarker = 'LDescription :='
        $position = $Content.IndexOf(
            $descriptionMarker,
            $position + $nameAssignment.Length,
            [StringComparison]::Ordinal
        )
        if ($position -lt 0) {
            throw "Tool description not found in source: $ToolName"
        }
        $position += $descriptionMarker.Length
        $argumentPosition = [ref]$position
        return Read-PascalStringArgument -Content $Content -Position $argumentPosition
    }
    $position += $marker.Length
    $argumentPosition = [ref]$position
    $purpose = Read-PascalStringArgument -Content $Content -Position $argumentPosition
    if ($purpose -match '^\d+(\.\d+)+$') {
        $position = $argumentPosition.Value
        while (($position -lt $Content.Length) -and ($Content[$position] -ne ',')) {
            $position++
        }
        $position++
        $argumentPosition = [ref]$position
        $purpose = Read-PascalStringArgument -Content $Content -Position $argumentPosition
    }
    return $purpose
}

function Get-PortuguesePurposes {
    param([string]$Path)

    $purposes = @{}
    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $matches = [regex]::Matches(
        $content,
        '(?m)^\| `(?<name>[^`]+)` \| (?<purpose>[^|]+) \| [^|]+ \|\r?$'
    )
    foreach ($match in $matches) {
        $purposes[$match.Groups['name'].Value] = $match.Groups['purpose'].Value.Trim()
    }
    return $purposes
}

function New-CatalogLines {
    param(
        [bool]$English,
        [hashtable]$PortuguesePurposes
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    if ($English) {
        $lines.Add("# RadIA built-in tool catalog")
        $lines.Add("")
        $lines.Add(
            "> Generated from the runtime manifest and Pascal tool descriptors. Do not edit manually. " +
            "Run ``scripts/Update-RadIA.RuntimeToolCatalog.ps1``."
        )
        $lines.Add("")
        $lines.Add(
            "This list contains only the built-in tools registered by the current package. " +
            "Architecture ideas and roadmap items remain in ``tool_catalog.md``."
        )
    } else {
        $lines.Add("# Catálogo de ferramentas internas do RadIA")
        $lines.Add("")
        $lines.Add(
            "> Gerado pelo manifesto do runtime e pela referência operacional. Não edite manualmente. " +
            "Execute ``scripts/Update-RadIA.RuntimeToolCatalog.ps1``."
        )
        $lines.Add("")
        $lines.Add(
            "Esta lista contém somente as ferramentas internas registradas pelo pacote atual. " +
            "Ideias de arquitetura e roadmap permanecem em ``tool_catalog.md``."
        )
    }
    $lines.Add("")

    foreach ($group in $manifest.groups) {
        $sourcePath = Join-Path $repositoryRoot $group.source
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            throw "Source unit not found: $($group.source)"
        }

        $sourceContent = Get-Content -LiteralPath $sourcePath -Raw -Encoding utf8
        if ($English) {
            $groupName = $group.name
        } else {
            $groupName = $portugueseGroupNames[$group.name]
            if ([string]::IsNullOrWhiteSpace($groupName)) {
                throw "Portuguese group name not found: $($group.name)"
            }
        }
        $lines.Add("## $groupName")
        $lines.Add("")
        if ($English) {
            $lines.Add("| Tool | Purpose | Source unit |")
        } else {
            $lines.Add("| Ferramenta | O que faz | Unit de origem |")
        }
        $lines.Add("|---|---|---|")

        foreach ($toolName in $group.tools) {
            if (-not $English) {
                if ($seenTools.ContainsKey($toolName)) {
                    throw "Duplicate runtime tool in manifest: $toolName"
                }
                $seenTools[$toolName] = $true
                $script:toolCount++
            }
            if (-not $sourceContent.Contains("'$toolName'")) {
                throw "Tool $toolName was not found in $($group.source)"
            }

            if ($English) {
                $purpose = Get-EnglishPurpose -Content $sourceContent -ToolName $toolName
            } else {
                $purpose = $PortuguesePurposes[$toolName]
                if ([string]::IsNullOrWhiteSpace($purpose)) {
                    throw "Portuguese purpose not found for runtime tool: $toolName"
                }
            }
            $sourceLabel = Split-Path -Leaf $group.source
            $lines.Add("| ``$toolName`` | $purpose | ``$sourceLabel`` |")
        }
        $lines.Add("")
    }

    if ($English) {
        $lines.Add("## Summary")
        $lines.Add("")
        $lines.Add("- Registered groups: $($manifest.groups.Count)")
        $lines.Add("- Registered built-in tools: $toolCount")
        $lines.Add("- Extensions can register additional tools at runtime.")
        $lines.Add("- The ``/tools`` command remains authoritative for the active IDE instance.")
    } else {
        $lines.Add("## Resumo")
        $lines.Add("")
        $lines.Add("- Grupos registrados: $($manifest.groups.Count)")
        $lines.Add("- Ferramentas internas registradas: $toolCount")
        $lines.Add("- Extensões podem registrar ferramentas adicionais em runtime.")
        $lines.Add("- O comando ``/tools`` permanece autoritativo para a instância ativa da IDE.")
    }
    return $lines
}

$portuguesePurposes = Get-PortuguesePurposes -Path $referencePath
$portugueseLines = New-CatalogLines -English $false -PortuguesePurposes $portuguesePurposes
$englishLines = New-CatalogLines -English $true -PortuguesePurposes $portuguesePurposes
$renderedCatalog = $portugueseLines -join [Environment]::NewLine
$renderedEnglishCatalog = $englishLines -join [Environment]::NewLine

if ($Check) {
    foreach ($item in @(
        @{ Path = $catalogPath; Content = $renderedCatalog },
        @{ Path = $englishCatalogPath; Content = $renderedEnglishCatalog }
    )) {
        if (-not (Test-Path -LiteralPath $item.Path)) {
            throw "Runtime tool catalog is missing: $($item.Path)"
        }

        $currentCatalog = Get-Content -LiteralPath $item.Path -Raw -Encoding utf8
        $normalizedCurrent = $currentCatalog.Replace("`r`n", "`n").TrimEnd()
        $normalizedExpected = $item.Content.Replace("`r`n", "`n").TrimEnd()
        if ($normalizedCurrent -ne $normalizedExpected) {
            throw "Runtime tool catalog is stale: $($item.Path)"
        }
    }
    Write-Host "Runtime tool catalogs validated: $toolCount tools." -ForegroundColor Green
    exit 0
}

[System.IO.File]::WriteAllText(
    $catalogPath,
    $renderedCatalog + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::WriteAllText(
    $englishCatalogPath,
    $renderedEnglishCatalog + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host "Runtime tool catalogs updated: $toolCount tools." -ForegroundColor Green
