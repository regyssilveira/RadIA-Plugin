program RadIASemanticEngine;

{$APPTYPE CONSOLE}

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  RadIA.Semantic.Lexer in 'RadIA.Semantic.Lexer.pas',
  RadIA.Semantic.Preprocessor in 'RadIA.Semantic.Preprocessor.pas',
  RadIA.Semantic.Parser in 'RadIA.Semantic.Parser.pas',
  RadIA.Semantic.Index in 'RadIA.Semantic.Index.pas',
  RadIA.Semantic.MissingMembers in 'RadIA.Semantic.MissingMembers.pas';

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
    Result[LIndex] := LArray[LIndex].Value;
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
  LCapabilities.Add('indexUnit');
  LCapabilities.Add('removeUnit');
  LCapabilities.Add('findSymbols');
  LCapabilities.Add('listPublicApiSymbols');
  LCapabilities.Add('findMembers');
  LCapabilities.Add('findResolvedMembers');
  LCapabilities.Add('completeResolvedMembers');
  LCapabilities.Add('indexStatus');
  LCapabilities.Add('clearIndex');
  LCapabilities.Add('loadIndexCache');
  LCapabilities.Add('saveIndexCache');
  LCapabilities.Add('shutdown');
  LResult.AddPair('capabilities', LCapabilities);
  Result.AddPair('result', LResult);
end;

function BuildCacheResult(
  const AId: TJSONValue;
  const ASucceeded: Boolean;
  const AError: string;
  const AIndex: TRadIASemanticIndex
): TJSONObject;
var
  LResult: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LResult.AddPair('succeeded', TJSONBool.Create(ASucceeded));
  LResult.AddPair('error', AError);
  LResult.AddPair('unitCount', TJSONNumber.Create(AIndex.UnitCount));
  LResult.AddPair('symbolCount', TJSONNumber.Create(AIndex.SymbolCount));
  Result.AddPair('result', LResult);
end;

function ReadScope(const AValue: string): TRadIASemanticUnitScope;
begin
  if SameText(AValue, 'group') then
    Result := susGroup
  else if SameText(AValue, 'rtl') then
    Result := susRTL
  else if SameText(AValue, 'vcl') then
    Result := susVCL
  else
    Result := susProject;
end;

function ScopeName(const AValue: TRadIASemanticUnitScope): string;
begin
  case AValue of
    susGroup: Result := 'group';
    susRTL: Result := 'rtl';
    susVCL: Result := 'vcl';
  else
    Result := 'project';
  end;
end;

function BuildIndexStatusResult(
  const AId: TJSONValue;
  const AIndex: TRadIASemanticIndex
): TJSONObject;
var
  LResult: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LResult.AddPair('unitCount', TJSONNumber.Create(AIndex.UnitCount));
  LResult.AddPair('symbolCount', TJSONNumber.Create(AIndex.SymbolCount));
  Result.AddPair('result', LResult);
end;

function BuildIndexMutationResult(
  const AId: TJSONValue;
  const AChanged: Boolean;
  const AIndex: TRadIASemanticIndex
): TJSONObject;
var
  LResult: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LResult.AddPair('changed', TJSONBool.Create(AChanged));
  LResult.AddPair('unitCount', TJSONNumber.Create(AIndex.UnitCount));
  LResult.AddPair('symbolCount', TJSONNumber.Create(AIndex.SymbolCount));
  Result.AddPair('result', LResult);
end;

function BuildIndexedSymbolsResult(
  const AId: TJSONValue;
  const ASymbols: TArray<TRadIASemanticIndexedSymbol>;
  const AResolution: TJSONObject = nil
): TJSONObject;
var
  LAncestor: string;
  LAncestors: TJSONArray;
  LArray: TJSONArray;
  LItem: TJSONObject;
  LResult: TJSONObject;
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LArray := TJSONArray.Create;
  for LSymbol in ASymbols do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('unitKey', LSymbol.UnitKey);
    LItem.AddPair('fileName', LSymbol.FileName);
    LItem.AddPair('scope', ScopeName(LSymbol.Scope));
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
    LAncestors := TJSONArray.Create;
    for LAncestor in LSymbol.AncestorNames do
      LAncestors.Add(LAncestor);
    LItem.AddPair('ancestors', LAncestors);
    LArray.AddElement(LItem);
  end;
  LResult.AddPair('symbols', LArray);
  if Assigned(AResolution) then
    LResult.AddPair('resolution', AResolution);
  Result.AddPair('result', LResult);
