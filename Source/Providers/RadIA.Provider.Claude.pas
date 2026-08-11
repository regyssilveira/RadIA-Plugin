unit RadIA.Provider.Claude;

interface

uses  RadIA.Core.Interfaces, RadIA.Core.TokenUsage, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIAClaudeProvider = class(TRadIAProviderBase)
  private
    function BuildRequestBody(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const AStream: Boolean; const ATemperature: Double; const AMaxTokens: Integer): string;
    function ParseResponseBody(const AResponseJson: string; out AUsage: TTokenUsage): string;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
    procedure ProcessStreamBuffer(var ABuffer: string; const ACallback: TStreamChunkCallback);
  end;

implementation

uses
  System.JSON, RadIA.Core.ProviderRegistry, RadIA.Core.Logger, System.SysUtils, System.Net.URLClient, RadIA.Core.Types;

{ TRadIAClaudeProvider }

constructor TRadIAClaudeProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'Claude';
end;

function TRadIAClaudeProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create(
    MODEL_CLAUDE_SONNET_5,
    MODEL_CLAUDE_OPUS_5,
    MODEL_CLAUDE_FABLE_5
  );
end;

function TRadIAClaudeProvider.GetName: string;
begin
  Result := 'Anthropic Claude';
end;

function TRadIAClaudeProvider.BuildRequestBody(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const AStream: Boolean; const ATemperature: Double; const AMaxTokens: Integer): string;
var
  LRootObj: TJSONObject;
  LMessagesArr: TJSONArray;
  LMsgObj: TJSONObject;
  LMsg: IRadIAChatMessage;
  LSystemPrompt: string;
begin
  LRootObj := TJSONObject.Create;
  try
    LRootObj.AddPair('model', GetActiveModel);
    if AMaxTokens > 0 then
      LRootObj.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens))
    else
      LRootObj.AddPair('max_tokens', TJSONNumber.Create(4096));

    if AStream then
      LRootObj.AddPair('stream', TJSONBool.Create(True));

    LMessagesArr := TJSONArray.Create;
    LRootObj.AddPair('messages', LMessagesArr);

    LSystemPrompt := '';

    { Add History }
    for LMsg in AHistory do
    begin
      if LMsg.Role = mrSystem then
      begin
        LSystemPrompt := LSystemPrompt + LMsg.Content + sLineBreak;
        Continue;
      end;

      LMsgObj := TJSONObject.Create;
      LMessagesArr.AddElement(LMsgObj);
      LMsgObj.AddPair('role', MessageRoleToString(LMsg.Role));
      LMsgObj.AddPair('content', LMsg.Content);
    end;

    { Add Current Prompt }
    LMsgObj := TJSONObject.Create;
    LMessagesArr.AddElement(LMsgObj);
    LMsgObj.AddPair('role', 'user');
    LMsgObj.AddPair('content', APrompt);

    { Add System instruction if present }
    if not LSystemPrompt.IsEmpty then
    begin
      LRootObj.AddPair('system', LSystemPrompt.Trim);
    end;

    Result := LRootObj.ToJSON;
  finally
    LRootObj.Free;
  end;
end;

function TRadIAClaudeProvider.ParseResponseBody(const AResponseJson: string; out AUsage: TTokenUsage): string;
var
  LJsonObj: TJSONObject;
  LContentArr: TJSONArray;
  LContentObj: TJSONObject;
  LUsageNode: TJSONObject;
begin
  Result := '';
  AUsage := TTokenUsage.Empty;

  LJsonObj := TJSONObject.ParseJSONValue(AResponseJson) as TJSONObject;
  if Assigned(LJsonObj) then
  begin
    try
      LContentArr := LJsonObj.GetValue('content') as TJSONArray;
      if Assigned(LContentArr) and (LContentArr.Count > 0) then
      begin
        LContentObj := LContentArr[0] as TJSONObject;
        if Assigned(LContentObj) then
        begin
          Result := LContentObj.GetValue<string>('text', '');
        end;
      end;

      if Result.IsEmpty then
      begin
        if LJsonObj.GetValue('error') <> nil then
          raise Exception.Create(LJsonObj.GetValue('error').ToString);
      end;

      { Extract token usage }
      LUsageNode := LJsonObj.GetValue('usage') as TJSONObject;
      if Assigned(LUsageNode) then
      begin
        AUsage.PromptTokens     := LUsageNode.GetValue<Integer>('input_tokens', 0);
        AUsage.CompletionTokens := LUsageNode.GetValue<Integer>('output_tokens', 0);
        AUsage.TotalTokens      := AUsage.PromptTokens + AUsage.CompletionTokens;
      end;
    finally
      LJsonObj.Free;
    end;
  end;
