unit RadIA.Core.SemanticQueryTools;

interface

uses
  RadIA.Core.SemanticQueries,
  RadIA.Core.Tools;

procedure RegisterRadIASemanticQueryTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticQueryService
);

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.SysUtils;

type
  TRadIAGetSemanticContextTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIASemanticQueryService;
  public
    constructor Create(const AService: IRadIASemanticQueryService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAFindSymbolReferencesTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIASemanticQueryService;
    function BuildAmbiguousError(
      const ASymbol: string;
      const ASymbols: TArray<TRadIASemanticLocation>
    ): TRadIAToolResult;
    function BuildResult(
      const ASymbol: string;
      const ASymbolId: string;
      const AReferences: TArray<TRadIASemanticReferenceLocation>
    ): TRadIAToolResult;
    function TryResolveSymbolId(
      const ASymbol: string;
      const AUnit: string;
      out ASymbolId: string;
      out AFailure: TRadIAToolResult
    ): Boolean;
  public
    constructor Create(const AService: IRadIASemanticQueryService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["symbol"],"properties":{' +
    '"symbol":{"type":"string"},"maxCharacters":{"type":"integer",' +
    '"minimum":256,"maximum":32768}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["symbol","context"],"properties":{' +
    '"symbol":{"type":"string"},"context":{"type":"string"}}}';
  CReferencesInputSchema =
    '{"type":"object","required":["symbol"],"properties":{' +
    '"symbol":{"type":"string","minLength":1},' +
    '"unit":{"type":"string"},' +
    '"includeCandidates":{"type":"boolean"},' +
    '"maxItems":{"type":"integer","minimum":1,"maximum":1000}}' +
    ',"additionalProperties":false}';
  CReferencesOutputSchema =
    '{"type":"object","required":["symbol","symbolId","references"],' +
    '"properties":{"symbol":{"type":"string"},' +
    '"symbolId":{"type":"string"},"references":{"type":"array"}}}';

constructor TRadIAGetSemanticContextTool.Create(
  const AService: IRadIASemanticQueryService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAGetSemanticContextTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LContext: string;
  LError: string;
  LMaxCharacters: Integer;
  LOutput: TJSONObject;
  LSymbol: string;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Semantic context arguments must be a JSON object.'
    ));
  try
    LSymbol := Trim(LArguments.GetValue<string>('symbol', ''));
    LMaxCharacters := LArguments.GetValue<Integer>('maxCharacters', 8192);
    if LSymbol = '' then
      Exit(TRadIAToolResult.Failed(
        'invalid_request',
        'A symbol name is required.'
      ));
    if not FService.BuildContext(
      LSymbol,
      LMaxCharacters,
      LContext,
      LError
    ) then
      Exit(TRadIAToolResult.Failed(
        'semantic_context_unavailable',
        LError +
        ' Use GetEditorSemanticContext for bounded active-unit fallback.'
      ));
    LOutput := TJSONObject.Create;
    try
      LOutput.AddPair('symbol', LSymbol);
      LOutput.AddPair('context', LContext);
      Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
    finally
      LOutput.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAGetSemanticContextTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetSemanticContext',
    '1.0.0',
    'Returns indexed declarations and resolved inherited members for a Delphi symbol.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(5000, True);
end;

constructor TRadIAFindSymbolReferencesTool.Create(
  const AService: IRadIASemanticQueryService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAFindSymbolReferencesTool.BuildAmbiguousError(
  const ASymbol: string;
  const ASymbols: TArray<TRadIASemanticLocation>
): TRadIAToolResult;
var
  LAlternative: string;
  LMessage: string;
  LSymbol: TRadIASemanticLocation;
begin
  LMessage := 'The symbol "' + ASymbol + '" is ambiguous. Specify unit. ' +
    'Available declarations: ';
  for LSymbol in ASymbols do
  begin
    LAlternative := LSymbol.UnitKey;
    if LAlternative.IsEmpty then
      LAlternative := LSymbol.FileName;
    if not LAlternative.IsEmpty and
      not ContainsText(LMessage, LAlternative) then
      LMessage := LMessage + LAlternative + '; ';
  end;
  Result := TRadIAToolResult.Failed('ambiguous_symbol', Trim(LMessage));
end;

function TRadIAFindSymbolReferencesTool.BuildResult(
  const ASymbol: string;
  const ASymbolId: string;
  const AReferences: TArray<TRadIASemanticReferenceLocation>
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LReference: TRadIASemanticReferenceLocation;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('symbol', ASymbol);
    LRoot.AddPair('symbolId', ASymbolId);
    LArray := TJSONArray.Create;
    for LReference in AReferences do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('unit', LReference.UnitKey);
      LItem.AddPair('fileName', LReference.FileName);
      LItem.AddPair('line', TJSONNumber.Create(LReference.Line));
      LItem.AddPair('column', TJSONNumber.Create(LReference.Column));
      LItem.AddPair(
        'startOffset',
        TJSONNumber.Create(LReference.StartOffset)
      );
      LItem.AddPair('length', TJSONNumber.Create(LReference.Length));
      LItem.AddPair('kind', LReference.Kind);
      LItem.AddPair('reason', LReference.Reason);
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair('references', LArray);
    LRoot.AddPair(
      'referenceCount',
      TJSONNumber.Create(Length(AReferences))
    );
    LRoot.AddPair(
      'navigationTool',
      'Use NavigateToFile with fileName, line, and column.'
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAFindSymbolReferencesTool.TryResolveSymbolId(
  const ASymbol: string;
  const AUnit: string;
  out ASymbolId: string;
  out AFailure: TRadIAToolResult
): Boolean;
var
  LError: string;
  LIds: TDictionary<string, Boolean>;
  LSelected: TList<TRadIASemanticLocation>;
  LSymbolItem: TRadIASemanticLocation;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  Result := False;
  ASymbolId := '';
  if not FService.FindSymbols(ASymbol, LSymbols, LError) then
  begin
    AFailure := TRadIAToolResult.Failed('semantic_query_failed', LError);
    Exit;
  end;
  LSelected := TList<TRadIASemanticLocation>.Create;
  LIds := TDictionary<string, Boolean>.Create;
  try
    for LSymbolItem in LSymbols do
      if AUnit.IsEmpty or SameText(LSymbolItem.UnitKey, AUnit) or
        SameText(LSymbolItem.FileName, AUnit) then
      begin
        LSelected.Add(LSymbolItem);
        if not LSymbolItem.SymbolId.IsEmpty then
          LIds.AddOrSetValue(LSymbolItem.SymbolId, True);
      end;
    if LSelected.Count = 0 then
    begin
      AFailure := TRadIAToolResult.Failed(
        'symbol_not_found',
        'No indexed declaration matched the requested symbol and unit.'
      );
      Exit;
    end;
    if LIds.Count <> 1 then
    begin
      AFailure := BuildAmbiguousError(ASymbol, LSelected.ToArray);
      Exit;
    end;
    for LSymbolItem in LSelected do
      if LIds.ContainsKey(LSymbolItem.SymbolId) then
      begin
        ASymbolId := LSymbolItem.SymbolId;
        Break;
      end;
    Result := not ASymbolId.IsEmpty;
  finally
    LIds.Free;
    LSelected.Free;
  end;
end;

function TRadIAFindSymbolReferencesTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LError: string;
  LFailure: TRadIAToolResult;
  LIncludeCandidates: Boolean;
  LMaxItems: Integer;
  LReferences: TArray<TRadIASemanticReferenceLocation>;
  LSymbol: string;
  LSymbolId: string;
  LUnit: string;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Reference arguments must be a JSON object.'
    ));
  try
    LSymbol := Trim(LArguments.GetValue<string>('symbol', ''));
    LUnit := Trim(LArguments.GetValue<string>('unit', ''));
    LIncludeCandidates := LArguments.GetValue<Boolean>(
      'includeCandidates',
      False
    );
    LMaxItems := LArguments.GetValue<Integer>('maxItems', 500);
    if LSymbol.IsEmpty then
      Exit(TRadIAToolResult.Failed(
        'invalid_request',
        'A symbol name is required.'
      ));
    if not TryResolveSymbolId(LSymbol, LUnit, LSymbolId, LFailure) then
      Exit(LFailure);
    if not FService.FindReferences(
      LSymbolId,
      LIncludeCandidates,
      LMaxItems,
      LReferences,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('reference_query_failed', LError));
    Result := BuildResult(LSymbol, LSymbolId, LReferences);
  finally
    LArguments.Free;
  end;
end;

function TRadIAFindSymbolReferencesTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'FindSymbolReferences',
    '1.0.0',
    'Finds confirmed Delphi symbol declarations and references. ' +
    'Ambiguous occurrences are excluded unless explicitly requested.',
    CReferencesInputSchema,
    CReferencesOutputSchema,
    trReadOnly
  ).WithExecutionOptions(10000, True);
end;

procedure RegisterRadIASemanticQueryTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticQueryService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAGetSemanticContextTool.Create(AService));
  ARegistry.RegisterTool(TRadIAFindSymbolReferencesTool.Create(AService));
end;

end.
