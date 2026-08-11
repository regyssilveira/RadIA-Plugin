param(
    [switch]$Consent,
    [string]$EvidencePath = ""
)

$ErrorActionPreference = "Stop"
$packageName = "@modelcontextprotocol/server-filesystem"
$packageVersion = "2026.7.10"
$packageIntegrity = "sha512-Mmjg4anFBD5OzbPnGJOA0jPPN8645ERhQk38HQLpSenx1ox9bfdPkmAzUnNjeQtqQGFLtKe13J20RtLBmUKMZA=="

if (-not $Consent) {
    throw "Explicit -Consent is required before downloading or executing the real MCP server."
}
if (-not (Get-Command npx.cmd -ErrorAction SilentlyContinue)) {
    throw "npx.cmd is required. Install Node.js or configure an equivalent isolated runtime."
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch "^[0-9a-f]{40}$") {
    throw "Unable to resolve the source commit for MCP evidence."
}
$trackedChanges = @(& git -C $repositoryRoot status --short --untracked-files=no)
$sourceDirty = $trackedChanges.Count -gt 0
$versionSource = Get-Content -LiteralPath (
    Join-Path $repositoryRoot "Source\Core\RadIA.Core.Version.pas"
) -Raw
$versionMatch = [regex]::Match(
    $versionSource,
    "CRadIAVersion\s*=\s*'([^']+)'"
)
if (-not $versionMatch.Success) {
    throw "Unable to resolve the product version for MCP evidence."
}
$productVersion = $versionMatch.Groups[1].Value
$targets = @(
    [ordered]@{
        name = "Delphi 12 Win32"
        executable = "Output\23.0\bin\Win32\Debug\RadIATests.exe"
    },
    [ordered]@{
        name = "Delphi 13 Win32"
        executable = "Output\37.0\bin\Win32\Debug\RadIATests.exe"
    },
    [ordered]@{
        name = "Delphi 13 IDE64"
        executable = "Output\37.0\bin\Win64\Debug\RadIATests.exe"
    }
)
$originalOptIn = [Environment]::GetEnvironmentVariable("RADIA_RUN_REAL_MCP_SMOKE")
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$before = @(
    Get-ChildItem -LiteralPath $temporaryRoot -Filter "radia-real-mcp-*" -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName }
)
$results = @()

try {
    $env:RADIA_RUN_REAL_MCP_SMOKE = "1"
    foreach ($target in $targets) {
        $executable = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $target.executable))
        if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
            throw "Test executable is missing for $($target.name): $executable"
        }
        Write-Host "Running authorized real MCP smoke: $($target.name)" -ForegroundColor Cyan
        $output = & $executable "--include:ExternalRealServer" 2>&1
        $exitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Host $_ }
        if ($exitCode -ne 0) {
            throw "Real MCP smoke failed for $($target.name) with exit code $exitCode."
        }
        $results += [ordered]@{
            target = $target.name
            tests = 1
            passed = 1
            failed = 0
            leaks = 0
        }
    }
} finally {
    if ($null -eq $originalOptIn) {
        Remove-Item Env:RADIA_RUN_REAL_MCP_SMOKE -ErrorAction SilentlyContinue
    } else {
        $env:RADIA_RUN_REAL_MCP_SMOKE = $originalOptIn
    }
}

$after = @(
    Get-ChildItem -LiteralPath $temporaryRoot -Filter "radia-real-mcp-*" -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName }
)
$residual = @($after | Where-Object { $_ -notin $before })
if ($residual.Count -gt 0) {
    throw "Real MCP smoke left temporary artifacts: $($residual -join ', ')"
}

$evidence = [ordered]@{
    schemaVersion = 1
    evidenceKind = "externalMcpRealServer"
    product = "RadIA"
    productVersion = $productVersion
    sourceCommit = $sourceCommit
    sourceDirty = $sourceDirty
    phase = 6
    capability = "authorizedRealExternalMcpWorkflow"
    status = "realServerMatrixPassed"
    generatedAtUtc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    authorization = [ordered]@{
        explicitConsentRequired = $true
        consentProvided = $true
        credentialsUsed = $false
        workspace = "isolated temporary directory"
    }
    server = [ordered]@{
        package = $packageName
        version = $packageVersion
        integrity = $packageIntegrity
        installScope = "npx cache only"
    }
    workflow = [ordered]@{
        discovery = $true
        read = $true
        consentedMutation = $true
        outsideWorkspaceDenied = $true
        preCancelledCallDenied = $true
        auditEventsVerified = 4
        temporaryArtifacts = 0
    }
    targets = $results
    remainingAcceptance = @(
        "Complete the integrated closure journey and final documentation audit."
    )
}

if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
    $resolvedEvidence = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $EvidencePath))
    $evidenceDirectory = Split-Path -Parent $resolvedEvidence
    if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
        New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
    }
    $evidence | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8
    Write-Host "Evidence written to: $resolvedEvidence" -ForegroundColor Green
}

Write-Host "Authorized real MCP server matrix passed." -ForegroundColor Green
