unit RadIA.Provider.Ollama;

interface

uses
  System.SysUtils, RadIA.Core.Interfaces, RadIA.Core.InlineCompletion,
  RadIA.Core.TokenUsage, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIAOllamaProvider = class(
    TRadIAProviderBase,
    IRadIADedicatedFimProvider
  )
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
    procedure FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>); override;
    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
    procedure SendFimAsync(
      const AContext: TRadIAInlineCompletionContext;
      const ACallback: TRadIAFimCompletionCallback;
      const AMaxTokens: Integer
    );
    procedure ProcessStreamBuffer(var ABuffer: string; const ACallback: TStreamChunkCallback);
  end;

implementation

uses
  System.Classes, RadIA.Core.Types, System.JSON, System.Threading,
  System.Generics.Collections, System.Math, RadIA.Core.ProviderRegistry, System.SyncObjs,
  RadIA.Core.Logger;

{ TRadIAOllamaProvider }

constructor TRadIAOllamaProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'Ollama';
end;

procedure TRadIAOllamaProvider.SendFimAsync(
  const AContext: TRadIAInlineCompletionContext;
  const ACallback: TRadIAFimCompletionCallback;
  const AMaxTokens: Integer
);
var
  LOptions: TJSONObject;
  LRequest: TJSONObject;
  LRequestBody: string;
  LUrl: string;
begin
  LRequest := TJSONObject.Create;
  try
    LRequest.AddPair('model', GetActiveModel);
    LRequest.AddPair('prompt', AContext.Prefix);
    LRequest.AddPair('suffix', AContext.Suffix);
    LRequest.AddPair('stream', TJSONBool.Create(False));
    LOptions := TJSONObject.Create;
    LOptions.AddPair('temperature', TJSONNumber.Create(0));
    if AMaxTokens > 0 then
      LOptions.AddPair('num_predict', TJSONNumber.Create(AMaxTokens));
    LRequest.AddPair('options', LOptions);
    LRequestBody := LRequest.ToJSON;
  finally
    LRequest.Free;
  end;
  LUrl := FConfig.OllamaBaseUrl.TrimRight(['/']) + '/api/generate';
  ExecuteRequestAsync(
    LUrl,
    nil,
    LRequestBody,
    function(
      const AResponseJson: string;
      out AUsage: TTokenUsage
    ): string
    var
      LResponse: TJSONObject;
    begin
      AUsage := TTokenUsage.Empty;
      LResponse := TJSONObject.ParseJSONValue(AResponseJson) as TJSONObject;
      if not Assigned(LResponse) then
        raise EConvertError.Create('Invalid Ollama FIM response.');
      try
        Result := LResponse.GetValue<string>('response', '');
        AUsage.PromptTokens := LResponse.GetValue<Integer>(
          'prompt_eval_count',
          0
        );
        AUsage.CompletionTokens := LResponse.GetValue<Integer>(
          'eval_count',
          0
        );
        AUsage.TotalTokens := AUsage.PromptTokens + AUsage.CompletionTokens;
      finally
        LResponse.Free;
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

function TRadIAOllamaProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create('llama3:latest', 'codellama:latest', 'mistral:latest', 'phi3:latest');
end;

function TRadIAOllamaProvider.GetName: string;
begin
  Result := 'Ollama Local/Network';
end;

function TRadIAOllamaProvider.BuildRequestBody(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const AStream: Boolean; const ATemperature: Double; const AMaxTokens: Integer): string;
var
  LRootObj: TJSONObject;
  LMessagesArr: TJSONArray;
  LMsgObj: TJSONObject;
  LMsg: IRadIAChatMessage;
  LOptionsObj: TJSONObject;
begin
  LRootObj := TJSONObject.Create;
  try
    LRootObj.AddPair('model', GetActiveModel);
    LRootObj.AddPair('stream', TJSONBool.Create(AStream));

    LOptionsObj := TJSONObject.Create;
    if ATemperature >= 0.0 then
      LOptionsObj.AddPair('temperature', TJSONNumber.Create(ATemperature));
    if AMaxTokens > 0 then
      LOptionsObj.AddPair('num_predict', TJSONNumber.Create(AMaxTokens));

    if LOptionsObj.Count > 0 then
      LRootObj.AddPair('options', LOptionsObj)
    else
      LOptionsObj.Free;

    LMessagesArr := TJSONArray.Create;
    LRootObj.AddPair('messages', LMessagesArr);

    { Add History }
    for LMsg in AHistory do
    begin
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

    Result := LRootObj.ToJSON;
  finally
    LRootObj.Free;
  end;
end;

function TRadIAOllamaProvider.ParseResponseBody(const AResponseJson: string; out AUsage: TTokenUsage): string;
var
  LJsonObj: TJSONObject;
  LMsgObj: TJSONObject;
begin
  Result := '';
  AUsage := TTokenUsage.Empty;

  LJsonObj := TJSONObject.ParseJSONValue(AResponseJson) as TJSONObject;
  if Assigned(LJsonObj) then
  begin
    try
      LMsgObj := LJsonObj.GetValue('message') as TJSONObject;
      if Assigned(LMsgObj) then
      begin
        Result := LMsgObj.GetValue<string>('content', '');
      end;

      if Result.IsEmpty then
      begin
        if LJsonObj.GetValue('error') <> nil then
          raise Exception.Create(LJsonObj.GetValue('error').ToString);
      end;

      { Extract token usage }
      AUsage.PromptTokens     := LJsonObj.GetValue<Integer>('prompt_eval_count', 0);
      AUsage.CompletionTokens := LJsonObj.GetValue<Integer>('eval_count', 0);
      AUsage.TotalTokens      := AUsage.PromptTokens + AUsage.CompletionTokens;
    finally
      LJsonObj.Free;
    end;
  end;
end;

procedure TRadIAOllamaProvider.SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
begin
  LUrl := FConfig.OllamaBaseUrl + '/api/chat';

  try
    LRequestBody := BuildRequestBody(APrompt, AHistory, False, ATemperature, AMaxTokens);
  except
    on E: Exception do
    begin
      ACallback('', 'Error building request JSON: ' + E.Message, False, TTokenUsage.Empty);
      Exit;
    end;
  end;

  ExecuteRequestAsync(LUrl, nil, LRequestBody,
    function(const AResponseJson: string; out AUsage: TTokenUsage): string
    begin
      Result := ParseResponseBody(AResponseJson, AUsage);
    end, ACallback);
end;

function ParseOllamaModelsFromJson(const AJsonStr: string): TList<string>;
var
  LJson: TJSONObject;
  LModelsArr: TJSONArray;
  LVal: TJSONValue;
  LModelObj: TJSONObject;
  LName: string;
begin
  Result := TList<string>.Create;
  LJson := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
  if not Assigned(LJson) then Exit;
  try
    LModelsArr := LJson.GetValue('models') as TJSONArray;
    if Assigned(LModelsArr) then
    begin
      for LVal in LModelsArr do
      begin
        if LVal is TJSONObject then
        begin
          LModelObj := LVal as TJSONObject;
          LName := LModelObj.GetValue<string>('name', '');
          if not LName.IsEmpty then
            Result.Add(LName);
        end;
      end;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAOllamaProvider.FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>);
