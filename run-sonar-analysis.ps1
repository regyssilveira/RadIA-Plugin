<#
.SYNOPSIS
    Script to run SonarQube analysis for the Rad IA Plugin project.
.DESCRIPTION
    This script executes the sonar-scanner CLI tool to analyze the project codebase,
    resolving the SonarQube token securely from parameters, local .env file, or environment variables.
.PARAMETER Token
    The SonarQube access token. If omitted, the script loads it from .env or
    the SONAR_TOKEN environment variable.
.PARAMETER HostUrl
    The URL of the SonarQube server. Defaults to http://localhost:9000.
.PARAMETER QualityGate
    Waits for the exact analysis and fails unless its Quality Gate is OK.
.EXAMPLE
    .\run-sonar-analysis.ps1
.EXAMPLE
    .\run-sonar-analysis.ps1 -Token "your-custom-token" -HostUrl "https://sonarqube.mycompany.com"
#>
param(
    [string]$Token = "",
    [string]$HostUrl = "http://localhost:9000",
    [switch]$Test,
    [string]$DelphiVersion = "",
    [switch]$QualityGate
)

$ErrorActionPreference = "Stop"

# 1. Resolve Token from environment configurations if not supplied via parameters
$ResolvedToken = $Token
$EnvFile = Join-Path $PSScriptRoot ".env"

if ([string]::IsNullOrWhiteSpace($ResolvedToken)) {
    # Check if local .env file exists and parse it
    if (Test-Path $EnvFile) {
        Write-Host "Loading credentials from local .env file..." -ForegroundColor Gray
        Get-Content $EnvFile | ForEach-Object {
            $Line = $_.Trim()
            if ($Line -and -not $Line.StartsWith("#") -and $Line.Contains("=")) {
                $Key, $Value = $Line.Split("=", 2)
                $Key = $Key.Trim()
                $Value = $Value.Trim()
                # Strip wrapping single/double quotes
                $Value = $Value -replace '^["'']|["'']$'
                if ($Key -eq "SONAR_TOKEN") {
                    $script:ResolvedToken = $Value
                }
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ResolvedToken)) {
    # Fallback to system environment variable
    if ($env:SONAR_TOKEN) {
        Write-Host "Using SONAR_TOKEN from system environment variables..." -ForegroundColor Gray
        $ResolvedToken = $env:SONAR_TOKEN
    }
}

if ([string]::IsNullOrWhiteSpace($ResolvedToken)) {
    Write-Error "SonarQube access token is missing. Please set it using one of the following methods:`n" +
                "  1. Define 'SONAR_TOKEN' in a local '.env' file in the project root (ignored by Git).`n" +
                "  2. Define the 'SONAR_TOKEN' environment variable in your system.`n" +
                "  3. Pass it directly via CLI: .\run-sonar-analysis.ps1 -Token `"your-token`""
    Exit 1
}

if ($Test) {
    Write-Host "Executando suite de testes de cobertura..." -ForegroundColor Cyan
    $buildParams = @("-Test")
    if ($DelphiVersion) {
        $buildParams += @("-DelphiVersion", $DelphiVersion)
    }

    # Executar build.ps1 com testes e cobertura
    powershell.exe -ExecutionPolicy Bypass -File build.ps1 $buildParams
    if ($LASTEXITCODE -ne 0) {
        Write-Error "A execucao de testes e cobertura falhou. Abortando analise do SonarQube."
        Exit $LASTEXITCODE
    }
}

Write-Host "Checking for sonar-scanner executable..." -ForegroundColor Cyan

# Check if sonar-scanner is available in PATH
$ScannerCmd = Get-Command "sonar-scanner" -ErrorAction SilentlyContinue

if ($null -eq $ScannerCmd) {
    Write-Error (
        "The 'sonar-scanner' executable was not found in PATH. " +
        "Install SonarQube Scanner CLI and add it to PATH."
    )
    Exit 1
}

Write-Host "Starting SonarQube analysis..." -ForegroundColor Cyan
Write-Host "Host URL: $HostUrl" -ForegroundColor Gray
Write-Host "Project Key: radia" -ForegroundColor Gray

# Run the scanner
& sonar-scanner -D"sonar.token=$ResolvedToken" -D"sonar.host.url=$HostUrl"

if ($LASTEXITCODE -eq 0) {
    Write-Host "SonarQube analysis completed successfully!" -ForegroundColor Green
} else {
    Write-Error "SonarQube analysis failed with exit code $LASTEXITCODE."
    Exit $LASTEXITCODE
}

if ($QualityGate) {
    & (Join-Path $PSScriptRoot "scripts\Test-RadIA.SonarQualityGate.ps1") `
        -Token $ResolvedToken `
        -HostUrl $HostUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Error "SonarQube Quality Gate verification failed."
        Exit $LASTEXITCODE
    }
}
