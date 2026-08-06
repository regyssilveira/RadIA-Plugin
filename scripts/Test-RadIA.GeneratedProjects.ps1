[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,

    [string]$EvidencePath = ""
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
$templateResults = @()
$expectedTemplates = @(
    "ConsoleApp",
    "DUnitXApp",
    "FmxApp",
    "LibraryApp",
    "PackageApp",
    "ServiceApp",
    "VclApp"
)

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
    $projectNames = @($projects | ForEach-Object { $_.BaseName })
    foreach ($expectedTemplate in $expectedTemplates) {
        if ($projectNames -notcontains $expectedTemplate) {
            throw "Generated project is missing: $expectedTemplate"
        }
    }

    foreach ($project in $projects) {
        Write-Host "Building generated project: $($project.BaseName)"
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        & $msBuildPath `
            $project.FullName `
            "/t:Build" `
            "/p:Config=Debug" `
            "/p:Platform=Win32" `
            "/p:DCC_UnitSearchPath=" `
            "/p:DelphiLibraryPath=$isolatedLibraryPath" `
            "/v:minimal" `
            "/nologo"
        $stopwatch.Stop()
        if ($LASTEXITCODE -ne 0) {
            throw "Generated project failed: $($project.FullName)"
        }
        $templateResults += [PSCustomObject]@{
            template = $project.BaseName
            projectFile = $project.Name
            platform = "Win32"
            configuration = "Debug"
            durationMs = $stopwatch.ElapsedMilliseconds
            status = "passed"
        }
    }

    if ($EvidencePath) {
        $resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
        $evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
        if ($evidenceDirectory) {
            New-Item `
                -ItemType Directory `
                -Path $evidenceDirectory `
                -Force |
                Out-Null
        }
        $sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
        if (
            $LASTEXITCODE -ne 0 -or
            $sourceCommit -notmatch "^[0-9a-f]{40}$"
        ) {
            throw "Unable to resolve the source commit."
        }
        $productVersion = (
            Get-Content `
                -LiteralPath (Join-Path $repositoryRoot "package.json") `
                -Raw |
                ConvertFrom-Json
        ).version
        [PSCustomObject]@{
            schemaVersion = 1
            evidenceKind = "generatedProjectTemplateTarget"
            product = "RadIA"
            productVersion = $productVersion
            sourceCommit = $sourceCommit
            delphiVersion = $DelphiVersion
            compilerProductVersion = (
                Get-Item -LiteralPath $compilerPath
            ).VersionInfo.ProductVersion
            platform = "Win32"
            templateCount = $templateResults.Count
            status = "passed"
            generatedAtUtc = [DateTime]::UtcNow.ToString("o")
            templates = $templateResults
        } |
            ConvertTo-Json -Depth 5 |
            Set-Content `
                -LiteralPath $resolvedEvidencePath `
                -Encoding UTF8
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
