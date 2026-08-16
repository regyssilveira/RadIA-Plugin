unit RadIA.Provider.Base;

interface

uses
  System.SysUtils, System.Net.URLClient, System.SyncObjs,
  RadIA.Core.Interfaces, RadIA.Core.TokenUsage,
  RadIA.Core.HierarchicalSettings;

type
  TParserFunc = reference to function(const AResponseJson: string; out AUsage: TTokenUsage): string;
  TProcessBufferFunc = reference to function(const ABuffer: string): string;

  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  { Base class for AI Providers implementing IRadIAProvider }
  TRadIAProviderBase = class(
    TInterfacedObject,
    IRadIAProvider,
    IRadIAExecutionSettingsAwareProvider
  )
  protected
    FConfig: IRadIAConfig;
    FProviderId: string;
    FHTTPClient: IRadIAHttpClient;
    FErrorDecoder: IRadIAErrorDecoder;
    FCancelled: Boolean;
    FRefreshLock: TCriticalSection;
    FModelOverride: string;
    FTimeoutOverrideMs: Integer;

    function GetOAuthTokenUrl: string; virtual;
    function GetOAuthClientId: string; virtual;
    function GetOAuthClientSecret: string; virtual;
    function HasValidCredentials: Boolean; virtual;
    function GetAuthorizationHeader: string; virtual;

    function GetApiKey: string;
    function GetActiveModel: string;
    function GetEffectiveTimeoutMs: Integer;
    function DoPostRequest(const AUrl: string; const AHeaders: TNetHeaders;
      const ARequestBody: string): string;
    procedure DoPostRequestStream(const AUrl: string; const AHeaders: TNetHeaders;
      const ARequestBody: string; const AOnWrite: TProc<TBytes>);
    procedure DoPostRequestStreamString(const AUrl: string; const AHeaders: TNetHeaders;
      const ARequestBody: string; const AOnStringChunk: TProc<string>);
    function DoGetRequest(const AUrl: string; const AHeaders: TNetHeaders; const ATimeoutMs: Integer = 0): string;

    { Concurrency and stream orchestration helpers }
    procedure ExecuteRequestAsync(const AUrl: string; const AHeaders: TNetHeaders;
      const ARequestBody: string; const AParseFunc: TParserFunc;
      const ACallback: TCompletionCallback);
    procedure ExecuteRequestStreamAsync(const AUrl: string; const AHeaders: TNetHeaders;
      const ARequestBody: string; const AProcessBufferFunc: TProcessBufferFunc;
      const ACallback: TStreamChunkCallback);
    procedure ProcessBufferLines(var ABuffer: string; const ALineCallback: TProc<string>);
    procedure HandleStreamException(E: Exception; var ABufferText: string;
      const AProcessBufferFunc: TProcessBufferFunc; const ACallback: TStreamChunkCallback);

    { OpenAI-compatible helpers (shared by OpenAI, DeepSeek, Groq providers) }
    function BuildOpenAICompatibleRequestBody(const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>; const AStream: Boolean;
      const ATemperature: Double; const AMaxTokens: Integer): string;
    function ParseOpenAICompatibleResponse(const AResponseJson: string;
      out AUsage: TTokenUsage): string;
    procedure ProcessOpenAICompatibleStreamBuffer(var ABuffer: string;
      const ACallback: TStreamChunkCallback);

    { Hook for providers that support model discovery via /models endpoint.
      Subclasses must return the base URL (without path) and optionally
      override FilterModelId to apply provider-specific filtering. }
    function GetModelsDiscoveryUrl: string; virtual;
    function FilterModelId(const AId: string): Boolean; virtual;
  public
    constructor Create(const AConfig: IRadIAConfig); virtual;
    destructor Destroy; override;

    { IRadIAProvider implementation }
    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); virtual; abstract;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); virtual;
    procedure FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>); virtual;
    function GetAvailableModels: TArray<string>; virtual; abstract;
    function GetName: string; virtual; abstract;
    function GetProviderId: string;
    procedure CancelCurrentRequest; virtual;
    procedure ApplyExecutionSettings(
      const ASettings: TRadIAExecutionSettings
    );
  end;

  { Ancestor class for OpenAI-compatible providers (OpenAI, DeepSeek, Groq) }
  TRadIAOpenAICompatibleProvider = class(TRadIAProviderBase)
  protected
    function GetBaseUrl: string; virtual; abstract;
    function GetAuthorizationHeader: string; override;
  public
    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
  end;

