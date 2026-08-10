unit RadIA.Core.CliManager;

interface

type
  TRadIACliKind = (
    ckCodex,
    ckClaude,
    ckGemini,
    ckCopilot
  );

  TRadIACliInstallChannel = (
    cicOfficialInstaller,
    cicNpm,
    cicWinget
  );

  TRadIACliDefinition = record
  private
    FKind: TRadIACliKind;
    FId: string;
    FDisplayName: string;
    FExecutableNames: TArray<string>;
    FPrimaryChannel: TRadIACliInstallChannel;
    FPackageId: string;
    FDocumentationUrl: string;
    FPrerequisites: TArray<string>;
    FAuthStatusArguments: TArray<string>;
    FAuthLoginHint: string;
  public
    constructor Create(
      const AKind: TRadIACliKind;
      const AId: string;
      const ADisplayName: string;
      const AExecutableNames: TArray<string>;
      const APrimaryChannel: TRadIACliInstallChannel;
      const APackageId: string;
      const ADocumentationUrl: string
    );
    function WithPrerequisites(
      const APrerequisites: TArray<string>
    ): TRadIACliDefinition;
    function WithAuthentication(
      const AStatusArguments: TArray<string>;
      const ALoginHint: string
    ): TRadIACliDefinition;
    function ToDiagnosticText: string;
    property Kind: TRadIACliKind read FKind;
    property Id: string read FId;
    property DisplayName: string read FDisplayName;
    property ExecutableNames: TArray<string> read FExecutableNames;
    property PrimaryChannel: TRadIACliInstallChannel read FPrimaryChannel;
    property PackageId: string read FPackageId;
    property DocumentationUrl: string read FDocumentationUrl;
    property Prerequisites: TArray<string> read FPrerequisites;
    property AuthStatusArguments: TArray<string> read FAuthStatusArguments;
    property AuthLoginHint: string read FAuthLoginHint;
  end;

  TRadIACliDetection = record
  private
    FDefinition: TRadIACliDefinition;
    FInstalled: Boolean;
    FExecutablePath: string;
    FSource: string;
  public
    constructor Create(
      const ADefinition: TRadIACliDefinition;
      const AInstalled: Boolean;
      const AExecutablePath: string;
      const ASource: string
    );
    function ToDiagnosticText: string;
    property Definition: TRadIACliDefinition read FDefinition;
    property Installed: Boolean read FInstalled;
    property ExecutablePath: string read FExecutablePath;
    property Source: string read FSource;
  end;

  TRadIACliInstallPlan = record
  private
    FExecutablePath: string;
    FArguments: TArray<string>;
    FPreview: string;
  public
    constructor Create(
      const AExecutablePath: string;
      const AArguments: TArray<string>;
      const APreview: string
    );
    property ExecutablePath: string read FExecutablePath;
    property Arguments: TArray<string> read FArguments;
    property Preview: string read FPreview;
  end;

  TRadIACliSetupDiagnostic = record
  private
    FReady: Boolean;
    FPrerequisiteName: string;
    FExecutablePath: string;
    FAction: string;
    FDocumentationUrl: string;
  public
    constructor Create(
      const AReady: Boolean;
      const APrerequisiteName: string;
      const AExecutablePath: string;
      const AAction: string;
      const ADocumentationUrl: string
    );
    property Ready: Boolean read FReady;
    property PrerequisiteName: string read FPrerequisiteName;
    property ExecutablePath: string read FExecutablePath;
    property Action: string read FAction;
    property DocumentationUrl: string read FDocumentationUrl;
  end;

  IRadIACliEnvironment = interface
    ['{E49148CA-B27C-49B5-9190-18B52EA570C6}']
    function FileExists(const AFileName: string): Boolean;
    function GetPathEntries: TArray<string>;
  end;

  TRadIACliEnvironment = class(
    TInterfacedObject,
    IRadIACliEnvironment
  )
  public
    function FileExists(const AFileName: string): Boolean;
    function GetPathEntries: TArray<string>;
  end;

  TRadIACliCatalog = class
  public
    class function All: TArray<TRadIACliDefinition>; static;
    class function FindById(
      const AId: string;
      out ADefinition: TRadIACliDefinition
    ): Boolean; static;
  end;

  TRadIACliDetector = class
  private
    FEnvironment: IRadIACliEnvironment;
    function FindInPath(
      const AExecutableNames: TArray<string>
    ): string;
    function FindInKnownLocations(
      const AExecutableNames: TArray<string>
    ): string;
  public
    constructor Create(
      const AEnvironment: IRadIACliEnvironment = nil
    );
    function Detect(
      const ADefinition: TRadIACliDefinition;
      const AConfiguredPath: string = ''
    ): TRadIACliDetection;
    function DetectAll: TArray<TRadIACliDetection>;
  end;

  TRadIACliResolver = class
  public
    class function ExpectedExecutablePath(
      const AClientId: string
    ): string; static;
    class function Resolve(
      const AClientId: string
    ): TRadIACliDetection; overload; static;
    class function Resolve(
      const AClientId: string;
      const AConfiguredPath: string;
      const AEnvironment: IRadIACliEnvironment
    ): TRadIACliDetection; overload; static;
  end;

  TRadIACliInstaller = class
  private
    class function BuildNpmPlan(
      const ADefinition: TRadIACliDefinition
    ): TRadIACliInstallPlan; static;
    class function BuildWingetPlan(
      const ADefinition: TRadIACliDefinition
    ): TRadIACliInstallPlan; static;
    class procedure ValidatePackageId(
      const APackageId: string
    ); static;
  public
    class function BuildPlan(
      const ADefinition: TRadIACliDefinition
    ): TRadIACliInstallPlan; static;
    class function BuildPrerequisitePlan(
      const ADefinition: TRadIACliDefinition
    ): TRadIACliInstallPlan; static;
  end;

  TRadIACliSetupAdvisor = class
  private
    class function FindExecutable(
      const ANames: TArray<string>
    ): string; static;
  public
    class function DiagnosePrerequisite(
      const ADefinition: TRadIACliDefinition
    ): TRadIACliSetupDiagnostic; static;
    class function ManualGuidance(
      const ADefinition: TRadIACliDefinition
    ): string; static;
    class function PrerequisiteManualGuidance(
      const ADefinition: TRadIACliDefinition;
      const ADiagnostic: TRadIACliSetupDiagnostic
    ): string; static;
  end;

  TRadIACliSetupHistory = class
  public
    class function FileName: string; static;
    class procedure Append(
      const AClientId: string;
      const AOperation: string;
      const ASucceeded: Boolean;
      const ADetails: string
    ); static;
  end;

  TRadIACliHealth = class
  public
    class function DescribeFailure(
      const AStdOut: string;
      const AStdErr: string;
      const AExitCode: Integer
    ): string; static;
    class function NormalizeVersionOutput(
      const AStdOut: string;
      const AStdErr: string
    ): string; static;
    class function VersionMeetsMinimum(
      const AVersionOutput: string;
      const AMinimumVersion: string
    ): Boolean; static;
  end;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.CliMcpSettings;