end;

procedure TRadIAClaudeProvider.SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LApiKey, LRequestBody: string;
  LHeaders: TNetHeaders;
begin
  LApiKey := GetApiKey;
  if LApiKey.IsEmpty then
  begin
    ACallback('', 'API Key is missing for Anthropic Claude. Please check settings.', False, TTokenUsage.Empty);
    Exit;
  end;

  LUrl := 'https://api.anthropic.com/v1/messages';

  SetLength(LHeaders, 2);
  LHeaders[0] := TNetHeader.Create('x-api-key', LApiKey);
  LHeaders[1] := TNetHeader.Create('anthropic-version', '2023-06-01');

  try
    LRequestBody := BuildRequestBody(APrompt, AHistory, False, ATemperature, AMaxTokens);
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
      Result := ParseResponseBody(AResponseJson, AUsage);
    end, ACallback);
end;

procedure ProcessClaudeJsonLine(const AJsonLine: string; const ACallback: TStreamChunkCallback;
  var AStopRequested: Boolean);
var
  LJson, LDeltaObj: TJSONObject;
  LTypeStr, LText: string;
begin
  try
    LJson := TJSONObject.ParseJSONValue(AJsonLine) as TJSONObject;
    if not Assigned(LJson) then Exit;
    try
      LTypeStr := LJson.GetValue<string>('type', '');
      if SameText(LTypeStr, 'content_block_delta') then
      begin
        LDeltaObj := LJson.GetValue('delta') as TJSONObject;
        if Assigned(LDeltaObj) then
        begin
          LText := LDeltaObj.GetValue<string>('text', '');
          if not LText.IsEmpty then
            ACallback(LText, False, '');
        end;
      end
      else if SameText(LTypeStr, 'message_stop') then
      begin
        AStopRequested := True;
        ACallback('', True, '');
      end;
    finally
      LJson.Free;
    end;
  except
    on E: Exception do
      TLogger.Log('ProcessStreamBuffer (Claude): Error parsing chunk JSON: ' + E.Message, 'Provider');
  end;
end;

procedure TRadIAClaudeProvider.ProcessStreamBuffer(var ABuffer: string; const ACallback: TStreamChunkCallback);
var
  LStopRequested: Boolean;
begin
  LStopRequested := False;
  ProcessBufferLines(ABuffer,
    procedure(ALine: string)
    var
      LJsonLine: string;
    begin
      if LStopRequested then
        Exit;

      if ALine.StartsWith('data:') then
      begin
        LJsonLine := Trim(ALine.Substring(5));
        if not LJsonLine.IsEmpty then
          ProcessClaudeJsonLine(LJsonLine, ACallback, LStopRequested);
      end;
    end);
end;

procedure TRadIAClaudeProvider.SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LApiKey, LRequestBody: string;
  LHeaders: TNetHeaders;
begin
  LApiKey := GetApiKey;
  if LApiKey.IsEmpty then
  begin
    ACallback('', True, 'API Key is missing for Anthropic Claude. Please check settings.');
    Exit;
  end;

  LUrl := 'https://api.anthropic.com/v1/messages';

  SetLength(LHeaders, 2);
  LHeaders[0] := TNetHeader.Create('x-api-key', LApiKey);
  LHeaders[1] := TNetHeader.Create('anthropic-version', '2023-06-01');

  try
    LRequestBody := BuildRequestBody(APrompt, AHistory, True, ATemperature, AMaxTokens);
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
      ProcessStreamBuffer(LTemp, ACallback);
      Result := LTemp;
    end, ACallback);
end;

initialization
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'Claude',
      'Anthropic Claude',
      'https://api.anthropic.com',
      True, // HasApiKey
      False, // HasCustomUrl
      [MODEL_CLAUDE_SONNET_5, MODEL_CLAUDE_OPUS_5, MODEL_CLAUDE_FABLE_5],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAClaudeProvider.Create(ACfg);
      end
    )
  );

end.
