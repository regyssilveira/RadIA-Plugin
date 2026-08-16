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
  const APatches: IRadIAMultiFilePatchService;
  const AHierarchy: IRadIASemanticHierarchyService = nil
);

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.JSON,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.Workspace;

type
  TRadIAReferenceList = TList<TRadIASemanticReferenceLocation>;
  TRadIAReferenceMap = TObjectDictionary<string, TRadIAReferenceList>;

  TRadIAHierarchyRenameRequest = record
    ContainerName: string;
    Signature: string;
    SymbolName: string;
    UnitName: string;
  end;

  TRadIAPrepareRenameSymbolTool = class(TInterfacedObject, IRadIATool)
  private
    FMutation: IRadIAEditorMutationFacade;
    FPatches: IRadIAMultiFilePatchService;
    FQueries: IRadIASemanticQueryService;
    FHierarchy: IRadIASemanticHierarchyService;
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
      const AHierarchySymbolCount: Integer;
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
    function CollectHierarchySymbolIds(
      const ASymbol: string;
      const AContainer: string;
      const AUnit: string;
      const ASignature: string;
      const ATypes: TArray<TRadIASemanticLocation>;
      out ASymbolIds: TArray<string>;
      out AError: string
    ): Boolean;
    function CollectTargetShape(
      const ASymbol: string;
      const AContainer: string;
      const AUnit: string;
      const ASignature: string;
      const AMembers: TArray<TRadIASemanticLocation>;
      out AShape: string;
      out AError: string
    ): Boolean;
    function CollectReferencesForIds(
      const ASymbolIds: TArray<string>;
      out AReferences: TArray<TRadIASemanticReferenceLocation>;
      out AError: string
    ): Boolean;
    function CollectRelatedTypes(
      const AContainer: string;
      const AUnit: string;
      const ATypes: TArray<TRadIASemanticLocation>;
      out ARelated: TDictionary<string, Boolean>;
      out AError: string
    ): Boolean;
    function ResolveHierarchyRoot(
      const AContainer: string;
      const AUnit: string;
      const ATypes: TArray<TRadIASemanticLocation>;
      out ARoot: TRadIASemanticLocation;
      out AError: string
    ): Boolean;
    function TouchesRelatedType(
      const ACandidate: TRadIASemanticLocation;
      const ATypes: TArray<TRadIASemanticLocation>;
      const ARelated: TDictionary<string, Boolean>
    ): Boolean;
    function ResolveSymbolId(
      const ASymbol: string;
      const AUnit: string;
      out ASymbolId: string;
      out AErrorCode: string;
      out AError: string
    ): Boolean;
    function ResolveHierarchyReferences(
      const ARequest: TRadIAHierarchyRenameRequest;
      out AReferences: TArray<TRadIASemanticReferenceLocation>;
      out ASymbolCount: Integer;
      out AErrorCode: string;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const AQueries: IRadIASemanticQueryService;
      const AMutation: IRadIAEditorMutationFacade;
      const APatches: IRadIAMultiFilePatchService;
      const AHierarchy: IRadIASemanticHierarchyService
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
    '"unit":{"type":"string"},"container":{"type":"string"},' +
    '"signature":{"type":"string"},' +
    '"includeHierarchy":{"type":"boolean"}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state","symbol",' +
    '"newName","replacementCount","files"],"properties":{' +
    '"previewId":{"type":"string"},"state":{"type":"string"},' +
    '"symbol":{"type":"string"},"newName":{"type":"string"},' +
    '"replacementCount":{"type":"integer"},' +
    '"hierarchySymbolCount":{"type":"integer"},' +
    '"files":{"type":"array"}}}';

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

function NormalizeRoutineSignature(
  const ASignature: string;
  const ASymbol: string
): string;
const
  CDirectives: array[0..6] of string = (
    'virtual', 'dynamic', 'override', 'abstract', 'reintroduce', 'overload',
    'final'
  );
var
  LDirective: string;
begin
  Result := LowerCase(ASignature);
  Result := TRegEx.Replace(
    Result,
    '\b' + TRegEx.Escape(LowerCase(ASymbol)) + '\b',
    '__radia_member__'
  );
  for LDirective in CDirectives do
    Result := TRegEx.Replace(Result, '\b' + LDirective + '\b', '');
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '', [rfReplaceAll]);
end;