implementation

uses
  System.JSON, System.Generics.Collections, System.Math, RadIA.Core.Logger,
  RadIA.Core.Container, RadIA.Core.HttpClient, RadIA.Core.ErrorDecoder, System.Classes, System.Net.HttpClient,
      System.Threading, RadIA.Core.Types, RadIA.Provider.Streaming, RadIA.Core.OAuth, System.DateUtils,
      RadIA.Core.ToolSecurity;

const
  CLogPreviewMaxLength = 320;

function MaskHeaders(const AHeaders: TNetHeaders): string;
var
  LHeader: TNetHeader;
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    for LHeader in AHeaders do
    begin
      if SameText(LHeader.Name, 'Authorization') or
         SameText(LHeader.Name, 'api-key') or
         SameText(LHeader.Name, 'x-api-key') or
         LHeader.Name.ToLower.Contains('key') or
         LHeader.Name.ToLower.Contains('token') then
      begin
        LList.Add(LHeader.Name + ': [MASKED]');
      end
      else
      begin
        LList.Add(LHeader.Name + ': ' + LHeader.Value);
      end;
    end;
    Result := LList.Text.Replace(#13#10, ', ').Trim([',', ' ']);
  finally
    LList.Free;
  end;
end;

function SanitizePayloadPreview(const APayload: string): string;
var
  LRedactor: IRadIASecretRedactor;
begin
  Result := APayload.Replace(#13, ' ').Replace(#10, ' ').Trim;
  { Redact before truncating: cutting first could split a secret and defeat the patterns }
  if TRadIAContainer.TryResolve<IRadIASecretRedactor>(LRedactor) then
    Result := LRedactor.Redact(Result);
  if Length(Result) > CLogPreviewMaxLength then
    Result := Copy(Result, 1, CLogPreviewMaxLength) + '...';
end;

procedure LogPayloadSummary(const AOperation, ALabel, APayload: string);
begin
  TLogger.Log(
    Format('%s: %s length=%d preview=%s',
      [AOperation, ALabel, Length(APayload), SanitizePayloadPreview(APayload)]),
    'Provider');
end;

function ExtractErrorMessageFromJson(const AJsonStr: string): string;
var
  LJson: TJSONObject;
  LError: TJSONObject;
begin
  Result := '';
  try
    LJson := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
    if Assigned(LJson) then
    begin
      try
        // Caso 1: {"error": {"message": "..."}}
        LError := LJson.GetValue('error') as TJSONObject;
        if Assigned(LError) then
        begin
          Result := LError.GetValue<string>('message', '');
          if Result.IsEmpty then
            Result := LError.GetValue<string>('msg', '');
        end;

        // Caso 2: {"error": "..."}
        if Result.IsEmpty then
          Result := LJson.GetValue<string>('error', '');

        // Caso 3: {"message": "..."}
        if Result.IsEmpty then
          Result := LJson.GetValue<string>('message', '');
      finally
        LJson.Free;
      end;
    end;
  except
    on E: Exception do
      TLogger.Log('ExtractErrorMessageFromJson: Failed to parse JSON error response: ' + E.Message, 'Provider');
  end;
end;

constructor TRadIAProviderBase.Create(const AConfig: IRadIAConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FRefreshLock := TCriticalSection.Create;
  FTimeoutOverrideMs := -1;

  if not TRadIAContainer.TryResolve<IRadIAHttpClient>(FHTTPClient) then
    FHTTPClient := TRadIAConcreteHttpClient.Create;

  if not TRadIAContainer.TryResolve<IRadIAErrorDecoder>(FErrorDecoder) then
    FErrorDecoder := TRadIAErrorDecoder.Create;

  FProviderId := '';
end;

destructor TRadIAProviderBase.Destroy;
begin
  FHTTPClient := nil;
  FErrorDecoder := nil;
  FRefreshLock.Free;
  inherited Destroy;
end;

function TRadIAProviderBase.GetApiKey: string;
begin
  Result := FConfig.GetApiKey(FProviderId);
end;

function TRadIAProviderBase.GetActiveModel: string;
begin
  if FModelOverride <> '' then
    Result := FModelOverride
  else
    Result := FConfig.GetActiveModel(FProviderId);
end;

function TRadIAProviderBase.GetEffectiveTimeoutMs: Integer;
begin
  if FTimeoutOverrideMs >= 0 then
    Result := FTimeoutOverrideMs
  else
    Result := FConfig.GetTimeout(FProviderId) * 1000;
  if Result <= 0 then
    Result := 60000;
end;

procedure TRadIAProviderBase.ApplyExecutionSettings(
  const ASettings: TRadIAExecutionSettings
);
begin
  if ASettings.HasModel then
    FModelOverride := ASettings.ModelId
  else
    FModelOverride := '';
  if ASettings.HasTimeout then
    FTimeoutOverrideMs := ASettings.TimeoutMs
  else
    FTimeoutOverrideMs := -1;
end;

function TRadIAProviderBase.GetProviderId: string;
begin
  Result := FProviderId;
end;

function TRadIAProviderBase.GetOAuthTokenUrl: string;
begin
  Result := '';
end;

function TRadIAProviderBase.GetOAuthClientId: string;
begin
  Result := '';
end;

function TRadIAProviderBase.GetOAuthClientSecret: string;
begin
  Result := '';
end;

procedure TRadIAProviderBase.CancelCurrentRequest;
begin
  TLogger.Log('CancelCurrentRequest: Requesting cancellation (FCancelled := True)', 'Provider');
  FCancelled := True;
  FHTTPClient.Cancel;
end;

function TRadIAProviderBase.DoGetRequest(const AUrl: string; const AHeaders: TNetHeaders;
    const ATimeoutMs: Integer = 0): string;
var
  LTimeoutMs: Integer;
begin
  TLogger.Log(Format('DoGetRequest: URL=%s', [AUrl]), 'Provider');
  TLogger.Log(Format('DoGetRequest: Headers=[%s]', [MaskHeaders(AHeaders)]), 'Provider');

  FCancelled := False;
  if ATimeoutMs > 0 then
    LTimeoutMs := ATimeoutMs
  else
    LTimeoutMs := GetEffectiveTimeoutMs;

  try
    Result := FHTTPClient.Get(AUrl, AHeaders, LTimeoutMs);
    TLogger.Log(Format('DoGetRequest: Response length=%d', [Length(Result)]), 'Provider');
  except
    on E: ERadIAHttpException do
    begin
      var LDecodedError := FErrorDecoder.DecodeError(E.StatusCode, E.Content);
      TLogger.Log(Format('DoGetRequest: HTTP Error: %s', [LDecodedError]), 'Provider');
      raise Exception.Create(LDecodedError);
    end;
    on E: Exception do
    begin
      TLogger.Log(Format('DoGetRequest: Exception occurred: %s', [E.Message]), 'Provider');
      raise;
    end;
  end;
end;

function TRadIAProviderBase.DoPostRequest(const AUrl: string; const AHeaders: TNetHeaders;
  const ARequestBody: string): string;
var
  LTimeoutMs: Integer;
begin
  TLogger.Log(Format('DoPostRequest: URL=%s', [AUrl]), 'Provider');
  TLogger.Log(Format('DoPostRequest: Headers=[%s]', [MaskHeaders(AHeaders)]), 'Provider');
  LogPayloadSummary('DoPostRequest', 'Request body', ARequestBody);

  FCancelled := False;
  LTimeoutMs := GetEffectiveTimeoutMs;

  try
    Result := FHTTPClient.Post(AUrl, AHeaders, ARequestBody, LTimeoutMs);
    LogPayloadSummary('DoPostRequest', 'Response body', Result);
  except
    on E: ERadIAHttpException do
    begin
      var LDecodedError := FErrorDecoder.DecodeError(E.StatusCode, E.Content);
      TLogger.Log(Format('DoPostRequest: HTTP Error: %s', [LDecodedError]), 'Provider');
      raise Exception.Create(LDecodedError);
    end;
    on E: Exception do
    begin
      TLogger.Log(Format('DoPostRequest: Exception occurred: %s', [E.Message]), 'Provider');
      raise;
    end;
  end;
end;

procedure TRadIAProviderBase.DoPostRequestStream(const AUrl: string; const AHeaders: TNetHeaders;
  const ARequestBody: string; const AOnWrite: TProc<TBytes>);
var
  LTimeoutMs: Integer;
begin
  TLogger.Log(Format('DoPostRequestStream: URL=%s', [AUrl]), 'Provider');
  TLogger.Log(Format('DoPostRequestStream: Headers=[%s]', [MaskHeaders(AHeaders)]), 'Provider');
  LogPayloadSummary('DoPostRequestStream', 'Request body', ARequestBody);

  FCancelled := False;
  LTimeoutMs := GetEffectiveTimeoutMs;

  try
    FHTTPClient.PostStream(AUrl, AHeaders, ARequestBody, AOnWrite, LTimeoutMs);
  except
    on E: ERadIAHttpException do
    begin
      var LDecodedError := FErrorDecoder.DecodeError(E.StatusCode, E.Content);
      TLogger.Log(Format('DoPostRequestStream: HTTP Error: %s', [LDecodedError]), 'Provider');
      raise Exception.Create(LDecodedError);
    end;
    on E: Exception do
    begin
      TLogger.Log(Format('DoPostRequestStream: Exception occurred: %s', [E.Message]), 'Provider');
      raise;
    end;
  end;
end;

procedure TRadIAProviderBase.DoPostRequestStreamString(const AUrl: string; const AHeaders: TNetHeaders;
  const ARequestBody: string; const AOnStringChunk: TProc<string>);
var
  LDecoder: TRadIAUtf8ChunkDecoder;
begin
  LDecoder := TRadIAUtf8ChunkDecoder.Create;
  try
    DoPostRequestStream(AUrl, AHeaders, ARequestBody,
      procedure(ABytes: TBytes)
      var
        LDecodedStr: string;
      begin
        if Assigned(AOnStringChunk) then
        begin
          LDecodedStr := LDecoder.Decode(ABytes);
          if not LDecodedStr.IsEmpty then
            AOnStringChunk(LDecodedStr);
        end;
      end);
  finally
    LDecoder.Free;
  end;
end;

procedure TRadIAProviderBase.ExecuteRequestAsync(const AUrl: string; const AHeaders: TNetHeaders;
  const ARequestBody: string; const AParseFunc: TParserFunc;
  const ACallback: TCompletionCallback);
var
  LTaskProc: TProc;
  LProviderRef: IRadIAProvider;
begin
  LProviderRef := Self;
  LTaskProc :=
    procedure
    var
      LResponseText: string;
      LUsage: TTokenUsage;
      LErrorMsg: string;
    begin
      try
        System.Math.SetExceptionMask(System.Math.exAllArithmeticExceptions);
        LProviderRef.GetProviderId;
        try
          LResponseText := DoPostRequest(AUrl, AHeaders, ARequestBody);
          LResponseText := AParseFunc(LResponseText, LUsage);

          if not GIsShuttingDown then
          begin
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  ACallback(LResponseText, '', False, LUsage);
                end
              )
            );
          end;
        except
          on E: Exception do
          begin
            LErrorMsg := E.ClassName + ': ' + E.Message;
            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                TThreadProcedure(
                  procedure
                  begin
                    ACallback('', LErrorMsg, False, TTokenUsage.Empty);
                  end
                )
              );
            end;
          end;
        end;
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end;

  TInterlocked.Increment(GActiveThreadCount);
  TTask.Run(LTaskProc);
