unit RadIA.Core.RemoteKnowledgeSettings;

interface

uses
  RadIA.Core.Knowledge,
  RadIA.Core.KnowledgeEmbeddingSelection,
  RadIA.Core.SettingsStorage;

type
  TRadIARemoteKnowledgeLimits = record
  private
    FDimensions: Integer;
    FMaxInputCharacters: Integer;
    FTimeoutMs: Integer;
  public
    constructor Create(
      const ADimensions: Integer;
      const ATimeoutMs: Integer;
      const AMaxInputCharacters: Integer
    );
    property Dimensions: Integer read FDimensions;
    property MaxInputCharacters: Integer read FMaxInputCharacters;
    property TimeoutMs: Integer read FTimeoutMs;
  end;

  TRadIARemoteKnowledgeConfiguration = record
  private
    FApiKey: string;
    FConsentGranted: Boolean;
    FDimensions: Integer;
    FEnabled: Boolean;
    FEndpoint: string;
    FMaxInputCharacters: Integer;
    FModel: string;
    FTimeoutMs: Integer;
  public
    constructor Create(
      const AEnabled: Boolean;
      const AConsentGranted: Boolean;
      const AEndpoint: string;
      const AModel: string;
      const AApiKey: string;
      const ALimits: TRadIARemoteKnowledgeLimits
    );
    property ApiKey: string read FApiKey;
    property ConsentGranted: Boolean read FConsentGranted;
    property Dimensions: Integer read FDimensions;
    property Enabled: Boolean read FEnabled;
    property Endpoint: string read FEndpoint;
    property MaxInputCharacters: Integer read FMaxInputCharacters;
    property Model: string read FModel;
    property TimeoutMs: Integer read FTimeoutMs;
  end;

  TRadIARemoteKnowledgeSettings = class(
    TInterfacedObject,
    IRadIAKnowledgeEmbeddingRemoteSettings
  )
  private
    FBasePath: string;
    FConfiguration: TRadIARemoteKnowledgeConfiguration;
    FStorage: IRadIASettingsStorage;
  public
    constructor Create(
      const AStorage: IRadIASettingsStorage = nil;
      const ABasePath: string = ''
    );
    function GetConsentGranted: Boolean;
    function GetEnabled: Boolean;
    function GetConfiguration: TRadIARemoteKnowledgeConfiguration;
    procedure Load;
    procedure Save(
      const AConfiguration: TRadIARemoteKnowledgeConfiguration
    );
    function TryCreateProvider(
      out AProvider: IRadIAKnowledgeEmbeddingProvider
    ): Boolean;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.Config,
  RadIA.Core.CredentialProtector,
  RadIA.Core.RemoteKnowledgeEmbeddings;

const
  CDefaultDimensions = 1536;
  CDefaultMaxInputCharacters = 12000;
  CDefaultTimeoutMs = 30000;

{ TRadIARemoteKnowledgeConfiguration }

constructor TRadIARemoteKnowledgeLimits.Create(
  const ADimensions: Integer;
  const ATimeoutMs: Integer;
  const AMaxInputCharacters: Integer
);
begin
  FDimensions := ADimensions;
  FTimeoutMs := ATimeoutMs;
  FMaxInputCharacters := AMaxInputCharacters;
end;

constructor TRadIARemoteKnowledgeConfiguration.Create(
  const AEnabled: Boolean;
  const AConsentGranted: Boolean;
  const AEndpoint: string;
  const AModel: string;
  const AApiKey: string;
  const ALimits: TRadIARemoteKnowledgeLimits
);
begin
  FEnabled := AEnabled;
  FConsentGranted := AConsentGranted;
  FEndpoint := Trim(AEndpoint);
  FModel := Trim(AModel);
  FApiKey := AApiKey;
  FDimensions := ALimits.Dimensions;
  FTimeoutMs := ALimits.TimeoutMs;
  FMaxInputCharacters := ALimits.MaxInputCharacters;
end;

{ TRadIARemoteKnowledgeSettings }

