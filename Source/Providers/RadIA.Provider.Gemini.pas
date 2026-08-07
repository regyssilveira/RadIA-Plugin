unit RadIA.Provider.Gemini;

interface

uses
  System.SysUtils, RadIA.Core.Interfaces, RadIA.Core.TokenUsage, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIAGeminiProvider = class(TRadIAProviderBase)
  private
    function BuildRequestBody(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ATemperature: Double; const AMaxTokens: Integer): string;
    function ParseResponseBody(const AResponseJson: string; out AUsage: TTokenUsage): string;
    function TryExtractNextJsonObject(var ABuffer: string; out AJsonObjectStr: string): Boolean;
    procedure ParseAndEmitCandidate(const AJsonStr: string; const ACallback: TStreamChunkCallback);
  protected
    function GetOAuthTokenUrl: string; override;
    function GetOAuthClientId: string; override;
    function GetOAuthClientSecret: string; override;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>); override;
    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
    procedure ProcessStreamBuffer(var ABuffer: string; const ACallback: TStreamChunkCallback);
  end;

implementation

uses
  System.Classes, RadIA.Core.Types, System.JSON, System.Threading,
  System.Generics.Collections, System.NetEncoding, System.SyncObjs, System.Math,
  RadIA.Core.Logger, RadIA.Core.ProviderRegistry, System.Net.URLClient,
  System.StrUtils;

{ TRadIAGeminiProvider }

constructor TRadIAGeminiProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'Gemini';
end;

function TRadIAGeminiProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create(
    MODEL_GEMINI_36_FLASH,
    MODEL_GEMINI_35_FLASH,
    MODEL_GEMINI_35_FLASH_LITE
  );
end;

function TRadIAGeminiProvider.GetName: string;
begin
  Result := 'Google Gemini';
end;

function TRadIAGeminiProvider.GetOAuthTokenUrl: string;
begin
  Result := 'https://oauth2.googleapis.com/token';
end;

function TRadIAGeminiProvider.GetOAuthClientId: string;
begin
  Result := System.StrUtils.ReverseString('moc.tnetnocresuelgoog.sppa.bm93j27b6j1mhfoujc93iftrt8p1od3c-8145760122101');
end;

function TRadIAGeminiProvider.GetOAuthClientSecret: string;
begin
  Result := System.StrUtils.ReverseString('WcEIfowAsH-6TninMcAapRtWvzkI-XPSCOG');
end;

function TRadIAGeminiProvider.BuildRequestBody(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const ATemperature: Double; const AMaxTokens: Integer): string;
var
  LRootObj: TJSONObject;
  LContentsArr: TJSONArray;
  LMsg: IRadIAChatMessage;
  LRoleStr: string;
  LSystemPrompt: string;
  LSystemObj: TJSONObject;
  LSystemPartsArr: TJSONArray;
  LSystemPartObj: TJSONObject;
  LGenConfigObj: TJSONObject;

  procedure AddMessageToContent(const AMsgContent, ARoleStr: string);
  var
    LContentObj, LPartObj: TJSONObject;
    LPartsArr: TJSONArray;
  begin
    LContentObj := TJSONObject.Create;
    LContentsArr.AddElement(LContentObj);
    LContentObj.AddPair('role', ARoleStr);

    LPartsArr := TJSONArray.Create;
    LContentObj.AddPair('parts', LPartsArr);

    LPartObj := TJSONObject.Create;
    LPartsArr.AddElement(LPartObj);
    LPartObj.AddPair('text', AMsgContent);
  end;

