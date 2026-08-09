unit RadIA.Core.ExternalMcp;

interface

uses
  System.Generics.Collections;

type
  TRadIAExternalMcpServerConfig = record
  private
    FArguments: TArray<string>;
    FCommand: string;
    FDisplayName: string;
    FEnabled: Boolean;
    FId: string;
    FTimeoutMs: Integer;
    FWorkingDirectory: string;
  public
    constructor Create(
      const AId: string;
      const ADisplayName: string;
      const ACommand: string;
      const AArguments: TArray<string>;
      const AWorkingDirectory: string;
      const AEnabled: Boolean;
      const ATimeoutMs: Integer
    );
    function Validate(out AError: string): Boolean;
    property Arguments: TArray<string> read FArguments;
    property Command: string read FCommand;
    property DisplayName: string read FDisplayName;
    property Enabled: Boolean read FEnabled;
    property Id: string read FId;
    property TimeoutMs: Integer read FTimeoutMs;
    property WorkingDirectory: string read FWorkingDirectory;
  end;

  TRadIAExternalMcpTool = record
  private
    FDescription: string;
    FInputSchema: string;
    FNamespacedName: string;
    FServerId: string;
    FToolName: string;
  public
    constructor Create(
      const AServerId: string;
      const AToolName: string;
      const ADescription: string;
      const AInputSchema: string
    );
    property Description: string read FDescription;
    property InputSchema: string read FInputSchema;
    property NamespacedName: string read FNamespacedName;
    property ServerId: string read FServerId;
    property ToolName: string read FToolName;
  end;

  IRadIAExternalMcpCatalog = interface
    ['{80B7173E-1C76-482D-BF17-D4D9DF01C074}']
    procedure ClearServer(const AServerId: string);
    function GetTools: TArray<TRadIAExternalMcpTool>;
    function PublishTools(
      const AServer: TRadIAExternalMcpServerConfig;
      const ATools: TArray<TRadIAExternalMcpTool>;
      out AError: string
    ): Boolean;
    function TryResolve(
      const ANamespacedName: string;
      out ATool: TRadIAExternalMcpTool
    ): Boolean;
  end;

  TRadIAExternalMcpCatalog = class(
    TInterfacedObject,
    IRadIAExternalMcpCatalog
  )
  private
    FTools: TDictionary<string, TRadIAExternalMcpTool>;
    class function Normalize(const AValue: string): string; static;
    procedure RemoveServerTools(const AServerId: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ClearServer(const AServerId: string);
    function GetTools: TArray<TRadIAExternalMcpTool>;
    function PublishTools(
      const AServer: TRadIAExternalMcpServerConfig;
      const ATools: TArray<TRadIAExternalMcpTool>;
      out AError: string
    ): Boolean;
    function TryResolve(
      const ANamespacedName: string;
      out ATool: TRadIAExternalMcpTool
    ): Boolean;
  end;

implementation

uses
  System.Character,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

const
  CMinimumTimeoutMs = 1000;
  CMaximumTimeoutMs = 600000;
  CExternalToolPrefix = 'mcp.';

function IsValidServerId(const AValue: string): Boolean;
var
  LChar: Char;
  LIndex: Integer;
begin
  Result := AValue <> '';
  if not Result then
    Exit;
  for LIndex := Low(AValue) to High(AValue) do
  begin
    LChar := AValue[LIndex];
    if not (LChar.IsLetterOrDigit or (LChar = '-') or (LChar = '_')) then
      Exit(False);
  end;
end;

function IsValidToolName(const AValue: string): Boolean;
var
  LChar: Char;
  LIndex: Integer;
begin
  Result := (AValue <> '') and (Length(AValue) <= 128);
  if not Result then
    Exit;
  for LIndex := Low(AValue) to High(AValue) do
  begin
    LChar := AValue[LIndex];
    if not (LChar.IsLetterOrDigit or (LChar = '-') or (LChar = '_')) then
      Exit(False);
  end;
end;

function IsValidInputSchema(const AValue: string): Boolean;
var
  LJson: TJSONValue;
begin
  Result := False;
  if (AValue = '') or (Length(AValue) > 1048576) then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AValue);
  try
    Result := LJson is TJSONObject;
  finally
    LJson.Free;
  end;
end;

{ TRadIAExternalMcpServerConfig }

constructor TRadIAExternalMcpServerConfig.Create(
  const AId: string;
  const ADisplayName: string;
  const ACommand: string;
  const AArguments: TArray<string>;
  const AWorkingDirectory: string;
  const AEnabled: Boolean;
  const ATimeoutMs: Integer
);
begin
  FId := Trim(LowerCase(AId));
  FDisplayName := Trim(ADisplayName);
  FCommand := Trim(ACommand);
  FArguments := AArguments;
  FWorkingDirectory := Trim(AWorkingDirectory);
  FEnabled := AEnabled;
  FTimeoutMs := ATimeoutMs;
end;

function TRadIAExternalMcpServerConfig.Validate(
  out AError: string
): Boolean;
var
  LArgument: string;
