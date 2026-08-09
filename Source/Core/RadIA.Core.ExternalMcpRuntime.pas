unit RadIA.Core.ExternalMcpRuntime;

interface

uses
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpClient,
  RadIA.Core.ExternalMcpContent,
  RadIA.Core.ExternalMcpSecurity,
  RadIA.Core.ExternalMcpSettings,
  RadIA.Core.Interfaces,
  RadIA.Core.Tools,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAExternalMcpRuntimeStatus = record
  private
    FConfiguredServers: Integer;
    FConnectedServers: Integer;
    FEnabledServers: Integer;
    FErrorCount: Integer;
    FGrantedTools: Integer;
    FPromptCount: Integer;
    FResourceCount: Integer;
    FToolCount: Integer;
  public
    property ConfiguredServers: Integer read FConfiguredServers;
    property ConnectedServers: Integer read FConnectedServers;
    property EnabledServers: Integer read FEnabledServers;
    property ErrorCount: Integer read FErrorCount;
    property GrantedTools: Integer read FGrantedTools;
    property PromptCount: Integer read FPromptCount;
    property ResourceCount: Integer read FResourceCount;
    property ToolCount: Integer read FToolCount;
  end;

  IRadIAExternalMcpRuntime = interface
    ['{883D325B-804A-49FD-BB09-C3928B59C22C}']
    function GetGrants: TArray<TRadIAExternalMcpToolGrant>;
    function GetServers: TArray<TRadIAExternalMcpServerConfig>;
    function GetStatus: TRadIAExternalMcpRuntimeStatus;
    function Refresh(out AError: string): Boolean;
    function SaveAndRefresh(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
  end;

  IRadIAExternalMcpClientFactory = interface
    ['{EB1EA9CD-F15C-4689-9795-23C7685E3983}']
    function CreateClient(
      out AClient: IRadIAExternalMcpClient;
      out AToolCatalog: IRadIAExternalMcpCatalog;
      out AContentCatalog: IRadIAExternalMcpContentCatalog
    ): Boolean;
  end;

  TRadIAExternalMcpClientFactory = class(
    TInterfacedObject,
    IRadIAExternalMcpClientFactory
  )
  public
    function CreateClient(
      out AClient: IRadIAExternalMcpClient;
      out AToolCatalog: IRadIAExternalMcpCatalog;
      out AContentCatalog: IRadIAExternalMcpContentCatalog
    ): Boolean;
  end;

  TRadIAExternalMcpWorkspaceRootProvider = class(
    TInterfacedObject,
    IRadIAExternalMcpWorkspaceRootProvider
  )
  private
    FIDEAdapter: IRadIAIDEAdapter;
  public
    constructor Create(const AIDEAdapter: IRadIAIDEAdapter);
    function GetWorkspaceRoot: string;
  end;

  TRadIAExternalMcpRuntime = class(
    TInterfacedObject,
    IRadIAExternalMcpRuntime
  )
  private type
    TRadIASession = record
      Client: IRadIAExternalMcpClient;
      ContentCatalog: IRadIAExternalMcpContentCatalog;
      ServerId: string;
      ToolCatalog: IRadIAExternalMcpCatalog;
    end;
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FClientFactory: IRadIAExternalMcpClientFactory;
    FGrants: TArray<TRadIAExternalMcpToolGrant>;
    FLock: TObject;
    FRegisteredNames: TArray<string>;
    FRegisteredTools: TArray<IRadIATool>;
    FRegistry: IRadIAToolRegistry;
    FRootProvider: IRadIAExternalMcpWorkspaceRootProvider;
    FServers: TArray<TRadIAExternalMcpServerConfig>;
    FSessions: TArray<TRadIASession>;
    FSettings: IRadIAExternalMcpSettingsStore;
    FStatus: TRadIAExternalMcpRuntimeStatus;
    function BuildAdapters(
      const ASessions: TArray<TRadIASession>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out ATools: TArray<IRadIATool>;
      out ANames: TArray<string>;
      out AError: string
    ): Boolean;
    function ConnectServer(
      const AServer: TRadIAExternalMcpServerConfig;
      out ASession: TRadIASession;
      out AError: string
    ): Boolean;
    class procedure DisconnectSessions(
      const ASessions: TArray<TRadIASession>
    ); static;
    function PublishRuntime(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      const ASessions: TArray<TRadIASession>;
      const ATools: TArray<IRadIATool>;
      const ANames: TArray<string>;
      const AStatus: TRadIAExternalMcpRuntimeStatus;
      out AError: string
    ): Boolean;
    procedure RecordRefreshFailure(
      const AConfiguredServers: Integer;
      const AEnabledServers: Integer
    );
  public
    constructor Create(
      const ASettings: IRadIAExternalMcpSettingsStore;
      const ARegistry: IRadIAToolRegistry;
      const ARootProvider: IRadIAExternalMcpWorkspaceRootProvider;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AClientFactory: IRadIAExternalMcpClientFactory
    );
    destructor Destroy; override;
    function GetGrants: TArray<TRadIAExternalMcpToolGrant>;
    function GetServers: TArray<TRadIAExternalMcpServerConfig>;
    function GetStatus: TRadIAExternalMcpRuntimeStatus;
    function Refresh(out AError: string): Boolean;
    function SaveAndRefresh(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.SysUtils,
  RadIA.Core.ExternalMcpTransport;

{ TRadIAExternalMcpClientFactory }

function TRadIAExternalMcpClientFactory.CreateClient(
  out AClient: IRadIAExternalMcpClient;
  out AToolCatalog: IRadIAExternalMcpCatalog;
  out AContentCatalog: IRadIAExternalMcpContentCatalog
): Boolean;
begin
  AToolCatalog := TRadIAExternalMcpCatalog.Create;
  AContentCatalog := TRadIAExternalMcpContentCatalog.Create;
  AClient := TRadIAExternalMcpClient.Create(
    TRadIAExternalMcpStdioTransport.Create,
    AToolCatalog,
    AContentCatalog
  );
  Result := True;
end;

{ TRadIAExternalMcpWorkspaceRootProvider }

constructor TRadIAExternalMcpWorkspaceRootProvider.Create(
  const AIDEAdapter: IRadIAIDEAdapter
);
begin
  inherited Create;
  if not Assigned(AIDEAdapter) then
    raise EArgumentNilException.Create('IDE adapter is required.');
  FIDEAdapter := AIDEAdapter;
end;

function TRadIAExternalMcpWorkspaceRootProvider.GetWorkspaceRoot: string;
begin
  Result := FIDEAdapter.GetActiveProjectFolder;
end;

{ TRadIAExternalMcpRuntime }

constructor TRadIAExternalMcpRuntime.Create(
  const ASettings: IRadIAExternalMcpSettingsStore;
  const ARegistry: IRadIAToolRegistry;
  const ARootProvider: IRadIAExternalMcpWorkspaceRootProvider;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AClientFactory: IRadIAExternalMcpClientFactory
);
begin
  inherited Create;
  if not Assigned(ASettings) then
    raise EArgumentNilException.Create('External MCP settings are required.');
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('Tool registry is required.');
  if not Assigned(ARootProvider) then
    raise EArgumentNilException.Create('Workspace root provider is required.');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('Workspace boundary is required.');
  if not Assigned(AClientFactory) then
    raise EArgumentNilException.Create('External MCP client factory is required.');
  FSettings := ASettings;
  FRegistry := ARegistry;
  FRootProvider := ARootProvider;
  FBoundary := ABoundary;
  FClientFactory := AClientFactory;
  FLock := TObject.Create;
end;

destructor TRadIAExternalMcpRuntime.Destroy;
begin
  TMonitor.Enter(FLock);
  try
    FRegistry.UnregisterTools(FRegisteredNames);
    DisconnectSessions(FSessions);
    FRegisteredTools := nil;
    FRegisteredNames := nil;
    FSessions := nil;
  finally
    TMonitor.Exit(FLock);
  end;
  FLock.Free;
  inherited Destroy;
end;

class procedure TRadIAExternalMcpRuntime.DisconnectSessions(
  const ASessions: TArray<TRadIASession>
);
var
  LSession: TRadIASession;
begin
  for LSession in ASessions do
    if Assigned(LSession.Client) then
      LSession.Client.Disconnect;
end;

function TRadIAExternalMcpRuntime.ConnectServer(
  const AServer: TRadIAExternalMcpServerConfig;
  out ASession: TRadIASession;
  out AError: string
): Boolean;
var
  LDiscovery: IRadIAExternalMcpDiscoveryClient;
begin
  ASession := Default(TRadIASession);
  AError := '';
  if not FClientFactory.CreateClient(
    ASession.Client,
    ASession.ToolCatalog,
    ASession.ContentCatalog
  ) then
  begin
    AError := 'Unable to create the external MCP client.';
    Exit(False);
  end;
  ASession.ServerId := AServer.Id;
  Result := ASession.Client.Connect(AServer, AError) and
    ASession.Client.DiscoverTools(AError);
  if Result and Supports(
    ASession.Client,
    IRadIAExternalMcpDiscoveryClient,
    LDiscovery
  ) then
  begin
    LDiscovery.DiscoverResources(AError);
    LDiscovery.DiscoverPrompts(AError);
    AError := '';
  end;
  if not Result then
    ASession.Client.Disconnect;
end;

procedure TRadIAExternalMcpRuntime.RecordRefreshFailure(
  const AConfiguredServers: Integer;
  const AEnabledServers: Integer
);
begin
  TMonitor.Enter(FLock);
  try
    FStatus.FConfiguredServers := AConfiguredServers;
    FStatus.FEnabledServers := AEnabledServers;
    FStatus.FErrorCount := 1;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpRuntime.BuildAdapters(
  const ASessions: TArray<TRadIASession>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out ATools: TArray<IRadIATool>;
  out ANames: TArray<string>;
  out AError: string
): Boolean;
var
  LGrant: TRadIAExternalMcpToolGrant;
  LGrantMap: TDictionary<string, TRadIAExternalMcpToolGrant>;
  LIndex: Integer;
  LSession: TRadIASession;
  LTool: TRadIAExternalMcpTool;
  LToolList: TList<IRadIATool>;
begin
  ATools := nil;
  ANames := nil;
  AError := '';
  LGrantMap := TDictionary<string, TRadIAExternalMcpToolGrant>.Create(
    TIStringComparer.Ordinal
  );
  LToolList := TList<IRadIATool>.Create;
  try
    for LGrant in AGrants do
      LGrantMap.Add(LGrant.NamespacedName, LGrant);
    for LSession in ASessions do
      for LTool in LSession.ToolCatalog.GetTools do
        if LGrantMap.TryGetValue(LTool.NamespacedName, LGrant) then
          LToolList.Add(
            TRadIAExternalMcpToolAdapter.Create(
              LSession.Client,
              LTool,
              LGrant,
              FRootProvider,
              FBoundary
            )
          );
    ATools := LToolList.ToArray;
    SetLength(ANames, Length(ATools));
    for LIndex := 0 to High(ATools) do
      ANames[LIndex] := ATools[LIndex].Descriptor.Name;
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
  LToolList.Free;
  LGrantMap.Free;
end;

function TRadIAExternalMcpRuntime.PublishRuntime(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  const ASessions: TArray<TRadIASession>;
  const ATools: TArray<IRadIATool>;
  const ANames: TArray<string>;
  const AStatus: TRadIAExternalMcpRuntimeStatus;
  out AError: string
): Boolean;
var
  LOldNames: TArray<string>;
  LOldSessions: TArray<TRadIASession>;
  LOldTools: TArray<IRadIATool>;
begin
  AError := '';
  TMonitor.Enter(FLock);
  try
    LOldNames := FRegisteredNames;
    LOldSessions := FSessions;
    LOldTools := FRegisteredTools;
    FRegistry.UnregisterTools(LOldNames);
    try
      FRegistry.RegisterTools(ATools);
    except
      on E: Exception do
      begin
        FRegistry.RegisterTools(LOldTools);
        AError := E.Message;
        Exit(False);
      end;
    end;
    FServers := Copy(AServers);
    FGrants := Copy(AGrants);
    FSessions := Copy(ASessions);
    FRegisteredTools := Copy(ATools);
    FRegisteredNames := Copy(ANames);
    FStatus := AStatus;
  finally
    TMonitor.Exit(FLock);
  end;
  DisconnectSessions(LOldSessions);
  Result := True;
end;

function TRadIAExternalMcpRuntime.Refresh(out AError: string): Boolean;
var
  LAdapters: TArray<IRadIATool>;
  LError: string;
  LGrants: TArray<TRadIAExternalMcpToolGrant>;
  LNames: TArray<string>;
  LPrompts: TArray<TRadIAExternalMcpPrompt>;
  LPreviousStatus: TRadIAExternalMcpRuntimeStatus;
  LResources: TArray<TRadIAExternalMcpResource>;
  LServer: TRadIAExternalMcpServerConfig;
  LServers: TArray<TRadIAExternalMcpServerConfig>;
  LSession: TRadIASession;
  LSessions: TList<TRadIASession>;
  LStatus: TRadIAExternalMcpRuntimeStatus;
begin
  AError := '';
  if not FSettings.Load(LServers, LGrants, AError) then
  begin
    LPreviousStatus := GetStatus;
    RecordRefreshFailure(
      LPreviousStatus.ConfiguredServers,
      LPreviousStatus.EnabledServers
    );
    Exit(False);
  end;
  LStatus := Default(TRadIAExternalMcpRuntimeStatus);
  LStatus.FConfiguredServers := Length(LServers);
  LStatus.FGrantedTools := Length(LGrants);
  LSessions := TList<TRadIASession>.Create;
  try
    for LServer in LServers do
      if LServer.Enabled then
      begin
        Inc(LStatus.FEnabledServers);
        if ConnectServer(LServer, LSession, LError) then
        begin
          LSessions.Add(LSession);
          Inc(LStatus.FConnectedServers);
          Inc(LStatus.FToolCount, Length(LSession.ToolCatalog.GetTools));
          LResources := LSession.ContentCatalog.GetResources;
          LPrompts := LSession.ContentCatalog.GetPrompts;
          Inc(LStatus.FResourceCount, Length(LResources));
          Inc(LStatus.FPromptCount, Length(LPrompts));
        end
        else
        begin
          RecordRefreshFailure(
            LStatus.FConfiguredServers,
            LStatus.FEnabledServers
          );
          DisconnectSessions(LSessions.ToArray);
          AError := 'An enabled external MCP server requires attention.';
          Exit(False);
        end;
      end;
    if not BuildAdapters(
      LSessions.ToArray,
      LGrants,
      LAdapters,
      LNames,
      AError
    ) then
    begin
      DisconnectSessions(LSessions.ToArray);
      RecordRefreshFailure(
        LStatus.FConfiguredServers,
        LStatus.FEnabledServers
      );
      Exit(False);
    end;
    Result := PublishRuntime(
      LServers,
      LGrants,
      LSessions.ToArray,
      LAdapters,
      LNames,
      LStatus,
      AError
    );
    if not Result then
    begin
      DisconnectSessions(LSessions.ToArray);
      RecordRefreshFailure(
        LStatus.FConfiguredServers,
        LStatus.FEnabledServers
      );
    end;
  finally
    LSessions.Free;
  end;
end;

function TRadIAExternalMcpRuntime.SaveAndRefresh(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
begin
  Result := FSettings.Save(AServers, AGrants, AError) and Refresh(AError);
end;

function TRadIAExternalMcpRuntime.GetServers:
  TArray<TRadIAExternalMcpServerConfig>;
begin
  TMonitor.Enter(FLock);
  try
    Result := Copy(FServers);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpRuntime.GetGrants:
  TArray<TRadIAExternalMcpToolGrant>;
begin
  TMonitor.Enter(FLock);
  try
    Result := Copy(FGrants);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpRuntime.GetStatus:
  TRadIAExternalMcpRuntimeStatus;
begin
  TMonitor.Enter(FLock);
  try
    Result := FStatus;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