begin
  LRootObj := TJSONObject.Create;
  try
    LContentsArr := TJSONArray.Create;
    LRootObj.AddPair('contents', LContentsArr);

    LSystemPrompt := '';

    { Add History }
    for LMsg in AHistory do
    begin
      if LMsg.Role = mrSystem then
      begin
        LSystemPrompt := LSystemPrompt + LMsg.Content + sLineBreak;
        Continue;
      end;

      if LMsg.Role = mrAssistant then
        LRoleStr := 'model'
      else
        LRoleStr := 'user';

      AddMessageToContent(LMsg.Content, LRoleStr);
    end;

    { Add Current Prompt }
    AddMessageToContent(APrompt, 'user');

    { Add System Instruction if present }
    if not LSystemPrompt.IsEmpty then
    begin
      LSystemObj := TJSONObject.Create;
      LRootObj.AddPair('systemInstruction', LSystemObj);

      LSystemPartsArr := TJSONArray.Create;
      LSystemObj.AddPair('parts', LSystemPartsArr);

      LSystemPartObj := TJSONObject.Create;
      LSystemPartsArr.AddElement(LSystemPartObj);
      LSystemPartObj.AddPair('text', LSystemPrompt.Trim);
    end;

    { Add Generation Config }
    LGenConfigObj := TJSONObject.Create;
    if ATemperature >= 0.0 then
      LGenConfigObj.AddPair('temperature', TJSONNumber.Create(ATemperature));
    if AMaxTokens > 0 then
      LGenConfigObj.AddPair('maxOutputTokens', TJSONNumber.Create(AMaxTokens));

    if LGenConfigObj.Count > 0 then
      LRootObj.AddPair('generationConfig', LGenConfigObj)
    else
      LGenConfigObj.Free;

    Result := LRootObj.ToJSON;
  finally
    LRootObj.Free;
  end;
end;

function TryGetCandidateText(AJson: TJSONObject; out AText: string): Boolean;
var
  LCandidates: TJSONArray;
  LCandidate, LContent, LPart: TJSONObject;
  LParts: TJSONArray;
begin
  Result := False;
  AText := '';

  LCandidates := AJson.GetValue('candidates') as TJSONArray;
  if not Assigned(LCandidates) or (LCandidates.Count = 0) then Exit;

  LCandidate := LCandidates[0] as TJSONObject;
  LContent := LCandidate.GetValue('content') as TJSONObject;
  if not Assigned(LContent) then Exit;

  LParts := LContent.GetValue('parts') as TJSONArray;
  if not Assigned(LParts) or (LParts.Count = 0) then Exit;

  LPart := LParts[0] as TJSONObject;
  if Assigned(LPart) then
  begin
    AText := LPart.GetValue<string>('text', '');
    Result := not AText.IsEmpty;
  end;
end;

function TRadIAGeminiProvider.ParseResponseBody(const AResponseJson: string; out AUsage: TTokenUsage): string;
var
  LJsonObj: TJSONObject;
  LUsageNode: TJSONObject;
begin
  Result := '';
  AUsage := TTokenUsage.Empty;

  LJsonObj := TJSONObject.ParseJSONValue(AResponseJson) as TJSONObject;
  if not Assigned(LJsonObj) then
    Exit;

  try
    TryGetCandidateText(LJsonObj, Result);

    if Result.IsEmpty and Assigned(LJsonObj.GetValue('error')) then
      raise Exception.Create(LJsonObj.GetValue('error').ToString);

    LUsageNode := LJsonObj.GetValue('usageMetadata') as TJSONObject;
    if Assigned(LUsageNode) then
    begin
      AUsage.PromptTokens     := LUsageNode.GetValue<Integer>('promptTokenCount', 0);
      AUsage.CompletionTokens := LUsageNode.GetValue<Integer>('candidatesTokenCount', 0);
      AUsage.TotalTokens      := LUsageNode.GetValue<Integer>('totalTokenCount', 0);
    end;
  finally
    LJsonObj.Free;
  end;
end;

procedure TRadIAGeminiProvider.SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LApiKey, LModel, LRequestBody: string;
  LHeaders: TNetHeaders;
