unit RadIA.Core.Terminal;

interface

uses
  System.Generics.Collections,
  RadIA.Core.AgentExecutors;

type
  TRadIATerminalColor = (
    tcDefault,
    tcBlack,
    tcRed,
    tcGreen,
    tcYellow,
    tcBlue,
    tcMagenta,
    tcCyan,
    tcWhite,
    tcBrightBlack,
    tcBrightRed,
    tcBrightGreen,
    tcBrightYellow,
    tcBrightBlue,
    tcBrightMagenta,
    tcBrightCyan,
    tcBrightWhite
  );

  TRadIATerminalTextStyle = record
  private
    FForeground: TRadIATerminalColor;
    FBold: Boolean;
  public
    class function Default: TRadIATerminalTextStyle; static;
    property Foreground: TRadIATerminalColor read FForeground;
    property Bold: Boolean read FBold;
  end;

  TRadIATerminalTextSegment = record
  private
    FText: string;
    FStyle: TRadIATerminalTextStyle;
  public
    constructor Create(
      const AText: string;
      const AStyle: TRadIATerminalTextStyle
    );
    property Text: string read FText;
    property Style: TRadIATerminalTextStyle read FStyle;
  end;

  TRadIATerminalAnsiParser = class
  private
    FPending: string;
    FStyle: TRadIATerminalTextStyle;
    procedure ApplyCode(const ACode: Integer);
    procedure ApplySgr(const AParameters: string);
    procedure AppendSegment(
      var ASegments: TArray<TRadIATerminalTextSegment>;
      const AText: string
    );
    function ConsumeEscape(
      const AInput: string;
      const AStartIndex: Integer;
      out ANextIndex: Integer
    ): Boolean;
  public
    constructor Create;
    function Feed(
      const AChunk: string
    ): TArray<TRadIATerminalTextSegment>;
    procedure Reset;
  end;

  TRadIATerminalProfile = record
  private
    FId: string;
    FDisplayName: string;
    FExecutablePath: string;
    FArgumentsPrefix: TArray<string>;
  public
    constructor Create(
      const AId: string;
      const ADisplayName: string;
      const AExecutablePath: string;
      const AArgumentsPrefix: TArray<string>
    );
    function BuildInvocation(
      const ACommand: string;
      const AWorkingDirectory: string
    ): TRadIACliInvocation;
    property Id: string read FId;
    property DisplayName: string read FDisplayName;
  end;

  TRadIATerminalSnippet = record
  private
    FName: string;
    FCommand: string;
  public
    constructor Create(const AName: string; const ACommand: string);
    property Name: string read FName;
    property Command: string read FCommand;
  end;

  TRadIATerminalHistoryEntry = record
  private
    FTimestampUtc: TDateTime;
    FProfileId: string;
    FCommand: string;
    FExitCode: Cardinal;
  public
    constructor Create(
      const ATimestampUtc: TDateTime;
      const AProfileId: string;
      const ACommand: string;
      const AExitCode: Cardinal
    );
    property TimestampUtc: TDateTime read FTimestampUtc;
    property ProfileId: string read FProfileId;
    property Command: string read FCommand;
    property ExitCode: Cardinal read FExitCode;
  end;

  TRadIATerminalCatalog = class
  public
    class function Profiles: TArray<TRadIATerminalProfile>; static;
    class function Snippets: TArray<TRadIATerminalSnippet>; static;
  end;

  TRadIATerminalHistory = class
  private
    FEntries: TList<TRadIATerminalHistoryEntry>;
    FFileName: string;
    FMaxEntries: Integer;
    procedure TrimToLimit;
  public
    constructor Create(
      const AFileName: string;
      const AMaxEntries: Integer = 200
    );
    destructor Destroy; override;
    procedure Add(const AEntry: TRadIATerminalHistoryEntry);
    procedure Load;
    procedure Save;
    function Entries: TArray<TRadIATerminalHistoryEntry>;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

{ TRadIATerminalTextStyle }

class function TRadIATerminalTextStyle.Default:
  TRadIATerminalTextStyle;
begin
  Result.FForeground := tcDefault;
  Result.FBold := False;
end;

{ TRadIATerminalTextSegment }

constructor TRadIATerminalTextSegment.Create(
  const AText: string;
  const AStyle: TRadIATerminalTextStyle
);
begin
  FText := AText;
  FStyle := AStyle;
end;

{ TRadIATerminalAnsiParser }

procedure TRadIATerminalAnsiParser.ApplyCode(const ACode: Integer);
begin
  case ACode of
    0:
      FStyle := TRadIATerminalTextStyle.Default;
    1:
      FStyle.FBold := True;
    22:
      FStyle.FBold := False;
    30..37:
      FStyle.FForeground :=
        TRadIATerminalColor(Ord(tcBlack) + ACode - 30);
    39:
      FStyle.FForeground := tcDefault;
    90..97:
      FStyle.FForeground :=
        TRadIATerminalColor(Ord(tcBrightBlack) + ACode - 90);
  end;