{ TRadIACliHealth }

function TryParseVersionCore(
  const AText: string;
  out AMajor: Integer;
  out AMinor: Integer;
  out APatch: Integer
): Boolean;
var
  LIndex: Integer;
  LPart: Integer;
  LStart: Integer;
  LValues: array[0..2] of Integer;
begin
  Result := False;
  LIndex := Low(AText);
  while (LIndex <= High(AText)) and not CharInSet(AText[LIndex], ['0'..'9']) do
    Inc(LIndex);
  for LPart := Low(LValues) to High(LValues) do
  begin
    LStart := LIndex;
    while (LIndex <= High(AText)) and CharInSet(AText[LIndex], ['0'..'9']) do
      Inc(LIndex);
    if (LStart = LIndex) or
      not TryStrToInt(Copy(AText, LStart, LIndex - LStart), LValues[LPart]) then
      Exit;
    if LPart < High(LValues) then
    begin
      if (LIndex > High(AText)) or (AText[LIndex] <> '.') then
        Exit;
      Inc(LIndex);
    end;
  end;
  AMajor := LValues[0];
  AMinor := LValues[1];
  APatch := LValues[2];
  Result := True;
end;

class function TRadIACliHealth.DescribeFailure(
  const AStdOut: string;
  const AStdErr: string;
  const AExitCode: Integer
): string;
var
  LText: string;