end;

function IsStructuralSymbol(
  const ASymbol: TRadIASemanticIndexedSymbol
): Boolean;
begin
  Result := ASymbol.Kind in [sskClass, sskRecord, sskInterface, sskHelper];
end;

function BuildResolution(
  const AIndex: TRadIASemanticIndex;
  const ARequestedSymbol: string;
  const ACandidateCount: Integer;
  const AEmptyReason: string
): TJSONObject;
var
  LAlternative: TJSONObject;
  LAlternatives: TJSONArray;
  LStructural: TList<TRadIASemanticIndexedSymbol>;
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  LStructural := TList<TRadIASemanticIndexedSymbol>.Create;
  try
    for LSymbol in AIndex.FindSymbols(ARequestedSymbol) do
      if IsStructuralSymbol(LSymbol) then
        LStructural.Add(LSymbol);
    Result := TJSONObject.Create;
    Result.AddPair('requestedSymbol', ARequestedSymbol);
    Result.AddPair('candidateCount', TJSONNumber.Create(ACandidateCount));
    LAlternatives := TJSONArray.Create;
    for LSymbol in LStructural do
    begin
      LAlternative := TJSONObject.Create;
      LAlternative.AddPair('unitKey', LSymbol.UnitKey);
      LAlternative.AddPair('fileName', LSymbol.FileName);
      LAlternative.AddPair('scope', ScopeName(LSymbol.Scope));
      LAlternatives.AddElement(LAlternative);
    end;
    Result.AddPair('alternatives', LAlternatives);
    if LStructural.Count = 0 then
    begin
      Result.AddPair('status', 'unresolved');
      Result.AddPair('reason', 'container-not-found');
    end
    else if LStructural.Count > 1 then
    begin
      Result.AddPair('status', 'ambiguous');
      Result.AddPair('reason', 'short-name-ambiguous');
    end
    else
    begin
      LSymbol := LStructural[0];
      Result.AddPair('originUnit', LSymbol.UnitKey);
      Result.AddPair('originFile', LSymbol.FileName);
      if ACandidateCount = 0 then
      begin
        Result.AddPair('status', 'not-found');
        Result.AddPair('reason', AEmptyReason);
      end
      else
      begin
        Result.AddPair('status', 'resolved');
        Result.AddPair('reason', 'exact-structural-match');
      end;
    end;
  finally
    LStructural.Free;
  end;
end;

function BuildMissingMemberPreviewResult(
  const AId: TJSONValue;
  const AIndex: TRadIASemanticIndex;
  const AParameters: TJSONObject
): TJSONObject;
var
  LPreview: TRadIASemanticMissingMemberPreview;
  LResult: TJSONObject;
begin
  LPreview := TRadIASemanticMissingMemberGenerator.Generate(
    AParameters.GetValue<string>('source', ''),
    AParameters.GetValue<string>('container', ''),
    AIndex.FindMissingMembers(
      AParameters.GetValue<string>('container', '')
    ),
    ReadStringArray(AParameters, 'defines')
  );
  Result := TJSONObject.Create;
  Result.AddPair('id', AId.Clone as TJSONValue);
  LResult := TJSONObject.Create;
  LResult.AddPair('protocolVersion', CProtocolVersion);
  LResult.AddPair('changed', TJSONBool.Create(LPreview.Changed));
  LResult.AddPair('missingCount', TJSONNumber.Create(LPreview.MissingCount));
  LResult.AddPair('proposedSource', LPreview.ProposedSource);
  LResult.AddPair('errorMessage', LPreview.ErrorMessage);
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
  LAncestor: string;
  LAncestors: TJSONArray;
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
    LAncestors := TJSONArray.Create;
    for LAncestor in LSymbol.AncestorNames do
      LAncestors.Add(LAncestor);
    LItem.AddPair('ancestors', LAncestors);
    LArray.AddElement(LItem);
  end;
  LResult.AddPair('symbols', LArray);
  LDiagnostics := TJSONArray.Create;
  for LText in LParsed.Diagnostics do
    LDiagnostics.Add(LText);
  LResult.AddPair('diagnostics', LDiagnostics);
  Result.AddPair('result', LResult);