end;

procedure ProcessResidualBuffer(var ABufferText: string;
  AProcessBufferFunc: TProcessBufferFunc; const AContext: string);
begin
  if ABufferText.IsEmpty then Exit;

  if not ABufferText.EndsWith(#10) then
    ABufferText := ABufferText + #10;
  try
    AProcessBufferFunc(ABufferText);
  except
    on E: Exception do
      TLogger.Log('ExecuteRequestStreamAsync: Exception on processing residual buffer ' +
        AContext + ': ' + E.Message, 'Provider');
  end;
end;

procedure TRadIAProviderBase.ExecuteRequestStreamAsync(const AUrl: string; const AHeaders: TNetHeaders;
  const ARequestBody: string; const AProcessBufferFunc: TProcessBufferFunc;
  const ACallback: TStreamChunkCallback);
var
  LTaskProc: TProc;
  LProviderRef: IRadIAProvider;
begin
  LProviderRef := Self;
  LTaskProc :=
    procedure
    var
      LBufferText: string;
    begin
      try
        System.Math.SetExceptionMask(System.Math.exAllArithmeticExceptions);
        LProviderRef.GetProviderId;
        LBufferText := '';
        try
          DoPostRequestStreamString(AUrl, AHeaders, ARequestBody,
            procedure(AChunk: string)
            begin
              LBufferText := LBufferText + AChunk;
              LBufferText := AProcessBufferFunc(LBufferText);
            end);

          // Process residual data in buffer after network stream completes
          ProcessResidualBuffer(LBufferText, AProcessBufferFunc, 'normal end');

          if not GIsShuttingDown then
          begin
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  ACallback('', True, '');
                end
              )
            );
          end;
        except
          on E: Exception do
          begin
            (LProviderRef as TRadIAProviderBase).HandleStreamException(E, LBufferText, AProcessBufferFunc, ACallback);
          end;
        end;
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end;

  TInterlocked.Increment(GActiveThreadCount);
  TTask.Run(LTaskProc);