var
  LUrl: string;
  LTaskProc: TProc;
  LProviderRef: IRadIAProvider;
begin
  LProviderRef := Self;
  LUrl := FConfig.OllamaBaseUrl + '/api/tags';

  LTaskProc := procedure
               var
                 LResponseText: string;
                 LModelsList: TList<string>;
                 LModelsArray: TArray<string>;
                 LErrorMsg: string;
               begin
                 try
                   System.Math.SetExceptionMask(System.Math.exAllArithmeticExceptions);
                   LProviderRef.GetProviderId;

                   try
                     LResponseText := DoGetRequest(LUrl, nil, 5000);
                     LModelsList := ParseOllamaModelsFromJson(LResponseText);
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
                     finally
                       LModelsList.Free;
                     end;
                   except
                     on E: Exception do
                     begin
                       LErrorMsg := E.ClassName + ': ' + E.Message;
                       LModelsArray := GetAvailableModels;
                       if not GIsShuttingDown then
                       begin
                         TThread.Queue(nil,
                           TThreadProcedure(
                             procedure
                             begin
                               ACallback(LModelsArray, LErrorMsg);
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

procedure TRadIAOllamaProvider.ProcessStreamBuffer(var ABuffer: string; const ACallback: TStreamChunkCallback);
var
  LStopRequested: Boolean;
begin
  LStopRequested := False;
  ProcessBufferLines(ABuffer,
    procedure(ALine: string)
    var
      LJson: TJSONObject;
      LMsgObj: TJSONObject;
      LContent: string;
      LDone: Boolean;
    begin
      if LStopRequested then
        Exit;

      try
        LJson := TJSONObject.ParseJSONValue(ALine) as TJSONObject;
        if Assigned(LJson) then
        begin
          try
            LContent := '';
            LMsgObj := LJson.GetValue('message') as TJSONObject;
            if Assigned(LMsgObj) then
            begin
              LContent := LMsgObj.GetValue<string>('content', '');
            end;

            LDone := LJson.GetValue<Boolean>('done', False);

            if not LContent.IsEmpty then
            begin
              ACallback(LContent, False, '');
            end;

            if LDone then
            begin
              LStopRequested := True;
              ACallback('', True, '');
            end;
          finally
            LJson.Free;
          end;
        end;
      except
        on E: Exception do
          TLogger.Log('ProcessStreamBuffer (Ollama): Error parsing chunk JSON: ' + E.Message, 'Provider');
      end;
    end);
end;

procedure TRadIAOllamaProvider.SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LRequestBody: string;
begin
  LUrl := FConfig.OllamaBaseUrl + '/api/chat';

  try
    LRequestBody := BuildRequestBody(APrompt, AHistory, True, ATemperature, AMaxTokens);
  except
    on E: Exception do
    begin
      ACallback('', True, 'Error building request JSON: ' + E.Message);
      Exit;
    end;
  end;

  ExecuteRequestStreamAsync(LUrl, nil, LRequestBody,
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
      'Ollama',
      'Ollama Local/Network',
      'http://localhost:11434',
      False, // HasApiKey
      True, // HasCustomUrl
      ['llama3:latest', 'codellama:latest', 'mistral:latest', 'phi3:latest'],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAOllamaProvider.Create(ACfg);
      end
    )
  );

end.