end;

procedure TRadIATerminalAnsiParser.ApplySgr(
  const AParameters: string
);
var
  LCode: Integer;
  LParameter: string;
  LParameters: TArray<string>;
begin
  if AParameters = '' then
  begin
    ApplyCode(0);
    Exit;
  end;
  LParameters := AParameters.Split([';']);
  for LParameter in LParameters do
  begin
    if not TryStrToInt(LParameter, LCode) then
      Continue;
    ApplyCode(LCode);
  end;
end;

procedure TRadIATerminalAnsiParser.AppendSegment(
  var ASegments: TArray<TRadIATerminalTextSegment>;
  const AText: string
);
var
  LIndex: Integer;
begin
  if AText = '' then
    Exit;
  LIndex := Length(ASegments);
  if (LIndex > 0) and
    (ASegments[LIndex - 1].Style.Foreground = FStyle.Foreground) and
    (ASegments[LIndex - 1].Style.Bold = FStyle.Bold) then
  begin
    ASegments[LIndex - 1].FText :=
      ASegments[LIndex - 1].Text + AText;
    Exit;
  end;
  SetLength(ASegments, LIndex + 1);
  ASegments[LIndex] := TRadIATerminalTextSegment.Create(
    AText,
    FStyle
  );
end;

function TRadIATerminalAnsiParser.ConsumeEscape(
  const AInput: string;
  const AStartIndex: Integer;
  out ANextIndex: Integer
): Boolean;
var
  LFinalIndex: Integer;
begin
  ANextIndex := AStartIndex;
  if (AStartIndex >= Length(AInput)) or
    (AInput[AStartIndex + 1] <> '[') then
  begin
    ANextIndex := AStartIndex + 1;
    Exit(True);
  end;
  LFinalIndex := AStartIndex + 2;
  while (LFinalIndex <= Length(AInput)) and
    not (
      (Ord(AInput[LFinalIndex]) >= $40) and
      (Ord(AInput[LFinalIndex]) <= $7E)
    ) do
    Inc(LFinalIndex);
  if LFinalIndex > Length(AInput) then
    Exit(False);
  if AInput[LFinalIndex] = 'm' then
    ApplySgr(
      Copy(
        AInput,
        AStartIndex + 2,
        LFinalIndex - AStartIndex - 2
      )
    );
  ANextIndex := LFinalIndex;
  Result := True;
end;

constructor TRadIATerminalAnsiParser.Create;
begin
  inherited Create;
  Reset;
end;

function TRadIATerminalAnsiParser.Feed(
  const AChunk: string
): TArray<TRadIATerminalTextSegment>;
var
  LEscapeIndex: Integer;
  LIndex: Integer;
  LInput: string;
  LNextIndex: Integer;