begin
  LText := LowerCase(AStdOut + sLineBreak + AStdErr);
  if LText.Contains('not recognized') or LText.Contains('not found') then
    Exit('A required command was not found. Run Diagnose or use Manual steps.');
  if LText.Contains('access is denied') or LText.Contains('permission denied') then
    Exit('Windows denied access. Review permissions and retry the approved step.');
  if LText.Contains('proxy') then
    Exit('The package manager reported a proxy problem. Review the network proxy settings.');
  if LText.Contains('network') or LText.Contains('timed out') then
    Exit('The download could not complete. Check the network and retry.');
  Result := Format(
    'The setup step failed with exit code %d. Use Manual steps for the official command and URL.',
    [AExitCode]
  );
end;

class function TRadIACliHealth.NormalizeVersionOutput(
  const AStdOut: string;
  const AStdErr: string
): string;
var
  LLines: TStringList;
  LOutput: string;
begin
  LOutput := Trim(AStdOut);
  if LOutput = '' then
    LOutput := Trim(AStdErr);
  LLines := TStringList.Create;
  try
    LLines.Text := LOutput;
    if LLines.Count = 0 then
      Exit('');
    Result := Trim(LLines[0]);
  finally
    LLines.Free;
  end;
end;

class function TRadIACliHealth.VersionMeetsMinimum(
  const AVersionOutput: string;
  const AMinimumVersion: string
): Boolean;
var
  LMajor: Integer;
  LMinimumMajor: Integer;
  LMinimumMinor: Integer;
  LMinimumPatch: Integer;
  LMinor: Integer;
  LPatch: Integer;
begin
  Result := TryParseVersionCore(AVersionOutput, LMajor, LMinor, LPatch) and
    TryParseVersionCore(
      AMinimumVersion,
      LMinimumMajor,
      LMinimumMinor,
      LMinimumPatch
    );
  if not Result then
    Exit;
  Result := (LMajor > LMinimumMajor) or
    ((LMajor = LMinimumMajor) and (LMinor > LMinimumMinor)) or
    ((LMajor = LMinimumMajor) and (LMinor = LMinimumMinor) and
      (LPatch >= LMinimumPatch));
end;

{ TRadIACliDefinition }

constructor TRadIACliDefinition.Create(
  const AKind: TRadIACliKind;
  const AId: string;
  const ADisplayName: string;
  const AExecutableNames: TArray<string>;
  const APrimaryChannel: TRadIACliInstallChannel;
  const APackageId: string;
  const ADocumentationUrl: string
);
begin
  FKind := AKind;
  FId := AId;
  FDisplayName := ADisplayName;
  FExecutableNames := AExecutableNames;
  FPrimaryChannel := APrimaryChannel;
  FPackageId := APackageId;
  FDocumentationUrl := ADocumentationUrl;
  FPrerequisites := [];
  FAuthStatusArguments := [];
  FAuthLoginHint := '';
end;

function TRadIACliDefinition.WithAuthentication(
  const AStatusArguments: TArray<string>;
  const ALoginHint: string
): TRadIACliDefinition;
begin
  Result := Self;
  Result.FAuthStatusArguments := AStatusArguments;
  Result.FAuthLoginHint := ALoginHint;
end;

function TRadIACliDefinition.WithPrerequisites(
  const APrerequisites: TArray<string>
): TRadIACliDefinition;
begin
  Result := Self;
  Result.FPrerequisites := APrerequisites;
end;

function TRadIACliDefinition.ToDiagnosticText: string;
begin
  Result := Format(
    '%d|%s|%s|%d|%d|%s|%s|%d|%d|%s',
    [
      Ord(Kind),
      Id,
      DisplayName,
      Length(ExecutableNames),
      Ord(PrimaryChannel),
      PackageId,
      DocumentationUrl,
      Length(Prerequisites),
      Length(AuthStatusArguments),
      AuthLoginHint
    ]
  );
end;

{ TRadIACliDetection }

