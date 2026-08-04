[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot "docs\runtime_tools.json"
$catalogPath = Join-Path $repositoryRoot "docs\runtime_tool_catalog.md"
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 |
    ConvertFrom-Json
$seenTools = @{}
$lines = [System.Collections.Generic.List[string]]::new()
$toolCount = 0

$lines.Add("# RadIA built-in tool catalog")
$lines.Add("")
$lines.Add(
    "> Generated from ``docs/runtime_tools.json``. Do not edit manually. " +
    "Run ``scripts/Update-RadIA.RuntimeToolCatalog.ps1``."
)
$lines.Add("")
$lines.Add(
    "This list contains only the built-in tools registered by the current package. " +
    "Architecture ideas and roadmap items remain in ``tool_catalog.md``."
)
$lines.Add("")

foreach ($group in $manifest.groups) {
    $sourcePath = Join-Path $repositoryRoot $group.source
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Source unit not found: $($group.source)"
    }

    $sourceContent = Get-Content -LiteralPath $sourcePath -Raw -Encoding utf8
    $lines.Add("## $($group.name)")
    $lines.Add("")
    $lines.Add("| Tool | Source unit |")
    $lines.Add("|---|---|")

    foreach ($toolName in $group.tools) {
        if ($seenTools.ContainsKey($toolName)) {
            throw "Duplicate runtime tool in manifest: $toolName"
        }
        if (-not $sourceContent.Contains("'$toolName'")) {
            throw "Tool $toolName was not found in $($group.source)"
        }

        $seenTools[$toolName] = $true
        $toolCount++
        $sourceLabel = Split-Path -Leaf $group.source
        $lines.Add("| ``$toolName`` | ``$sourceLabel`` |")
    }
    $lines.Add("")
}

$lines.Add("## Resumo")
$lines.Add("")
$lines.Add("- Registered groups: $($manifest.groups.Count)")
$lines.Add("- Registered built-in tools: $toolCount")
$lines.Add("- Extensions can register additional tools at runtime.")
$lines.Add("- The ``/tools`` command remains authoritative for the active IDE instance.")
$renderedCatalog = ($lines -join [Environment]::NewLine)

if ($Check) {
    if (-not (Test-Path -LiteralPath $catalogPath)) {
        throw "Runtime tool catalog is missing. Run the catalog update script."
    }

    $currentCatalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding utf8
    $normalizedCurrent = $currentCatalog.Replace("`r`n", "`n").TrimEnd()
    $normalizedExpected = $renderedCatalog.Replace("`r`n", "`n").TrimEnd()
    if ($normalizedCurrent -ne $normalizedExpected) {
        throw "Runtime tool catalog is stale. Run the catalog update script."
    }

    Write-Host "Runtime tool catalog validated: $toolCount tools." -ForegroundColor Green
    exit 0
}

[System.IO.File]::WriteAllText(
    $catalogPath,
    $renderedCatalog + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host "Runtime tool catalog updated: $toolCount tools." -ForegroundColor Green