begin
  AError := '';
  if not IsValidServerId(Id) then
    AError := 'Server ID must contain only letters, numbers, hyphens, or underscores.'
  else if DisplayName = '' then
    AError := 'Server display name is required.'
  else if Command = '' then
    AError := 'Server command is required.'
  else if (WorkingDirectory <> '') and
          not TPath.IsPathRooted(WorkingDirectory) then
    AError := 'Server working directory must be an absolute path.'
  else if (TimeoutMs < CMinimumTimeoutMs) or
          (TimeoutMs > CMaximumTimeoutMs) then
    AError := 'Server timeout must be between 1000 and 600000 milliseconds.';
  if AError = '' then
    for LArgument in Arguments do
      if LArgument.Contains(#0) or LArgument.Contains(#10) or
         LArgument.Contains(#13) then
      begin
        AError := 'Server arguments cannot contain control line characters.';
        Break;
      end;
  Result := AError = '';
end;

{ TRadIAExternalMcpTool }

constructor TRadIAExternalMcpTool.Create(
  const AServerId: string;
  const AToolName: string;
  const ADescription: string;
  const AInputSchema: string
);
begin
  FServerId := Trim(LowerCase(AServerId));
  FToolName := Trim(AToolName);
  FDescription := Trim(ADescription);
  FInputSchema := Trim(AInputSchema);
  FNamespacedName := CExternalToolPrefix + FServerId + '.' + FToolName;
end;

{ TRadIAExternalMcpCatalog }

constructor TRadIAExternalMcpCatalog.Create;
begin
  inherited Create;
  FTools := TDictionary<string, TRadIAExternalMcpTool>.Create;
end;

destructor TRadIAExternalMcpCatalog.Destroy;
begin
  FTools.Free;
  inherited Destroy;
end;

class function TRadIAExternalMcpCatalog.Normalize(
  const AValue: string
): string;
begin
  Result := LowerCase(Trim(AValue));
end;

procedure TRadIAExternalMcpCatalog.ClearServer(
  const AServerId: string
);
begin
  TMonitor.Enter(FTools);
  try
    RemoveServerTools(AServerId);
  finally
    TMonitor.Exit(FTools);
  end;
end;

procedure TRadIAExternalMcpCatalog.RemoveServerTools(
  const AServerId: string
);
var
  LKey: string;
  LKeys: TArray<string>;
begin
  LKeys := FTools.Keys.ToArray;
  for LKey in LKeys do
    if SameText(FTools[LKey].ServerId, AServerId) then
      FTools.Remove(LKey);
end;

function TRadIAExternalMcpCatalog.GetTools:
  TArray<TRadIAExternalMcpTool>;
begin
  TMonitor.Enter(FTools);
  try
    Result := FTools.Values.ToArray;
  finally
    TMonitor.Exit(FTools);
  end;
end;

function TRadIAExternalMcpCatalog.PublishTools(
  const AServer: TRadIAExternalMcpServerConfig;
  const ATools: TArray<TRadIAExternalMcpTool>;
  out AError: string
): Boolean;
var
  LConfigError: string;
  LKey: string;
  LPublished: TDictionary<string, TRadIAExternalMcpTool>;
  LTool: TRadIAExternalMcpTool;
begin
  AError := '';
  if not AServer.Validate(LConfigError) then
  begin
    AError := LConfigError;
    Exit(False);
  end;
  if not AServer.Enabled then
  begin
    AError := 'Disabled external MCP servers cannot publish tools.';
    Exit(False);
  end;
  LPublished := TDictionary<string, TRadIAExternalMcpTool>.Create;
  try
    for LTool in ATools do
    begin
      if not SameText(LTool.ServerId, AServer.Id) then
      begin
        AError := 'An external tool belongs to a different server.';
        Exit(False);
      end;
      if not IsValidToolName(LTool.ToolName) then
      begin
        AError := 'External tool name must use letters, numbers, hyphens, or underscores.';
        Exit(False);
      end;
      if Length(LTool.Description) > 4096 then
      begin
        AError := 'External tool description exceeds the safe limit.';
        Exit(False);
      end;
      if not IsValidInputSchema(LTool.InputSchema) then
      begin
        AError := 'External tool input schema must be a bounded JSON object.';
        Exit(False);
      end;
      LKey := Normalize(LTool.NamespacedName);
      if LPublished.ContainsKey(LKey) then
      begin
        AError := 'Duplicate external tool name: ' + LTool.NamespacedName;
        Exit(False);
      end;
      LPublished.Add(LKey, LTool);
    end;
    TMonitor.Enter(FTools);
    try
      RemoveServerTools(AServer.Id);
      for LKey in LPublished.Keys do
        FTools.Add(LKey, LPublished[LKey]);
    finally
      TMonitor.Exit(FTools);
    end;
    Result := True;
  finally
    LPublished.Free;
  end;
end;

function TRadIAExternalMcpCatalog.TryResolve(
  const ANamespacedName: string;
  out ATool: TRadIAExternalMcpTool
): Boolean;
begin
  TMonitor.Enter(FTools);
  try
    Result := FTools.TryGetValue(Normalize(ANamespacedName), ATool);
  finally
    TMonitor.Exit(FTools);
  end;
end;

end.
