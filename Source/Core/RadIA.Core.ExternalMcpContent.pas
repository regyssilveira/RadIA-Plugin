unit RadIA.Core.ExternalMcpContent;

interface

uses
  System.Generics.Collections,
  RadIA.Core.ExternalMcp;

type
  TRadIAExternalMcpResource = record
  private
    FDescription: string;
    FFederatedUri: string;
    FMimeType: string;
    FName: string;
    FServerId: string;
    FUri: string;
  public
    constructor Create(
      const AServerId: string;
      const AUri: string;
      const AName: string;
      const ADescription: string;
      const AMimeType: string
    );
    property Description: string read FDescription;
    property FederatedUri: string read FFederatedUri;
    property MimeType: string read FMimeType;
    property Name: string read FName;
    property ServerId: string read FServerId;
    property Uri: string read FUri;
  end;

  TRadIAExternalMcpPrompt = record
  private
    FArgumentsJson: string;
    FDescription: string;
    FName: string;
    FNamespacedName: string;
    FServerId: string;
  public
    constructor Create(
      const AServerId: string;
      const AName: string;
      const ADescription: string;
      const AArgumentsJson: string
    );
    property ArgumentsJson: string read FArgumentsJson;
    property Description: string read FDescription;
    property Name: string read FName;
    property NamespacedName: string read FNamespacedName;
    property ServerId: string read FServerId;
  end;

  IRadIAExternalMcpContentCatalog = interface
    ['{C3554A5D-C5AA-439F-B07E-8623ACD3F961}']
    procedure ClearServer(const AServerId: string);
    function GetPrompts: TArray<TRadIAExternalMcpPrompt>;
    function GetResources: TArray<TRadIAExternalMcpResource>;
    function PublishPrompts(
      const AServer: TRadIAExternalMcpServerConfig;
      const APrompts: TArray<TRadIAExternalMcpPrompt>;
      out AError: string
    ): Boolean;
    function PublishResources(
      const AServer: TRadIAExternalMcpServerConfig;
      const AResources: TArray<TRadIAExternalMcpResource>;
      out AError: string
    ): Boolean;
  end;

  TRadIAExternalMcpContentCatalog = class(
    TInterfacedObject,
    IRadIAExternalMcpContentCatalog
  )
  private
    FPrompts: TDictionary<string, TRadIAExternalMcpPrompt>;
    FResources: TDictionary<string, TRadIAExternalMcpResource>;
    class function Normalize(const AValue: string): string; static;
    procedure RemoveServer(const AServerId: string);
    class function ValidatePrompt(
      const AServerId: string;
      const APrompt: TRadIAExternalMcpPrompt;
      out AError: string
    ): Boolean; static;
    class function ValidateResource(
      const AServerId: string;
      const AResource: TRadIAExternalMcpResource;
      out AError: string
    ): Boolean; static;
    class function ValidateServer(
      const AServer: TRadIAExternalMcpServerConfig;
      const AContentKind: string;
      out AError: string
    ): Boolean; static;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ClearServer(const AServerId: string);
    function GetPrompts: TArray<TRadIAExternalMcpPrompt>;
    function GetResources: TArray<TRadIAExternalMcpResource>;
    function PublishPrompts(
      const AServer: TRadIAExternalMcpServerConfig;
      const APrompts: TArray<TRadIAExternalMcpPrompt>;
      out AError: string
    ): Boolean;
    function PublishResources(
      const AServer: TRadIAExternalMcpServerConfig;
      const AResources: TArray<TRadIAExternalMcpResource>;
      out AError: string
    ): Boolean;
  end;

implementation

uses
  System.Character,
  System.JSON,
  System.NetEncoding,
  System.SysUtils;

const
  CMaximumDescriptionLength = 4096;
  CMaximumIdentifierLength = 4096;
  CMaximumArgumentsLength = 1024 * 1024;

function IsValidPromptName(const AValue: string): Boolean;
var
  LChar: Char;
begin
  Result := (AValue <> '') and (Length(AValue) <= 128);
  if not Result then
    Exit;
  for LChar in AValue do
    if not (LChar.IsLetterOrDigit or (LChar = '-') or (LChar = '_')) then
      Exit(False);
