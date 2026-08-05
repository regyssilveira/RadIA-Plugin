unit RadIA.Core.RemoteKnowledgeEmbeddings;

interface

uses
  RadIA.Core.Knowledge;

type
  TRadIARemoteEmbeddingOptions = record
  private
    FApiKey: string;
    FDimensions: Integer;
    FEndpoint: string;
    FMaxInputCharacters: Integer;
    FModel: string;
    FTimeoutMs: Cardinal;
  public
    constructor Create(
      const AEndpoint: string;
      const AModel: string;
      const AApiKey: string;
      const ADimensions: Integer;
      const ATimeoutMs: Cardinal;
      const AMaxInputCharacters: Integer
    );
    property ApiKey: string read FApiKey;
    property Dimensions: Integer read FDimensions;
    property Endpoint: string read FEndpoint;
    property MaxInputCharacters: Integer read FMaxInputCharacters;
    property Model: string read FModel;
    property TimeoutMs: Cardinal read FTimeoutMs;
  end;

  IRadIARemoteEmbeddingTransport = interface
    ['{2EB44B84-6CB7-42FA-97F9-0A1333CA7957}']
    function PostJson(
      const AEndpoint: string;
      const ABody: string;
      const AApiKey: string;
      const ATimeoutMs: Cardinal
    ): string;
  end;

  TRadIAOpenAICompatibleEmbeddingProvider = class(
    TInterfacedObject,
    IRadIAKnowledgeEmbeddingProvider
  )
  private
    FOptions: TRadIARemoteEmbeddingOptions;
    FTransport: IRadIARemoteEmbeddingTransport;
    function BuildRequest(const AText: string): string;
    function ParseResponse(const AResponse: string): TArray<Single>;
  public
    constructor Create(
      const AOptions: TRadIARemoteEmbeddingOptions;
      const ATransport: IRadIARemoteEmbeddingTransport = nil
    );
    function Embed(const AText: string): TArray<Single>;
    function GetDimensions: Integer;
    function GetId: string;
    function IsLocal: Boolean;
  end;

implementation

uses
  System.Classes,
  System.JSON,
  System.Math,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.SysUtils;

const
  CMaximumDimensions = 4096;
  CMaximumResponseBytes = 4 * 1024 * 1024;

type
  TRadIARemoteEmbeddingHttpTransport = class(
    TInterfacedObject,
    IRadIARemoteEmbeddingTransport
  )
  public
    function PostJson(
      const AEndpoint: string;
      const ABody: string;
      const AApiKey: string;
      const ATimeoutMs: Cardinal
    ): string;
  end;

function IsLoopbackHost(const AHost: string): Boolean;
begin
  Result := SameText(AHost, 'localhost') or
    SameText(AHost, '127.0.0.1') or
    SameText(AHost, '::1');
end;

procedure ValidateEndpoint(const AEndpoint: string);
var
  LUri: TURI;
begin
  LUri := TURI.Create(AEndpoint);
  if SameText(LUri.Scheme, 'https') then
    Exit;
  if SameText(LUri.Scheme, 'http') and IsLoopbackHost(LUri.Host) then
    Exit;
  raise EArgumentException.Create(
    'Remote embedding endpoint must use HTTPS or loopback HTTP.'
  );
end;

{ TRadIARemoteEmbeddingOptions }

constructor TRadIARemoteEmbeddingOptions.Create(
  const AEndpoint: string;
  const AModel: string;
  const AApiKey: string;
  const ADimensions: Integer;
  const ATimeoutMs: Cardinal;
  const AMaxInputCharacters: Integer
);
begin
  if Trim(AEndpoint).IsEmpty then
    raise EArgumentException.Create(
      'Remote embedding endpoint is required.'
    );
  ValidateEndpoint(AEndpoint);
  if Trim(AModel).IsEmpty then
    raise EArgumentException.Create(
      'Remote embedding model is required.'
    );
  if (ADimensions <= 0) or (ADimensions > CMaximumDimensions) then
    raise EArgumentOutOfRangeException.Create(
      'Remote embedding dimensions must be between 1 and 4096.'
    );
  if (ATimeoutMs < 1000) or (ATimeoutMs > 120000) then
    raise EArgumentOutOfRangeException.Create(
      'Remote embedding timeout must be between 1000 and 120000 ms.'
    );
  if (AMaxInputCharacters <= 0) or
    (AMaxInputCharacters > 100000) then
    raise EArgumentOutOfRangeException.Create(
      'Remote embedding input limit must be between 1 and 100000.'
    );
  FEndpoint := AEndpoint;
  FModel := AModel;
  FApiKey := AApiKey;
  FDimensions := ADimensions;
  FTimeoutMs := ATimeoutMs;
  FMaxInputCharacters := AMaxInputCharacters;
end;

{ TRadIARemoteEmbeddingHttpTransport }

