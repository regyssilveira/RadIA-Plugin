unit RadIA.Core.AgentResultStore;

interface

type
  TRadIAAgentResultStoreOptions = record
  private
    FMaximumArtifactCharacters: Integer;
    FMaximumArtifactsPerSession: Integer;
    FMaximumSessionCharacters: Int64;
    FRetentionDays: Integer;
  public
    constructor Create(
      const AMaximumArtifactCharacters: Integer;
      const AMaximumArtifactsPerSession: Integer;
      const AMaximumSessionCharacters: Int64;
      const ARetentionDays: Integer
    );
    class function Defaults: TRadIAAgentResultStoreOptions; static;
    property MaximumArtifactCharacters: Integer read FMaximumArtifactCharacters;
    property MaximumArtifactsPerSession: Integer read FMaximumArtifactsPerSession;
    property MaximumSessionCharacters: Int64 read FMaximumSessionCharacters;
    property RetentionDays: Integer read FRetentionDays;
  end;

  TRadIAAgentResultArtifact = record
  private
    FArtifactId: string;
    FCharacterCount: Integer;
    FHash: string;
    FStepIndex: Integer;
  public
    constructor Create(
      const AArtifactId: string;
      const AHash: string;
      const ACharacterCount: Integer;
      const AStepIndex: Integer
    );
    property ArtifactId: string read FArtifactId;
    property CharacterCount: Integer read FCharacterCount;
    property Hash: string read FHash;
    property StepIndex: Integer read FStepIndex;
  end;

  IRadIAAgentResultStore = interface
    ['{B8EF6EA0-7EA8-4E3E-AC75-6B48F561914A}']
    function Store(
      const ASessionId: string;
      const AStepIndex: Integer;
      const AContent: string
    ): TRadIAAgentResultArtifact;
    function TryGetSummary(
      const ASessionId: string;
      const AArtifactId: string;
      out AArtifact: TRadIAAgentResultArtifact
    ): Boolean;
    function TryReadRange(
      const ASessionId: string;
      const AArtifactId: string;
      const AStartCharacter: Integer;
      const AMaxCharacters: Integer;
      out AContent: string;
      out ATotalCharacters: Integer
    ): Boolean;
    function CleanupExpired: Integer;
  end;

  TRadIAAgentFileResultStore = class(
    TInterfacedObject,
    IRadIAAgentResultStore
  )
  private
    FDirectory: string;
    FLock: TObject;
    FOptions: TRadIAAgentResultStoreOptions;
    function ArtifactPath(
      const ASessionId: string;
      const AArtifactId: string
    ): string;
    function BuildArtifactId(
      const AStepIndex: Integer;
      const AHash: string
    ): string;
    procedure ValidateArtifactId(const AArtifactId: string);
    procedure ValidateOptions;
    procedure ValidateSessionId(const ASessionId: string);
    procedure ValidateSessionQuota(
      const ASessionDirectory: string;
      const AArtifactPath: string;
      const AContentCharacters: Integer
    );
  public
    constructor Create(const ADirectory: string); overload;
    constructor Create(
      const ADirectory: string;
      const AOptions: TRadIAAgentResultStoreOptions
    ); overload;
    destructor Destroy; override;
    function Store(
      const ASessionId: string;
      const AStepIndex: Integer;
      const AContent: string
    ): TRadIAAgentResultArtifact;
    function TryGetSummary(
      const ASessionId: string;
      const AArtifactId: string;
      out AArtifact: TRadIAAgentResultArtifact
    ): Boolean;
    function TryReadRange(
      const ASessionId: string;
      const AArtifactId: string;
      const AStartCharacter: Integer;
      const AMaxCharacters: Integer;
      out AContent: string;
      out ATotalCharacters: Integer
    ): Boolean;
    function CleanupExpired: Integer;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.Math,
  System.SysUtils;

const
  CMaximumStoredResultCharacters = 8 * 1024 * 1024;
  CMaximumArtifactsPerSession = 100;
  CMaximumSessionCharacters = 64 * 1024 * 1024;
  CMaximumReadRangeCharacters = 64 * 1024;
  CResultRetentionDays = 14;

{ TRadIAAgentResultStoreOptions }

constructor TRadIAAgentResultStoreOptions.Create(
  const AMaximumArtifactCharacters: Integer;
  const AMaximumArtifactsPerSession: Integer;
  const AMaximumSessionCharacters: Int64;
  const ARetentionDays: Integer
);
begin
  FMaximumArtifactCharacters := AMaximumArtifactCharacters;
  FMaximumArtifactsPerSession := AMaximumArtifactsPerSession;
  FMaximumSessionCharacters := AMaximumSessionCharacters;
  FRetentionDays := ARetentionDays;
end;

class function TRadIAAgentResultStoreOptions.Defaults:
  TRadIAAgentResultStoreOptions;
