param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("22.0", "23.0", "37.0")]
    [string]$DelphiVersion,
    [ValidateRange(1, 50)]
    [int]$Cycles = 10,
    [ValidateRange(30, 600)]
    [int]$StartupTimeoutSeconds = 180,
    [switch]$IDE64
)

$ErrorActionPreference = "Stop"
$platform = "Win32"
$binName = "bin"
if ($IDE64) {
    $platform = "Win64"
    $binName = "bin64"
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

$results = @()
for ($cycle = 1; $cycle -le $Cycles; $cycle++) {
    $startedAt = [DateTime]::UtcNow
    $process = Start-Process -FilePath $bdsPath -PassThru
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
                '{"jsonrpc":"2.0","id":2,"method":"tools/call",' +
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
        $ideState = (
            $parsed |
                Where-Object { $_.id -eq 2 }
        ).result.structuredContent
        if ($initialize.result.serverInfo.version -ne "0.0.29") {
            throw "Unexpected RadIA version in cycle $cycle."
        }
        if ($ideState.platform -ne $platform) {
            throw "Unexpected IDE platform in cycle $cycle."
        }
        if (-not $ideState.versionName) {
            throw "IDE version name was empty in cycle $cycle."
        }

        $currentProcess = Get-Process -Id $process.Id -ErrorAction Stop
        if (-not $currentProcess.CloseMainWindow()) {
            throw "Delphi rejected the shutdown request in cycle $cycle."
        }
        if (-not $currentProcess.WaitForExit(30000)) {
            throw "Delphi did not exit cleanly in cycle $cycle."
        }
        $cleanupDeadline = [DateTime]::UtcNow.AddSeconds(5)
        while ((Test-Path -LiteralPath $instanceFile) -and
            ([DateTime]::UtcNow -lt $cleanupDeadline)) {
            Start-Sleep -Milliseconds 100
        }
        if (Test-Path -LiteralPath $instanceFile) {
            throw "MCP discovery remained after cycle $cycle."
        }

        $elapsed = [Math]::Round(
            ([DateTime]::UtcNow - $startedAt).TotalSeconds,
            2
        )
        $results += [pscustomobject]@{
            Cycle = $cycle
            ProcessId = $process.Id
            Version = $ideState.versionName
            Platform = $ideState.platform
            Seconds = $elapsed
        }
        Write-Host (
            "Cycle $cycle/$Cycles passed for Delphi " +
            "$DelphiVersion $platform in $elapsed s."
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
