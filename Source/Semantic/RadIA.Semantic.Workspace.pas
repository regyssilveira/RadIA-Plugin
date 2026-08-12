unit RadIA.Semantic.Workspace;

interface

uses
  System.Generics.Collections,
  RadIA.Semantic.Index;

type
  IRadIASemanticRequestClient = interface
    ['{5EC80CF5-8B45-485B-99F5-C30546D950CA}']
    function GetRestartCount: Integer;
    function Request(
      const AMethod: string;
      const AParameters: string;
      out AResponse: string;
      out AError: string
    ): Boolean;
    property RestartCount: Integer read GetRestartCount;
  end;

  TRadIASemanticWorkspaceFile = record
  private
    FContent: string;
    FFileName: string;
    FFingerprint: string;
    FScope: TRadIASemanticUnitScope;
    FUnitKey: string;
  public
    constructor Create(
      const AUnitKey: string;
      const AFileName: string;
      const AScope: TRadIASemanticUnitScope;
      const AFingerprint: string;
      const AContent: string
    );
    property Content: string read FContent;
    property FileName: string read FFileName;
    property Fingerprint: string read FFingerprint;
    property Scope: TRadIASemanticUnitScope read FScope;
    property UnitKey: string read FUnitKey;
  end;

  IRadIASemanticWorkspaceSynchronizer = interface
    ['{86A52B1D-3E7B-4FE8-9678-5ECFC72D20B1}']
    function Synchronize(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      const ADefines: TArray<string>;
      out AError: string
    ): Boolean;
    procedure Reset;
  end;

  TRadIASemanticWorkspaceSynchronizer = class(
    TInterfacedObject,
    IRadIASemanticWorkspaceSynchronizer
  )
  private
    FClient: IRadIASemanticRequestClient;
    FFingerprints: TDictionary<string, string>;
    FLastRestartCount: Integer;
    FNextRevision: Int64;
    function BuildIndexParameters(
      const AFile: TRadIASemanticWorkspaceFile;
      const ADefines: TArray<string>;
      const ARevision: Int64
    ): string;
    function IndexChangedFiles(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      const ADefines: TArray<string>;
      out ARestarted: Boolean;
      out AError: string
    ): Boolean;
    function RemoveMissingFiles(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      out AError: string
    ): Boolean;
  public
    constructor Create(const AClient: IRadIASemanticRequestClient);
    destructor Destroy; override;
    procedure Reset;
    function Synchronize(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      const ADefines: TArray<string>;
      out AError: string
    ): Boolean;
  end;

implementation

uses
  System.JSON,
  System.SysUtils;

function ScopeName(const AScope: TRadIASemanticUnitScope): string;
begin
  case AScope of
    susProject: Result := 'project';
    susGroup: Result := 'group';
    susRTL: Result := 'rtl';
    susVCL: Result := 'vcl';
  else
    Result := 'project';
  end;
end;

{ TRadIASemanticWorkspaceFile }

constructor TRadIASemanticWorkspaceFile.Create(
  const AUnitKey: string;
  const AFileName: string;
  const AScope: TRadIASemanticUnitScope;
  const AFingerprint: string;
  const AContent: string
);
begin
  FUnitKey := AUnitKey;
  FFileName := AFileName;
  FScope := AScope;
  FFingerprint := AFingerprint;
  FContent := AContent;
end;

{ TRadIASemanticWorkspaceSynchronizer }

constructor TRadIASemanticWorkspaceSynchronizer.Create(
  const AClient: IRadIASemanticRequestClient
);
begin
  inherited Create;
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('AClient');
  FClient := AClient;
  FFingerprints := TDictionary<string, string>.Create;
  FLastRestartCount := FClient.RestartCount;
end;

destructor TRadIASemanticWorkspaceSynchronizer.Destroy;
begin
  FFingerprints.Free;
  inherited Destroy;
end;

