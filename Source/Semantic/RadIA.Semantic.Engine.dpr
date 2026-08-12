program RadIASemanticEngine;

{$APPTYPE CONSOLE}

uses
  System.JSON,
  System.SysUtils,
  RadIA.Semantic.Lexer in 'RadIA.Semantic.Lexer.pas';

const
  CEngineName = 'RadIA Semantic Engine';
  CProtocolVersion = '1.0';

function BuildError(
  const AId: TJSONValue;
  const ACode: Integer;
  const AMessage: string
): TJSONObject;
var
  LError: TJSONObject;
begin
  Result := TJSONObject.Create;
  if Assigned(AId) then
    Result.AddPair('id', AId.Clone as TJSONValue)
  else
    Result.AddPair('id', TJSONNull.Create);
  LError := TJSONObject.Create;
  LError.AddPair('code', TJSONNumber.Create(ACode));
  LError.AddPair('message', AMessage);
  Result.AddPair('error', LError);
end;

function BuildTokenizeResult(
  const AId: TJSONValue;
  const ASource: string
): TJSONObject;
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LResult: TJSONObject;
  LToken: TRadIASemanticToken;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LArray := TJSONArray.Create;
  for LToken in TRadIASemanticLexer.Tokenize(ASource) do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('kind', TRadIASemanticLexer.TokenKindName(LToken.Kind));
    LItem.AddPair('startOffset', TJSONNumber.Create(LToken.StartOffset));
    LItem.AddPair('length', TJSONNumber.Create(LToken.Length));
    LArray.AddElement(LItem);
  end;
  LResult.AddPair('tokens', LArray);
  Result.AddPair('result', LResult);
end;

function BuildInitializeResult(const AId: TJSONValue): TJSONObject;
var
  LCapabilities: TJSONArray;
  LResult: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('name', CEngineName);
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LCapabilities := TJSONArray.Create;
  LCapabilities.Add('tokenize');
  LCapabilities.Add('shutdown');
  LResult.AddPair('capabilities', LCapabilities);
  Result.AddPair('result', LResult);
end;

function HandleRequest(
  const ARequest: TJSONObject;
  out AShutdown: Boolean
): TJSONObject;
var
  LId: TJSONValue;
  LMethod: string;
  LParameters: TJSONObject;
begin
  AShutdown := False;
  LId := ARequest.GetValue('id');
  LMethod := ARequest.GetValue<string>('method', '');
  if not Assigned(LId) or (LMethod = '') then
    Exit(BuildError(LId, -32600, 'A request requires id and method.'));
  if SameText(LMethod, 'initialize') then
    Exit(BuildInitializeResult(LId));
  if SameText(LMethod, 'shutdown') then
  begin
    AShutdown := True;
    Exit(BuildInitializeResult(LId));
  end;
  if SameText(LMethod, 'tokenize') then
  begin
    LParameters := ARequest.GetValue<TJSONObject>('params');
    if not Assigned(LParameters) then
      Exit(BuildError(LId, -32602, 'Tokenize requires params.'));
    Exit(BuildTokenizeResult(
      LId,
      LParameters.GetValue<string>('source', '')
    ));
  end;
  Result := BuildError(LId, -32601, 'Unknown semantic engine method.');
end;

procedure RunServer;
var
  LInput: string;
  LRequest: TJSONObject;
  LResponse: TJSONObject;
  LShutdown: Boolean;
begin
  LShutdown := False;
  while not Eof(Input) and not LShutdown do
  begin
    ReadLn(LInput);
    if Trim(LInput) = '' then
      Continue;
    LRequest := TJSONObject.ParseJSONValue(LInput) as TJSONObject;
    try
      if not Assigned(LRequest) then
        LResponse := BuildError(nil, -32700, 'Invalid JSON request.')
      else
        LResponse := HandleRequest(LRequest, LShutdown);
      try
        WriteLn(LResponse.ToJSON);
        Flush(Output);
      finally
        LResponse.Free;
      end;
    finally
      LRequest.Free;
    end;
  end;
end;

var
  LResponse: TJSONObject;

begin
  try
    RunServer;
  except
    on E: Exception do
    begin
      LResponse := BuildError(nil, -32603, E.Message);
      try
        WriteLn(LResponse.ToJSON);
      finally
        LResponse.Free;
      end;
      System.ExitCode := 1;
    end;
  end;
end.
