unit RadIA.Core.SemanticRefactoringTools;

interface

uses
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Patches,
  RadIA.Core.SemanticQueries,
  RadIA.Core.Tools;

procedure RegisterRadIASemanticRefactoringTools(
  const ARegistry: IRadIAToolRegistry;
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.Workspace;

type
  TRadIAReferenceList = TList<TRadIASemanticReferenceLocation>;
  TRadIAReferenceMap = TObjectDictionary<string, TRadIAReferenceList>;

  TRadIAPrepareRenameSymbolTool = class(TInterfacedObject, IRadIATool)
  private
    FMutation: IRadIAEditorMutationFacade;
    FPatches: IRadIAMultiFilePatchService;
    FQueries: IRadIASemanticQueryService;
    function BuildProposedContent(
      const ASnapshot: TRadIAEditorContent;
      const AReferences: TRadIAReferenceList;
      const AOldName: string;
      const ANewName: string;
      out AContent: string;
      out AError: string
    ): Boolean;
    function BuildResult(
      const ASymbol: string;
      const ANewName: string;
      const AReplacementCount: Integer;
      const APatchResult: TRadIAMultiFilePatchResult
    ): TRadIAToolResult;
    function BuildSpecs(
      const AReferences: TArray<TRadIASemanticReferenceLocation>;
      const AOldName: string;
      const ANewName: string;
      out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
      out AReplacementCount: Integer;
      out AError: string
    ): Boolean;
    function ResolveSymbolId(
      const ASymbol: string;
      const AUnit: string;
      out ASymbolId: string;
      out AErrorCode: string;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const AQueries: IRadIASemanticQueryService;
      const AMutation: IRadIAEditorMutationFacade;
      const APatches: IRadIAMultiFilePatchService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["symbol","newName"],' +
    '"properties":{"symbol":{"type":"string","minLength":1},' +
    '"newName":{"type":"string","minLength":1},' +
    '"unit":{"type":"string"}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state","symbol",' +
    '"newName","replacementCount","files"],"properties":{' +
    '"previewId":{"type":"string"},"state":{"type":"string"},' +
    '"symbol":{"type":"string"},"newName":{"type":"string"},' +
    '"replacementCount":{"type":"integer"},"files":{"type":"array"}}}';

function IsDelphiIdentifier(const AValue: string): Boolean;
const
  CReservedWords =
    '|and|array|as|asm|begin|case|class|const|constructor|destructor|' +
    'dispinterface|div|do|downto|else|end|except|exports|file|finalization|' +
    'finally|for|function|goto|if|implementation|in|inherited|initialization|' +
    'inline|interface|is|label|library|mod|nil|not|object|of|or|out|packed|' +
    'procedure|program|property|raise|record|repeat|resourcestring|set|shl|' +
    'shr|string|then|threadvar|to|try|type|unit|until|uses|var|while|with|xor|';
var
  LCharacter: Char;
  LIndex: Integer;
begin
  Result := not AValue.IsEmpty and
    CharInSet(AValue[1], ['A'..'Z', 'a'..'z', '_']);
  if not Result then
    Exit;
  for LIndex := 2 to Length(AValue) do
  begin
    LCharacter := AValue[LIndex];
    if not CharInSet(LCharacter, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
  end;
  Result := not ContainsText(
    CReservedWords,
    '|' + LowerCase(AValue) + '|'
  );
end;

function CompareReferenceOffsets(
  const ALeft: TRadIASemanticReferenceLocation;
  const ARight: TRadIASemanticReferenceLocation
): Integer;
begin
  Result := ARight.StartOffset - ALeft.StartOffset;
end;

constructor TRadIAPrepareRenameSymbolTool.Create(
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
begin
  inherited Create;
  if not Assigned(AQueries) then
    raise EArgumentNilException.Create('AQueries');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FQueries := AQueries;
  FMutation := AMutation;
  FPatches := APatches;
end;

function TRadIAPrepareRenameSymbolTool.BuildProposedContent(
  const ASnapshot: TRadIAEditorContent;
  const AReferences: TRadIAReferenceList;
  const AOldName: string;
  const ANewName: string;
  out AContent: string;
  out AError: string
): Boolean;
var
  LCurrent: string;
  LReference: TRadIASemanticReferenceLocation;
begin
  Result := False;
  AContent := ASnapshot.Content;
  AError := '';
  AReferences.Sort(
    TComparer<TRadIASemanticReferenceLocation>.Construct(
      CompareReferenceOffsets
    )
  );
  for LReference in AReferences do
  begin
    if (LReference.StartOffset < 0) or
      (LReference.Length <> Length(AOldName)) or
      (LReference.StartOffset + LReference.Length > Length(AContent)) then
    begin
      AError := 'The semantic reference range is outside the current file.';
      Exit;
    end;
    LCurrent := Copy(
      AContent,
      LReference.StartOffset + 1,
      LReference.Length
    );
    if not SameText(LCurrent, AOldName) then
    begin
      AError := 'A semantic reference changed after indexing. Refresh and retry.';
      Exit;
    end;
    Delete(AContent, LReference.StartOffset + 1, LReference.Length);
    Insert(ANewName, AContent, LReference.StartOffset + 1);
  end;
  Result := True;
end;

function TRadIAPrepareRenameSymbolTool.BuildResult(
  const ASymbol: string;
  const ANewName: string;
  const AReplacementCount: Integer;
  const APatchResult: TRadIAMultiFilePatchResult
): TRadIAToolResult;
var
  LEntry: TRadIAMultiFilePatchEntry;
  LFiles: TJSONArray;
  LRoot: TJSONObject;
begin
  if not APatchResult.Success then
    Exit(TRadIAToolResult.Failed(
      APatchResult.ErrorCode,
      APatchResult.ErrorMessage
    ));
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('previewId', APatchResult.Preview.Id);
    LRoot.AddPair('state', 'prepared');
    LRoot.AddPair('symbol', ASymbol);
    LRoot.AddPair('newName', ANewName);
    LRoot.AddPair(
      'replacementCount',
      TJSONNumber.Create(AReplacementCount)
    );
    LFiles := TJSONArray.Create;
    LRoot.AddPair('files', LFiles);
    for LEntry in APatchResult.Preview.Entries do
      LFiles.Add(LEntry.Spec.TargetFile);
    LRoot.AddPair(
      'nextAction',
      'Review the preview, then use ApplyMultiFilePatch. ' +
      'Use RevertMultiFilePatch to roll back.'
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAPrepareRenameSymbolTool.BuildSpecs(
  const AReferences: TArray<TRadIASemanticReferenceLocation>;
  const AOldName: string;
  const ANewName: string;
  out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
  out AReplacementCount: Integer;
  out AError: string
): Boolean;
var
  LEntry: TPair<string, TRadIAReferenceList>;
  LMap: TRadIAReferenceMap;
  LReference: TRadIASemanticReferenceLocation;
  LSnapshot: TRadIAEditorContent;
  LSpecList: TList<TRadIAMultiFilePatchSpec>;
  LProposedContent: string;
begin
  Result := False;
  ASpecs := nil;
  AReplacementCount := 0;
  AError := '';
  LMap := TRadIAReferenceMap.Create([doOwnsValues]);
  LSpecList := TList<TRadIAMultiFilePatchSpec>.Create;
  try
    for LReference in AReferences do
    begin
      if not LMap.ContainsKey(LReference.FileName) then
        LMap.Add(LReference.FileName, TRadIAReferenceList.Create);
      LMap[LReference.FileName].Add(LReference);
      Inc(AReplacementCount);
    end;
    for LEntry in LMap do
    begin
      LSnapshot := FMutation.ReadContent(LEntry.Key, -1);
      if LSnapshot.FileName.IsEmpty or LSnapshot.Truncated then
      begin
        AError := 'A referenced file is not fully readable: ' + LEntry.Key;
        Exit;
      end;
      if not BuildProposedContent(
        LSnapshot,
        LEntry.Value,
        AOldName,
        ANewName,
        LProposedContent,
        AError
      ) then
        Exit;
      LSpecList.Add(TRadIAMultiFilePatchSpec.Create(
        LSnapshot.FileName,
        LSnapshot.Revision,
        LProposedContent
      ));
    end;
    ASpecs := LSpecList.ToArray;
    Result := Length(ASpecs) > 0;
    if not Result then
      AError := 'No confirmed semantic references were found.';
  finally
    LSpecList.Free;
    LMap.Free;
  end;
end;

function TRadIAPrepareRenameSymbolTool.ResolveSymbolId(
  const ASymbol: string;
  const AUnit: string;
  out ASymbolId: string;
  out AErrorCode: string;
  out AError: string
): Boolean;
var
  LIds: TDictionary<string, Boolean>;
  LItem: TRadIASemanticLocation;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  Result := False;
  ASymbolId := '';
  AErrorCode := 'semantic_query_failed';
  if not FQueries.FindSymbols(ASymbol, LSymbols, AError) then
    Exit;
  LIds := TDictionary<string, Boolean>.Create;
  try
    for LItem in LSymbols do
      if AUnit.IsEmpty or SameText(LItem.UnitKey, AUnit) or
        SameText(LItem.FileName, AUnit) then
        if not LItem.SymbolId.IsEmpty then
          LIds.AddOrSetValue(LItem.SymbolId, True);
    if LIds.Count = 0 then
    begin
      AErrorCode := 'symbol_not_found';
      AError := 'No indexed declaration matched the requested symbol and unit.';
      Exit;
    end;
    if LIds.Count > 1 then
    begin
      AErrorCode := 'ambiguous_symbol';
      AError := 'The symbol is ambiguous. Specify its unit before renaming.';
      Exit;
    end;
    ASymbolId := LIds.Keys.ToArray[0];
    Result := True;
  finally
    LIds.Free;
  end;
end;

function TRadIAPrepareRenameSymbolTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LError: string;
  LErrorCode: string;
  LNewName: string;
  LPatchResult: TRadIAMultiFilePatchResult;
  LReferences: TArray<TRadIASemanticReferenceLocation>;
  LReplacementCount: Integer;
  LSpecs: TArray<TRadIAMultiFilePatchSpec>;
  LSymbol: string;
  LSymbolId: string;
  LUnit: string;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Rename arguments must be a JSON object.'
    ));
  try
    LSymbol := Trim(LArguments.GetValue<string>('symbol', ''));
    LNewName := Trim(LArguments.GetValue<string>('newName', ''));
    LUnit := Trim(LArguments.GetValue<string>('unit', ''));
    if not IsDelphiIdentifier(LSymbol) or
      not IsDelphiIdentifier(LNewName) or SameText(LSymbol, LNewName) then
      Exit(TRadIAToolResult.Failed(
        'invalid_identifier',
        'Both names must be distinct valid Delphi identifiers.'
      ));
    if not ResolveSymbolId(
      LSymbol,
      LUnit,
      LSymbolId,
      LErrorCode,
      LError
    ) then
      Exit(TRadIAToolResult.Failed(LErrorCode, LError));
    if not FQueries.FindReferences(
      LSymbolId,
      False,
      1000,
      LReferences,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('reference_query_failed', LError));
    if not BuildSpecs(
      LReferences,
      LSymbol,
      LNewName,
      LSpecs,
      LReplacementCount,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('rename_precondition_failed', LError));
    LPatchResult := FPatches.Prepare(LSpecs);
    Result := BuildResult(
      LSymbol,
      LNewName,
      LReplacementCount,
      LPatchResult
    );
  finally
    LArguments.Free;
  end;
end;

function TRadIAPrepareRenameSymbolTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareRenameSymbol',
    '1.0.0',
    'Prepares an exact semantic Delphi symbol rename across Pascal and DFM files.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

procedure RegisterRadIASemanticRefactoringTools(
  const ARegistry: IRadIAToolRegistry;
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareRenameSymbolTool.Create(
    AQueries,
    AMutation,
    APatches
  ));
end;

end.
