[CmdletBinding()]
param(
    [string]$EvidencePath = (
        ".\Output\Validation\FireDACAdvisor\firedac-advisor-plan.json"
    ),
    [string[]]$ScenarioId = @(),
    [string[]]$TargetId = @(),
    [ValidateRange(30, 1800)]
    [int]$StartupTimeoutSeconds = 180,
    [switch]$KeepFixtures,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path `
    $repositoryRoot `
    "Tests\Usage\firedac-advisor-matrix.json"
$smokePath = Join-Path $PSScriptRoot "Test-RadIA.IDESmoke.ps1"
$connectedScenarioIds = @(
    "firedac-inventory-navigation",
    "firedac-selected-sql-analysis",
    "firedac-credential-redaction",
    "firedac-unsafe-transaction",
    "firedac-shared-thread-connection",
    "firedac-sqlite-grid-csv",
    "firedac-sqlite-dml-rejection",
    "firedac-repository-preview-denied",
    "firedac-repository-applied"
)

function Set-RadIAFireDACFixtureContent {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $normalized = $Content.Replace("`r`n", "`n").Replace("`n", "`r`n")
    Set-Content `
        -LiteralPath $Path `
        -Value $normalized `
        -Encoding UTF8 `
        -NoNewline
}

function Expand-RadIAFireDACFilter {
    param([string[]]$Value)

    return @(
        $Value |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
}

function New-RadIAFireDACFixture {
    param(
        [Parameter(Mandatory = $true)][string]$ScenarioId,
        [Parameter(Mandatory = $true)][string]$TargetId
    )

    $fixtureRoot = Join-Path `
        $repositoryRoot `
        ("Output\Validation\FireDACAdvisor\Fixtures\" +
            "$ScenarioId-$TargetId-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    $unitPath = Join-Path $fixtureRoot "RadIA.FireDAC.E2E.Data.pas"
    $dfmPath = Join-Path $fixtureRoot "RadIA.FireDAC.E2E.Data.dfm"
    $projectPath = Join-Path $fixtureRoot "RadIAFireDACE2E.dproj"
    $programPath = Join-Path $fixtureRoot "RadIAFireDACE2E.dpr"
    $databasePath = ""
    $testExecutablePath = ""
    $programContent = @'
program RadIAFireDACE2E;

uses
  RadIA.FireDAC.E2E.Data in 'RadIA.FireDAC.E2E.Data.pas';

begin
end.
'@
    Set-RadIAFireDACFixtureContent `
        -Path $programPath `
        -Content $programContent
    $unitContent = @'
unit RadIA.FireDAC.E2E.Data;

interface

uses
  FireDAC.Comp.Client,
  System.Threading;

type
  TRadIAFireDACE2EData = class
  private
    FConnection: TFDConnection;
    FQuery: TFDQuery;
  public
    procedure LoadCustomer;
    procedure RunWorker;
    procedure SaveCustomer;
  end;

implementation

procedure TRadIAFireDACE2EData.LoadCustomer;
begin
  FQuery.SQL.Text := 'select id from customer where id = :Id';
  FQuery.ParamByName('Id').AsString := '1';
end;

procedure TRadIAFireDACE2EData.RunWorker;
begin
  TTask.Run(
    procedure
    begin
      FConnection.Open;
      FQuery.Open;
    end
  );
end;

procedure TRadIAFireDACE2EData.SaveCustomer;
begin
  FConnection.StartTransaction;
  FQuery.ExecSQL;
  FConnection.Commit;
end;

end.
'@
    Set-RadIAFireDACFixtureContent `
        -Path $unitPath `
        -Content $unitContent
    $dfmContent = @'
object RadIAFireDACE2EData: TRadIAFireDACE2EData
  object MainConnection: TFDConnection
    Params.Strings = (
      'DriverID=SQLite'
      'Password=radia-e2e-secret')
  end
  object CustomerQuery: TFDQuery
    Connection = MainConnection
    SQL.Strings = (
      'select id from customer where id = :Id')
  end
end
'@
    Set-RadIAFireDACFixtureContent `
        -Path $dfmPath `
        -Content $dfmContent
    $projectContent = @'
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectGuid>{82A22732-E130-4892-B2FD-51BCBDF847F6}</ProjectGuid>
    <MainSource>RadIAFireDACE2E.dpr</MainSource>
    <ProjectVersion>20.3</ProjectVersion>
    <FrameworkType>VCL</FrameworkType>
    <Base>True</Base>
    <Config Condition="'$(Config)'==''">Debug</Config>
    <Platform Condition="'$(Platform)'==''">Win32</Platform>
    <TargetedPlatforms>3</TargetedPlatforms>
    <AppType>Application</AppType>
    <ProjectName Condition="'$(ProjectName)'==''">RadIAFireDACE2E</ProjectName>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Config)'=='Base' or '$(Base)'!=''">
    <Base>true</Base>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Config)'=='Debug' or '$(Cfg_1)'!=''">
    <Cfg_1>true</Cfg_1>
    <CfgParent>Base</CfgParent>
    <Base>true</Base>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Base)'!=''">
    <DCC_DcuOutput>.\.radia\debug\dcu</DCC_DcuOutput>
    <DCC_ExeOutput>.</DCC_ExeOutput>
  </PropertyGroup>
  <ItemGroup>
    <DelphiCompile Include="RadIAFireDACE2E.dpr">
      <MainSource>MainSource</MainSource>
    </DelphiCompile>
    <DCCReference Include="RadIA.FireDAC.E2E.Data.pas"/>
    <BuildConfiguration Include="Base">
      <Key>Base</Key>
    </BuildConfiguration>
    <BuildConfiguration Include="Debug">
      <Key>Cfg_1</Key>
      <CfgParent>Base</CfgParent>
    </BuildConfiguration>
  </ItemGroup>
  <ProjectExtensions>
    <Borland.Personality>Delphi.Personality.12</Borland.Personality>
    <Borland.ProjectType/>
    <BorlandProject>
      <Delphi.Personality>
        <Source>
          <Source Name="MainSource">RadIAFireDACE2E.dpr</Source>
        </Source>
      </Delphi.Personality>
      <Platforms>
        <Platform value="Win32">True</Platform>
      </Platforms>
    </BorlandProject>
    <ProjectFileVersion>12</ProjectFileVersion>
  </ProjectExtensions>
  <Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets"
    Condition="Exists('$(BDS)\Bin\CodeGear.Delphi.Targets')"/>
</Project>
'@
    Set-RadIAFireDACFixtureContent `
        -Path $projectPath `
        -Content $projectContent
    if ($ScenarioId -in @(
        "firedac-sqlite-grid-csv",
        "firedac-sqlite-dml-rejection"
    )) {
        $databasePath = Join-Path $fixtureRoot "firedac-e2e.sqlite"
        $python = Get-Command python.exe -ErrorAction SilentlyContinue
        if (-not $python) {
            throw "Python is required to create the SQLite E2E fixture."
        }
        $fixtureCode = @'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
connection.execute(
    "create table customer(id integer primary key, name text, access_token text)"
)
connection.executemany(
    "insert into customer(id, name, access_token) values (?, ?, ?)",
    [
        (1, "Ada", "radia-secret-one"),
        (2, "Grace", "radia-secret-two"),
        (3, "Linus", "radia-secret-three"),
    ],
)
connection.commit()
connection.close()
'@
        $fixtureCodeBase64 = [Convert]::ToBase64String(
            [Text.Encoding]::UTF8.GetBytes($fixtureCode)
        )
        $bootstrapCode = (
            "import base64,sys;" +
            "payload=sys.argv[1];" +
            "sys.argv=[sys.argv[0],sys.argv[2]];" +
            "exec(base64.b64decode(payload))"
        )
        & $python.Source `
            -c $bootstrapCode `
            $fixtureCodeBase64 `
            $databasePath
        if ($LASTEXITCODE -ne 0 -or
            -not (Test-Path -LiteralPath $databasePath -PathType Leaf)) {
            throw "The SQLite E2E fixture could not be created."
        }
    }
    if ($ScenarioId -eq "firedac-repository-applied") {
        $testSourcePlatform = if ($TargetId -eq "delphi13-ide64") {
            "Win64"
        } else {
            "Win32"
        }
        $testSourceVersion = if ($TargetId -eq "delphi12-win32") {
            "23.0"
        } else {
            "37.0"
        }
        $testSourcePath = Join-Path `
            $repositoryRoot `
            ("Output\$testSourceVersion\bin\$testSourcePlatform\" +
                "Debug\RadIATests.exe")
        if (-not (Test-Path -LiteralPath $testSourcePath -PathType Leaf)) {
            throw "The DUnitX E2E executable was not found: $testSourcePath"
        }
        $testExecutablePath = Join-Path `
            $fixtureRoot `
            "RadIAFireDACE2ETests.exe"
        Copy-Item `
            -LiteralPath $testSourcePath `
            -Destination $testExecutablePath
        foreach ($supportExecutable in @(
            "RadIA.MCP.Bridge.exe",
            "RadIA.Semantic.Engine.exe"
        )) {
            $supportSourcePath = Join-Path `
                (Split-Path -Parent $testSourcePath) `
                $supportExecutable
            if (-not (Test-Path `
                -LiteralPath $supportSourcePath `
                -PathType Leaf)) {
                throw "DUnitX support executable missing: $supportSourcePath"
            }
            Copy-Item `
                -LiteralPath $supportSourcePath `
                -Destination (Join-Path $fixtureRoot $supportExecutable)
        }
    }
    return [PSCustomObject]@{
        Root = $fixtureRoot
        ProjectPath = $projectPath
        DatabasePath = $databasePath
        TestExecutablePath = $testExecutablePath
    }
}

function Resolve-RadIAFireDACEvidencePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = [IO.Path]::GetFullPath($Path)
    $outputRoot = [IO.Path]::GetFullPath(
        (Join-Path $repositoryRoot "Output")
    )
    if (-not $resolved.StartsWith(
        $outputRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "FireDAC Advisor evidence must remain inside Output."
    }
    return $resolved
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "FireDAC Advisor matrix was not found: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported FireDAC Advisor matrix schema."
}
$targets = @($manifest.targets)
$scenarios = @($manifest.scenarios)
$ScenarioId = @(Expand-RadIAFireDACFilter -Value $ScenarioId)
$TargetId = @(Expand-RadIAFireDACFilter -Value $TargetId)
if ($targets.Count -ne 3) {
    throw "FireDAC Advisor matrix must contain exactly three IDE targets."
}
if ($scenarios.Count -ne 16) {
    throw "FireDAC Advisor matrix must contain exactly 16 scenarios."
}
$expectedTargets = @(
    "delphi12-win32",
    "delphi13-win32",
    "delphi13-ide64"
)
if ((@($targets.id) -join ",") -ne ($expectedTargets -join ",")) {
    throw "FireDAC Advisor matrix targets are incomplete or out of order."
}
$duplicateIds = @(
    $scenarios.id |
        Group-Object |
        Where-Object { $_.Count -gt 1 }
)
if ($duplicateIds.Count -gt 0) {
    throw "FireDAC Advisor matrix contains duplicate scenario identifiers."
}
$unknownScenarios = @(
    $ScenarioId | Where-Object { $_ -notin @($scenarios.id) }
)
if ($unknownScenarios.Count -gt 0) {
    throw "Unknown FireDAC scenario(s): $($unknownScenarios -join ', ')"
}
$unknownTargets = @(
    $TargetId | Where-Object { $_ -notin @($targets.id) }
)
if ($unknownTargets.Count -gt 0) {
    throw "Unknown FireDAC target(s): $($unknownTargets -join ', ')"
}
$selectedScenarios = @(
    if ($ScenarioId.Count -gt 0) {
        $scenarios | Where-Object { $_.id -in $ScenarioId }
    } else {
        $scenarios
    }
)
$selectedTargets = @(
    if ($TargetId.Count -gt 0) {
        $targets | Where-Object { $_.id -in $TargetId }
    } else {
        $targets
    }
)
$runs = @()
foreach ($scenario in $selectedScenarios) {
    if ($scenario.id -notmatch '^firedac-[a-z0-9-]+$') {
        throw "Invalid FireDAC Advisor scenario identifier: $($scenario.id)"
    }
    if (@($scenario.tools).Count -eq 0) {
        throw "Scenario $($scenario.id) does not declare tools."
    }
    if (@($scenario.requiredEvidence).Count -eq 0) {
        throw "Scenario $($scenario.id) does not declare evidence."
    }
    if ($scenario.rollbackExpected -and -not $scenario.mutationExpected) {
        throw "Scenario $($scenario.id) expects rollback without mutation."
    }
    foreach ($target in $selectedTargets) {
        $runs += [PSCustomObject]@{
            scenarioId = $scenario.id
            targetId = $target.id
            delphiVersion = $target.delphiVersion
            ideArchitecture = if ($target.ide64) { "Win64" } else { "Win32" }
            tools = @($scenario.tools)
            mutationExpected = [bool]$scenario.mutationExpected
            rollbackExpected = [bool]$scenario.rollbackExpected
            requiredEvidence = @($scenario.requiredEvidence)
        }
    }
}

$plan = [PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "fireDACAdvisorIDEPlan"
    targetCount = $targets.Count
    selectedTargetCount = $selectedTargets.Count
    scenarioCount = $scenarios.Count
    selectedScenarioCount = $selectedScenarios.Count
    runCount = $runs.Count
    runs = $runs
}
if ($PlanOnly) {
    $plan | ConvertTo-Json -Depth 7
    exit 0
}

$unsupported = @(
    $selectedScenarios |
        Where-Object { $_.id -notin $connectedScenarioIds }
)
if ($unsupported.Count -gt 0) {
    throw (
        "FireDAC IDE execution is not connected for: " +
        (($unsupported.id | Sort-Object) -join ", ")
    )
}
$resolvedEvidence = Resolve-RadIAFireDACEvidencePath -Path $EvidencePath
$evidenceDirectory = Split-Path -Parent $resolvedEvidence
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$results = @()
foreach ($run in $runs) {
    $fixture = New-RadIAFireDACFixture `
        -ScenarioId $run.scenarioId `
        -TargetId $run.targetId
    try {
        $runEvidence = Join-Path `
            $evidenceDirectory `
            "$($run.scenarioId)-$($run.targetId).json"
        $arguments = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $smokePath,
            "-DelphiVersion",
            $run.delphiVersion,
            "-Cycles",
            "1",
            "-StartupTimeoutSeconds",
            [string]$StartupTimeoutSeconds,
            "-SkipPackageHashCheck",
            "-FireDACScenarioId",
            $run.scenarioId,
            "-FireDACProjectPath",
            $fixture.ProjectPath,
            "-FireDACEvidencePath",
            $runEvidence
        )
        if ($fixture.DatabasePath) {
            $arguments += @(
                "-FireDACDatabasePath",
                $fixture.DatabasePath
            )
        }
        if ($fixture.TestExecutablePath) {
            $arguments += @(
                "-FireDACTestExecutablePath",
                $fixture.TestExecutablePath
            )
        }
        if ($run.ideArchitecture -eq "Win64") {
            $arguments += "-IDE64"
        }
        $previousErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            $output = & powershell.exe @arguments 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
        $results += [PSCustomObject]@{
            scenarioId = $run.scenarioId
            targetId = $run.targetId
            status = if ($exitCode -eq 0) { "passed" } else { "failed" }
            exitCode = $exitCode
            evidencePath = $runEvidence
            outputTail = if ($output.Length -gt 4096) {
                $output.Substring($output.Length - 4096)
            } else {
                $output
            }
        }
        if ($exitCode -ne 0) {
            break
        }
    } finally {
        if (-not $KeepFixtures -and
            (Test-Path -LiteralPath $fixture.Root -PathType Container)) {
            try {
                Remove-Item `
                    -LiteralPath $fixture.Root `
                    -Recurse `
                    -Force `
                    -ErrorAction Stop
            } catch {
                Write-Warning (
                    "FireDAC fixture remains for inspection because it is " +
                    "locked: $($fixture.Root)"
                )
            }
        }
    }
}
$status = if (
    $results.Count -eq $runs.Count -and
    @($results | Where-Object { $_.status -ne "passed" }).Count -eq 0
) {
    "passed"
} else {
    "failed"
}
[PSCustomObject]@{
    schemaVersion = 1
    evidenceKind = "fireDACAdvisorIDEMatrix"
    status = $status
    expectedRunCount = $runs.Count
    runCount = $results.Count
    generatedAtUtc = [DateTime]::UtcNow.ToString("o")
    runs = $results
} | ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8
if ($status -ne "passed") {
    throw "FireDAC Advisor IDE matrix failed: $resolvedEvidence"
}
Write-Host "FireDAC Advisor IDE matrix passed: $resolvedEvidence"