begin
  Result := TRadIAAgentResultStoreOptions.Create(
    CMaximumStoredResultCharacters,
    CMaximumArtifactsPerSession,
    CMaximumSessionCharacters,
    CResultRetentionDays
  );
end;

{ TRadIAAgentResultArtifact }

constructor TRadIAAgentResultArtifact.Create(
  const AArtifactId: string;
  const AHash: string;
  const ACharacterCount: Integer;
  const AStepIndex: Integer
);
begin
  FArtifactId := AArtifactId;
  FHash := AHash;
  FCharacterCount := ACharacterCount;
  FStepIndex := AStepIndex;
end;

{ TRadIAAgentFileResultStore }

constructor TRadIAAgentFileResultStore.Create(const ADirectory: string);
begin
  Create(ADirectory, TRadIAAgentResultStoreOptions.Defaults);
end;

constructor TRadIAAgentFileResultStore.Create(
  const ADirectory: string;
  const AOptions: TRadIAAgentResultStoreOptions
);
begin
  inherited Create;
  if Trim(ADirectory) = '' then
    raise EArgumentException.Create('Result store directory is required.');
  FDirectory := TPath.GetFullPath(ADirectory);
  FOptions := AOptions;
  ValidateOptions;
  FLock := TObject.Create;
end;

destructor TRadIAAgentFileResultStore.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TRadIAAgentFileResultStore.ArtifactPath(
  const ASessionId: string;
  const AArtifactId: string
): string;
begin
  ValidateSessionId(ASessionId);
  ValidateArtifactId(AArtifactId);
  Result := TPath.Combine(
    TPath.Combine(FDirectory, ASessionId),
    AArtifactId + '.json'
  );
end;

function TRadIAAgentFileResultStore.BuildArtifactId(
  const AStepIndex: Integer;
  const AHash: string
): string;
begin
  Result := Format('step-%d-%s', [AStepIndex, LowerCase(Copy(AHash, 1, 24))]);
end;

function TRadIAAgentFileResultStore.Store(
  const ASessionId: string;
  const AStepIndex: Integer;
  const AContent: string
): TRadIAAgentResultArtifact;
var
  LArtifactId: string;
  LDirectory: string;
  LHash: string;
  LPath: string;
  LTemporaryPath: string;
begin
  ValidateSessionId(ASessionId);
  if AStepIndex < 1 then
    raise EArgumentOutOfRangeException.Create('AStepIndex');
  if Length(AContent) > FOptions.MaximumArtifactCharacters then
    raise EArgumentOutOfRangeException.Create('AContent');
  LHash := THashSHA2.GetHashString(AContent, THashSHA2.TSHA2Version.SHA256);
  LArtifactId := BuildArtifactId(AStepIndex, LHash);
  LPath := ArtifactPath(ASessionId, LArtifactId);
  LDirectory := ExtractFileDir(LPath);
  TMonitor.Enter(FLock);
  try
    TDirectory.CreateDirectory(LDirectory);
    if not TFile.Exists(LPath) then
    begin
      ValidateSessionQuota(LDirectory, LPath, Length(AContent));
      LTemporaryPath := LPath + '.' + TGUID.NewGuid.ToString + '.tmp';
      TFile.WriteAllText(LTemporaryPath, AContent, TEncoding.UTF8);
      try
        TFile.Move(LTemporaryPath, LPath);
      finally
        if TFile.Exists(LTemporaryPath) then
          TFile.Delete(LTemporaryPath);
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := TRadIAAgentResultArtifact.Create(
    LArtifactId,
    LowerCase(LHash),
    Length(AContent),
    AStepIndex
  );
end;

function TRadIAAgentFileResultStore.CleanupExpired: Integer;
var
  LCutoff: TDateTime;
  LFile: string;
  LSessionDirectory: string;
begin
  Result := 0;
  if not TDirectory.Exists(FDirectory) then
    Exit;
  LCutoff := Now - FOptions.RetentionDays;
  TMonitor.Enter(FLock);
  try
    for LSessionDirectory in TDirectory.GetDirectories(FDirectory) do
    begin
      for LFile in TDirectory.GetFiles(LSessionDirectory, '*.json') do
        if TFile.GetLastWriteTime(LFile) < LCutoff then
        begin
          TFile.Delete(LFile);
          Inc(Result);
        end;
      if Length(TDirectory.GetFiles(LSessionDirectory)) = 0 then
        TDirectory.Delete(LSessionDirectory, False);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAAgentFileResultStore.TryGetSummary(
  const ASessionId: string;
  const AArtifactId: string;
  out AArtifact: TRadIAAgentResultArtifact
): Boolean;
var
  LContent: string;
  LHash: string;
  LPath: string;
  LSeparator: Integer;
  LStepText: string;
