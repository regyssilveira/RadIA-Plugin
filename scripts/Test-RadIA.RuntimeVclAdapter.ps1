param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $PSScriptRoot "Build-RadIA.RuntimeLab.ps1"
$outputRoot = Join-Path $repositoryRoot "Output\$DelphiVersion\runtime-lab"
$binaryDirectory = Join-Path $outputRoot "bin"
$laboratory = Join-Path $binaryDirectory "RadIARuntimeLab.exe"
$probe = Join-Path $binaryDirectory "RadIARuntimeVclProbe.exe"
$connectionRoot = Join-Path $env:APPDATA "RadIA\RuntimeAdapter"

& $buildScript -DelphiVersion $DelphiVersion
if ($LASTEXITCODE -ne 0) {
    throw "Runtime laboratory build failed."
}

$process = Start-Process -FilePath $laboratory -PassThru -WindowStyle Hidden
try {
    $connectionFile = Join-Path $connectionRoot "$($process.Id).json"
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while ((-not (Test-Path -LiteralPath $connectionFile)) -and
        ([DateTime]::UtcNow -lt $deadline)) {
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $connectionFile)) {
        throw "Runtime VCL connection file was not published."
    }
    & $probe $process.Id "runtime-vcl-e2e-$DelphiVersion"
    if ($LASTEXITCODE -ne 0) {
        throw "Runtime VCL cross-process probe failed."
    }
} finally {
    if (-not $process.HasExited) {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(3000)) {
            Stop-Process -Id $process.Id -Force
        }
    }
}