end;

procedure TRadIAProviderBase.HandleStreamException(E: Exception; var ABufferText: string;
  const AProcessBufferFunc: TProcessBufferFunc; const ACallback: TStreamChunkCallback);
var
  LErrorMsg: string;
  LJsonError: string;
begin
  ProcessResidualBuffer(ABufferText, AProcessBufferFunc, 'in error handler');

  LErrorMsg := E.Message;
  if (E is ENetHTTPClientException) or SameText(E.ClassName, 'ENetHTTPClientException') then
  begin
    LJsonError := ExtractErrorMessageFromJson(ABufferText);
    if not LJsonError.IsEmpty then
      LErrorMsg := LErrorMsg + ' Response: ' + LJsonError
    else if not ABufferText.Trim.IsEmpty then
      LErrorMsg := LErrorMsg + ' Response: ' + ABufferText.Trim;
  end;
  LErrorMsg := E.ClassName + ': ' + LErrorMsg;

  if not GIsShuttingDown then
  begin
    TThread.Queue(nil,
      TThreadProcedure(
        procedure
        begin
          ACallback('', True, LErrorMsg);
        end
      )
    );
  end;
end;

procedure TRadIAProviderBase.ProcessBufferLines(var ABuffer: string; const ALineCallback: TProc<string>);
var
  LLine: string;
  LIdx: Integer;
  LStartPos: Integer;
  LPtr: PChar;
  LLen: Integer;
  LLastProcessedPos: Integer;
