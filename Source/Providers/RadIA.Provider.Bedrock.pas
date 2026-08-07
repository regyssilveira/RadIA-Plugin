unit RadIA.Provider.Bedrock;

interface

uses
  System.SysUtils, RadIA.Core.Interfaces, RadIA.Core.TokenUsage, RadIA.Provider.Base;

type
  { Event callback for event stream parsing }
  TEventStreamChunkEvent = reference to procedure(const AChunk: string; AIsDone: Boolean; const AError: string);

  { Parser for AWS EventStream binary chunks }
  TRadIAAwsEventStreamParser = class
  private
    FBuffer: TBytes;
    FOnChunk: TEventStreamChunkEvent;
    function ReadBigEndian32(AOffset: Integer): Cardinal;
    procedure ParseFrame(const AFrameBytes: TBytes);
    procedure ProcessDecodedJson(const AJsonStr: string);
  public
    constructor Create(const AOnChunk: TEventStreamChunkEvent);
    destructor Destroy; override;
    procedure ProcessBytes(const ANewBytes: TBytes);
  end;

  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  { AWS Bedrock Provider Client }
  TRadIABedrockProvider = class(TRadIAProviderBase)
  private
    function BuildBedrockRequestBody(const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>; const ATemperature: Double;
      const AMaxTokens: Integer): string;
    function ParseBedrockResponse(const AResponseJson: string;
      out AUsage: TTokenUsage): string;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;

    procedure FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>); override;
    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
  end;

implementation

uses
  System.Classes, System.Net.URLClient, RadIA.Core.Types,
  System.JSON, System.Threading, System.NetEncoding, System.Math,
  RadIA.Core.AwsSigner, RadIA.Core.ProviderRegistry, RadIA.Core.Logger, System.SyncObjs;

{ TRadIAAwsEventStreamParser }

constructor TRadIAAwsEventStreamParser.Create(const AOnChunk: TEventStreamChunkEvent);
begin
  inherited Create;
  FOnChunk := AOnChunk;
  FBuffer := nil;
end;

destructor TRadIAAwsEventStreamParser.Destroy;
begin
  FBuffer := nil;
  inherited Destroy;
end;

function TRadIAAwsEventStreamParser.ReadBigEndian32(AOffset: Integer): Cardinal;
begin
  Result := (Cardinal(FBuffer[AOffset]) shl 24) or
            (Cardinal(FBuffer[AOffset + 1]) shl 16) or
            (Cardinal(FBuffer[AOffset + 2]) shl 8) or
             Cardinal(FBuffer[AOffset + 3]);
end;

procedure TRadIAAwsEventStreamParser.ProcessBytes(const ANewBytes: TBytes);
var
  LOldLen, LNewLen: Integer;
  LTotalLength: Cardinal;
  LFrameBytes: TBytes;
  LRemaining: Integer;
  LTemp: TBytes;
begin
  if Length(ANewBytes) = 0 then
    Exit;

  LOldLen := Length(FBuffer);
  LNewLen := Length(ANewBytes);
  SetLength(FBuffer, LOldLen + LNewLen);
  Move(ANewBytes[0], FBuffer[LOldLen], LNewLen);

  while Length(FBuffer) >= 12 do
  begin
    LTotalLength := ReadBigEndian32(0);

    if Cardinal(Length(FBuffer)) < LTotalLength then
      Break; // Wait for more data

    SetLength(LFrameBytes, LTotalLength);
    Move(FBuffer[0], LFrameBytes[0], LTotalLength);

    try
      ParseFrame(LFrameBytes);
    except
      on E: Exception do
      begin
        TLogger.Log('TRadIAAwsEventStreamParser.ProcessBytes error: ' + E.Message, 'Bedrock');
        if Assigned(FOnChunk) then
          FOnChunk('', True, 'AWS EventStream Parse Error: ' + E.Message);
      end;
    end;

    LRemaining := Length(FBuffer) - Integer(LTotalLength);
    if LRemaining > 0 then
    begin
      SetLength(LTemp, LRemaining);
      Move(FBuffer[LTotalLength], LTemp[0], LRemaining);
      FBuffer := LTemp;
    end
    else
      FBuffer := nil;
  end;
end;

procedure TRadIAAwsEventStreamParser.ProcessDecodedJson(const AJsonStr: string);
var
  LObj, LDelta: TJSONObject;
  LType, LText: string;