begin
  AArtifact := Default(TRadIAAgentResultArtifact);
  LPath := ArtifactPath(ASessionId, AArtifactId);
  if not TFile.Exists(LPath) then
    Exit(False);
  LContent := TFile.ReadAllText(LPath, TEncoding.UTF8);
  LHash := LowerCase(
    THashSHA2.GetHashString(LContent, THashSHA2.TSHA2Version.SHA256)
  );
  LStepText := Copy(AArtifactId, 6, MaxInt);
  LSeparator := Pos('-', LStepText);
  if LSeparator <= 1 then
    Exit(False);
  LStepText := Copy(LStepText, 1, LSeparator - 1);
  AArtifact := TRadIAAgentResultArtifact.Create(
    AArtifactId,
    LHash,
    Length(LContent),
    StrToIntDef(LStepText, 0)
  );
  Result := AArtifact.StepIndex > 0;
end;

function TRadIAAgentFileResultStore.TryReadRange(
  const ASessionId: string;
  const AArtifactId: string;
  const AStartCharacter: Integer;
  const AMaxCharacters: Integer;
  out AContent: string;
  out ATotalCharacters: Integer
): Boolean;
var
  LContent: string;
  LLength: Integer;
  LPath: string;
  LStart: Integer;
begin
  AContent := '';
  ATotalCharacters := 0;
  if AStartCharacter < 0 then
    raise EArgumentOutOfRangeException.Create('AStartCharacter');
  if (AMaxCharacters < 1) or
    (AMaxCharacters > CMaximumReadRangeCharacters) then
    raise EArgumentOutOfRangeException.Create('AMaxCharacters');
  LPath := ArtifactPath(ASessionId, AArtifactId);
  if not TFile.Exists(LPath) then
    Exit(False);
  LContent := TFile.ReadAllText(LPath, TEncoding.UTF8);
  ATotalCharacters := Length(LContent);
  if AStartCharacter >= ATotalCharacters then
    Exit(True);
  LStart := AStartCharacter + 1;
  LLength := Min(AMaxCharacters, ATotalCharacters - AStartCharacter);
  if (LStart > 1) and (LStart <= Length(LContent)) and
    (Ord(LContent[LStart]) >= $DC00) and
    (Ord(LContent[LStart]) <= $DFFF) then
    Inc(LStart);
  if (LLength > 0) and (LStart + LLength - 1 < Length(LContent)) and
    (Ord(LContent[LStart + LLength - 1]) >= $D800) and
    (Ord(LContent[LStart + LLength - 1]) <= $DBFF) then
    Dec(LLength);
  AContent := Copy(LContent, LStart, Max(0, LLength));
  Result := True;
end;

procedure TRadIAAgentFileResultStore.ValidateArtifactId(
  const AArtifactId: string
);
var
  LCharacter: Char;
begin
  if (Length(AArtifactId) < 30) or (Length(AArtifactId) > 96) then
    raise EArgumentException.Create('Invalid result artifact id.');
  for LCharacter in AArtifactId do
    if not CharInSet(LCharacter, ['a'..'z', '0'..'9', '-']) then
      raise EArgumentException.Create('Invalid result artifact id.');
end;

procedure TRadIAAgentFileResultStore.ValidateOptions;
begin
  if (FOptions.MaximumArtifactCharacters < 1) or
    (FOptions.MaximumArtifactsPerSession < 1) or
    (FOptions.MaximumSessionCharacters < 1) or
    (FOptions.RetentionDays < 1) then
    raise EArgumentOutOfRangeException.Create('AOptions');
  if FOptions.MaximumArtifactCharacters >
    FOptions.MaximumSessionCharacters then
    raise EArgumentException.Create(
      'Artifact limit cannot exceed the session limit.'
    );
end;

procedure TRadIAAgentFileResultStore.ValidateSessionQuota(
  const ASessionDirectory: string;
  const AArtifactPath: string;
  const AContentCharacters: Integer
);
var
  LCharacters: Int64;
  LFile: string;
  LFiles: TArray<string>;
begin
  LFiles := TDirectory.GetFiles(ASessionDirectory, '*.json');
  if Length(LFiles) >= FOptions.MaximumArtifactsPerSession then
    raise EInvalidOpException.Create('Result artifact session quota exceeded.');
  LCharacters := 0;
  for LFile in LFiles do
    if not SameText(LFile, AArtifactPath) then
      Inc(
        LCharacters,
        Length(TFile.ReadAllText(LFile, TEncoding.UTF8))
      );
  if LCharacters + AContentCharacters > FOptions.MaximumSessionCharacters then
    raise EInvalidOpException.Create('Result character session quota exceeded.');
end;

procedure TRadIAAgentFileResultStore.ValidateSessionId(
  const ASessionId: string
);
var
  LCharacter: Char;
begin
  if (Length(ASessionId) < 1) or (Length(ASessionId) > 128) then
    raise EArgumentException.Create('Invalid result session id.');
  for LCharacter in ASessionId do
    if not CharInSet(
      LCharacter,
      ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']
    ) then
      raise EArgumentException.Create('Invalid result session id.');
end;

end.
