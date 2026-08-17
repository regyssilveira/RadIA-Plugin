[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [switch]$IDE64,
    [Parameter(Mandatory = $true)]
    [string]$EvidencePath
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$platform = if ($IDE64) { "Win64" } else { "Win32" }
$previousPackage = Join-Path $repositoryRoot (
    "Output\Packages\RadIA-v2.17.2-Delphi-" +
    "$DelphiVersion-$platform-Release.zip"
)
if (-not (Test-Path -LiteralPath $previousPackage -PathType Leaf)) {
    throw "Previous release package was not found: $previousPackage"
}

$arguments = @{
    DelphiVersion = $DelphiVersion
    Cycles = 1
    ExercisePackageLifecycle = $true
    DevelopmentCandidate = $true
    UpgradeFromPackagePath = $previousPackage
    EvidencePath = $EvidencePath
}
if ($IDE64) {
    $arguments.IDE64 = $true
}
$settingsPath = "HKCU:\Software\Embarcadero\BDS\$DelphiVersion\RadIA"
New-Item -Path $settingsPath -Force | Out-Null
$settings = Get-ItemProperty -LiteralPath $settingsPath
$windowVisibleProperty = $settings.PSObject.Properties["WindowVisible"]
$hadWindowVisible = $null -ne $windowVisibleProperty
$previousWindowVisible = if ($hadWindowVisible) {
    $windowVisibleProperty.Value
} else {
    $null
}
$settingsPreserved = $false
try {
    New-ItemProperty -LiteralPath $settingsPath -Name "WindowVisible" `
        -PropertyType DWord -Value 0 -Force | Out-Null
    & (Join-Path $PSScriptRoot "Test-RadIA.IDESmoke.ps1") @arguments
    $settingsPreserved = (
        Get-ItemPropertyValue -LiteralPath $settingsPath `
            -Name "WindowVisible" -ErrorAction Stop
    ) -eq 0
} finally {
    if ($hadWindowVisible) {
        Set-ItemProperty -LiteralPath $settingsPath -Name "WindowVisible" `
            -Value $previousWindowVisible
    } else {
        Remove-ItemProperty -LiteralPath $settingsPath `
            -Name "WindowVisible" -ErrorAction SilentlyContinue
    }
}

$evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
$cycle = @($evidence.cycles)[0]
$requiredModes = @(
    "Uninstall",
    "InstallPreviousVersion",
    "UpgradeToCurrentVersion",
    "Repair"
)
$missingModes = @(
    $requiredModes | Where-Object { $_ -notin @($cycle.PackageLifecycleModes) }
)
$passed =
    $evidence.packageLifecycleExercised -eq $true -and
    $evidence.upgradeExercised -eq $true -and
    $cycle.ShutdownClean -eq $true -and
    $cycle.UpgradeExercised -eq $true -and
    $settingsPreserved -and
    $missingModes.Count -eq 0
if (-not $passed) {
    throw "Install and upgrade E2E did not satisfy the release contract."
}

$evidence | Add-Member -NotePropertyName packageLoaded `
    -NotePropertyValue $true -Force
$evidence | Add-Member -NotePropertyName versionUpdated `
    -NotePropertyValue $true -Force
$evidence | Add-Member -NotePropertyName settingsPreserved `
    -NotePropertyValue $settingsPreserved -Force
$evidence | Add-Member -NotePropertyName cleanShutdown `
    -NotePropertyValue $true -Force
$evidence | ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $EvidencePath -Encoding UTF8

Write-Host "Install and upgrade E2E passed: $EvidencePath"