begin
  LObj := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
  if not Assigned(LObj) then Exit;
  try
    LType := LObj.GetValue<string>('type', '');
    if SameText(LType, 'content_block_delta') then
    begin
      LDelta := LObj.GetValue('delta') as TJSONObject;
      if Assigned(LDelta) then
      begin
        LText := LDelta.GetValue<string>('text', '');
        if not LText.IsEmpty and Assigned(FOnChunk) then
          FOnChunk(LText, False, '');
      end;
    end;
  finally
    LObj.Free;
  end;
end;

procedure TRadIAAwsEventStreamParser.ParseFrame(const AFrameBytes: TBytes);
var
  LTotalLength, LHeadersLength: Cardinal;
  LPayloadOffset: Cardinal;
  LPayloadLength: Cardinal;
  LPayloadBytes: TBytes;
  LPayloadJson: string;
  LObj: TJSONObject;
  LBytesBase64: string;
  LDecodedBytes: TBytes;
begin
  LTotalLength := (Cardinal(AFrameBytes[0]) shl 24) or
                  (Cardinal(AFrameBytes[1]) shl 16) or
                  (Cardinal(AFrameBytes[2]) shl 8) or
                   Cardinal(AFrameBytes[3]);

  LHeadersLength := (Cardinal(AFrameBytes[4]) shl 24) or
                    (Cardinal(AFrameBytes[5]) shl 16) or
                    (Cardinal(AFrameBytes[6]) shl 8) or
                     Cardinal(AFrameBytes[7]);

  LPayloadOffset := 12 + LHeadersLength;
  LPayloadLength := LTotalLength - LHeadersLength - 16;

  if LPayloadLength <= 0 then
    Exit;

  SetLength(LPayloadBytes, LPayloadLength);
  Move(AFrameBytes[LPayloadOffset], LPayloadBytes[0], LPayloadLength);

  LPayloadJson := TEncoding.UTF8.GetString(LPayloadBytes);
  LObj := TJSONObject.ParseJSONValue(LPayloadJson) as TJSONObject;
  if not Assigned(LObj) then
    Exit;

  try
    LBytesBase64 := LObj.GetValue<string>('bytes', '');
    if LBytesBase64.IsEmpty then
      Exit;

    LDecodedBytes := TNetEncoding.Base64.DecodeStringToBytes(LBytesBase64);
    ProcessDecodedJson(TEncoding.UTF8.GetString(LDecodedBytes));
  finally
    LObj.Free;
  end;
end;

{ TRadIABedrockProvider }

constructor TRadIABedrockProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'Bedrock';
end;

function TRadIABedrockProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create(
    'anthropic.claude-sonnet-5',
    'anthropic.claude-opus-5',
    'anthropic.claude-fable-5'
  );
end;

function TRadIABedrockProvider.GetName: string;
begin
  Result := 'AWS Bedrock';
end;

procedure TRadIABedrockProvider.FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>);
begin
  if not GIsShuttingDown then
  begin
    TThread.Queue(nil,
      procedure
      begin
        ACallback(GetAvailableModels, '');
      end
    );
  end;
end;

function TRadIABedrockProvider.BuildBedrockRequestBody(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ATemperature: Double;
  const AMaxTokens: Integer): string;
var
  LRoot: TJSONObject;
  LMessages: TJSONArray;
  LMsgObj: TJSONObject;
  LMsg: IRadIAChatMessage;
  LMaxTok: Integer;
  LSystemPrompt: string;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('anthropic_version', 'bedrock-2023-05-31');

    LMaxTok := AMaxTokens;
    if LMaxTok <= 0 then
      LMaxTok := 4096;
    LRoot.AddPair('max_tokens', TJSONNumber.Create(LMaxTok));

    if ATemperature >= 0.0 then
      LRoot.AddPair('temperature', TJSONNumber.Create(ATemperature));

    LSystemPrompt := FConfig.SystemPrompt;
    if not LSystemPrompt.IsEmpty then
      LRoot.AddPair('system', LSystemPrompt);

    LMessages := TJSONArray.Create;
    LRoot.AddPair('messages', LMessages);

    { History messages }
    for LMsg in AHistory do
    begin
      LMsgObj := TJSONObject.Create;
      LMsgObj.AddPair('role', MessageRoleToString(LMsg.Role));
      LMsgObj.AddPair('content', LMsg.Content);
      LMessages.AddElement(LMsgObj);
    end;

    { Current prompt }
    LMsgObj := TJSONObject.Create;
    LMsgObj.AddPair('role', 'user');
    LMsgObj.AddPair('content', APrompt);
    LMessages.AddElement(LMsgObj);

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIABedrockProvider.ParseBedrockResponse(const AResponseJson: string;
  out AUsage: TTokenUsage): string;
