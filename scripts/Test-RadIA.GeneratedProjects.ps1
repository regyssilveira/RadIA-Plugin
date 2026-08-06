[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion
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
$isolatedLibraryPath = (
    (Join-Path $studioRoot "lib\Win32\release") +
    "%3B" +
    (Join-Path $studioRoot "source\DUnitX")
)
$validationRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("RadIA-Generated-$DelphiVersion-" + [Guid]::NewGuid().ToString("N"))
$previousBds = $env:BDS
$previousBdsBin = $env:BDSBIN

if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
    throw "Delphi compiler not found: $compilerPath"
}
if (-not (Test-Path -LiteralPath $msBuildPath -PathType Leaf)) {
    throw "MSBuild not found: $msBuildPath"
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
    if ($projects.Count -ne 7) {
        throw "Expected seven generated projects, found $($projects.Count)."
    }

    foreach ($project in $projects) {
        Write-Host "Building generated project: $($project.BaseName)"
        & $msBuildPath `
            $project.FullName `
            "/t:Build" `
            "/p:Config=Debug" `
            "/p:Platform=Win32" `
            "/p:DCC_UnitSearchPath=" `
            "/p:DelphiLibraryPath=$isolatedLibraryPath" `
            "/v:minimal" `
            "/nologo"
        if ($LASTEXITCODE -ne 0) {
            throw "Generated project failed: $($project.FullName)"
        }
    }

    Write-Host (
        "All seven generated projects passed on Delphi $DelphiVersion."
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
