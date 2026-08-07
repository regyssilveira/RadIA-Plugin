param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("23.0", "37.0")]
    [string]$DelphiVersion,
    [Parameter(Mandatory = $true)]
    [string]$FastMMRoot,
    [switch]$Win64
)

$ErrorActionPreference = "Stop"
$resolvedFastMMRoot = [IO.Path]::GetFullPath($FastMMRoot)
$sourcePath = [IO.Path]::GetFullPath(".\Tests\MemoryLab")
$platform = if ($Win64) { "Win64" } else { "Win32" }
$compilerName = if ($Win64) { "dcc64.exe" } else { "dcc32.exe" }
$compiler = Join-Path (
    "C:\Program Files (x86)\Embarcadero\Studio\$DelphiVersion\bin"
) $compilerName
$fastMMUnit = Join-Path $resolvedFastMMRoot "FastMM5.pas"
$debugLibraryName = if ($Win64) {
    "FastMM_FullDebugMode64.dll"
} else {
    "FastMM_FullDebugMode.dll"
}
$debugLibrary = Join-Path (
    $resolvedFastMMRoot
) "FullDebugMode DLL\Precompiled\$debugLibraryName"
$outputPath = [IO.Path]::GetFullPath(
    ".\Output\MemoryLab\$DelphiVersion\$platform"
)

if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw "Delphi compiler was not found: $compiler"
}
if (-not (Test-Path -LiteralPath $fastMMUnit -PathType Leaf)) {
    throw "FastMM5.pas was not found: $fastMMUnit"
}
if (-not (Test-Path -LiteralPath $debugLibrary -PathType Leaf)) {
    throw "FastMM5 debug library was not found: $debugLibrary"
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$arguments = @(
    "-B",
    "-DDEBUG;FastMM_EnableMemoryLeakReporting",
    "-E$outputPath",
    "-I$resolvedFastMMRoot",
    "-LE$outputPath",
    "-LN$outputPath",
    "-M",
    "-N0$outputPath",
    "-NH$outputPath",
    "-NO$outputPath",
    "-NSSystem;Winapi",
    "-U$resolvedFastMMRoot",
    "-V",
    "-VN",
    (Join-Path $sourcePath "RadIAMemoryLab.dpr")
)

& $compiler $arguments
if ($LASTEXITCODE -ne 0) {
    throw "Memory laboratory build failed for Delphi $DelphiVersion $platform."
}

Copy-Item -LiteralPath $debugLibrary -Destination $outputPath -Force
Write-Host "Memory laboratory built: $outputPath"