begin
  LLen := ABuffer.Length;
  if LLen = 0 then
    Exit;

  LPtr := PChar(ABuffer);
  LStartPos := 0;
  LLastProcessedPos := 0;

  while LStartPos < LLen do
  begin
    LIdx := LStartPos;
    while (LIdx < LLen) and (LPtr[LIdx] <> #10) do
      Inc(LIdx);

    if LIdx >= LLen then
      Break;

    LLine := ABuffer.Substring(LStartPos, LIdx - LStartPos);
    LStartPos := LIdx + 1;
    LLastProcessedPos := LStartPos;

    LLine := Trim(LLine);
    if not LLine.IsEmpty then
    begin
      ALineCallback(LLine);
    end;
  end;

  if LLastProcessedPos > 0 then
    ABuffer := ABuffer.Substring(LLastProcessedPos);
end;

procedure TRadIAProviderBase.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
begin
  { Default fallback simulating streaming }
  SendPromptAsync(APrompt, AHistory,
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    var
      LResCopy: string;
      LErrCopy: string;
    begin
      LResCopy := AResponse;
      LErrCopy := AError;
      if not GIsShuttingDown then
      begin
        TThread.Queue(nil,
          TThreadProcedure(
            procedure
            begin
              ACallback(LResCopy, True, LErrCopy);
            end
          )
        );
      end;
    end, ATemperature, AMaxTokens);
end;

{ --- OpenAI-Compatible Shared Helpers --- }

function TRadIAProviderBase.BuildOpenAICompatibleRequestBody(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const AStream: Boolean;
  const ATemperature: Double; const AMaxTokens: Integer): string;
var
  LRootObj: TJSONObject;
  LMessagesArr: TJSONArray;
  LMsgObj: TJSONObject;
  LMsg: IRadIAChatMessage;
begin
  LRootObj := TJSONObject.Create;
  try
    LRootObj.AddPair('model', GetActiveModel);
    if AStream then
      LRootObj.AddPair('stream', TJSONBool.Create(True));

    if ATemperature >= 0.0 then
      LRootObj.AddPair('temperature', TJSONNumber.Create(ATemperature));
    if AMaxTokens > 0 then
      LRootObj.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens));

    LMessagesArr := TJSONArray.Create;
    LRootObj.AddPair('messages', LMessagesArr);

    { Add history messages }
    for LMsg in AHistory do
    begin
      LMsgObj := TJSONObject.Create;
      LMessagesArr.AddElement(LMsgObj);
      LMsgObj.AddPair('role', MessageRoleToString(LMsg.Role));
      LMsgObj.AddPair('content', LMsg.Content);
    end;

    { Add current user prompt }
    LMsgObj := TJSONObject.Create;
    LMessagesArr.AddElement(LMsgObj);
    LMsgObj.AddPair('role', 'user');
    LMsgObj.AddPair('content', APrompt);

    Result := LRootObj.ToJSON;
  finally
    LRootObj.Free;
  end;