constructor TRadIARemoteKnowledgeSettings.Create(
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
  if FBasePath.IsEmpty then
    FBasePath := TRadIAConfig.GetRegistryPath + '\Knowledge\Remote';
  Load;
end;

function TRadIARemoteKnowledgeSettings.GetConfiguration:
  TRadIARemoteKnowledgeConfiguration;
begin
  Result := FConfiguration;
end;

function TRadIARemoteKnowledgeSettings.GetConsentGranted: Boolean;
begin
  Result := FConfiguration.ConsentGranted;
end;

function TRadIARemoteKnowledgeSettings.GetEnabled: Boolean;
begin
  Result := FConfiguration.Enabled;
end;

procedure TRadIARemoteKnowledgeSettings.Load;
var
  LApiKey: string;
begin
  FConfiguration := TRadIARemoteKnowledgeConfiguration.Create(
    False,
    False,
    '',
    '',
    '',
    TRadIARemoteKnowledgeLimits.Create(
      CDefaultDimensions,
      CDefaultTimeoutMs,
      CDefaultMaxInputCharacters
    )
  );
  if not FStorage.OpenKey(FBasePath, False) then
    Exit;
  try
    LApiKey := TCredentialProtector.Unprotect(
      FStorage.ReadString('ApiKey', '')
    );
    FConfiguration := TRadIARemoteKnowledgeConfiguration.Create(
      FStorage.ReadInteger('Enabled', 0) = 1,
      FStorage.ReadInteger('ConsentGranted', 0) = 1,
      FStorage.ReadString('Endpoint', ''),
      FStorage.ReadString('Model', ''),
      LApiKey,
      TRadIARemoteKnowledgeLimits.Create(
        FStorage.ReadInteger('Dimensions', CDefaultDimensions),
        FStorage.ReadInteger('TimeoutMs', CDefaultTimeoutMs),
        FStorage.ReadInteger(
          'MaxInputCharacters',
          CDefaultMaxInputCharacters
        )
      )
    );
  finally
    FStorage.CloseKey;
  end;
end;

procedure TRadIARemoteKnowledgeSettings.Save(
  const AConfiguration: TRadIARemoteKnowledgeConfiguration
);
begin
  if not FStorage.OpenKey(FBasePath, True) then
    raise EInOutError.Create(
      'Unable to open remote knowledge settings.'
    );
  try
    FStorage.WriteInteger('Enabled', Ord(AConfiguration.Enabled));
    FStorage.WriteInteger(
      'ConsentGranted',
      Ord(AConfiguration.ConsentGranted)
    );
    FStorage.WriteString('Endpoint', AConfiguration.Endpoint);
    FStorage.WriteString('Model', AConfiguration.Model);
    FStorage.WriteString(
      'ApiKey',
      TCredentialProtector.Protect(AConfiguration.ApiKey)
    );
    FStorage.WriteInteger('Dimensions', AConfiguration.Dimensions);
    FStorage.WriteInteger('TimeoutMs', AConfiguration.TimeoutMs);
    FStorage.WriteInteger(
      'MaxInputCharacters',
      AConfiguration.MaxInputCharacters
    );
    FConfiguration := AConfiguration;
  finally
    FStorage.CloseKey;
  end;
end;

function TRadIARemoteKnowledgeSettings.TryCreateProvider(
  out AProvider: IRadIAKnowledgeEmbeddingProvider
): Boolean;
var
  LOptions: TRadIARemoteEmbeddingOptions;
begin
  AProvider := nil;
  Result := False;
  if not GetEnabled or not GetConsentGranted then
    Exit;
  try
    LOptions := TRadIARemoteEmbeddingOptions.Create(
      FConfiguration.Endpoint,
      FConfiguration.Model,
      FConfiguration.ApiKey,
      FConfiguration.Dimensions,
      FConfiguration.TimeoutMs,
      FConfiguration.MaxInputCharacters
    );
    AProvider := TRadIAOpenAICompatibleEmbeddingProvider.Create(LOptions);
    Result := True;
  except
    on EArgumentException do
      AProvider := nil;
  end;
end;

end.