end;

function RequireParameters(const ARequest: TJSONObject): TJSONObject;
begin
  Result := ARequest.GetValue<TJSONObject>('params');
  if not Assigned(Result) then
    raise EArgumentException.Create('The request requires params.');
end;

function IsAnalysisMethod(const AMethod: string): Boolean;
begin
  Result := SameText(AMethod, 'tokenize') or
    SameText(AMethod, 'preprocess') or SameText(AMethod, 'parse') or
    SameText(AMethod, 'analyze');
end;

function HandleAnalysisRequest(
  const AMethod: string;
  const AId: TJSONValue;
  const AParameters: TJSONObject
): TJSONObject;
begin
  if SameText(AMethod, 'tokenize') then
    Exit(BuildTokenizeResult(
      AId,
      AParameters.GetValue<string>('source', '')
    ));
  if SameText(AMethod, 'preprocess') then
    Exit(BuildPreprocessResult(
      AId,
      AParameters.GetValue<string>('source', ''),
      ReadStringArray(AParameters, 'defines')
    ));
  if SameText(AMethod, 'parse') then
    Exit(BuildParseResult(
      AId,
      AParameters.GetValue<string>('source', ''),
      ReadStringArray(AParameters, 'defines')
    ));
  Result := BuildAnalyzeResult(
    AId,
    AParameters.GetValue<string>('source', ''),
    ReadStringArray(AParameters, 'defines')
  );
end;

function HandleIndexRequest(
  const ARequest: TJSONObject;
  const AMethod: string;
  const AId: TJSONValue;
  const AIndex: TRadIASemanticIndex
): TJSONObject;
var
  LCacheError: string;
  LParameters: TJSONObject;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
