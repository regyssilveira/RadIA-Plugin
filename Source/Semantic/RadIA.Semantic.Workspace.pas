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
    function ResolveContent(
      const AFile: TRadIASemanticWorkspaceFile
    ): TRadIASemanticWorkspaceFile;
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
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  System.SysUtils,
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
  LContent := TFile.ReadAllText(AFile.FileName, TEncoding.UTF8);
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