var
  LObj: TJSONObject;
  LContent: TJSONArray;
  LContentObj: TJSONObject;
  LUsageObj: TJSONObject;
begin
  Result := '';
  AUsage := TTokenUsage.Empty;

  LObj := TJSONObject.ParseJSONValue(AResponseJson) as TJSONObject;
  if not Assigned(LObj) then
    Exit;

  try
    LContent := LObj.GetValue('content') as TJSONArray;
    if Assigned(LContent) and (LContent.Count > 0) then
    begin
       LContentObj := LContent[0] as TJSONObject;
      if Assigned(LContentObj) then
        Result := LContentObj.GetValue<string>('text', '');
    end;

    LUsageObj := LObj.GetValue('usage') as TJSONObject;
    if Assigned(LUsageObj) then
    begin
      AUsage.PromptTokens := LUsageObj.GetValue<Integer>('input_tokens', 0);
      AUsage.CompletionTokens := LUsageObj.GetValue<Integer>('output_tokens', 0);
      AUsage.TotalTokens := AUsage.PromptTokens + AUsage.CompletionTokens;
    end;
  finally
    LObj.Free;
  end;
end;

procedure TRadIABedrockProvider.SendPromptAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TCompletionCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LHeaders: TNetHeaders;
  LBody: string;
  LAmzDate, LDateStamp: string;
  LUrl: string;
  LUri: string;
  LRegion: string;
  LAccessKey: string;
  LSecretKey: string;
  LSessionToken: string;
  LModelId: string;
  LTask: TProc;
  LProviderRef: IRadIAProvider;
begin
  LProviderRef := Self;
  FCancelled := False;

  LAccessKey := FConfig.AwsAccessKeyId;
  LSecretKey := FConfig.AwsSecretAccessKey;
  LRegion := FConfig.AwsRegion;
  LSessionToken := FConfig.AwsSessionToken;
  LModelId := GetActiveModel;

  if LModelId.IsEmpty then
    LModelId := 'anthropic.claude-sonnet-5';

  LUri := '/model/' + LModelId + '/invoke';
  LUrl := Format('https://bedrock-runtime.%s.amazonaws.com%s', [LRegion, LUri]);

  LBody := BuildBedrockRequestBody(APrompt, AHistory, ATemperature, AMaxTokens);

  TAwsSigV4Signer.GetAmzDateTimeStrings(LAmzDate, LDateStamp);

  var LReq: TAwsSignRequest;
  LReq.AccessKeyId := LAccessKey;
  LReq.SecretAccessKey := LSecretKey;
  LReq.Region := LRegion;
  LReq.Service := 'bedrock';
  LReq.Method := 'POST';
  LReq.Uri := LUri;
  LReq.Payload := LBody;
  LReq.AmzDate := LAmzDate;
  LReq.DateStamp := LDateStamp;
  LReq.SessionToken := LSessionToken;

  var LHeadersList := TAwsSigV4Signer.ComputeSignatureHeaders(LReq);
  try
    SetLength(LHeaders, LHeadersList.Count);
    for var I := 0 to LHeadersList.Count - 1 do
    begin
      LHeaders[I].Name := LHeadersList.Names[I];
      LHeaders[I].Value := LHeadersList.ValueFromIndex[I];
    end;
  finally
    LHeadersList.Free;
  end;

  LTask :=
    procedure
    var
      LResponseJson: string;
      LTextResponse: string;
      LUsage: TTokenUsage;
      LErrorMsg: string;
    begin
      try
        System.Math.SetExceptionMask(System.Math.exAllArithmeticExceptions);
        LProviderRef.GetProviderId;
        try
          LResponseJson := DoPostRequest(LUrl, LHeaders, LBody);
          LTextResponse := ParseBedrockResponse(LResponseJson, LUsage);

          if not GIsShuttingDown then
          begin
            TThread.Queue(nil,
              procedure
              begin
                ACallback(LTextResponse, '', False, LUsage);
              end
            );
          end;
        except
          on E: Exception do
          begin
            LErrorMsg := E.ClassName + ': ' + E.Message;
            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  ACallback('', LErrorMsg, False, TTokenUsage.Empty);
                end
              );
            end;
          end;
        end;
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end;

  TInterlocked.Increment(GActiveThreadCount);
  TTask.Run(LTask);
