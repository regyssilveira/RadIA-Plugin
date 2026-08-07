unit RadIA.Provider.AzureOpenAI;

interface

uses
  RadIA.Core.Interfaces, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  { Native provider for Microsoft Azure OpenAI }
  TRadIAAzureOpenAIProvider = class(TRadIAProviderBase)
  protected
    function GetBaseUrl: string;
    function GetApiVersion: string;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;

    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
  end;

implementation

uses
  RadIA.Core.ProviderRegistry, System.SysUtils, System.Net.URLClient, RadIA.Core.TokenUsage;

{ TRadIAAzureOpenAIProvider }

constructor TRadIAAzureOpenAIProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'AzureOpenAI';
end;

function TRadIAAzureOpenAIProvider.GetBaseUrl: string;
begin
  Result := FConfig.GetProviderBaseUrl(FProviderId);
end;

function TRadIAAzureOpenAIProvider.GetApiVersion: string;
begin
  Result := FConfig.GetAzureApiVersion;
  if Result.IsEmpty then
    Result := '2024-02-15-preview';
end;

function TRadIAAzureOpenAIProvider.GetAvailableModels: TArray<string>;
begin
  { Azure uses Deployment Names mapped by the administrator.
    We return standard default identifiers, but the user will write or select
    their own Deployment Name in the settings/combobox. }
  Result := TArray<string>.Create('gpt-5.6-terra', 'gpt-5.6-sol', 'gpt-5.6-luna');
end;

function TRadIAAzureOpenAIProvider.GetName: string;
begin
  Result := 'Azure OpenAI';
end;

procedure TRadIAAzureOpenAIProvider.SendPromptAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TCompletionCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
  LHeaders: TNetHeaders;
  LApiKey: string;
begin
  LApiKey := GetApiKey;
  if LApiKey.IsEmpty then
  begin
    ACallback('', 'API Key is missing for Azure OpenAI. Please check settings.', False, TTokenUsage.Empty);
    Exit;
  end;

  if GetBaseUrl.IsEmpty then
  begin
    ACallback('', 'Endpoint Base URL is missing for Azure OpenAI. Please check settings.', False, TTokenUsage.Empty);
    Exit;
  end;

  if GetActiveModel.IsEmpty then
  begin
    ACallback('', 'Deployment Name is missing for Azure OpenAI. Please check settings.', False, TTokenUsage.Empty);
    Exit;
  end;

  LUrl := Format('%s/openai/deployments/%s/chat/completions?api-version=%s',
    [GetBaseUrl.TrimRight(['/']), GetActiveModel, GetApiVersion]);

  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('api-key', LApiKey);

  try
    LRequestBody := BuildOpenAICompatibleRequestBody(APrompt, AHistory, False, ATemperature, AMaxTokens);
  except
    on E: Exception do
    begin
      ACallback('', 'Error building request JSON: ' + E.Message, False, TTokenUsage.Empty);
      Exit;
    end;
  end;

  ExecuteRequestAsync(LUrl, LHeaders, LRequestBody,
    function(const AResponseJson: string; out AUsage: TTokenUsage): string
    begin
      Result := ParseOpenAICompatibleResponse(AResponseJson, AUsage);
    end, ACallback);
end;

procedure TRadIAAzureOpenAIProvider.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
  LHeaders: TNetHeaders;
  LApiKey: string;
begin
  LApiKey := GetApiKey;
  if LApiKey.IsEmpty then
  begin
    ACallback('', True, 'API Key is missing for Azure OpenAI. Please check settings.');
    Exit;
  end;

  if GetBaseUrl.IsEmpty then
  begin
    ACallback('', True, 'Endpoint Base URL is missing for Azure OpenAI. Please check settings.');
    Exit;
  end;

  if GetActiveModel.IsEmpty then
  begin
    ACallback('', True, 'Deployment Name is missing for Azure OpenAI. Please check settings.');
    Exit;
  end;

  LUrl := Format('%s/openai/deployments/%s/chat/completions?api-version=%s',
    [GetBaseUrl.TrimRight(['/']), GetActiveModel, GetApiVersion]);

  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('api-key', LApiKey);

  try
    LRequestBody := BuildOpenAICompatibleRequestBody(APrompt, AHistory, True, ATemperature, AMaxTokens);
  except
    on E: Exception do
    begin
      ACallback('', True, 'Error building request JSON: ' + E.Message);
      Exit;
    end;
  end;

  ExecuteRequestStreamAsync(LUrl, LHeaders, LRequestBody,
    function(const ABuffer: string): string
    var
      LTemp: string;
    begin
      LTemp := ABuffer;
      ProcessOpenAICompatibleStreamBuffer(LTemp, ACallback);
      Result := LTemp;
    end, ACallback);
end;

initialization
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'AzureOpenAI',
      'Azure OpenAI',
      '',
      True,  { Requer API Key }
      True,  { Permite URL customizada (Resource Endpoint) }
      ['gpt-5.6-terra', 'gpt-5.6-sol', 'gpt-5.6-luna'],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAAzureOpenAIProvider.Create(ACfg);
      end
    )
  );

end.
