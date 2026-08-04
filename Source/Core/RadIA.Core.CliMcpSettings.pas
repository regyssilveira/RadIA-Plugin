unit RadIA.Core.CliMcpSettings;

interface

uses
  RadIA.Core.SettingsStorage;

type
  TRadIACliMcpClientSettings = record
  private
    FCliExecutablePath: string;
    FMcpConfigPath: string;
    FMcpBridgePath: string;
  public
    constructor Create(
      const ACliExecutablePath: string;
      const AMcpConfigPath: string;
      const AMcpBridgePath: string
    );
    function ToDiagnosticText: string;
    property CliExecutablePath: string read FCliExecutablePath;
    property McpConfigPath: string read FMcpConfigPath;
    property McpBridgePath: string read FMcpBridgePath;
  end;

  TRadIACliMcpSettings = class
  private
    FStorage: IRadIASettingsStorage;
    FBasePath: string;
    function ClientPath(const AClientId: string): string;
    procedure ValidateClientId(const AClientId: string);
  public
    constructor Create(
      const AStorage: IRadIASettingsStorage = nil;
      const ABasePath: string = ''
    );
    function Load(
      const AClientId: string;
      const ADefaultConfigPath: string;
      const ADefaultBridgePath: string
    ): TRadIACliMcpClientSettings;
    procedure Save(
      const AClientId: string;
      const ASettings: TRadIACliMcpClientSettings
    );
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.Config;

{ TRadIACliMcpClientSettings }

constructor TRadIACliMcpClientSettings.Create(
  const ACliExecutablePath: string;
  const AMcpConfigPath: string;
  const AMcpBridgePath: string
);
begin
  FCliExecutablePath := ACliExecutablePath;
  FMcpConfigPath := AMcpConfigPath;
  FMcpBridgePath := AMcpBridgePath;
end;

function TRadIACliMcpClientSettings.ToDiagnosticText: string;
begin
  Result := Format(
    '%s|%s|%s',
    [
      CliExecutablePath,
      McpConfigPath,
      McpBridgePath
    ]
  );
end;

{ TRadIACliMcpSettings }

constructor TRadIACliMcpSettings.Create(
  const AStorage: IRadIASettingsStorage;
  const ABasePath: string
);
begin
  inherited Create;
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := TRadIARegistrySettingsStorage.Create;
  FBasePath := Trim(ABasePath);
  if FBasePath = '' then
    FBasePath := TRadIAConfig.GetRegistryPath + '\CliMcp';
end;

function TRadIACliMcpSettings.ClientPath(
  const AClientId: string
): string;
begin
  ValidateClientId(AClientId);
  Result := FBasePath + '\' + LowerCase(Trim(AClientId));
end;

function TRadIACliMcpSettings.Load(
  const AClientId: string;
  const ADefaultConfigPath: string;
  const ADefaultBridgePath: string
): TRadIACliMcpClientSettings;
begin
  if not FStorage.OpenKey(ClientPath(AClientId), False) then
    Exit(
      TRadIACliMcpClientSettings.Create(
        '',
        ADefaultConfigPath,
        ADefaultBridgePath
      )
    );
  try
    Result := TRadIACliMcpClientSettings.Create(
      FStorage.ReadString('CliExecutablePath', ''),
      FStorage.ReadString('McpConfigPath', ADefaultConfigPath),
      FStorage.ReadString('McpBridgePath', ADefaultBridgePath)
    );
  finally
    FStorage.CloseKey;
  end;
end;

procedure TRadIACliMcpSettings.Save(
  const AClientId: string;
  const ASettings: TRadIACliMcpClientSettings
);
begin
  if not FStorage.OpenKey(ClientPath(AClientId), True) then
    raise EInOutError.Create('Unable to open the CLI and MCP settings.');
  try
    FStorage.WriteString(
      'CliExecutablePath',
      ASettings.CliExecutablePath
    );
    FStorage.WriteString(
      'McpConfigPath',
      ASettings.McpConfigPath
    );
    FStorage.WriteString(
      'McpBridgePath',
      ASettings.McpBridgePath
    );
  finally
    FStorage.CloseKey;
  end;
end;

procedure TRadIACliMcpSettings.ValidateClientId(
  const AClientId: string
);
var
  LCharacter: Char;
  LClientId: string;
begin
  LClientId := Trim(AClientId);
  if LClientId = '' then
    raise EArgumentException.Create('The CLI client ID is required.');
  for LCharacter in LClientId do
    if not CharInSet(LCharacter, ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']) then
      raise EArgumentException.Create('The CLI client ID contains invalid characters.');
end;

end.
