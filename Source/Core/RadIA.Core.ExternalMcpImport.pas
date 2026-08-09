unit RadIA.Core.ExternalMcpImport;

interface

uses
  System.JSON,
  RadIA.Core.ExternalMcp;

type
  TRadIAExternalMcpConfigImporter = class
  private
    class function ReadArguments(
      const AServer: TJSONObject;
      out AArguments: TArray<string>;
      out AError: string
    ): Boolean; static;
  public
    class function ImportJson(
      const AJson: string;
      out AServers: TArray<TRadIAExternalMcpServerConfig>;
      out AError: string
    ): Boolean; static;
  end;

implementation

uses
  System.SysUtils;

const
  CMaximumImportLength = 4 * 1024 * 1024;
  CMaximumServers = 64;

class function TRadIAExternalMcpConfigImporter.ReadArguments(
  const AServer: TJSONObject;
  out AArguments: TArray<string>;
  out AError: string
): Boolean;
var
  LArray: TJSONArray;
  LIndex: Integer;
  LValue: TJSONValue;
begin
  AArguments := nil;
  AError := '';
  LValue := AServer.GetValue('args');
  if not Assigned(LValue) then
    Exit(True);
  if not (LValue is TJSONArray) then
  begin
    AError := 'Imported MCP args must be an array of strings.';
    Exit(False);
  end;
  LArray := TJSONArray(LValue);
  SetLength(AArguments, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    if not (LArray[LIndex] is TJSONString) then
    begin
      AError := 'Every imported MCP argument must be a string.';
      Exit(False);
    end;
    AArguments[LIndex] := LArray[LIndex].Value;
  end;
  Result := True;
end;

class function TRadIAExternalMcpConfigImporter.ImportJson(
  const AJson: string;
  out AServers: TArray<TRadIAExternalMcpServerConfig>;
  out AError: string
): Boolean;
var
  LArguments: TArray<string>;
  LError: string;
  LIndex: Integer;
  LImported: TArray<TRadIAExternalMcpServerConfig>;
  LImportedServer: TRadIAExternalMcpServerConfig;
  LPair: TJSONPair;
  LRoot: TJSONObject;
  LServer: TJSONObject;
  LServers: TJSONObject;
  LServersValue: TJSONValue;
begin
  AServers := nil;
  AError := '';
  if (Trim(AJson) = '') or (Length(AJson) > CMaximumImportLength) then
  begin
    AError := 'The MCP configuration is empty or exceeds 4 MiB.';
    Exit(False);
  end;
  LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    if not Assigned(LRoot) then
    begin
      AError := 'The MCP configuration must be a JSON object.';
      Exit(False);
    end;
    LServersValue := LRoot.GetValue('mcpServers');
    if not Assigned(LServersValue) then
      LServersValue := LRoot.GetValue('servers');
    if not (LServersValue is TJSONObject) then
    begin
      AError := 'The configuration must contain an mcpServers or servers object.';
      Exit(False);
    end;
    LServers := TJSONObject(LServersValue);
    if LServers.Count > CMaximumServers then
    begin
      AError := 'The MCP configuration exceeds the 64-server limit.';
      Exit(False);
    end;
    SetLength(LImported, LServers.Count);
    LIndex := 0;
    for LPair in LServers do
    begin
      if not (LPair.JsonValue is TJSONObject) then
      begin
        AError := 'Every imported MCP server must be a JSON object.';
        Exit(False);
      end;
      LServer := TJSONObject(LPair.JsonValue);
      if not ReadArguments(LServer, LArguments, AError) then
        Exit(False);
      LImportedServer := TRadIAExternalMcpServerConfig.Create(
        LPair.JsonString.Value,
        LServer.GetValue<string>('displayName', LPair.JsonString.Value),
        LServer.GetValue<string>('command', ''),
        LArguments,
        LServer.GetValue<string>('cwd', ''),
        LServer.GetValue<Boolean>('enabled', True),
        LServer.GetValue<Integer>('timeoutMs', 30000)
      );
      if not LImportedServer.Validate(LError) then
      begin
        AError := 'Invalid imported server "' + LPair.JsonString.Value + '": ' + LError;
        Exit(False);
      end;
      LImported[LIndex] := LImportedServer;
      Inc(LIndex);
    end;
    AServers := LImported;
    Result := True;
  finally
    LRoot.Free;
  end;
end;

end.