begin
  if not HasValidCredentials then
  begin
    ACallback('',
      'Credentials (API Key or OAuth Token) are missing or ' +
      'invalid for Google Gemini. Please check settings.',
      False, TTokenUsage.Empty);
    Exit;
  end;

  LModel := GetActiveModel;

  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
  begin
    LUrl := Format('https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent', [LModel]);
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + FConfig.GetOAuthAccessToken(FProviderId));
  end
  else
  begin
    LApiKey := GetApiKey;
    LUrl := Format('https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s',
      [LModel, TNetEncoding.URL.Encode(LApiKey)]);
    LHeaders := nil;
  end;

  try
    LRequestBody := BuildRequestBody(APrompt, AHistory, ATemperature, AMaxTokens);
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

function IsModelValidForGeneration(AModelObj: TJSONObject): Boolean;
var
  LMethodsArr: TJSONArray;
  LMethodVal: TJSONValue;
begin
  Result := False;
  LMethodsArr := AModelObj.GetValue('supportedGenerationMethods') as TJSONArray;
  if not Assigned(LMethodsArr) then Exit;

  for LMethodVal in LMethodsArr do
  begin
    if SameText(LMethodVal.Value, 'generateContent') then
      Exit(True);
  end;
end;

function ParseAvailableModelsFromJson(const AJsonStr: string): TList<string>;
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
    if not Assigned(LModelsArr) then Exit;

    for LVal in LModelsArr do
    begin
      if not (LVal is TJSONObject) then Continue;

      LModelObj := LVal as TJSONObject;
      LName := LModelObj.GetValue<string>('name', '');
      if LName.IsEmpty then Continue;

      if IsModelValidForGeneration(LModelObj) then
      begin
        if LName.StartsWith('models/') then
          LName := LName.Substring(7);
        Result.Add(LName);
      end;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAGeminiProvider.FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>);
var
  LApiKey: string;
  LUrl: string;
  LTaskProc: TProc;
  LProviderRef: IRadIAProvider;
  LHeaders: TNetHeaders;
begin
  LProviderRef := Self;

  if not HasValidCredentials then
  begin
    if not GIsShuttingDown then
    begin
      TThread.Queue(nil,
        procedure
        begin
          ACallback(GetAvailableModels,
            'Credentials (API Key or OAuth Token) are missing or ' +
            'invalid for Google Gemini. Using fallback models.');
        end);
    end;
    Exit;
  end;

  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
  begin
    LUrl := 'https://generativelanguage.googleapis.com/v1beta/models';
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + FConfig.GetOAuthAccessToken(FProviderId));
  end
  else
  begin
    LApiKey := GetApiKey;
    LUrl := Format('https://generativelanguage.googleapis.com/v1beta/models?key=%s',
      [TNetEncoding.URL.Encode(LApiKey)]);
    LHeaders := nil;
  end;

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
                     LResponseText := DoGetRequest(LUrl, LHeaders, 5000);
                     LModelsList := ParseAvailableModelsFromJson(LResponseText);
                     try
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

procedure SkipJsonString(LPtr: PChar; var I: Integer; LLen: Integer);
begin
  Inc(I);
  while I < LLen do
  begin
    if LPtr[I] = '\' then
      Inc(I)
    else if LPtr[I] = '"' then
      Exit;
    Inc(I);
  end;
end;

function FindJsonObjectEnd(const ABuffer: string; out AEndIdx: Integer): Boolean;
var
  LBrackets, I, LLen: Integer;
  LPtr: PChar;
begin
  Result := False;
  LBrackets := 0;
  LLen := ABuffer.Length;
  LPtr := PChar(ABuffer);
  AEndIdx := -1;
  I := 0;

  while I < LLen do
  begin
    case LPtr[I] of
      '"': SkipJsonString(LPtr, I, LLen);
      '{': Inc(LBrackets);
      '}':
      begin
        Dec(LBrackets);
        if LBrackets = 0 then
        begin
          AEndIdx := I;
          Exit(True);
        end;
      end;
    end;
    Inc(I);
  end;
end;

function TRadIAGeminiProvider.TryExtractNextJsonObject(var ABuffer: string; out AJsonObjectStr: string): Boolean;
var
  LEndIdx: Integer;