end;

function TRadIAProviderBase.ParseOpenAICompatibleResponse(const AResponseJson: string;
  out AUsage: TTokenUsage): string;
var
  LJsonObj: TJSONObject;
  LChoices: TJSONArray;
  LChoice: TJSONObject;
  LMessage: TJSONObject;
  LUsageNode: TJSONObject;
begin
  Result := '';
  AUsage := TTokenUsage.Empty;

  LJsonObj := TJSONObject.ParseJSONValue(AResponseJson) as TJSONObject;
  if not Assigned(LJsonObj) then
    Exit;

  try
    { Extract text from choices[0].message.content }
    LChoices := LJsonObj.GetValue('choices') as TJSONArray;
    if Assigned(LChoices) and (LChoices.Count > 0) then
    begin
      LChoice := LChoices[0] as TJSONObject;
      LMessage := LChoice.GetValue('message') as TJSONObject;
      if Assigned(LMessage) then
        Result := LMessage.GetValue<string>('content', '');
    end;

    { Check for API error node }
    if Result.IsEmpty and Assigned(LJsonObj.GetValue('error')) then
      raise Exception.Create(LJsonObj.GetValue('error').ToString);

    { Extract token usage }
    LUsageNode := LJsonObj.GetValue('usage') as TJSONObject;
    if Assigned(LUsageNode) then
    begin
      AUsage.PromptTokens     := LUsageNode.GetValue<Integer>('prompt_tokens', 0);
      AUsage.CompletionTokens := LUsageNode.GetValue<Integer>('completion_tokens', 0);
      AUsage.TotalTokens      := LUsageNode.GetValue<Integer>('total_tokens', 0);
    end;
  finally
    LJsonObj.Free;
  end;
end;

procedure ProcessOpenAIJsonLine(const AJsonLine: string; const ACallback: TStreamChunkCallback; var ADone: Boolean);
var
  LJson, LChoice, LDelta: TJSONObject;
  LChoices: TJSONArray;
  LContent: string;
