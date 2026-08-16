unit RadIA.Semantic.Workspace;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
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

  IRadIASemanticCancelableRequestClient = interface
    ['{6513AC4B-8E3D-40D6-A55A-8F930C2DDF53}']
    function RequestCancelable(
      const AMethod: string;
      const AParameters: string;
      const AIsCancelled: TFunc<Boolean>;
      out AResponse: string;
      out AError: string
    ): Boolean;
  end;

  IRadIASemanticEngineLifecycle = interface
    ['{AF670F4C-F678-45A8-A4E8-37C663D133A0}']
    procedure Stop;
  end;

  IRadIASemanticEngineDiagnostics = interface
    ['{5AB6B95D-5FF8-4611-A90E-14D450497CC8}']
    function GetDiagnosticsJson: string;
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

  IRadIASemanticWorkspaceSource = interface
    ['{C25AC7AC-CBB8-4ED1-B36F-5E73C495033E}']
    function Capture(
      out AFiles: TArray<TRadIASemanticWorkspaceFile>;
      out ADefines: TArray<string>;
      out AError: string
    ): Boolean;
  end;

  IRadIASemanticWorkspaceCoordinator = interface
    ['{8AA0F069-55A2-4BA1-B478-BB25DFEB2BD6}']
    function IsRunning: Boolean;
    procedure MarkDirty;
    procedure Poll;
    procedure Stop;
  end;

  TRadIASemanticWorkspaceSynchronizer = class(
    TInterfacedObject,
    IRadIASemanticWorkspaceSynchronizer
  )
  private
    FCacheFile: string;
    FCacheLoaded: Boolean;
    FClient: IRadIASemanticRequestClient;
    FFingerprints: TDictionary<string, string>;
    FLastRestartCount: Integer;
    FNextRevision: Int64;
    FProfileKey: string;
    function BuildCacheFile(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>
    ): string;
    function BuildProfileKey(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      const ADefines: TArray<string>
    ): string;
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
    function PrepareCache(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      const ADefines: TArray<string>;
      out AError: string
    ): Boolean;
    function PersistCache(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      const ADefines: TArray<string>;
      out AError: string
    ): Boolean;
    function RestoreCache(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      out AError: string
    ): Boolean;
    function ResolveContent(
      const AFile: TRadIASemanticWorkspaceFile
    ): TRadIASemanticWorkspaceFile;
    function SaveCache(out AError: string): Boolean;
    function SynchronizeIndexState(
      const AFiles: TArray<TRadIASemanticWorkspaceFile>;
      const ADefines: TArray<string>;
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

  TRadIASemanticWorkspaceCoordinator = class(
    TInterfacedObject,
    IRadIASemanticWorkspaceCoordinator
  )
  private
    FDefines: TArray<string>;
    FDirty: Boolean;
    FFiles: TArray<TRadIASemanticWorkspaceFile>;
    FRunning: Boolean;
    FSource: IRadIASemanticWorkspaceSource;
    FStopped: Boolean;
    FSynchronizer: IRadIASemanticWorkspaceSynchronizer;
    procedure ExecuteSync;
  public
    constructor Create(
      const ASource: IRadIASemanticWorkspaceSource;
      const ASynchronizer: IRadIASemanticWorkspaceSynchronizer
    );
    function IsRunning: Boolean;
    procedure MarkDirty;
    procedure Poll;
    procedure Stop;
  end;

implementation

uses
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  RadIA.Core.Types;

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

function ReadSemanticFileContent(const AFileName: string): string;
var
  LBytes: TBytes;
  LHeader: array[0..3] of Byte;
  LInput: TFileStream;
  LOutput: TMemoryStream;
begin
  if not SameText(ExtractFileExt(AFileName), '.dfm') then
    Exit(TFile.ReadAllText(AFileName, TEncoding.UTF8));
  LInput := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if LInput.Size < Length(LHeader) then
      Exit(TFile.ReadAllText(AFileName, TEncoding.UTF8));
    LInput.ReadBuffer(LHeader, Length(LHeader));
    LInput.Position := 0;
    if not ((LHeader[0] = $54) and (LHeader[1] = $50) and
      (LHeader[2] = $46) and (LHeader[3] = $30)) then
      Exit(TFile.ReadAllText(AFileName, TEncoding.UTF8));
    LOutput := TMemoryStream.Create;
    try
      ObjectBinaryToText(LInput, LOutput);
      SetLength(LBytes, LOutput.Size);
      LOutput.Position := 0;
      if Length(LBytes) > 0 then
        LOutput.ReadBuffer(LBytes[0], Length(LBytes));
      Result := TEncoding.UTF8.GetString(LBytes);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
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

function TRadIASemanticWorkspaceSynchronizer.BuildCacheFile(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>
): string;
var
  LFile: TRadIASemanticWorkspaceFile;
  LIdentity: string;
  LRoot: string;
begin
  LIdentity := '';
  for LFile in AFiles do
    if LFile.Scope = susProject then
    begin
      LIdentity := LowerCase(
        TPath.GetDirectoryName(TPath.GetFullPath(LFile.FileName))
      );
      Break;
    end;
  if LIdentity = '' then
    for LFile in AFiles do
      if LFile.Scope = susGroup then
      begin
        LIdentity := LowerCase(
          TPath.GetDirectoryName(TPath.GetFullPath(LFile.FileName))
        );
        Break;
      end;
  if LIdentity = '' then
    LIdentity := 'empty-workspace';
  LRoot := GetEnvironmentVariable('APPDATA');
  if LRoot = '' then
    LRoot := TPath.GetTempPath;
  Result := TPath.Combine(
    TPath.Combine(LRoot, 'RadIA\Semantic'),
    THashSHA2.GetHashString(LIdentity) + '.json'
  );
end;

function TRadIASemanticWorkspaceSynchronizer.BuildProfileKey(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  const ADefines: TArray<string>
): string;
var
  LDefine: string;
  LFile: TRadIASemanticWorkspaceFile;
  LProfile: TStringList;
begin
  LProfile := TStringList.Create;
  try
    LProfile.Sorted := True;
    LProfile.Duplicates := dupIgnore;
    LProfile.Add(
      'compiler=' +
      FloatToStr(CompilerVersion, TFormatSettings.Invariant)
    );
    {$IFDEF WIN64}
    LProfile.Add('platform=Win64');
    {$ELSE}
    LProfile.Add('platform=Win32');
    {$ENDIF}
    for LDefine in ADefines do
      LProfile.Add('define=' + UpperCase(LDefine));
    for LFile in AFiles do
      LProfile.Add(
        'file=' + LowerCase(LFile.UnitKey) + ':' + LFile.Fingerprint
      );
    Result := THashSHA2.GetHashString('semantic-profile-v1' + LProfile.Text);
  finally
    LProfile.Free;
  end;
end;

function TRadIASemanticWorkspaceSynchronizer.RestoreCache(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  out AError: string
): Boolean;
var
  LDocument: TJSONObject;
  LFile: TRadIASemanticWorkspaceFile;
  LParameters: TJSONObject;
  LResponse: string;
  LResult: TJSONObject;
begin
  Result := False;
  LParameters := TJSONObject.Create;
  try
    LParameters.AddPair('fileName', FCacheFile);
    LParameters.AddPair('profileKey', FProfileKey);
    if not FClient.Request(
      'loadIndexCache',
      LParameters.ToJSON,
      LResponse,
      AError
    ) then
      Exit;
  finally
    LParameters.Free;
  end;
  FCacheLoaded := True;
  LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    LResult := nil;
    if Assigned(LDocument) then
      LResult := LDocument.GetValue<TJSONObject>('result');
    if not Assigned(LResult) then
    begin
      AError := 'The semantic cache response was invalid.';
      Exit;
    end;
    if not LResult.GetValue<Boolean>('succeeded', False) then
      Exit(True);
    if LResult.GetValue<Integer>('unitCount', 0) > 0 then
      for LFile in AFiles do
        FFingerprints.AddOrSetValue(LFile.UnitKey, LFile.Fingerprint);
    Result := True;
  finally
    LDocument.Free;
  end;
end;

function TRadIASemanticWorkspaceSynchronizer.SaveCache(
  out AError: string
): Boolean;
var
  LDocument: TJSONObject;
  LParameters: TJSONObject;
  LResponse: string;
  LResult: TJSONObject;
begin
  LParameters := TJSONObject.Create;
  try
    LParameters.AddPair('fileName', FCacheFile);
    LParameters.AddPair('profileKey', FProfileKey);
    if not FClient.Request(
      'saveIndexCache',
      LParameters.ToJSON,
      LResponse,
      AError
    ) then
      Exit(False);
  finally
    LParameters.Free;
  end;
  LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    LResult := nil;
    if Assigned(LDocument) then
      LResult := LDocument.GetValue<TJSONObject>('result');
    Result := Assigned(LResult) and
      LResult.GetValue<Boolean>('succeeded', False);
    if not Result then
      AError := 'The semantic cache could not be saved.';
  finally
    LDocument.Free;
  end;
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
  LResolvedFile: TRadIASemanticWorkspaceFile;
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
    LResolvedFile := ResolveContent(LFile);
    LRestartCount := FClient.RestartCount;
    if not FClient.Request(
      'indexUnit',
      BuildIndexParameters(LResolvedFile, ADefines, FNextRevision),
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

function TRadIASemanticWorkspaceSynchronizer.ResolveContent(
  const AFile: TRadIASemanticWorkspaceFile
): TRadIASemanticWorkspaceFile;
var
  LContent: string;
begin
  if (AFile.Content <> '') or not TFile.Exists(AFile.FileName) then
    Exit(AFile);
  LContent := ReadSemanticFileContent(AFile.FileName);
  Result := TRadIASemanticWorkspaceFile.Create(
    AFile.UnitKey,
    AFile.FileName,
    AFile.Scope,
    AFile.Fingerprint,
    LContent
  );
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
  FCacheLoaded := False;
  FLastRestartCount := FClient.RestartCount;
end;

function TRadIASemanticWorkspaceSynchronizer.SynchronizeIndexState(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  const ADefines: TArray<string>;
  out AError: string
): Boolean;
const
  CMaximumAttempts = 3;
var
  LAttempt: Integer;
  LRestartCount: Integer;
  LRestarted: Boolean;
begin
  for LAttempt := 1 to CMaximumAttempts do
  begin
    if LAttempt > 1 then
    begin
      Reset;
      FCacheLoaded := True;
    end;
    if not IndexChangedFiles(AFiles, ADefines, LRestarted, AError) then
      Exit(False);
    if LRestarted then
      Continue;
    LRestartCount := FClient.RestartCount;
    if not RemoveMissingFiles(AFiles, AError) then
      Exit(False);
    if FClient.RestartCount = LRestartCount then
      Exit(True);
  end;
  AError :=
    'The semantic engine restarted repeatedly during workspace synchronization.';
  Result := False;
end;

function TRadIASemanticWorkspaceSynchronizer.PrepareCache(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  const ADefines: TArray<string>;
  out AError: string
): Boolean;
var
  LCacheFile: string;
  LProfileKey: string;
begin
  LCacheFile := BuildCacheFile(AFiles);
  LProfileKey := BuildProfileKey(AFiles, ADefines);
  if not SameText(FCacheFile, LCacheFile) then
  begin
    Reset;
    FCacheFile := LCacheFile;
    FProfileKey := LProfileKey;
  end
  else if not FCacheLoaded and not SameText(FProfileKey, LProfileKey) then
    FProfileKey := LProfileKey
  else if FCacheLoaded then
    FProfileKey := LProfileKey;
  Result := FCacheLoaded or RestoreCache(AFiles, AError);
end;

function TRadIASemanticWorkspaceSynchronizer.PersistCache(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  const ADefines: TArray<string>;
  out AError: string
): Boolean;
var
  LRestartCount: Integer;
begin
  LRestartCount := FClient.RestartCount;
  if not SaveCache(AError) and (FClient.RestartCount = LRestartCount) then
  begin
    AError := '';
    FLastRestartCount := FClient.RestartCount;
    Exit(True);
  end;
  if FClient.RestartCount = LRestartCount then
    Exit(True);
  Reset;
  FCacheLoaded := True;
  if not SynchronizeIndexState(AFiles, ADefines, AError) then
    Exit(False);
  LRestartCount := FClient.RestartCount;
  if not SaveCache(AError) and (FClient.RestartCount = LRestartCount) then
  begin
    AError := '';
    FLastRestartCount := FClient.RestartCount;
    Exit(True);
  end;
  Result := FClient.RestartCount = LRestartCount;
  if not Result then
    AError :=
      'The semantic engine restarted while persisting its recovered cache.';
end;

function TRadIASemanticWorkspaceSynchronizer.Synchronize(
  const AFiles: TArray<TRadIASemanticWorkspaceFile>;
  const ADefines: TArray<string>;
  out AError: string
): Boolean;
begin
  AError := '';
  if FClient.RestartCount <> FLastRestartCount then
    Reset;
  if not PrepareCache(AFiles, ADefines, AError) then
    Exit(False);
  if not SynchronizeIndexState(AFiles, ADefines, AError) then
    Exit(False);
  if not PersistCache(AFiles, ADefines, AError) then
    Exit(False);
  FLastRestartCount := FClient.RestartCount;
  Result := True;
end;

{ TRadIASemanticWorkspaceCoordinator }

constructor TRadIASemanticWorkspaceCoordinator.Create(
  const ASource: IRadIASemanticWorkspaceSource;
  const ASynchronizer: IRadIASemanticWorkspaceSynchronizer
);
begin
  inherited Create;
  if not Assigned(ASource) then
    raise EArgumentNilException.Create('ASource');
  if not Assigned(ASynchronizer) then
    raise EArgumentNilException.Create('ASynchronizer');
  FSource := ASource;
  FSynchronizer := ASynchronizer;
  FDirty := True;
end;

procedure TRadIASemanticWorkspaceCoordinator.ExecuteSync;
var
  LError: string;
begin
  try
    FSynchronizer.Synchronize(FFiles, FDefines, LError);
  finally
    TMonitor.Enter(Self);
    try
      FRunning := False;
    finally
      TMonitor.Exit(Self);
    end;
    TInterlocked.Decrement(GActiveThreadCount);
  end;
end;

function TRadIASemanticWorkspaceCoordinator.IsRunning: Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := FRunning;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIASemanticWorkspaceCoordinator.MarkDirty;
begin
  TMonitor.Enter(Self);
  try
    if not FStopped then
      FDirty := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIASemanticWorkspaceCoordinator.Poll;
var
  LAction: TProc;
  LError: string;
  LKeepAlive: IRadIASemanticWorkspaceCoordinator;
  LThread: TThread;
begin
  TMonitor.Enter(Self);
  try
    if FStopped or FRunning or not FDirty then
      Exit;
    if not FSource.Capture(FFiles, FDefines, LError) then
      Exit;
    FDirty := False;
    FRunning := True;
  finally
    TMonitor.Exit(Self);
  end;
  LKeepAlive := Self;
  LAction :=
    procedure
    begin
      LKeepAlive.IsRunning;
      ExecuteSync;
    end;
  TInterlocked.Increment(GActiveThreadCount);
  try
    LThread := TThread.CreateAnonymousThread(LAction);
    LThread.FreeOnTerminate := True;
    LThread.Start;
  except
    TMonitor.Enter(Self);
    try
      FRunning := False;
      FDirty := True;
    finally
      TMonitor.Exit(Self);
    end;
    TInterlocked.Decrement(GActiveThreadCount);
    raise;
  end;
end;

procedure TRadIASemanticWorkspaceCoordinator.Stop;
begin
  TMonitor.Enter(Self);
  try
    FStopped := True;
    FDirty := False;
  finally
    TMonitor.Exit(Self);
  end;
end;

end.