function TRadIARemoteEmbeddingHttpTransport.PostJson(
  const AEndpoint: string;
  const ABody: string;
  const AApiKey: string;
  const ATimeoutMs: Cardinal
): string;
var
  LClient: THTTPClient;
  LContent: TStringStream;
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := ATimeoutMs;
    LClient.ResponseTimeout := ATimeoutMs;
    LClient.HandleRedirects := False;
    LHeaders := [
      TNameValuePair.Create('Content-Type', 'application/json')
    ];
    if not AApiKey.IsEmpty then
      LHeaders := LHeaders + [
        TNameValuePair.Create('Authorization', 'Bearer ' + AApiKey)
      ];
    LContent := TStringStream.Create(ABody, TEncoding.UTF8);
    try
      LResponse := LClient.Post(AEndpoint, LContent, nil, LHeaders);
    finally
      LContent.Free;
    end;
    if (LResponse.StatusCode < 200) or
      (LResponse.StatusCode >= 300) then
      raise EInvalidOpException.CreateFmt(
        'Remote embedding request failed with HTTP %d.',
        [LResponse.StatusCode]
      );
    if LResponse.ContentLength > CMaximumResponseBytes then
      raise EInvalidOpException.Create(
        'Remote embedding response exceeds the 4 MiB limit.'
      );
    Result := LResponse.ContentAsString(TEncoding.UTF8);
    if TEncoding.UTF8.GetByteCount(Result) > CMaximumResponseBytes then
      raise EInvalidOpException.Create(
        'Remote embedding response exceeds the 4 MiB limit.'
      );
  finally
    LClient.Free;
  end;
end;

{ TRadIAOpenAICompatibleEmbeddingProvider }

function TRadIAOpenAICompatibleEmbeddingProvider.BuildRequest(
  const AText: string
): string;
var
  LInput: string;
  LRoot: TJSONObject;
begin
  LInput := AText;
  if Length(LInput) > FOptions.MaxInputCharacters then
    SetLength(LInput, FOptions.MaxInputCharacters);
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('model', FOptions.Model);
    LRoot.AddPair('input', LInput);
    LRoot.AddPair('encoding_format', 'float');
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

constructor TRadIAOpenAICompatibleEmbeddingProvider.Create(
  const AOptions: TRadIARemoteEmbeddingOptions;
  const ATransport: IRadIARemoteEmbeddingTransport
);
begin
  inherited Create;
  FOptions := AOptions;
  if Assigned(ATransport) then
    FTransport := ATransport
  else
    FTransport := TRadIARemoteEmbeddingHttpTransport.Create;
end;

function TRadIAOpenAICompatibleEmbeddingProvider.Embed(
  const AText: string
): TArray<Single>;
var
  LResponse: string;
begin
  Result := nil;
  if Trim(AText).IsEmpty then
    Exit;
  LResponse := FTransport.PostJson(
    FOptions.Endpoint,
    BuildRequest(AText),
    FOptions.ApiKey,
    FOptions.TimeoutMs
  );
  Result := ParseResponse(LResponse);
end;

function TRadIAOpenAICompatibleEmbeddingProvider.GetDimensions: Integer;
begin
  Result := FOptions.Dimensions;
end;

function TRadIAOpenAICompatibleEmbeddingProvider.GetId: string;
begin
  Result := 'openai-compatible:' + LowerCase(FOptions.Model) + ':' +
    FOptions.Dimensions.ToString;
end;

function TRadIAOpenAICompatibleEmbeddingProvider.IsLocal: Boolean;
begin
  Result := False;
end;

function TRadIAOpenAICompatibleEmbeddingProvider.ParseResponse(
  const AResponse: string
): TArray<Single>;
var
  LData: TJSONArray;
  LEmbedding: TJSONArray;
  LIndex: Integer;
  LItem: TJSONObject;
  LRoot: TJSONObject;
  LValue: Double;
begin
  Result := nil;
  LRoot := TJSONObject.ParseJSONValue(AResponse) as TJSONObject;
  if not Assigned(LRoot) then
    raise EInvalidOpException.Create(
      'Remote embedding response must be a JSON object.'
    );
  try
    LData := LRoot.GetValue('data') as TJSONArray;
    if not Assigned(LData) or (LData.Count <> 1) or
      not (LData[0] is TJSONObject) then
      raise EInvalidOpException.Create(
        'Remote embedding response must contain exactly one item.'
      );
    LItem := TJSONObject(LData[0]);
    LEmbedding := LItem.GetValue('embedding') as TJSONArray;
    if not Assigned(LEmbedding) or
      (LEmbedding.Count <> FOptions.Dimensions) then
      raise EInvalidOpException.Create(
        'Remote embedding dimensions do not match configuration.'
      );
    SetLength(Result, LEmbedding.Count);
    for LIndex := 0 to LEmbedding.Count - 1 do
    begin
      LValue := LEmbedding[LIndex].AsType<Double>;
      if IsNan(LValue) or IsInfinite(LValue) then
        raise EInvalidOpException.Create(
          'Remote embedding contains a non-finite value.'
        );
      Result[LIndex] := LValue;
    end;
  finally
    LRoot.Free;
  end;
end;

end.
