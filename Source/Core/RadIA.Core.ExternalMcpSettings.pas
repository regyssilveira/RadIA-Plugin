unit RadIA.Core.ExternalMcpSettings;

interface

uses
  System.JSON,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpSecurity;

type
  IRadIAExternalMcpSettingsStore = interface
    ['{C44CD1C6-BD65-4F8C-A0D9-80D34A21F9B7}']
    function Load(
      out AServers: TArray<TRadIAExternalMcpServerConfig>;
      out AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
    function Save(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
  end;

  TRadIAExternalMcpSettingsStore = class(
    TInterfacedObject,
    IRadIAExternalMcpSettingsStore
  )
  private
    FFileName: string;
    FLock: TObject;
    class procedure AtomicWrite(
      const AFileName: string;
      const AContent: string
    ); static;
    class function BuildPayload(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>
    ): string; static;
    class function ParsePayload(
      const AJson: string;
      out AServers: TArray<TRadIAExternalMcpServerConfig>;
      out AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean; static;
    class function ParseGrants(
      const AItems: TJSONArray;
      out AGrants: TArray<TRadIAExternalMcpToolGrant>
    ): Boolean; static;
    class function ParseServers(
      const AItems: TJSONArray;
      out AServers: TArray<TRadIAExternalMcpServerConfig>
    ): Boolean; static;
    class function ValidateGrants(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean; static;
    class function ValidateServers(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      out AError: string
    ): Boolean; static;
    class function ValidateSettings(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean; static;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function Load(
      out AServers: TArray<TRadIAExternalMcpServerConfig>;
      out AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
    function Save(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
  end;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.CredentialProtector,
  RadIA.Core.Tools;

const
  CSchemaVersion = 1;
  CMaximumServers = 64;
  CMaximumGrants = 512;
  CMaximumProtectedPayloadLength = 8 * 1024 * 1024;

function ParseRisk(
  const AValue: string;
  out ARisk: TRadIAToolRisk
): Boolean;
begin
  Result := True;
  if SameText(AValue, 'readOnly') then
    ARisk := trReadOnly
  else if SameText(AValue, 'reversibleWrite') then
    ARisk := trReversibleWrite
  else if SameText(AValue, 'structuralWrite') then
    ARisk := trStructuralWrite
  else if SameText(AValue, 'execution') then
    ARisk := trExecution
  else if SameText(AValue, 'destructive') then
    ARisk := trDestructive
  else if SameText(AValue, 'sensitive') then
    ARisk := trSensitive
  else
    Result := False;
end;

function JsonStrings(const AValues: TArray<string>): TJSONArray;
var
  LValue: string;
begin
  Result := TJSONArray.Create;
  for LValue in AValues do
    Result.Add(LValue);
end;

function ReadStrings(
  const AArray: TJSONArray;
  out AValues: TArray<string>
): Boolean;
var
  LIndex: Integer;
begin
  AValues := nil;
  Result := Assigned(AArray);
  if not Result then
    Exit;
  SetLength(AValues, AArray.Count);
  for LIndex := 0 to AArray.Count - 1 do
  begin
    if not (AArray[LIndex] is TJSONString) then
      Exit(False);
    AValues[LIndex] := AArray[LIndex].Value;
  end;
end;

{ TRadIAExternalMcpSettingsStore }

constructor TRadIAExternalMcpSettingsStore.Create(
  const AFileName: string
);
begin
  inherited Create;
  FFileName := Trim(AFileName);
  if FFileName = '' then
    raise EArgumentException.Create('External MCP settings file is required.');
  FLock := TObject.Create;
end;

destructor TRadIAExternalMcpSettingsStore.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

class procedure TRadIAExternalMcpSettingsStore.AtomicWrite(
  const AFileName: string;
  const AContent: string
);
var
  LDirectory: string;
  LTemporaryFileName: string;
begin
  LDirectory := ExtractFilePath(AFileName);
  if LDirectory <> '' then
    TDirectory.CreateDirectory(LDirectory);
  LTemporaryFileName := AFileName + '.' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '') + '.tmp';
  try
    TFile.WriteAllText(LTemporaryFileName, AContent, TEncoding.UTF8);
    if not MoveFileEx(
      PChar(LTemporaryFileName),
      PChar(AFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    ) then
      RaiseLastOSError;
  finally
    if TFile.Exists(LTemporaryFileName) then
      TFile.Delete(LTemporaryFileName);
  end;
end;

class function TRadIAExternalMcpSettingsStore.BuildPayload(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>
): string;
var
  LGrant: TRadIAExternalMcpToolGrant;
  LGrantJson: TJSONObject;
  LGrants: TJSONArray;
  LRoot: TJSONObject;
  LServer: TRadIAExternalMcpServerConfig;
  LServerJson: TJSONObject;
  LServers: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LServers := TJSONArray.Create;
    for LServer in AServers do
    begin
      LServerJson := TJSONObject.Create;
      LServerJson.AddPair('id', LServer.Id);
      LServerJson.AddPair('displayName', LServer.DisplayName);
      LServerJson.AddPair('command', LServer.Command);
      LServerJson.AddPair('arguments', JsonStrings(LServer.Arguments));
      LServerJson.AddPair('workingDirectory', LServer.WorkingDirectory);
      LServerJson.AddPair('enabled', TJSONBool.Create(LServer.Enabled));
      LServerJson.AddPair('timeoutMs', TJSONNumber.Create(LServer.TimeoutMs));
      LServers.AddElement(LServerJson);
    end;
    LRoot.AddPair('servers', LServers);
    LGrants := TJSONArray.Create;
    for LGrant in AGrants do
    begin
      LGrantJson := TJSONObject.Create;
      LGrantJson.AddPair('name', LGrant.NamespacedName);
      LGrantJson.AddPair('risk', RadIAToolRiskName(LGrant.Risk));
      LGrantJson.AddPair(
        'consentEveryTime',
        TJSONBool.Create(LGrant.ConsentEveryTime)
      );
      LGrantJson.AddPair('pathArguments', JsonStrings(LGrant.PathArguments));
      LGrantJson.AddPair(
        'allowUnboundedAccess',
        TJSONBool.Create(LGrant.AllowUnboundedAccess)
      );
      LGrants.AddElement(LGrantJson);
    end;
    LRoot.AddPair('grants', LGrants);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAExternalMcpSettingsStore.Load(
  out AServers: TArray<TRadIAExternalMcpServerConfig>;
  out AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
var
  LEnvelope: TJSONObject;
  LPayload: string;
  LProtectedPayload: string;
begin
  AServers := nil;
  AGrants := nil;
  AError := '';
  TMonitor.Enter(FLock);
  try
    try
      if not TFile.Exists(FFileName) then
        Exit(True);
      LEnvelope := TJSONObject.ParseJSONValue(
        TFile.ReadAllText(FFileName, TEncoding.UTF8)
      ) as TJSONObject;
      try
        if not Assigned(LEnvelope) or
           (LEnvelope.GetValue<Integer>('schemaVersion', 0) <> CSchemaVersion) then
        begin
          AError := 'External MCP settings envelope is invalid or unsupported.';
          Exit(False);
        end;
        LProtectedPayload := LEnvelope.GetValue<string>('protectedPayload', '');
        if (LProtectedPayload = '') or
           (Length(LProtectedPayload) > CMaximumProtectedPayloadLength) then
        begin
          AError := 'External MCP protected settings payload is invalid.';
          Exit(False);
        end;
        LPayload := TCredentialProtector.UnprotectText(LProtectedPayload);
        if LPayload = '' then
        begin
          AError := 'External MCP settings could not be decrypted for this Windows user.';
          Exit(False);
        end;
        Result := ParsePayload(LPayload, AServers, AGrants, AError);
      finally
        LEnvelope.Free;
      end;
    except
      on E: Exception do
      begin
        AServers := nil;
        AGrants := nil;
        AError := 'External MCP settings could not be loaded: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TRadIAExternalMcpSettingsStore.ParsePayload(
  const AJson: string;
  out AServers: TArray<TRadIAExternalMcpServerConfig>;
  out AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
var
  LGrants: TJSONArray;
  LRoot: TJSONObject;
  LServers: TJSONArray;
begin
  Result := False;
  AServers := nil;
  AGrants := nil;
  AError := '';
  LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    if not Assigned(LRoot) or not (LRoot.GetValue('servers') is TJSONArray) or
       not (LRoot.GetValue('grants') is TJSONArray) then
    begin
      AError := 'External MCP protected payload is invalid.';
      Exit;
    end;
    LServers := TJSONArray(LRoot.GetValue('servers'));
    LGrants := TJSONArray(LRoot.GetValue('grants'));
    if (LServers.Count > CMaximumServers) or (LGrants.Count > CMaximumGrants) then
    begin
      AError := 'External MCP settings exceed the safe item limits.';
      Exit;
    end;
    if not ParseServers(LServers, AServers) or
       not ParseGrants(LGrants, AGrants) then
      Exit;
    Result := ValidateSettings(AServers, AGrants, AError);
  finally
    LRoot.Free;
  end;
  if not Result and (AError = '') then
    AError := 'External MCP protected payload contains invalid items.';
end;

class function TRadIAExternalMcpSettingsStore.ParseGrants(
  const AItems: TJSONArray;
  out AGrants: TArray<TRadIAExternalMcpToolGrant>
): Boolean;
var
  LGrant: TJSONObject;
  LIndex: Integer;
  LPathArguments: TArray<string>;
  LRisk: TRadIAToolRisk;
begin
  Result := False;
  AGrants := nil;
  SetLength(AGrants, AItems.Count);
  for LIndex := 0 to AItems.Count - 1 do
  begin
    if not (AItems[LIndex] is TJSONObject) then
      Exit;
    LGrant := TJSONObject(AItems[LIndex]);
    if not ParseRisk(LGrant.GetValue<string>('risk', ''), LRisk) or
       not (LGrant.GetValue('pathArguments') is TJSONArray) or
       not ReadStrings(
         TJSONArray(LGrant.GetValue('pathArguments')),
         LPathArguments
       ) then
      Exit;
    AGrants[LIndex] := TRadIAExternalMcpToolGrant.Create(
      LGrant.GetValue<string>('name', ''),
      LRisk,
      LGrant.GetValue<Boolean>('consentEveryTime', False),
      LPathArguments,
      LGrant.GetValue<Boolean>('allowUnboundedAccess', False)
    );
  end;
  Result := True;
end;

class function TRadIAExternalMcpSettingsStore.ParseServers(
  const AItems: TJSONArray;
  out AServers: TArray<TRadIAExternalMcpServerConfig>
): Boolean;
var
  LArguments: TArray<string>;
  LIndex: Integer;
  LServer: TJSONObject;
begin
  Result := False;
  AServers := nil;
  SetLength(AServers, AItems.Count);
  for LIndex := 0 to AItems.Count - 1 do
  begin
    if not (AItems[LIndex] is TJSONObject) then
      Exit;
    LServer := TJSONObject(AItems[LIndex]);
    if not (LServer.GetValue('arguments') is TJSONArray) or
       not ReadStrings(
         TJSONArray(LServer.GetValue('arguments')),
         LArguments
       ) then
      Exit;
    AServers[LIndex] := TRadIAExternalMcpServerConfig.Create(
      LServer.GetValue<string>('id', ''),
      LServer.GetValue<string>('displayName', ''),
      LServer.GetValue<string>('command', ''),
      LArguments,
      LServer.GetValue<string>('workingDirectory', ''),
      LServer.GetValue<Boolean>('enabled', False),
      LServer.GetValue<Integer>('timeoutMs', 0)
    );
  end;
  Result := True;
end;

function TRadIAExternalMcpSettingsStore.Save(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
var
  LEnvelope: TJSONObject;
  LProtectedPayload: string;
begin
  Result := False;
  AError := '';
  if not ValidateSettings(AServers, AGrants, AError) then
    Exit;
  LProtectedPayload := TCredentialProtector.ProtectText(
    BuildPayload(AServers, AGrants)
  );
  if LProtectedPayload = '' then
  begin
    AError := 'External MCP settings could not be protected for this Windows user.';
    Exit;
  end;
  LEnvelope := TJSONObject.Create;
  try
    LEnvelope.AddPair('schemaVersion', TJSONNumber.Create(CSchemaVersion));
    LEnvelope.AddPair('protectedPayload', LProtectedPayload);
    TMonitor.Enter(FLock);
    try
      AtomicWrite(FFileName, LEnvelope.Format(2));
    finally
      TMonitor.Exit(FLock);
    end;
    Result := True;
  except
    on E: Exception do
      AError := 'External MCP settings could not be saved: ' + E.Message;
  end;
  LEnvelope.Free;
end;

class function TRadIAExternalMcpSettingsStore.ValidateSettings(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
begin
  AError := '';
  if (Length(AServers) > CMaximumServers) or
     (Length(AGrants) > CMaximumGrants) then
  begin
    AError := 'External MCP settings exceed the safe item limits.';
    Exit(False);
  end;
  Result := ValidateServers(AServers, AError) and
    ValidateGrants(AServers, AGrants, AError);
end;

class function TRadIAExternalMcpSettingsStore.ValidateGrants(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
var
  LGrant: TRadIAExternalMcpToolGrant;
  LNames: TDictionary<string, Boolean>;
  LServer: TRadIAExternalMcpServerConfig;
begin
  LNames := TDictionary<string, Boolean>.Create;
  try
    for LGrant in AGrants do
    begin
      if not LGrant.Validate(AError) then
        Exit(False);
      if LNames.ContainsKey(LowerCase(LGrant.NamespacedName)) then
      begin
        AError := 'External MCP grant names must be unique.';
        Exit(False);
      end;
      LNames.Add(LowerCase(LGrant.NamespacedName), True);
      Result := False;
      for LServer in AServers do
        if LGrant.NamespacedName.StartsWith('mcp.' + LServer.Id + '.') then
        begin
          Result := True;
          Break;
        end;
      if not Result then
      begin
        AError := 'External MCP grant references an unknown server.';
        Exit;
      end;
    end;
    Result := True;
  finally
    LNames.Free;
  end;
end;

class function TRadIAExternalMcpSettingsStore.ValidateServers(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  out AError: string
): Boolean;
var
  LIds: TDictionary<string, Boolean>;
  LServer: TRadIAExternalMcpServerConfig;
begin
  LIds := TDictionary<string, Boolean>.Create;
  try
    for LServer in AServers do
    begin
      if not LServer.Validate(AError) then
        Exit(False);
      if LIds.ContainsKey(LServer.Id) then
      begin
        AError := 'External MCP server IDs must be unique.';
        Exit(False);
      end;
      LIds.Add(LServer.Id, True);
    end;
    Result := True;
  finally
    LIds.Free;
  end;
end;

end.