constructor TRadIACliDetection.Create(
  const ADefinition: TRadIACliDefinition;
  const AInstalled: Boolean;
  const AExecutablePath: string;
  const ASource: string
);
begin
  FDefinition := ADefinition;
  FInstalled := AInstalled;
  FExecutablePath := AExecutablePath;
  FSource := ASource;
end;

function TRadIACliDetection.ToDiagnosticText: string;
begin
  Result := Format(
    '%s|%s|%s|%s',
    [
      Definition.ToDiagnosticText,
      BoolToStr(Installed, True),
      ExecutablePath,
      Source
    ]
  );
end;

{ TRadIACliEnvironment }

function TRadIACliEnvironment.FileExists(
  const AFileName: string
): Boolean;
begin
  Result := System.SysUtils.FileExists(AFileName);
end;

{ TRadIACliInstallPlan }

constructor TRadIACliInstallPlan.Create(
  const AExecutablePath: string;
  const AArguments: TArray<string>;
  const APreview: string
);
begin
  FExecutablePath := AExecutablePath;
  FArguments := AArguments;
  FPreview := APreview;
end;

{ TRadIACliSetupDiagnostic }

constructor TRadIACliSetupDiagnostic.Create(
  const AReady: Boolean;
  const APrerequisiteName: string;
  const AExecutablePath: string;
  const AAction: string;
  const ADocumentationUrl: string
);
begin
  FReady := AReady;
  FPrerequisiteName := APrerequisiteName;
  FExecutablePath := AExecutablePath;
  FAction := AAction;
  FDocumentationUrl := ADocumentationUrl;
end;

function TRadIACliEnvironment.GetPathEntries: TArray<string>;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.StrictDelimiter := True;
    LList.Delimiter := ';';
    LList.DelimitedText := GetEnvironmentVariable('PATH');
    Result := LList.ToStringArray;
  finally
    LList.Free;
  end;
end;

{ TRadIACliCatalog }

class function TRadIACliCatalog.All: TArray<TRadIACliDefinition>;
begin
  Result := [
    TRadIACliDefinition.Create(
      ckCodex,
      'codex',
      'Codex CLI',
      ['codex.exe', 'codex.cmd', 'codex'],
      cicNpm,
      '@openai/codex',
      'https://github.com/openai/codex'
    ).WithPrerequisites(['Node.js 20 or later']).WithAuthentication(
      ['login', 'status'],
      'codex login'
    ),
    TRadIACliDefinition.Create(
      ckClaude,
      'claude',
      'Claude Code',
      ['claude.exe', 'claude.cmd', 'claude'],
      cicNpm,
      '@anthropic-ai/claude-code',
      'https://docs.anthropic.com/en/docs/claude-code'
    ).WithPrerequisites(
      ['Node.js 18 or later', 'Git Bash or WSL']
    ).WithAuthentication(
      ['auth', 'status'],
      'claude auth login'
    ),
    TRadIACliDefinition.Create(
      ckGemini,
      'gemini',
      'Gemini CLI',
      ['gemini.exe', 'gemini.cmd', 'gemini'],
      cicNpm,
      '@google/gemini-cli',
      'https://github.com/google-gemini/gemini-cli'
    ).WithPrerequisites(['Node.js 20 or later']).WithAuthentication(
      [],
      'Start gemini and use /auth'
    ),
    TRadIACliDefinition.Create(
      ckCopilot,
      'copilot',
      'GitHub Copilot CLI',
      ['copilot.exe', 'copilot.cmd', 'copilot'],
      cicWinget,
      'GitHub.Copilot',
      'https://docs.github.com/en/copilot/how-tos/copilot-cli'
    ).WithPrerequisites(['PowerShell 7 or later']).WithAuthentication(
      [],
      'copilot login'
    )
  ];
end;

class function TRadIACliCatalog.FindById(
  const AId: string;
  out ADefinition: TRadIACliDefinition
): Boolean;
var
  LDefinition: TRadIACliDefinition;
begin
  for LDefinition in All do
    if SameText(LDefinition.Id, Trim(AId)) then
    begin
      ADefinition := LDefinition;
      Exit(True);
    end;
  ADefinition := Default(TRadIACliDefinition);
  Result := False;
