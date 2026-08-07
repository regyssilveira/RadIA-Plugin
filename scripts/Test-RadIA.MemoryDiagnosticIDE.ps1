param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [Parameter(Mandatory = $true)]
    [string]$FastMMRoot,
    [Parameter(Mandatory = $true)]
    [string]$EvidencePath,
    [switch]$IDE64,
    [ValidateRange(30, 600)]
    [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$runtimeProject = Join-Path `
    $repositoryRoot `
    "Tests\RuntimeLab\RadIARuntimeLab.dproj"
$runtimeSource = Join-Path `
    $repositoryRoot `
    "Tests\RuntimeLab\RadIARuntimeLab.dpr"
$runtimeExecutable = Join-Path `
    (Split-Path -Parent $runtimeProject) `
    "RadIARuntimeLab.exe"
$fastMMUnit = Join-Path $FastMMRoot "FastMM5.pas"
if (-not (Test-Path -LiteralPath $fastMMUnit -PathType Leaf)) {
    throw "FastMM5.pas was not found under $FastMMRoot."
}
if (-not (Test-Path -LiteralPath $runtimeProject -PathType Leaf)) {
    throw "Runtime laboratory project was not found: $runtimeProject"
}

$buildArguments = @(
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $repositoryRoot "build.ps1"),
    "-DelphiVersion",
    $DelphiVersion,
    "-Install"
)
if ($IDE64) {
    $buildArguments += "-IDE64"
}
& powershell.exe @buildArguments
if ($LASTEXITCODE -ne 0) {
    throw "The current RadIA build could not be installed."
}

$binName = if ($IDE64) { "bin64" } else { "bin" }
$bdsRoot = (
    Get-ItemProperty `
        -LiteralPath "HKCU:\Software\Embarcadero\BDS\$DelphiVersion" `
        -Name "RootDir"
).RootDir
$bdsPath = Join-Path $bdsRoot "$binName\bds.exe"
if (-not (Test-Path -LiteralPath $bdsPath -PathType Leaf)) {
    throw "Delphi executable was not found: $bdsPath"
}
$runningTarget = @(
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ExecutablePath -and
            [IO.Path]::GetFullPath($_.ExecutablePath).Equals(
                [IO.Path]::GetFullPath($bdsPath),
                [StringComparison]::OrdinalIgnoreCase
            )
        }
)
if ($runningTarget.Count -gt 0) {
    throw "Close all instances of the target Delphi IDE: $bdsPath"
}

$settingsPath = (
    "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\" +
    "RadIA\MemoryDiagnostics"
)
if (-not (Test-Path -LiteralPath $settingsPath)) {
    New-Item -Path $settingsPath -Force | Out-Null
}
New-ItemProperty `
    -LiteralPath $settingsPath `
    -Name "RootPath" `
    -PropertyType String `
    -Value ([IO.Path]::GetFullPath($FastMMRoot)) `
    -Force |
    Out-Null
New-ItemProperty `
    -LiteralPath $settingsPath `
    -Name "LicenseAcknowledged" `
    -PropertyType DWord `
    -Value 1 `
    -Force |
    Out-Null
New-ItemProperty `
    -LiteralPath $settingsPath `
    -Name "MaxDurationMs" `
    -PropertyType DWord `
    -Value 120000 `
    -Force |
    Out-Null
New-ItemProperty `
    -LiteralPath $settingsPath `
    -Name "MaxLogBytes" `
    -PropertyType String `
    -Value "52428800" `
    -Force |
    Out-Null
New-ItemProperty `
    -LiteralPath $settingsPath `
    -Name "MaxRepetitions" `
    -PropertyType DWord `
    -Value 10 `
    -Force |
    Out-Null

$resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
if (-not (Test-Path -LiteralPath $evidenceDirectory)) {
    New-Item -Path $evidenceDirectory -ItemType Directory -Force |
        Out-Null
}
if (Test-Path -LiteralPath $resolvedEvidencePath) {
    Remove-Item -LiteralPath $resolvedEvidencePath -Force
}
$sourceHashBefore = (
    Get-FileHash -LiteralPath $runtimeSource -Algorithm SHA256
).Hash
$memoryLogPath = Join-Path (
    Split-Path -Parent $runtimeProject
) ".radia\memory\latest-fastmm5.log"
if (Test-Path -LiteralPath $memoryLogPath) {
    Remove-Item -LiteralPath $memoryLogPath -Force
}

$previousDiagnosticEnvironment = (
    $env:RADIA_IDE_SMOKE_MEMORY_DIAGNOSTIC
)
$previousLeakEnvironment = $env:RADIA_MEMORY_DIAGNOSTIC_SMOKE
$process = $null
try {
    $env:RADIA_IDE_SMOKE_MEMORY_DIAGNOSTIC = $resolvedEvidencePath
    $env:RADIA_MEMORY_DIAGNOSTIC_SMOKE = "1"
    $process = Start-Process `
        -FilePath $bdsPath `
        -ArgumentList @($runtimeProject) `
        -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (
        -not (Test-Path -LiteralPath $resolvedEvidencePath) -and
        [DateTime]::UtcNow -lt $deadline
    ) {
        if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
            throw "Delphi exited before producing memory diagnostic evidence."
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path -LiteralPath $resolvedEvidencePath)) {
        throw "The memory diagnostic IDE smoke timed out."
    }
    $result = Get-Content `
        -LiteralPath $resolvedEvidencePath `
        -Raw `
        -Encoding utf8 |
        ConvertFrom-Json
    if ($result.success -ne $true) {
        throw (
            "Memory diagnostic failed: " +
            $result.errorCode + " - " +
            $result.errorMessage
        )
    }
    $leaks = @(
        $result.evidence.groups |
            Where-Object { $_.kind -eq "leak" }
    )
    if (
        $result.evidence.schemaVersion -ne 1 -or
        $result.evidence.termination -ne "controlled" -or
        $leaks.Count -lt 1 -or
        $result.evidence.snapshots.Count -ne 2
    ) {
        throw "The memory diagnostic evidence is incomplete."
    }
    $sourceHashAfter = (
        Get-FileHash -LiteralPath $runtimeSource -Algorithm SHA256
    ).Hash
    if ($sourceHashAfter -ne $sourceHashBefore) {
        throw "The runtime laboratory DPR was not restored exactly."
    }
    Write-Host (
        "FastMM5 IDE diagnostic passed: Delphi $DelphiVersion " +
        "$(if ($IDE64) { 'Win64' } else { 'Win32' }), " +
        "$($leaks.Count) leak group(s), DPR restored."
    ) -ForegroundColor Green
} finally {
    $env:RADIA_IDE_SMOKE_MEMORY_DIAGNOSTIC = (
        $previousDiagnosticEnvironment
    )
    $env:RADIA_MEMORY_DIAGNOSTIC_SMOKE = $previousLeakEnvironment
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ExecutablePath -and
            [IO.Path]::GetFullPath($_.ExecutablePath).Equals(
                [IO.Path]::GetFullPath($runtimeExecutable),
                [StringComparison]::OrdinalIgnoreCase
            )
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force
        }
    if ($process -and
        (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(30000)) {
            Stop-Process -Id $process.Id -Force
            [void]$process.WaitForExit(10000)
        }
    }
}