end;

function IsValidArguments(const AValue: string): Boolean;
var
  LJson: TJSONValue;
begin
  Result := False;
  if (AValue = '') or (Length(AValue) > CMaximumArgumentsLength) then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AValue);
  try
    Result := LJson is TJSONArray;
  finally
    LJson.Free;
  end;
end;

{ TRadIAExternalMcpResource }

constructor TRadIAExternalMcpResource.Create(
  const AServerId: string;
  const AUri: string;
  const AName: string;
  const ADescription: string;
  const AMimeType: string
);
begin
  FServerId := Trim(LowerCase(AServerId));
  FUri := Trim(AUri);
  FName := Trim(AName);
  FDescription := Trim(ADescription);
  FMimeType := Trim(AMimeType);
  FFederatedUri := 'mcp://' + FServerId + '/resources/' +
    TNetEncoding.URL.Encode(FUri);
end;

{ TRadIAExternalMcpPrompt }

constructor TRadIAExternalMcpPrompt.Create(
  const AServerId: string;
  const AName: string;
  const ADescription: string;
  const AArgumentsJson: string
);
begin
  FServerId := Trim(LowerCase(AServerId));
  FName := Trim(AName);
  FDescription := Trim(ADescription);
  FArgumentsJson := Trim(AArgumentsJson);
  FNamespacedName := 'mcp.' + FServerId + '.prompt.' + FName;
end;

{ TRadIAExternalMcpContentCatalog }

constructor TRadIAExternalMcpContentCatalog.Create;
begin
  inherited Create;
  FPrompts := TDictionary<string, TRadIAExternalMcpPrompt>.Create;
  FResources := TDictionary<string, TRadIAExternalMcpResource>.Create;
end;

destructor TRadIAExternalMcpContentCatalog.Destroy;
begin
  FResources.Free;
  FPrompts.Free;
  inherited Destroy;
end;

class function TRadIAExternalMcpContentCatalog.Normalize(
  const AValue: string
): string;
begin
  Result := LowerCase(Trim(AValue));
end;

procedure TRadIAExternalMcpContentCatalog.ClearServer(
  const AServerId: string
);
begin
  TMonitor.Enter(Self);
  try
    RemoveServer(AServerId);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TRadIAExternalMcpContentCatalog.GetPrompts:
  TArray<TRadIAExternalMcpPrompt>;
begin
  TMonitor.Enter(Self);
  try
    Result := FPrompts.Values.ToArray;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TRadIAExternalMcpContentCatalog.GetResources:
  TArray<TRadIAExternalMcpResource>;
begin
  TMonitor.Enter(Self);
  try
    Result := FResources.Values.ToArray;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIAExternalMcpContentCatalog.RemoveServer(
  const AServerId: string
);
var
  LKey: string;
begin
  for LKey in FPrompts.Keys.ToArray do
    if SameText(FPrompts[LKey].ServerId, AServerId) then
      FPrompts.Remove(LKey);
  for LKey in FResources.Keys.ToArray do
    if SameText(FResources[LKey].ServerId, AServerId) then
      FResources.Remove(LKey);
end;

class function TRadIAExternalMcpContentCatalog.ValidatePrompt(
  const AServerId: string;
  const APrompt: TRadIAExternalMcpPrompt;
  out AError: string
): Boolean;
begin
  AError := '';
  if not SameText(APrompt.ServerId, AServerId) then
    AError := 'An external MCP prompt belongs to a different server.'
  else if not IsValidPromptName(APrompt.Name) then
    AError := 'External MCP prompt name is invalid.'
  else if Length(APrompt.Description) > CMaximumDescriptionLength then
    AError := 'External MCP prompt description exceeds the safe limit.'
  else if not IsValidArguments(APrompt.ArgumentsJson) then
    AError := 'External MCP prompt arguments must be a bounded JSON array.';
  Result := AError = '';
end;

