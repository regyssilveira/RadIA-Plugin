unit RadIA.Core.SemanticExtractMethodTools;

interface

uses
  RadIA.Core.MultiFilePatches,
  RadIA.Core.SemanticQueries,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

procedure RegisterRadIASemanticExtractMethodTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const ARoutines: IRadIASemanticRoutineService;
  const APatches: IRadIAMultiFilePatchService
);

implementation

uses
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.DelphiExtraction,
  RadIA.Core.DelphiSignatures;

type
  TRadIAPrepareExtractMethodTool = class(TInterfacedObject, IRadIATool)
  private
    FPatches: IRadIAMultiFilePatchService;
    FQueries: IRadIASemanticQueryService;
    FRoutines: IRadIASemanticRoutineService;
    FWorkspace: IRadIAWorkspaceFacade;
    function BuildPreview(
      const ASnapshot: TRadIAEditorContent;
      const ASelection: TRadIADelphiExtractSelection;
      const ARoutine: TRadIADelphiExtractRoutine;
      const AMethodName: string;
      const AParameters: TArray<TRadIADelphiExtractParameter>;
      out AProposedContent: string;
      out AError: string
    ): Boolean;
    function FindDeclarationOffset(
      const ASnapshot: TRadIAEditorContent;
      const ARoutine: TRadIADelphiExtractRoutine;
      out AOffset: Integer;
      out AIndent: string;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AQueries: IRadIASemanticQueryService;
      const ARoutines: IRadIASemanticRoutineService;
      const APatches: IRadIAMultiFilePatchService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["methodName"],"properties":{' +
    '"methodName":{"type":"string","minLength":1}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state","methodName",' +
    '"file","parameterCount","nextAction"],"properties":{' +
    '"previewId":{"type":"string"},"state":{"type":"string"},' +
    '"methodName":{"type":"string"},"file":{"type":"string"},' +
    '"parameterCount":{"type":"integer"},' +
    '"nextAction":{"type":"string"}}}';

function IsDelphiIdentifier(const AValue: string): Boolean;
const
  CReservedWords =
    '|and|array|as|asm|begin|case|class|const|constructor|destructor|' +
    'dispinterface|div|do|downto|else|end|except|exports|file|' +
    'finalization|finally|for|function|goto|if|implementation|in|' +
    'inherited|initialization|inline|interface|is|label|library|mod|' +
    'nil|not|object|of|or|out|packed|procedure|program|property|raise|' +
    'record|repeat|resourcestring|set|shl|shr|string|then|threadvar|' +
    'to|try|type|unit|until|uses|var|while|with|xor|';
var
  LIndex: Integer;
begin
  Result := not AValue.IsEmpty and
    CharInSet(AValue[1], ['A'..'Z', 'a'..'z', '_']);
  if not Result then
    Exit;
  for LIndex := 2 to Length(AValue) do
    if not CharInSet(
      AValue[LIndex],
      ['A'..'Z', 'a'..'z', '0'..'9', '_']
    ) then
      Exit(False);
  Result := not ContainsText(
    CReservedWords,
    '|' + LowerCase(AValue) + '|'
  );
end;

function DetectLineBreak(const ASource: string): string;
begin
  if Pos(#13#10, ASource) > 0 then
    Result := #13#10
  else
    Result := #10;
end;

function LineIndentAt(const ASource: string; const AOffset: Integer): string;
var
  LIndex: Integer;
  LStart: Integer;
begin
  LStart := AOffset + 1;
  while (LStart > 1) and
    not CharInSet(ASource[LStart - 1], [#10, #13]) do
    Dec(LStart);
  LIndex := LStart;
  while (LIndex <= Length(ASource)) and
    CharInSet(ASource[LIndex], [' ', #9]) do
    Inc(LIndex);
  Result := Copy(ASource, LStart, LIndex - LStart);
end;

function LineStartOffset(const ASource: string; const AOffset: Integer): Integer;
begin
  Result := AOffset;
  while (Result > 0) and
    not CharInSet(ASource[Result], [#10, #13]) do
    Dec(Result);
end;

function ParameterModifier(
  const AKind: TRadIADelphiExtractParameterKind
): string;
begin
  case AKind of
    epkConst: Result := 'const ';
    epkVar: Result := 'var ';
    epkOut: Result := 'out ';
  else
    Result := '';
  end;
end;

function RenderParameters(
  const AParameters: TArray<TRadIADelphiExtractParameter>
): string;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to Length(AParameters) - 1 do
  begin
    if LIndex > 0 then
      Result := Result + '; ';
    Result := Result + ParameterModifier(AParameters[LIndex].Kind) +
      AParameters[LIndex].Name + ': ' + AParameters[LIndex].TypeName;
  end;
  if not Result.IsEmpty then
    Result := '(' + Result + ')';
end;

function RenderArguments(
  const AParameters: TArray<TRadIADelphiExtractParameter>
): string;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to Length(AParameters) - 1 do
  begin
    if LIndex > 0 then
      Result := Result + ', ';
    Result := Result + AParameters[LIndex].Name;
  end;
  if not Result.IsEmpty then
    Result := '(' + Result + ')';
end;

procedure InsertAt(var AContent: string; const AOffset: Integer; const AText: string);
begin
  Insert(AText, AContent, AOffset + 1);
end;

procedure ReplaceRange(
  var AContent: string;
  const AOffset: Integer;
  const ALength: Integer;
  const AText: string
);
begin
  Delete(AContent, AOffset + 1, ALength);
  InsertAt(AContent, AOffset, AText);
end;

constructor TRadIAPrepareExtractMethodTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const ARoutines: IRadIASemanticRoutineService;
  const APatches: IRadIAMultiFilePatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AQueries) then
    raise EArgumentNilException.Create('AQueries');
  if not Assigned(ARoutines) then
    raise EArgumentNilException.Create('ARoutines');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FWorkspace := AWorkspace;
  FQueries := AQueries;
  FRoutines := ARoutines;
  FPatches := APatches;
end;

function TRadIAPrepareExtractMethodTool.FindDeclarationOffset(
  const ASnapshot: TRadIAEditorContent;
  const ARoutine: TRadIADelphiExtractRoutine;
  out AOffset: Integer;
  out AIndent: string;
  out AError: string
): Boolean;
var
  LIndex: Integer;
  LLocation: TRadIASemanticLocation;
  LParsed: TRadIADelphiSignature;
  LRoutines: TArray<TRadIASemanticLocation>;
begin
  Result := False;
  AOffset := -1;
  AIndent := '';
  if not TRadIADelphiSignatureParser.TryParse(
    ARoutine.Signature,
    LParsed,
    AError
  ) then
    Exit;
  if not FRoutines.FindRoutineSymbols(
    ARoutine.Name,
    ASnapshot.UnitName,
    ARoutine.ContainerName,
    LParsed.RenderCore(ARoutine.Name),
    LRoutines,
    AError
  ) then
    Exit;
  for LIndex := 0 to Length(LRoutines) - 1 do
  begin
    LLocation := LRoutines[LIndex];
    if not SameText(LLocation.DeclarationSection, 'interface') or
      not SameText(LLocation.FileName, ASnapshot.FileName) then
      Continue;
    if AOffset >= 0 then
    begin
      AError := 'More than one class declaration matched the active method.';
      Exit;
    end;
    AIndent := LineIndentAt(ASnapshot.Content, LLocation.StartOffset);
    AOffset := LineStartOffset(ASnapshot.Content, LLocation.StartOffset);
  end;
  Result := AOffset >= 0;
  if not Result then
    AError := 'The class declaration for the active method was not found.';
end;

function TRadIAPrepareExtractMethodTool.BuildPreview(
  const ASnapshot: TRadIAEditorContent;
  const ASelection: TRadIADelphiExtractSelection;
  const ARoutine: TRadIADelphiExtractRoutine;
  const AMethodName: string;
  const AParameters: TArray<TRadIADelphiExtractParameter>;
  out AProposedContent: string;
  out AError: string
): Boolean;
var
  LArguments: string;
  LCall: string;
  LDeclaration: string;
  LDeclarationIndent: string;
  LDeclarationOffset: Integer;
  LImplementation: string;
  LLineBreak: string;
  LParameters: string;
  LSelectionIndent: string;
begin
  Result := False;
  if ARoutine.ContainerName.IsEmpty then
  begin
    AError := 'Extract Method currently requires a method inside a Delphi type.';
    Exit;
  end;
  if not FindDeclarationOffset(
    ASnapshot,
    ARoutine,
    LDeclarationOffset,
    LDeclarationIndent,
    AError
  ) then
    Exit;
  LLineBreak := DetectLineBreak(ASnapshot.Content);
  LParameters := RenderParameters(AParameters);
  LArguments := RenderArguments(AParameters);
  LSelectionIndent := LineIndentAt(
    ASnapshot.Content,
    ASelection.StartOffset
  );
  LCall := LSelectionIndent + AMethodName + LArguments + ';';
  if ASelection.Content.EndsWith(LLineBreak) then
    LCall := LCall + LLineBreak;
  LImplementation := 'procedure ' + ARoutine.ContainerName + '.' +
    AMethodName + LParameters + ';' + LLineBreak + 'begin' + LLineBreak +
    ASelection.Content + 'end;' + LLineBreak + LLineBreak;
  LDeclaration := LDeclarationIndent + 'procedure ' + AMethodName +
    LParameters + ';' + LLineBreak;
  AProposedContent := ASnapshot.Content;
  ReplaceRange(
    AProposedContent,
    ASelection.StartOffset,
    ASelection.Length,
    LCall
  );
  InsertAt(AProposedContent, ARoutine.StartOffset, LImplementation);
  InsertAt(AProposedContent, LDeclarationOffset, LDeclaration);
  Result := True;
end;

function TRadIAPrepareExtractMethodTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LEditorSelection: TRadIAEditorSelection;
  LError: string;
  LMethodName: string;
  LParameters: TArray<TRadIADelphiExtractParameter>;
  LPatchResult: TRadIAMultiFilePatchResult;
  LProposedContent: string;
  LRoutine: TRadIADelphiExtractRoutine;
  LSelection: TRadIADelphiExtractSelection;
  LSnapshot: TRadIAEditorContent;
  LSpec: TRadIAMultiFilePatchSpec;
  LRoot: TJSONObject;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Extract Method arguments must be a JSON object.'
    ));
  try
    LMethodName := Trim(LArguments.GetValue<string>('methodName', ''));
    if not IsDelphiIdentifier(LMethodName) then
      Exit(TRadIAToolResult.Failed(
        'invalid_identifier',
        'The extracted method name must be a valid Delphi identifier.'
      ));
    LSnapshot := FWorkspace.GetEditorContent(-1);
    LEditorSelection := FWorkspace.GetEditorSelection;
    if LSnapshot.FileName.IsEmpty or LSnapshot.Truncated then
      Exit(TRadIAToolResult.Failed(
        'editor_unavailable',
        'The complete active Delphi editor buffer is required.'
      ));
    if not TRadIADelphiExtractionAnalyzer.TryAnalyze(
      LSnapshot.Content,
      LEditorSelection.Content,
      LEditorSelection.Line,
      LEditorSelection.Column,
      LSelection,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('extract_method_precondition', LError));
    if not TRadIADelphiExtractionAnalyzer.TryFindEnclosingRoutine(
      LSnapshot.Content,
      LSelection,
      LRoutine,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('extract_method_precondition', LError));
    if not TRadIADelphiExtractionAnalyzer.TryInferParameters(
      LSnapshot.Content,
      LSelection,
      LRoutine.Signature,
      LRoutine.StartOffset,
      LParameters,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('extract_method_precondition', LError));
    if FQueries.HasResolvedMember(LRoutine.ContainerName, LMethodName) then
      Exit(TRadIAToolResult.Failed(
        'member_exists',
        'The target type already declares the requested method name.'
      ));
    if not BuildPreview(
      LSnapshot,
      LSelection,
      LRoutine,
      LMethodName,
      LParameters,
      LProposedContent,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('extract_method_precondition', LError));
    LSpec := TRadIAMultiFilePatchSpec.Create(
      LSnapshot.FileName,
      LSnapshot.Revision,
      LProposedContent
    );
    LPatchResult := FPatches.Prepare([LSpec]);
    if not LPatchResult.Success then
      Exit(TRadIAToolResult.Failed(
        LPatchResult.ErrorCode,
        LPatchResult.ErrorMessage
      ));
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('previewId', LPatchResult.Preview.Id);
      LRoot.AddPair('state', 'prepared');
      LRoot.AddPair('methodName', LMethodName);
      LRoot.AddPair('file', LSnapshot.FileName);
      LRoot.AddPair(
        'parameterCount',
        TJSONNumber.Create(Length(LParameters))
      );
      LRoot.AddPair(
        'nextAction',
        'Review the preview, then use ApplyMultiFilePatch. ' +
        'Use RevertMultiFilePatch to roll back.'
      );
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAPrepareExtractMethodTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareExtractMethod',
    '1.0.0',
    'Prepares a transactional Extract Method refactoring from the active Delphi selection.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

procedure RegisterRadIASemanticExtractMethodTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const ARoutines: IRadIASemanticRoutineService;
  const APatches: IRadIAMultiFilePatchService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareExtractMethodTool.Create(
    AWorkspace,
    AQueries,
    ARoutines,
    APatches
  ));
end;

end.