function TRadIASemanticWorkspaceSynchronizer.BuildIndexParameters(
  const AFile: TRadIASemanticWorkspaceFile;
  const ADefines: TArray<string>;
  const ARevision: Int64
): string;
var
  LDefine: string;
  LDefines: TJSONArray;
  LObject: TJSONObject;
begin
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('unitKey', AFile.UnitKey);
    LObject.AddPair('fileName', AFile.FileName);
    LObject.AddPair('scope', ScopeName(AFile.Scope));
    LObject.AddPair('revision', TJSONNumber.Create(ARevision));
    LObject.AddPair('source', AFile.Content);
    LDefines := TJSONArray.Create;
    for LDefine in ADefines do
      LDefines.Add(LDefine);
    LObject.AddPair('defines', LDefines);
    Result := LObject.ToJSON;
  finally
    LObject.Free;
  end;
end;

function TRadIASemanticWorkspaceSynchronizer.IndexChangedFiles(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  const ADefines: TArray<string>;
  out ARestarted: Boolean;
  out AError: string
): Boolean;
var
  LFile: TRadIASemanticWorkspaceFile;
  LFingerprint: string;
  LRestartCount: Integer;
  LResponse: string;
begin
  Result := False;
  ARestarted := False;
  for LFile in AFiles do
  begin
    if FFingerprints.TryGetValue(LFile.UnitKey, LFingerprint) and
      SameText(LFingerprint, LFile.Fingerprint) then
      Continue;
    Inc(FNextRevision);
    LRestartCount := FClient.RestartCount;
    if not FClient.Request(
      'indexUnit',
      BuildIndexParameters(LFile, ADefines, FNextRevision),
      LResponse,
      AError
    ) then
      Exit;
    FFingerprints.AddOrSetValue(LFile.UnitKey, LFile.Fingerprint);
    if FClient.RestartCount <> LRestartCount then
      ARestarted := True;
  end;
  Result := True;
end;

function TRadIASemanticWorkspaceSynchronizer.RemoveMissingFiles(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  out AError: string
): Boolean;
var
  LCurrent: TDictionary<string, Boolean>;
  LFile: TRadIASemanticWorkspaceFile;
  LKey: string;
  LKnownKeys: TArray<string>;
  LParameters: TJSONObject;
  LResponse: string;
begin
  Result := False;
  LCurrent := TDictionary<string, Boolean>.Create;
  try
    for LFile in AFiles do
      LCurrent.AddOrSetValue(LFile.UnitKey, True);
    LKnownKeys := FFingerprints.Keys.ToArray;
    for LKey in LKnownKeys do
    begin
      if LCurrent.ContainsKey(LKey) then
        Continue;
      LParameters := TJSONObject.Create;
      try
        LParameters.AddPair('unitKey', LKey);
        if not FClient.Request(
          'removeUnit',
          LParameters.ToJSON,
          LResponse,
          AError
        ) then
          Exit;
      finally
        LParameters.Free;
      end;
      FFingerprints.Remove(LKey);
    end;
    Result := True;
  finally
    LCurrent.Free;
  end;
end;

procedure TRadIASemanticWorkspaceSynchronizer.Reset;
begin
  FFingerprints.Clear;
  FLastRestartCount := FClient.RestartCount;
end;

function TRadIASemanticWorkspaceSynchronizer.Synchronize(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  const ADefines: TArray<string>;
  out AError: string
): Boolean;
var
  LRestarted: Boolean;
begin
  AError := '';
  if FClient.RestartCount <> FLastRestartCount then
    Reset;
  if not IndexChangedFiles(AFiles, ADefines, LRestarted, AError) then
    Exit(False);
  if LRestarted then
  begin
    Reset;
    if not IndexChangedFiles(AFiles, ADefines, LRestarted, AError) then
      Exit(False);
    if LRestarted then
    begin
      AError := 'The semantic engine restarted repeatedly during workspace synchronization.';
      Exit(False);
    end;
  end;
  Result := RemoveMissingFiles(AFiles, AError);
  if Result then
    FLastRestartCount := FClient.RestartCount;
end;

end.