end;

constructor TRadIACliDetector.Create(
  const AEnvironment: IRadIACliEnvironment
);
begin
  inherited Create;
  if Assigned(AEnvironment) then
    FEnvironment := AEnvironment
  else
    FEnvironment := TRadIACliEnvironment.Create;
end;

function TRadIACliDetector.Detect(
  const ADefinition: TRadIACliDefinition;
  const AConfiguredPath: string
): TRadIACliDetection;
var
  LExecutablePath: string;
begin
  LExecutablePath := Trim(AConfiguredPath);
  if (LExecutablePath <> '') and
    FEnvironment.FileExists(LExecutablePath) then
    Exit(
      TRadIACliDetection.Create(
        ADefinition,
        True,
        LExecutablePath,
        'configured'
      )
    );

  LExecutablePath := FindInPath(ADefinition.ExecutableNames);
  if LExecutablePath = '' then
    LExecutablePath := FindInKnownLocations(ADefinition.ExecutableNames);
  Result := TRadIACliDetection.Create(
    ADefinition,
    LExecutablePath <> '',
    LExecutablePath,
    'path'
  );
end;

function TRadIACliDetector.DetectAll: TArray<TRadIACliDetection>;
var
  LDefinition: TRadIACliDefinition;
  LDetections: TList<TRadIACliDetection>;
begin
  LDetections := TList<TRadIACliDetection>.Create;
  try
    for LDefinition in TRadIACliCatalog.All do
      LDetections.Add(Detect(LDefinition));
    Result := LDetections.ToArray;
  finally
    LDetections.Free;
  end;
end;

{ TRadIACliInstaller }

class function TRadIACliInstaller.BuildNpmPlan(
  const ADefinition: TRadIACliDefinition
): TRadIACliInstallPlan;
var
  LCommand: string;
begin
  LCommand := 'npm install --global ' + ADefinition.PackageId + '@latest';
  Result := TRadIACliInstallPlan.Create(
    'cmd.exe',
    ['/d', '/s', '/c', LCommand],
    LCommand
  );
end;

class function TRadIACliInstaller.BuildPlan(
  const ADefinition: TRadIACliDefinition
): TRadIACliInstallPlan;
begin
  ValidatePackageId(ADefinition.PackageId);
  case ADefinition.PrimaryChannel of
    cicNpm:
      Result := BuildNpmPlan(ADefinition);
    cicWinget:
      Result := BuildWingetPlan(ADefinition);
  else
    raise EInvalidOpException.Create(
      'Automated installation is unavailable for this official channel.'
    );
  end;
end;

function TRadIACliDetector.FindInKnownLocations(
  const AExecutableNames: TArray<string>
): string;
var
  LCandidate: string;
  LDirectory: string;
  LDirectories: TArray<string>;
  LExecutableName: string;
begin
  LDirectories := [
    TPath.Combine(GetEnvironmentVariable('APPDATA'), 'npm'),
    TPath.Combine(GetEnvironmentVariable('ProgramFiles'), 'nodejs'),
    TPath.Combine(
      GetEnvironmentVariable('LOCALAPPDATA'),
      'Microsoft\WinGet\Links'
    )
  ];
  for LDirectory in LDirectories do
    for LExecutableName in AExecutableNames do
    begin
      LCandidate := TPath.Combine(LDirectory, LExecutableName);
      if FEnvironment.FileExists(LCandidate) then
        Exit(LCandidate);
    end;
  Result := '';
end;

class function TRadIACliInstaller.BuildPrerequisitePlan(
  const ADefinition: TRadIACliDefinition
): TRadIACliInstallPlan;
const
  CNodeCommand =
    'winget install --id OpenJS.NodeJS.LTS --exact --source winget ' +
    '--accept-source-agreements --accept-package-agreements --disable-interactivity';
begin
  if ADefinition.PrimaryChannel <> cicNpm then
    raise EInvalidOpException.Create(
      'This prerequisite cannot be installed automatically.'
    );
  Result := TRadIACliInstallPlan.Create(
    'cmd.exe',
    ['/d', '/s', '/c', CNodeCommand],
    CNodeCommand
  );
end;