end;

procedure TRadIABedrockProvider.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
var
  LHeaders: TNetHeaders;
  LBody: string;
  LAmzDate, LDateStamp: string;
  LUrl: string;
  LUri: string;
  LRegion: string;
  LAccessKey: string;
  LSecretKey: string;
  LSessionToken: string;
  LModelId: string;
  LTask: TProc;
  LProviderRef: IRadIAProvider;
begin
  LProviderRef := Self;
  FCancelled := False;

  LAccessKey := FConfig.AwsAccessKeyId;
  LSecretKey := FConfig.AwsSecretAccessKey;
  LRegion := FConfig.AwsRegion;
  LSessionToken := FConfig.AwsSessionToken;
  LModelId := GetActiveModel;

  if LModelId.IsEmpty then
    LModelId := 'anthropic.claude-sonnet-5';

  LUri := '/model/' + LModelId + '/invoke-with-response-stream';
  LUrl := Format('https://bedrock-runtime.%s.amazonaws.com%s', [LRegion, LUri]);

  LBody := BuildBedrockRequestBody(APrompt, AHistory, ATemperature, AMaxTokens);

  TAwsSigV4Signer.GetAmzDateTimeStrings(LAmzDate, LDateStamp);

  var LReq: TAwsSignRequest;
  LReq.AccessKeyId := LAccessKey;
  LReq.SecretAccessKey := LSecretKey;
  LReq.Region := LRegion;
  LReq.Service := 'bedrock';
  LReq.Method := 'POST';
  LReq.Uri := LUri;
  LReq.Payload := LBody;
  LReq.AmzDate := LAmzDate;
  LReq.DateStamp := LDateStamp;
  LReq.SessionToken := LSessionToken;

  var LHeadersList := TAwsSigV4Signer.ComputeSignatureHeaders(LReq);
  try
    SetLength(LHeaders, LHeadersList.Count);
    for var I := 0 to LHeadersList.Count - 1 do
    begin
      LHeaders[I].Name := LHeadersList.Names[I];
      LHeaders[I].Value := LHeadersList.ValueFromIndex[I];
    end;
  finally
    LHeadersList.Free;
  end;

  LTask :=
    procedure
    var
      LParser: TRadIAAwsEventStreamParser;
      LErrorMsg: string;
    begin
      try
        System.Math.SetExceptionMask(System.Math.exAllArithmeticExceptions);
        LProviderRef.GetProviderId;

        LParser := TRadIAAwsEventStreamParser.Create(
          procedure(const AChunk: string; AIsDone: Boolean; const AError: string)
          begin
            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  ACallback(AChunk, AIsDone, AError);
                end
              );
            end;
          end
        );
        try
          try
            DoPostRequestStream(LUrl, LHeaders, LBody,
              procedure(ABytes: TBytes)
              begin
                LParser.ProcessBytes(ABytes);
              end
            );

            if not GIsShuttingDown then
            begin
              TThread.Queue(nil,
                procedure
                begin
                  ACallback('', True, '');
                end
              );
            end;
          except
            on E: Exception do
            begin
              LErrorMsg := E.ClassName + ': ' + E.Message;
              if not GIsShuttingDown then
              begin
                TThread.Queue(nil,
                  procedure
                  begin
                    ACallback('', True, LErrorMsg);
                  end
                );
              end;
            end;
          end;
        finally
          LParser.Free;
        end;
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end;

  TInterlocked.Increment(GActiveThreadCount);
  TTask.Run(LTask);
end;

initialization
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'Bedrock',
      'AWS Bedrock',
      'https://bedrock-runtime.us-east-1.amazonaws.com',
      False, // HasApiKey
      False, // HasCustomUrl
      ['anthropic.claude-sonnet-5', 'anthropic.claude-opus-5', 'anthropic.claude-fable-5'],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIABedrockProvider.Create(ACfg);
      end
    )
  );

end.