function TypeIdentity(const ASymbol: TRadIASemanticLocation): string;
begin
  Result := LowerCase(ASymbol.UnitKey + '.' + ASymbol.Name);
end;

function CountTypesNamed(
  const AName: string;
  const ATypes: TArray<TRadIASemanticLocation>
): Integer;
var
  LType: TRadIASemanticLocation;
begin
  Result := 0;
  for LType in ATypes do
    if SameText(LType.Name, AName) then
      Inc(Result);
end;

function ReferencesType(
  const AReference: string;
  const ATarget: TRadIASemanticLocation;
  const ATypes: TArray<TRadIASemanticLocation>
): Boolean;
begin
  if Pos('.', AReference) > 0 then
    Exit(SameText(AReference, ATarget.UnitKey + '.' + ATarget.Name));
  Result := SameText(AReference, ATarget.Name) and
    (CountTypesNamed(ATarget.Name, ATypes) = 1);
end;

function TypesAreDirectlyRelated(
  const ALeft: TRadIASemanticLocation;
  const ARight: TRadIASemanticLocation;
  const ATypes: TArray<TRadIASemanticLocation>
): Boolean;
var
  LAncestor: string;
begin
  for LAncestor in ALeft.AncestorNames do
    if ReferencesType(LAncestor, ARight, ATypes) then
      Exit(True);
  for LAncestor in ARight.AncestorNames do
    if ReferencesType(LAncestor, ALeft, ATypes) then
      Exit(True);
  Result := False;
end;