class procedure TRadIACliInstaller.ValidatePackageId(
  const APackageId: string
);
var
  LCharacter: Char;
begin
  if Trim(APackageId) = '' then
    raise EArgumentException.Create('The official package ID is unavailable.');
  for LCharacter in APackageId do
    if not CharInSet(
      LCharacter,
      ['a'..'z', 'A'..'Z', '0'..'9', '@', '/', '.', '_', '-']
    ) then
      raise EArgumentException.Create(
        'The official package ID contains invalid characters.'
      );
end;

class function TRadIACliInstaller.BuildWingetPlan(
  const ADefinition: TRadIACliDefinition
): TRadIACliInstallPlan;
var
  LCommand: string;
begin
  LCommand :=
    'winget install --id ' + ADefinition.PackageId +
    ' --exact --source winget --accept-source-agreements ' +
    '--accept-package-agreements --disable-interactivity';
  Result := TRadIACliInstallPlan.Create(
    'cmd.exe',
    ['/d', '/s', '/c', LCommand],
    LCommand
  );
end;

{ TRadIACliSetupAdvisor }

class function TRadIACliSetupAdvisor.FindExecutable(
  const ANames: TArray<string>
): string;
var
  LName: string;
  LPath: string;
begin
  for LName in ANames do
  begin
    LPath := FileSearch(LName, GetEnvironmentVariable('PATH'));
    if LPath <> '' then
      Exit(LPath);
  end;
  Result := '';
end;

class function TRadIACliSetupAdvisor.DiagnosePrerequisite(
  const ADefinition: TRadIACliDefinition
): TRadIACliSetupDiagnostic;
var
  LPath: string;
begin
  case ADefinition.PrimaryChannel of
    cicNpm:
      begin
        LPath := FindExecutable(['npm.cmd', 'npm.exe', 'npm']);
        Result := TRadIACliSetupDiagnostic.Create(
          LPath <> '',
          'Node.js and npm',
          LPath,
          'Install Node.js LTS, then run Diagnose again.',
          'https://nodejs.org/en/download'
        );
      end;
    cicWinget:
      begin
        LPath := FindExecutable(['winget.exe', 'winget']);
        Result := TRadIACliSetupDiagnostic.Create(
          LPath <> '',
          'Windows Package Manager (winget)',
          LPath,
          'Install or update App Installer, then run Diagnose again.',
          'https://learn.microsoft.com/windows/package-manager/winget/'
        );
      end;
  else
    Result := TRadIACliSetupDiagnostic.Create(
      True,
      '',
      '',
      '',
      ADefinition.DocumentationUrl
    );
  end;
end;

class function TRadIACliSetupAdvisor.ManualGuidance(
  const ADefinition: TRadIACliDefinition
): string;
var
  LPlan: TRadIACliInstallPlan;
begin
  LPlan := TRadIACliInstaller.BuildPlan(ADefinition);
  Result := Format(
    '%s installation options:' + sLineBreak +
    'Official documentation: %s' + sLineBreak +
    'Official command: %s' + sLineBreak +
    'Expected executable names: %s' + sLineBreak +
    'Portable alternative: select the full executable path with Browse.',
    [
      ADefinition.DisplayName,
      ADefinition.DocumentationUrl,
      LPlan.Preview,
      string.Join(', ', ADefinition.ExecutableNames)
    ]
  );
end;

class function TRadIACliSetupAdvisor.PrerequisiteManualGuidance(
  const ADefinition: TRadIACliDefinition;
  const ADiagnostic: TRadIACliSetupDiagnostic
): string;
var
  LRecommendedVersion: string;
begin
  if ADefinition.PrimaryChannel = cicNpm then
    LRecommendedVersion := 'current LTS release'
  else
    LRecommendedVersion := 'current stable release';
  Result := Format(
    '%s is required for the optional %s installation channel.' + sLineBreak +
    'Official source: %s' + sLineBreak +
    'Recommended version: %s.' + sLineBreak +
    'Install it using the official installer, then reopen this screen.' + sLineBreak +
    'Click Diagnose to verify detection and continue the original setup.' + sLineBreak +
    'Alternative: cancel and select an existing portable CLI with Browse.',
    [
      ADiagnostic.PrerequisiteName,
      ADefinition.DisplayName,
      ADiagnostic.DocumentationUrl,
      LRecommendedVersion
    ]
  );
