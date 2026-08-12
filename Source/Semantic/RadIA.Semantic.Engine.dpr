program RadIASemanticEngine;

{$APPTYPE CONSOLE}

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  RadIA.Semantic.Lexer in 'RadIA.Semantic.Lexer.pas',
  RadIA.Semantic.Preprocessor in 'RadIA.Semantic.Preprocessor.pas',
  RadIA.Semantic.Parser in 'RadIA.Semantic.Parser.pas';

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

function ReadStringArray(
  const AObject: TJSONObject;
  const AName: string
): TArray<string>;
var
  LArray: TJSONArray;
  LIndex: Integer;
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AName);
  if not (LValue is TJSONArray) then
    Exit(nil);
  LArray := TJSONArray(LValue);
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
    Result[LIndex] := LArray.Items[LIndex].Value;
end;

function BuildPreprocessResult(
  const AId: TJSONValue;
  const ASource: string;
  const ADefines: TArray<string>
): TJSONObject;
var
  LDiagnostics: TJSONArray;
  LInclude: TRadIASemanticIncludeReference;
  LIncludes: TJSONArray;
  LItem: TJSONObject;
  LProcessed: TRadIASemanticProcessedToken;
  LPreprocessResult: TRadIASemanticPreprocessResult;
  LResult: TJSONObject;
  LText: string;
  LTokens: TJSONArray;
begin
  LPreprocessResult := TRadIASemanticPreprocessor.Process(
    ASource,
    ADefines
  );
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LTokens := TJSONArray.Create;
  for LProcessed in LPreprocessResult.Tokens do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair(
      'kind',
      TRadIASemanticLexer.TokenKindName(LProcessed.Token.Kind)
    );
    LItem.AddPair(
      'activity',
      TRadIASemanticPreprocessor.ActivityName(LProcessed.Activity)
    );
    LItem.AddPair(
      'startOffset',
      TJSONNumber.Create(LProcessed.Token.StartOffset)
    );
    LItem.AddPair('length', TJSONNumber.Create(LProcessed.Token.Length));
    LTokens.AddElement(LItem);
  end;
  LResult.AddPair('tokens', LTokens);
  LIncludes := TJSONArray.Create;
  for LInclude in LPreprocessResult.Includes do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('path', LInclude.Path);
    LItem.AddPair('startOffset', TJSONNumber.Create(LInclude.StartOffset));
    LItem.AddPair(
      'activity',
      TRadIASemanticPreprocessor.ActivityName(LInclude.Activity)
    );
    LIncludes.AddElement(LItem);
  end;
  LResult.AddPair('includes', LIncludes);
  LDiagnostics := TJSONArray.Create;
  for LText in LPreprocessResult.Diagnostics do
    LDiagnostics.Add(LText);
  LResult.AddPair('diagnostics', LDiagnostics);
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
  LCapabilities.Add('preprocess');
  LCapabilities.Add('parse');
  LCapabilities.Add('analyze');
  LCapabilities.Add('shutdown');
  LResult.AddPair('capabilities', LCapabilities);
  Result.AddPair('result', LResult);
end;

function BuildAnalyzeResult(
  const AId: TJSONValue;
  const ASource: string;
  const ADefines: TArray<string>
): TJSONObject;
var
  LContiguous: Boolean;
  LDiagnostics: TJSONArray;
  LExpectedOffset: Integer;
  LHasModule: Boolean;
  LParsed: TRadIASemanticParseResult;
  LResult: TJSONObject;
  LSymbol: TRadIASemanticSymbol;
  LText: string;
  LToken: TRadIASemanticToken;
begin
  LExpectedOffset := 0;
  LContiguous := True;
  for LToken in TRadIASemanticLexer.Tokenize(ASource) do
  begin
    if (LToken.StartOffset <> LExpectedOffset) or (LToken.Length < 1) then
      LContiguous := False;
    Inc(LExpectedOffset, LToken.Length);
  end;
  LParsed := TRadIASemanticParser.Parse(ASource, ADefines);
  LHasModule := False;
  for LSymbol in LParsed.Symbols do
    if LSymbol.Kind = sskModule then
    begin
      LHasModule := True;
      Break;
    end;

  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LResult.AddPair('sourceLength', TJSONNumber.Create(Length(ASource)));
  LResult.AddPair('coveredLength', TJSONNumber.Create(LExpectedOffset));
  LResult.AddPair('tokensContiguous', TJSONBool.Create(LContiguous));
  LResult.AddPair('hasModule', TJSONBool.Create(LHasModule));
  LResult.AddPair('symbolCount', TJSONNumber.Create(Length(LParsed.Symbols)));
  LDiagnostics := TJSONArray.Create;
  for LText in LParsed.Diagnostics do
    LDiagnostics.Add(LText);
  LResult.AddPair('diagnostics', LDiagnostics);
  Result.AddPair('result', LResult);
end;

function BuildParseResult(
  const AId: TJSONValue;
  const ASource: string;
  const ADefines: TArray<string>
): TJSONObject;
var
  LArray: TJSONArray;
  LDiagnostics: TJSONArray;
  LItem: TJSONObject;
  LParsed: TRadIASemanticParseResult;
  LResult: TJSONObject;
  LSymbol: TRadIASemanticSymbol;
  LText: string;
begin
  LParsed := TRadIASemanticParser.Parse(ASource, ADefines);
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LArray := TJSONArray.Create;
  for LSymbol in LParsed.Symbols do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('name', LSymbol.Name);
    LItem.AddPair('kind', TRadIASemanticParser.SymbolKindName(LSymbol.Kind));
    LItem.AddPair('container', LSymbol.ContainerName);
    LItem.AddPair(
      'visibility',
      TRadIASemanticParser.VisibilityName(LSymbol.Visibility)
    );
    LItem.AddPair('startOffset', TJSONNumber.Create(LSymbol.StartOffset));
    LItem.AddPair('length', TJSONNumber.Create(LSymbol.Length));
    LItem.AddPair('signature', LSymbol.Signature);
    LArray.AddElement(LItem);
  end;
  LResult.AddPair('symbols', LArray);
  LDiagnostics := TJSONArray.Create;
  for LText in LParsed.Diagnostics do
    LDiagnostics.Add(LText);
  LResult.AddPair('diagnostics', LDiagnostics);
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
  if SameText(LMethod, 'preprocess') then
  begin
    LParameters := ARequest.GetValue<TJSONObject>('params');
    if not Assigned(LParameters) then
      Exit(BuildError(LId, -32602, 'Preprocess requires params.'));
    Exit(BuildPreprocessResult(
      LId,
      LParameters.GetValue<string>('source', ''),
      ReadStringArray(LParameters, 'defines')
    ));
  end;
  if SameText(LMethod, 'parse') then
  begin
    LParameters := ARequest.GetValue<TJSONObject>('params');
    if not Assigned(LParameters) then
      Exit(BuildError(LId, -32602, 'Parse requires params.'));
    Exit(BuildParseResult(
      LId,
      LParameters.GetValue<string>('source', ''),
      ReadStringArray(LParameters, 'defines')
    ));
  end;
  if SameText(LMethod, 'analyze') then
  begin
    LParameters := ARequest.GetValue<TJSONObject>('params');
    if not Assigned(LParameters) then
      Exit(BuildError(LId, -32602, 'Analyze requires params.'));
    Exit(BuildAnalyzeResult(
      LId,
      LParameters.GetValue<string>('source', ''),
      ReadStringArray(LParameters, 'defines')
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