begin
  Result := False;
  AJsonObjectStr := '';
  ABuffer := ABuffer.TrimLeft(['[', ',', #13, #10, ' ', ']']);
  if ABuffer.IsEmpty or not ABuffer.StartsWith('{') then Exit;

  if FindJsonObjectEnd(ABuffer, LEndIdx) then
  begin
    AJsonObjectStr := ABuffer.Substring(0, LEndIdx + 1);
    ABuffer := ABuffer.Substring(LEndIdx + 1);
    Result := True;
  end;
end;

function TryGetErrorText(AJson: TJSONObject; out AText: string): Boolean;
var
  LError: TJSONValue;
begin
  Result := False;
  AText := '';
  LError := AJson.GetValue('error');
  if not Assigned(LError) then Exit;

  if LError is TJSONObject then
    AText := TJSONObject(LError).GetValue<string>('message', '');
  if AText.IsEmpty then
    AText := LError.ToString;
  Result := True;
end;



procedure TRadIAGeminiProvider.ParseAndEmitCandidate(const AJsonStr: string; const ACallback: TStreamChunkCallback);
var
  LJson: TJSONObject;
  LText: string;
begin
  try
    LJson := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
    if not Assigned(LJson) then Exit;
    try
      if TryGetErrorText(LJson, LText) then
      begin
        TLogger.Log('PSB: API error=' + LText, 'Provider');
        ACallback('', True, LText);
        Exit;
      end;

      if TryGetCandidateText(LJson, LText) then
        ACallback(LText, False, '');
    finally
      LJson.Free;
    end;
  except
    on E: Exception do
      TLogger.Log(Format('PSB: Exception=%s', [E.Message]), 'Provider');
  end;
end;


procedure TRadIAGeminiProvider.ProcessStreamBuffer(var ABuffer: string; const ACallback: TStreamChunkCallback);
var
  LCandidateStr: string;
  LObjectCount: Integer;
begin
  LObjectCount := 0;
  TLogger.Log(Format('PSB: Entry BufferLen=%d First30=|%s|',
    [ABuffer.Length, ABuffer.Substring(0, Min(30, ABuffer.Length))]), 'Provider');

  while TryExtractNextJsonObject(ABuffer, LCandidateStr) do
  begin
    Inc(LObjectCount);
    TLogger.Log(Format('PSB: Obj#%d Found ObjLen=%d', [LObjectCount, LCandidateStr.Length]), 'Provider');
    ParseAndEmitCandidate(LCandidateStr, ACallback);
  end;

  TLogger.Log(Format('PSB: Exit Objs=%d ResidualLen=%d', [LObjectCount, ABuffer.Length]), 'Provider');
end;

procedure TRadIAGeminiProvider.SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer);
var
  LUrl, LApiKey, LModel, LRequestBody: string;
  LHeaders: TNetHeaders;
begin
  if not HasValidCredentials then
  begin
    ACallback('', True,
      'Credentials (API Key or OAuth Token) are missing or ' +
      'invalid for Google Gemini. Please check settings.');
    Exit;
  end;

  LModel := GetActiveModel;

  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
  begin
    LUrl := Format('https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent', [LModel]);
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create('Authorization', 'Bearer ' + FConfig.GetOAuthAccessToken(FProviderId));
  end
  else
  begin
    LApiKey := GetApiKey;
    LUrl := Format('https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?key=%s',
      [LModel, TNetEncoding.URL.Encode(LApiKey)]);
    LHeaders := nil;
  end;

  try
    LRequestBody := BuildRequestBody(APrompt, AHistory, ATemperature, AMaxTokens);
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
      'Gemini',
      'Google Gemini',
      'https://generativelanguage.googleapis.com',
      True, // HasApiKey
      False, // HasCustomUrl
      [MODEL_GEMINI_36_FLASH, MODEL_GEMINI_35_FLASH, MODEL_GEMINI_35_FLASH_LITE],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAGeminiProvider.Create(ACfg);
      end
    )
  );

end.
