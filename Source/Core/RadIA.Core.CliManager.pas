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
    function ToDiagnosticText: string;
    property Kind: TRadIACliKind read FKind;
    property Id: string read FId;
    property DisplayName: string read FDisplayName;
    property ExecutableNames: TArray<string> read FExecutableNames;
    property PrimaryChannel: TRadIACliInstallChannel read FPrimaryChannel;
    property PackageId: string read FPackageId;
    property DocumentationUrl: string read FDocumentationUrl;
    property Prerequisites: TArray<string> read FPrerequisites;
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

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils;

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
    '%d|%s|%s|%d|%d|%s|%s|%d',
    [
      Ord(Kind),
      Id,
      DisplayName,
      Length(ExecutableNames),
      Ord(PrimaryChannel),
      PackageId,
      DocumentationUrl,
      Length(Prerequisites)
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
      cicOfficialInstaller,
      '@openai/codex',
      'https://github.com/openai/codex'
    ),
    TRadIACliDefinition.Create(
      ckClaude,
      'claude',
      'Claude Code',
      ['claude.exe', 'claude.cmd', 'claude'],
      cicOfficialInstaller,
      '@anthropic-ai/claude-code',
      'https://docs.anthropic.com/en/docs/claude-code'
    ).WithPrerequisites(['Git Bash or WSL']),
    TRadIACliDefinition.Create(
      ckGemini,
      'gemini',
      'Gemini CLI',
      ['gemini.exe', 'gemini.cmd', 'gemini'],
      cicNpm,
      '@google/gemini-cli',
      'https://github.com/google-gemini/gemini-cli'
    ).WithPrerequisites(['Node.js 20 or later']),
    TRadIACliDefinition.Create(
      ckCopilot,
      'copilot',
      'GitHub Copilot CLI',
      ['copilot.exe', 'copilot.cmd', 'copilot'],
      cicWinget,
      'GitHub.Copilot',
      'https://docs.github.com/en/copilot/how-tos/copilot-cli'
    ).WithPrerequisites(['PowerShell 7 or later'])
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

end.
