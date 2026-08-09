unit RadIA.Provider.LMStudio;

interface

uses
  RadIA.Core.InlineCompletion,
  RadIA.Core.Interfaces,
  RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIALMStudioProvider = class(
    TRadIAOpenAICompatibleProvider,
    IRadIADedicatedFimProvider
  )
  protected
    function GetBaseUrl: string; override;
    function GetModelsDiscoveryUrl: string; override;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
    procedure SendFimAsync(
      const AContext: TRadIAInlineCompletionContext;
      const ACallback: TRadIAFimCompletionCallback;
      const AMaxTokens: Integer
    );
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  System.Net.URLClient,
  RadIA.Core.ProviderRegistry,
  RadIA.Core.TokenUsage;

{ TRadIALMStudioProvider }

constructor TRadIALMStudioProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'LMStudio';
end;

function TRadIALMStudioProvider.GetBaseUrl: string;
begin
  Result := FConfig.GetProviderBaseUrl(FProviderId);
  if Result.IsEmpty then
    Result := 'http://localhost:1234/v1';
end;

function TRadIALMStudioProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create('lms-default');
end;

function TRadIALMStudioProvider.GetName: string;
begin
  Result := 'LM Studio';
end;

function TRadIALMStudioProvider.GetModelsDiscoveryUrl: string;
begin
  Result := GetBaseUrl.TrimRight(['/']) + '/models';
end;

procedure TRadIALMStudioProvider.SendFimAsync(
  const AContext: TRadIAInlineCompletionContext;
  const ACallback: TRadIAFimCompletionCallback;
  const AMaxTokens: Integer
);
var
  LApiKey: string;
  LHeaders: TNetHeaders;
  LRequest: TJSONObject;
  LRequestBody: string;
  LUrl: string;
begin
  LApiKey := FConfig.GetApiKey(FProviderId);
  if LApiKey.IsEmpty then
    LApiKey := 'lm-studio';
  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + LApiKey);
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('model', GetActiveModel);
    LRequest.AddPair('prompt', AContext.Prefix);
    LRequest.AddPair('suffix', AContext.Suffix);
    LRequest.AddPair('temperature', TJSONNumber.Create(0));
    if AMaxTokens > 0 then
      LRequest.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens));
    LRequestBody := LRequest.ToJSON;
  finally
    LRequest.Free;
  end;
  LUrl := GetBaseUrl.TrimRight(['/']) + '/completions';
  ExecuteRequestAsync(
    LUrl,
    LHeaders,
    LRequestBody,
    function(
      const AResponseJson: string;
      out AUsage: TTokenUsage
    ): string
    var
      LChoice: TJSONObject;
      LChoices: TJSONArray;
      LRoot: TJSONObject;
      LUsage: TJSONObject;
    begin
      AUsage := TTokenUsage.Empty;
      LRoot := TJSONObject.ParseJSONValue(AResponseJson) as TJSONObject;
      if not Assigned(LRoot) then
        raise EConvertError.Create('Invalid LM Studio FIM response.');
      try
        Result := '';
        LChoices := LRoot.GetValue('choices') as TJSONArray;
        if Assigned(LChoices) and (LChoices.Count > 0) and
          (LChoices[0] is TJSONObject) then
        begin
          LChoice := LChoices[0] as TJSONObject;
          Result := LChoice.GetValue<string>('text', '');
        end;
        LUsage := LRoot.GetValue('usage') as TJSONObject;
        if Assigned(LUsage) then
        begin
          AUsage.PromptTokens := LUsage.GetValue<Integer>('prompt_tokens', 0);
          AUsage.CompletionTokens := LUsage.GetValue<Integer>(
            'completion_tokens',
            0
          );
          AUsage.TotalTokens := LUsage.GetValue<Integer>('total_tokens', 0);
        end;
      finally
        LRoot.Free;
      end;
    end,
    procedure(
      const AResponse: string;
      const AError: string;
      AFromCache: Boolean;
      const AUsage: TTokenUsage
    )
    begin
      ACallback(AResponse, AError);
    end
  );
end;

procedure TRadIALMStudioProvider.SendPromptAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TCompletionCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
  LHeaders: TNetHeaders;
  LApiKey: string;
begin
  LUrl := GetBaseUrl.TrimRight(['/']) + '/chat/completions';

  LApiKey := FConfig.GetApiKey(FProviderId);
  if LApiKey.IsEmpty then
    LApiKey := 'lm-studio'; { Dummy API Key since LM Studio is local and doesn't require auth }

  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + LApiKey);

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

procedure TRadIALMStudioProvider.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
  LHeaders: TNetHeaders;
  LApiKey: string;
begin
  LUrl := GetBaseUrl.TrimRight(['/']) + '/chat/completions';

  LApiKey := FConfig.GetApiKey(FProviderId);
  if LApiKey.IsEmpty then
    LApiKey := 'lm-studio'; { Dummy API Key }

  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + LApiKey);

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
      'LMStudio',
      'LM Studio',
      'http://localhost:1234/v1',
      False, { HasApiKey }
      True,  { HasCustomUrl }
      ['lms-default'],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIALMStudioProvider.Create(ACfg);
      end
    )
  );

end.