begin
  if SameText(AMethod, 'indexUnit') then
  begin
    LParameters := RequireParameters(ARequest);
    Exit(BuildIndexMutationResult(
      AId,
      AIndex.IndexUnit(
        TRadIASemanticUnitDescriptor.Create(
          LParameters.GetValue<string>('unitKey', ''),
          LParameters.GetValue<string>('fileName', ''),
          ReadScope(LParameters.GetValue<string>('scope', 'project')),
          LParameters.GetValue<Int64>('revision', 0)
        ),
        LParameters.GetValue<string>('source', ''),
        ReadStringArray(LParameters, 'defines')
      ),
      AIndex
    ));
  end;
  if SameText(AMethod, 'removeUnit') then
  begin
    LParameters := RequireParameters(ARequest);
    Exit(BuildIndexMutationResult(
      AId,
      AIndex.RemoveUnit(LParameters.GetValue<string>('unitKey', '')),
      AIndex
    ));
  end;
  if SameText(AMethod, 'findSymbols') then
  begin
    LParameters := RequireParameters(ARequest);
    Exit(BuildIndexedSymbolsResult(
      AId,
      AIndex.FindSymbols(LParameters.GetValue<string>('name', ''))
    ));
  end;
  if SameText(AMethod, 'listPublicApiSymbols') then
  begin
    LParameters := RequireParameters(ARequest);
    Exit(BuildIndexedSymbolsResult(
      AId,
      AIndex.ListPublicApiSymbols(
        LParameters.GetValue<Integer>('maxItems', 2000)
      )
    ));
  end;
  if SameText(AMethod, 'findMembers') then
  begin
    LParameters := RequireParameters(ARequest);
    Exit(BuildIndexedSymbolsResult(
      AId,
      AIndex.FindMembers(LParameters.GetValue<string>('container', ''))
    ));
  end;
  if SameText(AMethod, 'findResolvedMembers') then
  begin
    LParameters := RequireParameters(ARequest);
    LSymbols := AIndex.FindResolvedMembers(
      LParameters.GetValue<string>('container', '')
    );
    Exit(BuildIndexedSymbolsResult(
      AId,
      LSymbols,
      BuildResolution(
        AIndex,
        LParameters.GetValue<string>('container', ''),
        Length(LSymbols),
        'container-has-no-members'
      )
    ));
  end;
  if SameText(AMethod, 'completeResolvedMembers') then
  begin
    LParameters := RequireParameters(ARequest);
    LSymbols := AIndex.CompleteResolvedMembers(
      LParameters.GetValue<string>('container', ''),
      LParameters.GetValue<string>('prefix', ''),
      LParameters.GetValue<Integer>('maxItems', 20)
    );
    Exit(BuildIndexedSymbolsResult(
      AId,
      LSymbols,
      BuildResolution(
        AIndex,
        LParameters.GetValue<string>('container', ''),
        Length(LSymbols),
        'prefix-has-no-match'
      )
    ));
  end;
  if SameText(AMethod, 'findMissingMembers') then
  begin
    LParameters := RequireParameters(ARequest);
    LSymbols := AIndex.FindMissingMembers(
      LParameters.GetValue<string>('container', '')
    );
    Exit(BuildIndexedSymbolsResult(
      AId,
      LSymbols,
      BuildResolution(
        AIndex,
        LParameters.GetValue<string>('container', ''),
        Length(LSymbols),
        'contract-is-satisfied'
      )
    ));
  end;
  if SameText(AMethod, 'prepareMissingMembers') then
  begin
    LParameters := RequireParameters(ARequest);
    Exit(BuildMissingMemberPreviewResult(AId, AIndex, LParameters));
  end;
  if SameText(AMethod, 'indexStatus') then
    Exit(BuildIndexStatusResult(AId, AIndex));
  if SameText(AMethod, 'clearIndex') then
  begin
    AIndex.Clear;
    Exit(BuildIndexMutationResult(AId, True, AIndex));
  end;
  if SameText(AMethod, 'loadIndexCache') then
  begin
    LParameters := RequireParameters(ARequest);
    Exit(BuildCacheResult(
      AId,
      AIndex.LoadCache(
        LParameters.GetValue<string>('fileName', ''),
        LCacheError
      ),
      LCacheError,
      AIndex
    ));
  end;
  if SameText(AMethod, 'saveIndexCache') then
  begin
    LParameters := RequireParameters(ARequest);
    AIndex.SaveCache(LParameters.GetValue<string>('fileName', ''));
    Exit(BuildCacheResult(AId, True, '', AIndex));
  end;
  Result := BuildError(AId, -32601, 'Unknown semantic engine method.');
end;

function HandleRequest(
  const ARequest: TJSONObject;
  const AIndex: TRadIASemanticIndex;
  out AShutdown: Boolean
): TJSONObject;
var
  LId: TJSONValue;
  LMethod: string;
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
  if IsAnalysisMethod(LMethod) then
    Exit(HandleAnalysisRequest(
      LMethod,
      LId,
      RequireParameters(ARequest)
    ));
  Result := HandleIndexRequest(ARequest, LMethod, LId, AIndex);
end;

function HandleRequestSafely(
  const ARequest: TJSONObject;
  const AIndex: TRadIASemanticIndex;
  out AShutdown: Boolean
): TJSONObject;
begin
  try
    Result := HandleRequest(ARequest, AIndex, AShutdown);
  except
    on E: Exception do
      Result := BuildError(ARequest.GetValue('id'), -32603, E.Message);
  end;
end;

procedure RunServer;
var
  LIndex: TRadIASemanticIndex;
  LInput: string;
  LRequest: TJSONObject;
  LResponse: TJSONObject;
  LShutdown: Boolean;
begin
  LShutdown := False;
  LIndex := TRadIASemanticIndex.Create;
  try
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
          LResponse := HandleRequestSafely(LRequest, LIndex, LShutdown);
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
  finally
    LIndex.Free;
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