begin
  SetLength(Result, 0);
  LInput := FPending + AChunk;
  FPending := '';
  LIndex := 1;
  while LIndex <= Length(LInput) do
  begin
    LEscapeIndex := Pos(#27, LInput, LIndex);
    if LEscapeIndex = 0 then
    begin
      AppendSegment(Result, Copy(LInput, LIndex, MaxInt));
      Exit;
    end;
    AppendSegment(
      Result,
      Copy(LInput, LIndex, LEscapeIndex - LIndex)
    );
    if not ConsumeEscape(LInput, LEscapeIndex, LNextIndex) then
    begin
      FPending := Copy(LInput, LEscapeIndex, MaxInt);
      Exit;
    end;
    LIndex := LNextIndex + 1;
  end;
end;

procedure TRadIATerminalAnsiParser.Reset;
begin
  FPending := '';
  FStyle := TRadIATerminalTextStyle.Default;
end;

{ TRadIATerminalProfile }

constructor TRadIATerminalProfile.Create(
  const AId: string;
  const ADisplayName: string;
  const AExecutablePath: string;
  const AArgumentsPrefix: TArray<string>
);
begin
  FId := AId;
  FDisplayName := ADisplayName;
  FExecutablePath := AExecutablePath;
  FArgumentsPrefix := AArgumentsPrefix;
end;

function TRadIATerminalProfile.BuildInvocation(
  const ACommand: string;
  const AWorkingDirectory: string
): TRadIACliInvocation;
var
  LArguments: TArray<string>;
begin
  if Trim(ACommand) = '' then
    raise EArgumentException.Create('The terminal command is required.');
  LArguments := Copy(FArgumentsPrefix);
  LArguments := LArguments + [ACommand];
  Result := TRadIACliInvocation.Create(
    FExecutablePath,
    LArguments,
    AWorkingDirectory,
    'text'
  );
end;

{ TRadIATerminalSnippet }

constructor TRadIATerminalSnippet.Create(
  const AName: string;
  const ACommand: string
);
begin
  FName := AName;
  FCommand := ACommand;
end;

{ TRadIATerminalHistoryEntry }

constructor TRadIATerminalHistoryEntry.Create(
  const ATimestampUtc: TDateTime;
  const AProfileId: string;
  const ACommand: string;
  const AExitCode: Cardinal
);
begin
  FTimestampUtc := ATimestampUtc;
  FProfileId := AProfileId;
  FCommand := ACommand;
  FExitCode := AExitCode;
end;

{ TRadIATerminalCatalog }

class function TRadIATerminalCatalog.Profiles:
  TArray<TRadIATerminalProfile>;
begin
  Result := [
    TRadIATerminalProfile.Create(
      'powershell',
      'Windows PowerShell',
      'powershell.exe',
      ['-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command']
    ),
    TRadIATerminalProfile.Create(
      'cmd',
      'Command Prompt',
      GetEnvironmentVariable('ComSpec'),
      ['/D', '/S', '/C']
    )
  ];
end;

class function TRadIATerminalCatalog.Snippets:
  TArray<TRadIATerminalSnippet>;
begin
  Result := [
    TRadIATerminalSnippet.Create(
      'Build Delphi 13',
      'powershell.exe -ExecutionPolicy Bypass -File build.ps1 ' +
        '-DelphiVersion "37.0"'
    ),
    TRadIATerminalSnippet.Create(
      'Run Delphi 13 tests',
      'powershell.exe -ExecutionPolicy Bypass -File build.ps1 ' +
        '-DelphiVersion "37.0" -Test'
    ),
    TRadIATerminalSnippet.Create('Git status', 'git status --short'),
    TRadIATerminalSnippet.Create('Git diff check', 'git diff --check')
  ];
end;

{ TRadIATerminalHistory }

constructor TRadIATerminalHistory.Create(
  const AFileName: string;
  const AMaxEntries: Integer
);
begin
  inherited Create;
  if Trim(AFileName) = '' then
    raise EArgumentException.Create('The terminal history file is required.');
  if AMaxEntries < 1 then
    raise EArgumentOutOfRangeException.Create(
      'The terminal history limit must be positive.'
    );
  FFileName := AFileName;
  FMaxEntries := AMaxEntries;
  FEntries := TList<TRadIATerminalHistoryEntry>.Create;
end;

destructor TRadIATerminalHistory.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TRadIATerminalHistory.Add(
  const AEntry: TRadIATerminalHistoryEntry
);
begin
  if Trim(AEntry.Command) = '' then
    Exit;
  FEntries.Add(AEntry);
  TrimToLimit;
end;

function TRadIATerminalHistory.Entries:
  TArray<TRadIATerminalHistoryEntry>;
begin
  Result := FEntries.ToArray;
end;

procedure TRadIATerminalHistory.Load;
var
  LArray: TJSONArray;
  LEntry: TJSONValue;
  LRoot: TJSONValue;
  LTimestamp: TDateTime;
begin
  FEntries.Clear;
  if not TFile.Exists(FFileName) then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(FFileName, TEncoding.UTF8)
  );
  try
    if not (LRoot is TJSONArray) then
      Exit;
    LArray := TJSONArray(LRoot);
    for LEntry in LArray do
      if (LEntry is TJSONObject) and
        TryISO8601ToDate(
          TJSONObject(LEntry).GetValue<string>('timestampUtc', ''),
          LTimestamp,
          False
        ) then
        FEntries.Add(
          TRadIATerminalHistoryEntry.Create(
            LTimestamp,
            TJSONObject(LEntry).GetValue<string>('profileId', ''),
            TJSONObject(LEntry).GetValue<string>('command', ''),
            TJSONObject(LEntry).GetValue<Integer>('exitCode', 0)
          )
        );
    TrimToLimit;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIATerminalHistory.Save;
var
  LArray: TJSONArray;
  LDirectory: string;
  LEntry: TRadIATerminalHistoryEntry;
  LObject: TJSONObject;
begin
  LDirectory := ExtractFileDir(FFileName);
  if LDirectory <> '' then
    TDirectory.CreateDirectory(LDirectory);
  LArray := TJSONArray.Create;
  try
    for LEntry in FEntries do
    begin
      LObject := TJSONObject.Create;
      LObject.AddPair(
        'timestampUtc',
        DateToISO8601(LEntry.TimestampUtc, False)
      );
      LObject.AddPair('profileId', LEntry.ProfileId);
      LObject.AddPair('command', LEntry.Command);
      LObject.AddPair(
        'exitCode',
        TJSONNumber.Create(LEntry.ExitCode)
      );
      LArray.AddElement(LObject);
    end;
    TFile.WriteAllText(FFileName, LArray.ToJSON, TEncoding.UTF8);
  finally
    LArray.Free;
  end;
end;

procedure TRadIATerminalHistory.TrimToLimit;
begin
  while FEntries.Count > FMaxEntries do
    FEntries.Delete(0);
end;

end.