constructor TRadIAPrepareRenameSymbolTool.Create(
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService;
  const AHierarchy: IRadIASemanticHierarchyService
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
  FHierarchy := AHierarchy;
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
  const AHierarchySymbolCount: Integer;
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
    if AHierarchySymbolCount > 0 then
      LRoot.AddPair(
        'hierarchySymbolCount',
        TJSONNumber.Create(AHierarchySymbolCount)
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

function TRadIAPrepareRenameSymbolTool.ResolveHierarchyRoot(
  const AContainer: string;
  const AUnit: string;
  const ATypes: TArray<TRadIASemanticLocation>;
  out ARoot: TRadIASemanticLocation;
  out AError: string
): Boolean;
var
  LCandidate: TRadIASemanticLocation;
  LRootCount: Integer;
begin
  AError := '';
  LRootCount := 0;
  for LCandidate in ATypes do
    if SameText(LCandidate.Name, AContainer) and
      (AUnit.IsEmpty or SameText(LCandidate.UnitKey, AUnit) or
      SameText(LCandidate.FileName, AUnit)) then
    begin
      ARoot := LCandidate;
      Inc(LRootCount);
    end;
  Result := LRootCount = 1;
  if Result then
    Exit;
  if LRootCount = 0 then
    AError := 'The requested hierarchy container was not indexed.'
  else
    AError := 'The hierarchy container is ambiguous. Specify its unit.';
end;

function TRadIAPrepareRenameSymbolTool.TouchesRelatedType(
  const ACandidate: TRadIASemanticLocation;
  const ATypes: TArray<TRadIASemanticLocation>;
  const ARelated: TDictionary<string, Boolean>
): Boolean;
var
  LKnown: TRadIASemanticLocation;
begin
  for LKnown in ATypes do
    if ARelated.ContainsKey(TypeIdentity(LKnown)) and
      TypesAreDirectlyRelated(ACandidate, LKnown, ATypes) then
      Exit(True);
  Result := False;
end;

function TRadIAPrepareRenameSymbolTool.CollectRelatedTypes(
  const AContainer: string;
  const AUnit: string;
  const ATypes: TArray<TRadIASemanticLocation>;
  out ARelated: TDictionary<string, Boolean>;
  out AError: string
): Boolean;
var
  LAdded: Boolean;
  LCandidate: TRadIASemanticLocation;
  LRoot: TRadIASemanticLocation;
begin
  ARelated := nil;
  if not ResolveHierarchyRoot(AContainer, AUnit, ATypes, LRoot, AError) then
    Exit(False);
  ARelated := TDictionary<string, Boolean>.Create;
  ARelated.Add(TypeIdentity(LRoot), True);
  repeat
    LAdded := False;
    for LCandidate in ATypes do
    begin
      if ARelated.ContainsKey(TypeIdentity(LCandidate)) then
        Continue;
      if not TouchesRelatedType(LCandidate, ATypes, ARelated) then
        Continue;
      ARelated.Add(TypeIdentity(LCandidate), True);
      LAdded := True;
    end;
  until not LAdded;
  Result := True;
end;

function TRadIAPrepareRenameSymbolTool.CollectTargetShape(
  const ASymbol: string;
  const AContainer: string;
  const AUnit: string;
  const ASignature: string;
  const AMembers: TArray<TRadIASemanticLocation>;
  out AShape: string;
  out AError: string
): Boolean;
var
  LItem: TRadIASemanticLocation;
  LShapes: TDictionary<string, Boolean>;
begin
  LShapes := TDictionary<string, Boolean>.Create;
  try
    for LItem in AMembers do
      if SameText(LItem.ContainerName, AContainer) and
        (AUnit.IsEmpty or SameText(LItem.UnitKey, AUnit)) then
        if ASignature.IsEmpty or SameText(LItem.Signature, ASignature) then
          LShapes.AddOrSetValue(
            NormalizeRoutineSignature(LItem.Signature, ASymbol),
            True
          );
    if LShapes.Count <> 1 then
    begin
      AError := 'The hierarchy member is missing or overloaded. ' +
        'Specify its exact signature.';
      Exit(False);
    end;
    AShape := LShapes.Keys.ToArray[0];
    Result := True;
  finally
    LShapes.Free;
  end;
end;

function TRadIAPrepareRenameSymbolTool.CollectHierarchySymbolIds(
  const ASymbol: string;
  const AContainer: string;
  const AUnit: string;
  const ASignature: string;
  const ATypes: TArray<TRadIASemanticLocation>;
  out ASymbolIds: TArray<string>;
  out AError: string
): Boolean;
var
  LIds: TDictionary<string, Boolean>;
  LItem: TRadIASemanticLocation;
  LMembers: TArray<TRadIASemanticLocation>;
  LRelated: TDictionary<string, Boolean>;
  LShape: string;
begin
  ASymbolIds := nil;
  if not CollectRelatedTypes(AContainer, AUnit, ATypes, LRelated, AError) then
    Exit(False);
  LIds := TDictionary<string, Boolean>.Create;
  try
    if not FQueries.FindSymbols(ASymbol, LMembers, AError) then
      Exit(False);
    if not CollectTargetShape(
      ASymbol,
      AContainer,
      AUnit,
      ASignature,
      LMembers,
      LShape,
      AError
    ) then
      Exit(False);
    for LItem in LMembers do
      if LRelated.ContainsKey(
        LowerCase(LItem.UnitKey + '.' + LItem.ContainerName)
      ) and SameText(
        NormalizeRoutineSignature(LItem.Signature, ASymbol),
        LShape
      ) and
        not LItem.SymbolId.IsEmpty then
        LIds.AddOrSetValue(LItem.SymbolId, True);
    ASymbolIds := LIds.Keys.ToArray;
    Result := Length(ASymbolIds) > 0;
    if not Result then
      AError := 'No proven hierarchy declarations matched the requested member.';
  finally
    LIds.Free;
    LRelated.Free;
  end;
end;

function TRadIAPrepareRenameSymbolTool.CollectReferencesForIds(
  const ASymbolIds: TArray<string>;
  out AReferences: TArray<TRadIASemanticReferenceLocation>;
  out AError: string
): Boolean;
var
  LAll: TList<TRadIASemanticReferenceLocation>;
  LId: string;
  LItem: TRadIASemanticReferenceLocation;
  LItems: TArray<TRadIASemanticReferenceLocation>;
  LSeen: TDictionary<string, Boolean>;
  LKey: string;
begin
  LAll := TList<TRadIASemanticReferenceLocation>.Create;
  LSeen := TDictionary<string, Boolean>.Create;
  try
    for LId in ASymbolIds do
    begin
      if not FQueries.FindReferences(LId, False, 1000, LItems, AError) then
        Exit(False);
      for LItem in LItems do
      begin
        LKey := LowerCase(LItem.FileName) + '|' + LItem.StartOffset.ToString;
        if LSeen.ContainsKey(LKey) then
          Continue;
        LSeen.Add(LKey, True);
        LAll.Add(LItem);
      end;
    end;
    AReferences := LAll.ToArray;
    Result := True;
  finally
    LSeen.Free;
    LAll.Free;
  end;
end;

function TRadIAPrepareRenameSymbolTool.ResolveHierarchyReferences(
  const ARequest: TRadIAHierarchyRenameRequest;
  out AReferences: TArray<TRadIASemanticReferenceLocation>;
  out ASymbolCount: Integer;
  out AErrorCode: string;
  out AError: string
): Boolean;
var
  LIds: TArray<string>;
  LTypes: TArray<TRadIASemanticLocation>;
begin
  AErrorCode := 'hierarchy_query_failed';
  if not Assigned(FHierarchy) then
  begin
    AError := 'Hierarchy analysis is unavailable in the current runtime.';
    Exit(False);
  end;
  if ARequest.ContainerName.IsEmpty then
  begin
    AErrorCode := 'hierarchy_container_required';
    AError := 'A container is required for a hierarchy-aware rename.';
    Exit(False);
  end;
  if not FHierarchy.ListTypeSymbols(LTypes, AError) then
    Exit(False);
  if not CollectHierarchySymbolIds(
    ARequest.SymbolName,
    ARequest.ContainerName,
    ARequest.UnitName,
    ARequest.Signature,
    LTypes,
    LIds,
    AError
  ) then
  begin
    AErrorCode := 'hierarchy_precondition_failed';
    Exit(False);
  end;
  ASymbolCount := Length(LIds);
  Result := CollectReferencesForIds(LIds, AReferences, AError);
  if not Result then
    AErrorCode := 'reference_query_failed';
end;

function TRadIAPrepareRenameSymbolTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LHierarchyRequest: TRadIAHierarchyRenameRequest;
  LHierarchySymbolCount: Integer;
  LIncludeHierarchy: Boolean;
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
    LIncludeHierarchy := LArguments.GetValue<Boolean>(
      'includeHierarchy',
      False
    );
    LHierarchySymbolCount := 0;
    if not IsDelphiIdentifier(LSymbol) or
      not IsDelphiIdentifier(LNewName) or SameText(LSymbol, LNewName) then
      Exit(TRadIAToolResult.Failed(
        'invalid_identifier',
        'Both names must be distinct valid Delphi identifiers.'
      ));
    if LIncludeHierarchy then
    begin
      LHierarchyRequest.SymbolName := LSymbol;
      LHierarchyRequest.ContainerName := Trim(
        LArguments.GetValue<string>('container', '')
      );
      LHierarchyRequest.UnitName := LUnit;
      LHierarchyRequest.Signature := Trim(
        LArguments.GetValue<string>('signature', '')
      );
      if not ResolveHierarchyReferences(
        LHierarchyRequest,
        LReferences,
        LHierarchySymbolCount,
        LErrorCode,
        LError
      ) then
        Exit(TRadIAToolResult.Failed(LErrorCode, LError));
    end
    else
    begin
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
    end;
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
      LHierarchySymbolCount,
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
    '1.1.0',
    'Prepares an exact semantic Delphi symbol rename, optionally across a proven class hierarchy.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

procedure RegisterRadIASemanticRefactoringTools(
  const ARegistry: IRadIAToolRegistry;
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService;
  const AHierarchy: IRadIASemanticHierarchyService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareRenameSymbolTool.Create(
    AQueries,
    AMutation,
    APatches,
    AHierarchy
  ));
end;

end.