end;

{ TRadIACliSetupHistory }

class procedure TRadIACliSetupHistory.Append(
  const AClientId: string;
  const AOperation: string;
  const ASucceeded: Boolean;
  const ADetails: string
);
var
  LEntry: TJSONObject;
  LFolder: string;
begin
  LFolder := TPath.GetDirectoryName(FileName);
  TDirectory.CreateDirectory(LFolder);
  LEntry := TJSONObject.Create;
  try
    LEntry.AddPair(
      'timestampUtc',
      DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True)
    );
    LEntry.AddPair('clientId', AClientId);
    LEntry.AddPair('operation', AOperation);
    LEntry.AddPair('succeeded', TJSONBool.Create(ASucceeded));
    LEntry.AddPair('details', Copy(ADetails, 1, 500));
    TFile.AppendAllText(
      FileName,
      LEntry.ToJSON + sLineBreak,
      TEncoding.UTF8
    );
  finally
    LEntry.Free;
  end;
end;

class function TRadIACliSetupHistory.FileName: string;
var
  LOverride: string;
begin
  LOverride := Trim(GetEnvironmentVariable('RADIA_CLI_MCP_HISTORY_PATH'));
  if LOverride <> '' then
    Exit(LOverride);
  Result := TPath.Combine(
    TPath.Combine(TPath.GetHomePath, 'RadIA'),
    'cli-mcp-setup-history.jsonl'
  );
end;

function TRadIACliDetector.FindInPath(
  const AExecutableNames: TArray<string>
): string;
var
  LDirectory: string;
  LExecutableName: string;
  LCandidate: string;
begin
  for LDirectory in FEnvironment.GetPathEntries do
    for LExecutableName in AExecutableNames do
    begin
      LCandidate := TPath.Combine(
        LDirectory.Trim([' ', '"']),
        LExecutableName
      );
      if FEnvironment.FileExists(LCandidate) then
        Exit(LCandidate);
    end;
  Result := '';
end;

{ TRadIACliResolver }

class function TRadIACliResolver.ExpectedExecutablePath(
  const AClientId: string
): string;
var
  LDefinition: TRadIACliDefinition;
begin
  Result := '';
  if not TRadIACliCatalog.FindById(AClientId, LDefinition) then
    Exit;
  case LDefinition.PrimaryChannel of
    cicNpm:
      Result := TPath.Combine(
        TPath.Combine(GetEnvironmentVariable('APPDATA'), 'npm'),
        LDefinition.Id + '.cmd'
      );
    cicWinget:
      Result := TPath.Combine(
        TPath.Combine(
          GetEnvironmentVariable('LOCALAPPDATA'),
          'Microsoft\WinGet\Links'
        ),
        LDefinition.Id + '.exe'
      );
  end;
end;

class function TRadIACliResolver.Resolve(
  const AClientId: string
): TRadIACliDetection;
var
  LSettings: TRadIACliMcpClientSettings;
  LSettingsStore: TRadIACliMcpSettings;
begin
  LSettingsStore := TRadIACliMcpSettings.Create;
  try
    LSettings := LSettingsStore.Load(AClientId, '', '');
  finally
    LSettingsStore.Free;
  end;

  Result := Resolve(AClientId, LSettings.CliExecutablePath, nil);
end;

class function TRadIACliResolver.Resolve(
  const AClientId: string;
  const AConfiguredPath: string;
  const AEnvironment: IRadIACliEnvironment
): TRadIACliDetection;
var
  LDefinition: TRadIACliDefinition;
  LDetector: TRadIACliDetector;
begin
  if not TRadIACliCatalog.FindById(AClientId, LDefinition) then
    raise EArgumentException.CreateFmt(
      'The CLI client "%s" is not supported.',
      [AClientId]
    );
  LDetector := TRadIACliDetector.Create(AEnvironment);
  try
    Result := LDetector.Detect(
      LDefinition,
      AConfiguredPath
    );
  finally
    LDetector.Free;
  end;
end;

end.