begin
  if AJsonLine = '[DONE]' then
  begin
    ACallback('', True, '');
    ADone := True;
    Exit;
  end;

  try
    LJson := TJSONObject.ParseJSONValue(AJsonLine) as TJSONObject;
    if Assigned(LJson) then
    begin
      try
        LChoices := LJson.GetValue('choices') as TJSONArray;
        if Assigned(LChoices) and (LChoices.Count > 0) then
        begin
          LChoice := LChoices[0] as TJSONObject;
          LDelta := LChoice.GetValue('delta') as TJSONObject;
          if Assigned(LDelta) then
          begin
            LContent := LDelta.GetValue<string>('content', '');
            if not LContent.IsEmpty then
              ACallback(LContent, False, '');
          end;
        end;
      finally
        LJson.Free;
      end;
    end;
  except
    on E: Exception do
      TLogger.Log('ProcessOpenAICompatibleStreamBuffer: Error parsing chunk JSON: ' + E.Message, 'Provider');
  end;
end;

procedure TRadIAProviderBase.ProcessOpenAICompatibleStreamBuffer(var ABuffer: string;
  const ACallback: TStreamChunkCallback);
var
  LDone: Boolean;
begin
  LDone := False;
  ProcessBufferLines(ABuffer,
    procedure(ALine: string)
    var
      LJsonLine: string;
    begin
      if LDone then Exit;

      if ALine.Trim.StartsWith('data:') then
      begin
        LJsonLine := Trim(ALine.Trim.Substring(5));
        ProcessOpenAIJsonLine(LJsonLine, ACallback, LDone);
      end;
    end);
end;

{ --- Model Discovery Hook (for OpenAI-compatible /models endpoints) --- }

function TRadIAProviderBase.GetModelsDiscoveryUrl: string;
begin
  Result := '';
end;

function TRadIAProviderBase.FilterModelId(const AId: string): Boolean;
begin
  Result := not AId.IsEmpty;
end;

function ParseOpenAIModelsFromJson(const AJsonStr: string; AFilterFunc: TFunc<string, Boolean>): TList<string>;
var
  LJson: TJSONObject;
  LData: TJSONArray;
  LVal: TJSONValue;
  LId: string;
  I: Integer;
begin
  Result := TList<string>.Create;
  LJson := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
  if not Assigned(LJson) then Exit;
  try
    LData := LJson.GetValue('data') as TJSONArray;
    if Assigned(LData) then
    begin
      for I := 0 to LData.Count - 1 do
      begin
        LVal := LData[I];
        if LVal.TryGetValue<string>('id', LId) then
        begin
          if (not Assigned(AFilterFunc)) or AFilterFunc(LId) then
            Result.Add(LId);
        end;
      end;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAProviderBase.FetchAvailableModelsAsync(
  const ACallback: TProc<TArray<string>, string>);
var
  LUrl: string;
  LHeaders: TNetHeaders;
  LTaskProc: TProc;
  LProviderRef: IRadIAProvider;
  FallbackToDefaultModels: TProc<string>;