class function TRadIAExternalMcpContentCatalog.ValidateResource(
  const AServerId: string;
  const AResource: TRadIAExternalMcpResource;
  out AError: string
): Boolean;
begin
  AError := '';
  if not SameText(AResource.ServerId, AServerId) then
    AError := 'An external MCP resource belongs to a different server.'
  else if (AResource.Uri = '') or
          (Length(AResource.Uri) > CMaximumIdentifierLength) then
    AError := 'External MCP resource URI is invalid.'
  else if Length(AResource.Name) > CMaximumIdentifierLength then
    AError := 'External MCP resource name exceeds the safe limit.'
  else if Length(AResource.Description) > CMaximumDescriptionLength then
    AError := 'External MCP resource description exceeds the safe limit.'
  else if Length(AResource.MimeType) > 256 then
    AError := 'External MCP resource MIME type exceeds the safe limit.';
  Result := AError = '';
end;

class function TRadIAExternalMcpContentCatalog.ValidateServer(
  const AServer: TRadIAExternalMcpServerConfig;
  const AContentKind: string;
  out AError: string
): Boolean;
begin
  Result := AServer.Validate(AError);
  if Result and not AServer.Enabled then
  begin
    AError := 'Disabled external MCP servers cannot publish ' + AContentKind + '.';
    Result := False;
  end;
end;

function TRadIAExternalMcpContentCatalog.PublishPrompts(
  const AServer: TRadIAExternalMcpServerConfig;
  const APrompts: TArray<TRadIAExternalMcpPrompt>;
  out AError: string
): Boolean;
var
  LKey: string;
  LPrompt: TRadIAExternalMcpPrompt;
  LSnapshot: TDictionary<string, TRadIAExternalMcpPrompt>;
begin
  Result := False;
  AError := '';
  if not ValidateServer(AServer, 'prompts', AError) then
    Exit;
  LSnapshot := TDictionary<string, TRadIAExternalMcpPrompt>.Create;
  try
    for LPrompt in APrompts do
    begin
      if not ValidatePrompt(AServer.Id, LPrompt, AError) then
        Exit;
      LKey := Normalize(LPrompt.NamespacedName);
      if LSnapshot.ContainsKey(LKey) then
      begin
        AError := 'Duplicate external MCP prompt: ' + LPrompt.NamespacedName;
        Exit;
      end;
      LSnapshot.Add(LKey, LPrompt);
    end;
    TMonitor.Enter(Self);
    try
      for LKey in FPrompts.Keys.ToArray do
        if SameText(FPrompts[LKey].ServerId, AServer.Id) then
          FPrompts.Remove(LKey);
      for LKey in LSnapshot.Keys do
        FPrompts.Add(LKey, LSnapshot[LKey]);
    finally
      TMonitor.Exit(Self);
    end;
    Result := True;
  finally
    LSnapshot.Free;
  end;
end;

function TRadIAExternalMcpContentCatalog.PublishResources(
  const AServer: TRadIAExternalMcpServerConfig;
  const AResources: TArray<TRadIAExternalMcpResource>;
  out AError: string
): Boolean;
var
  LKey: string;
  LResource: TRadIAExternalMcpResource;
  LSnapshot: TDictionary<string, TRadIAExternalMcpResource>;
begin
  Result := False;
  AError := '';
  if not ValidateServer(AServer, 'resources', AError) then
    Exit;
  LSnapshot := TDictionary<string, TRadIAExternalMcpResource>.Create;
  try
    for LResource in AResources do
    begin
      if not ValidateResource(AServer.Id, LResource, AError) then
        Exit;
      LKey := Normalize(LResource.FederatedUri);
      if LSnapshot.ContainsKey(LKey) then
      begin
        AError := 'Duplicate external MCP resource: ' + LResource.Uri;
        Exit;
      end;
      LSnapshot.Add(LKey, LResource);
    end;
    TMonitor.Enter(Self);
    try
      for LKey in FResources.Keys.ToArray do
        if SameText(FResources[LKey].ServerId, AServer.Id) then
          FResources.Remove(LKey);
      for LKey in LSnapshot.Keys do
        FResources.Add(LKey, LSnapshot[LKey]);
    finally
      TMonitor.Exit(Self);
    end;
    Result := True;
  finally
    LSnapshot.Free;
  end;
end;

end.