begin
  LProviderRef := Self;

  FallbackToDefaultModels := procedure(AReason: string)
  begin
    if not GIsShuttingDown then
    begin
      TThread.Queue(nil,
        TThreadProcedure(
          procedure
          var
            LModels: TArray<string>;
          begin
            LModels := GetAvailableModels;
            ACallback(LModels, AReason);
          end
        )
      );
    end;
  end;

  LUrl := GetModelsDiscoveryUrl;

  { Providers that do not supply a discovery URL fall back to static list }
  if LUrl.IsEmpty then
  begin
    FallbackToDefaultModels('');
    Exit;
  end;

  if not HasValidCredentials then
  begin
    FallbackToDefaultModels(Format(
      'Credentials (API Key or OAuth Token) are missing or invalid for %s.',
      [GetName]));
    Exit;
  end;

  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Authorization', GetAuthorizationHeader);

  LTaskProc :=
    procedure
    var
      LResponseText: string;
      LModelsList: TList<string>;
      LModelsArray: TArray<string>;
      LErrorMsg: string;
    begin
      LProviderRef.GetProviderId;
      LModelsList := TList<string>.Create;
      try
        try
          LResponseText := DoGetRequest(LUrl, LHeaders, 5000); // Fast 5-second timeout for model discovery
          LModelsList := ParseOpenAIModelsFromJson(LResponseText,
            function(AId: string): Boolean
            begin
              Result := FilterModelId(AId);
            end);
          try
            LModelsList.Sort;

            if LModelsList.Count = 0 then
              LModelsArray := GetAvailableModels
            else
              LModelsArray := LModelsList.ToArray;

            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                TThreadProcedure(
                  procedure
                  begin
                    ACallback(LModelsArray, '');
                  end
                )
              );
            end;
          except
            on E: Exception do
            begin
              LErrorMsg := E.ClassName + ': ' + E.Message;
              FallbackToDefaultModels(LErrorMsg);
            end;
          end;
        finally
          LModelsList.Free;
        end;
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end;

  TInterlocked.Increment(GActiveThreadCount);
  TTask.Run(LTaskProc);
end;

{ TRadIAOpenAICompatibleProvider }

function TRadIAOpenAICompatibleProvider.GetAuthorizationHeader: string;
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
    Result := 'Bearer ' + FConfig.GetOAuthAccessToken(FProviderId)
  else
    Result := 'Bearer ' + GetApiKey;
end;

function TRadIAProviderBase.GetAuthorizationHeader: string;
begin
  Result := 'Bearer ' + GetApiKey;
end;

function TRadIAProviderBase.HasValidCredentials: Boolean;
var
  LAuthType: string;
  LOAuth: TRadIAOAuthManager;
  LTokenUrl, LClientId, LClientSecret: string;
begin
  LAuthType := FConfig.GetProviderAuthType(FProviderId);
  if SameText(LAuthType, 'oauth') then
  begin
    FRefreshLock.Acquire;
    try
      if FConfig.GetOAuthAccessToken(FProviderId).IsEmpty or
         ((FConfig.GetOAuthTokenExpiry(FProviderId) <> 0) and
          (FConfig.GetOAuthTokenExpiry(FProviderId) <= System.DateUtils.IncMinute(Now, 5))) then
      begin
        LTokenUrl := GetOAuthTokenUrl;
        LClientId := GetOAuthClientId;
        LClientSecret := GetOAuthClientSecret;
        if (not LTokenUrl.IsEmpty) and (not LClientId.IsEmpty) then
        begin
          LOAuth := TRadIAOAuthManager.Create(FConfig, nil);
          try
            LOAuth.RefreshAccessToken(FProviderId, LTokenUrl, LClientId, LClientSecret);
          finally
            LOAuth.Free;
          end;
        end;
      end;
    finally
      FRefreshLock.Release;
    end;
    Result := not FConfig.GetOAuthAccessToken(FProviderId).IsEmpty;
  end
  else
    Result := not GetApiKey.IsEmpty;
end;

procedure TRadIAOpenAICompatibleProvider.SendPromptAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TCompletionCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
  LHeaders: TNetHeaders;
begin
  if not HasValidCredentials then
  begin
    ACallback('',
      Format('Credentials (API Key or OAuth Token) are missing or ' +
      'invalid for %s. Please check settings.', [GetName]),
      False, TTokenUsage.Empty);
    Exit;
  end;

  LUrl := GetBaseUrl.TrimRight(['/']) + '/chat/completions';
  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Authorization', GetAuthorizationHeader);

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

procedure TRadIAOpenAICompatibleProvider.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
  LHeaders: TNetHeaders;
begin
  if not HasValidCredentials then
  begin
    ACallback('', True,
      Format('Credentials (API Key or OAuth Token) are missing or ' +
      'invalid for %s. Please check settings.', [GetName]));
    Exit;
  end;

  LUrl := GetBaseUrl.TrimRight(['/']) + '/chat/completions';
  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Authorization', GetAuthorizationHeader);

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

end.
