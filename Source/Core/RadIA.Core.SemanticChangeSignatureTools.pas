unit RadIA.Core.SemanticChangeSignatureTools;

interface

uses
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Patches,
  RadIA.Core.SemanticQueries,
  RadIA.Core.Tools;

procedure RegisterRadIASemanticChangeSignatureTools(
  const ARegistry: IRadIAToolRegistry;
  const AQueries: IRadIASemanticQueryService;
  const ARoutines: IRadIASemanticRoutineService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.JSON,
  System.SysUtils,
  RadIA.Core.DelphiCallArguments,
  RadIA.Core.DelphiSignatures,
  RadIA.Core.Workspace;

type
  TRadIAChangeSignatureRequest = record
  private
    FBindings: TArray<TRadIADelphiArgumentBinding>;
    FContainerName: string;
    FMappings: TArray<TRadIADelphiParameterMapping>;
    FNewSignature: string;
    FOldSignature: string;
    FSymbolName: string;
    FUnitName: string;
  public
    constructor Create(
      const ASymbolName: string;
      const AUnitName: string;
      const AContainerName: string;
      const AOldSignature: string;
      const ANewSignature: string
    );
    function WithBindings(
      const ABindings: TArray<TRadIADelphiArgumentBinding>
    ): TRadIAChangeSignatureRequest;
    function WithMappings(
      const AMappings: TArray<TRadIADelphiParameterMapping>
    ): TRadIAChangeSignatureRequest;
    property Bindings: TArray<TRadIADelphiArgumentBinding> read FBindings;
    property ContainerName: string read FContainerName;
    property Mappings: TArray<TRadIADelphiParameterMapping> read FMappings;
    property NewSignature: string read FNewSignature;
    property OldSignature: string read FOldSignature;
    property SymbolName: string read FSymbolName;
    property UnitName: string read FUnitName;
  end;

  TRadIAChangeSignatureEdit = record
  private
    FLength: Integer;
    FReplacement: string;
    FStartOffset: Integer;
  public
    constructor Create(
      const AStartOffset: Integer;
      const ALength: Integer;
      const AReplacement: string
    );
    property Length: Integer read FLength;
    property Replacement: string read FReplacement;
    property StartOffset: Integer read FStartOffset;
  end;

  TRadIAChangeSignatureEditList = TList<TRadIAChangeSignatureEdit>;
  TRadIAChangeSignatureEditMap = TObjectDictionary<
    string,
    TRadIAChangeSignatureEditList
  >;

  TRadIAChangeSignatureCallContext = record
  private
    FDelta: TRadIADelphiSignatureDelta;
    FNewSignature: TRadIADelphiSignature;
    FOldSignature: TRadIADelphiSignature;
    FReferences: TArray<TRadIASemanticReferenceLocation>;
    FRequest: TRadIAChangeSignatureRequest;
    FRoutines: TArray<TRadIASemanticLocation>;
  public
    constructor Create(
      const ARequest: TRadIAChangeSignatureRequest;
      const AOldSignature: TRadIADelphiSignature;
      const ANewSignature: TRadIADelphiSignature;
      const ADelta: TRadIADelphiSignatureDelta;
      const ARoutines: TArray<TRadIASemanticLocation>;
      const AReferences: TArray<TRadIASemanticReferenceLocation>
    );
    property Delta: TRadIADelphiSignatureDelta read FDelta;
    property NewSignature: TRadIADelphiSignature read FNewSignature;
    property OldSignature: TRadIADelphiSignature read FOldSignature;
    property References: TArray<TRadIASemanticReferenceLocation>
      read FReferences;
    property Request: TRadIAChangeSignatureRequest read FRequest;
    property Routines: TArray<TRadIASemanticLocation> read FRoutines;
  end;

  TRadIAPrepareChangeSignatureTool = class(TInterfacedObject, IRadIATool)
  private
    FMutation: IRadIAEditorMutationFacade;
    FPatches: IRadIAMultiFilePatchService;
    FQueries: IRadIASemanticQueryService;
    FRoutines: IRadIASemanticRoutineService;
    procedure AddEdit(
      const AMap: TRadIAChangeSignatureEditMap;
      const AFileName: string;
      const AEdit: TRadIAChangeSignatureEdit
    );
    function AddCallEdits(
      const AContext: TRadIAChangeSignatureCallContext;
      const AMap: TRadIAChangeSignatureEditMap;
      out AError: string
    ): Boolean;
    function AddRoutineEdits(
      const ANewSignature: TRadIADelphiSignature;
      const ARoutines: TArray<TRadIASemanticLocation>;
      const AMap: TRadIAChangeSignatureEditMap;
      out AError: string
    ): Boolean;
    function BuildContent(
      const ASnapshot: TRadIAEditorContent;
      const AEdits: TRadIAChangeSignatureEditList;
      out AContent: string;
      out AError: string
    ): Boolean;
    function BuildResult(
      const ARequest: TRadIAChangeSignatureRequest;
      const APatchResult: TRadIAMultiFilePatchResult;
      const AEditCount: Integer
    ): TRadIAToolResult;
    function BuildSpecs(
      const AMap: TRadIAChangeSignatureEditMap;
      out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
      out AError: string
    ): Boolean;
    function LoadRequest(
      const AArgumentsJson: string;
      out ARequest: TRadIAChangeSignatureRequest;
      out AError: string
    ): Boolean;
    function ResolveRoutineFamily(
      const ARequest: TRadIAChangeSignatureRequest;
      out ARoutines: TArray<TRadIASemanticLocation>;
      out ASymbolId: string;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const AQueries: IRadIASemanticQueryService;
      const ARoutines: IRadIASemanticRoutineService;
      const AMutation: IRadIAEditorMutationFacade;
      const APatches: IRadIAMultiFilePatchService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["symbol","oldSignature",' +
    '"newSignature"],"properties":{"symbol":{"type":"string"},' +
    '"unit":{"type":"string"},"container":{"type":"string"},' +
    '"oldSignature":{"type":"string"},"newSignature":{"type":"string"},' +
    '"mappings":{"type":"array"},"bindings":{"type":"array"}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state","symbol",' +
    '"editCount","files"],"properties":{"previewId":{"type":"string"},' +
    '"state":{"type":"string"},"symbol":{"type":"string"},' +
    '"editCount":{"type":"integer"},"files":{"type":"array"}}}';
  CReferenceLimit = 1000;

constructor TRadIAChangeSignatureRequest.Create(
  const ASymbolName: string;
  const AUnitName: string;
  const AContainerName: string;
  const AOldSignature: string;
  const ANewSignature: string
);
begin
  FSymbolName := ASymbolName;
  FUnitName := AUnitName;
  FContainerName := AContainerName;
  FOldSignature := AOldSignature;
  FNewSignature := ANewSignature;
end;

function TRadIAChangeSignatureRequest.WithBindings(
  const ABindings: TArray<TRadIADelphiArgumentBinding>
): TRadIAChangeSignatureRequest;
begin
  Result := Self;
  Result.FBindings := Copy(ABindings);
end;

function TRadIAChangeSignatureRequest.WithMappings(
  const AMappings: TArray<TRadIADelphiParameterMapping>
): TRadIAChangeSignatureRequest;
begin
  Result := Self;
  Result.FMappings := Copy(AMappings);
end;

constructor TRadIAChangeSignatureEdit.Create(
  const AStartOffset: Integer;
  const ALength: Integer;
  const AReplacement: string
);
begin
  FStartOffset := AStartOffset;
  FLength := ALength;
  FReplacement := AReplacement;
end;

constructor TRadIAChangeSignatureCallContext.Create(
  const ARequest: TRadIAChangeSignatureRequest;
  const AOldSignature: TRadIADelphiSignature;
  const ANewSignature: TRadIADelphiSignature;
  const ADelta: TRadIADelphiSignatureDelta;
  const ARoutines: TArray<TRadIASemanticLocation>;
  const AReferences: TArray<TRadIASemanticReferenceLocation>
);
begin
  FRequest := ARequest;
  FOldSignature := AOldSignature;
  FNewSignature := ANewSignature;
  FDelta := ADelta;
  FRoutines := Copy(ARoutines);
  FReferences := Copy(AReferences);
end;

function CompareChangeEdits(
  const ALeft: TRadIAChangeSignatureEdit;
  const ARight: TRadIAChangeSignatureEdit
): Integer;
begin
  Result := ARight.StartOffset - ALeft.StartOffset;
end;

function IsInsideRoutine(
  const AReference: TRadIASemanticReferenceLocation;
  const ARoutines: TArray<TRadIASemanticLocation>
): Boolean;
var
  LRoutine: TRadIASemanticLocation;
begin
  for LRoutine in ARoutines do
    if SameText(LRoutine.FileName, AReference.FileName) and
      (AReference.StartOffset >= LRoutine.StartOffset) and
      (AReference.StartOffset <
        LRoutine.StartOffset + Length(LRoutine.Signature)) then
      Exit(True);
  Result := False;
end;

function ParseMappings(
  const AArray: TJSONArray;
  out AMappings: TArray<TRadIADelphiParameterMapping>;
  out AError: string
): Boolean;
var
  LIndex: Integer;
  LItem: TJSONObject;
begin
  Result := True;
  AMappings := nil;
  AError := '';
  if not Assigned(AArray) then
    Exit;
  SetLength(AMappings, AArray.Count);
  for LIndex := 0 to AArray.Count - 1 do
  begin
    LItem := AArray[LIndex] as TJSONObject;
    if not Assigned(LItem) then
    begin
      AError := 'Each parameter mapping must be an object.';
      Exit(False);
    end;
    AMappings[LIndex] := TRadIADelphiParameterMapping.Create(
      Trim(LItem.GetValue<string>('oldName', '')),
      Trim(LItem.GetValue<string>('newName', ''))
    );
  end;
end;

function ParseBindings(
  const AArray: TJSONArray;
  out ABindings: TArray<TRadIADelphiArgumentBinding>;
  out AError: string
): Boolean;
var
  LIndex: Integer;
  LItem: TJSONObject;
begin
  Result := True;
  ABindings := nil;
  AError := '';
  if not Assigned(AArray) then
    Exit;
  SetLength(ABindings, AArray.Count);
  for LIndex := 0 to AArray.Count - 1 do
  begin
    LItem := AArray[LIndex] as TJSONObject;
    if not Assigned(LItem) then
    begin
      AError := 'Each new parameter binding must be an object.';
      Exit(False);
    end;
    ABindings[LIndex] := TRadIADelphiArgumentBinding.Create(
      Trim(LItem.GetValue<string>('parameterName', '')),
      Trim(LItem.GetValue<string>('expression', ''))
    );
  end;
end;

constructor TRadIAPrepareChangeSignatureTool.Create(
  const AQueries: IRadIASemanticQueryService;
  const ARoutines: IRadIASemanticRoutineService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
begin
  inherited Create;
  if not Assigned(AQueries) then
    raise EArgumentNilException.Create('AQueries');
  if not Assigned(ARoutines) then
    raise EArgumentNilException.Create('ARoutines');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FQueries := AQueries;
  FRoutines := ARoutines;
  FMutation := AMutation;
  FPatches := APatches;
end;

procedure TRadIAPrepareChangeSignatureTool.AddEdit(
  const AMap: TRadIAChangeSignatureEditMap;
  const AFileName: string;
  const AEdit: TRadIAChangeSignatureEdit
);
begin
  if not AMap.ContainsKey(AFileName) then
    AMap.Add(AFileName, TRadIAChangeSignatureEditList.Create);
  AMap[AFileName].Add(AEdit);
end;

function TRadIAPrepareChangeSignatureTool.AddCallEdits(
  const AContext: TRadIAChangeSignatureCallContext;
  const AMap: TRadIAChangeSignatureEditMap;
  out AError: string
): Boolean;
var
  LCallRequest: TRadIADelphiCallRewriteRequest;
  LCallSite: TRadIADelphiCallSite;
  LReference: TRadIASemanticReferenceLocation;
  LRewrite: TRadIADelphiCallRewrite;
  LSnapshot: TRadIAEditorContent;
begin
  Result := False;
  AError := '';
  for LReference in AContext.References do
  begin
    if IsInsideRoutine(LReference, AContext.Routines) then
      Continue;
    if SameText(LReference.Kind, 'candidate') then
    begin
      AError := 'An overloaded or ambiguous call cannot be changed safely: ' +
        LReference.FileName;
      Exit;
    end;
    LSnapshot := FMutation.ReadContent(LReference.FileName, -1);
    if LSnapshot.FileName.IsEmpty or LSnapshot.Truncated then
    begin
      AError := 'A referenced call file is not fully readable: ' +
        LReference.FileName;
      Exit;
    end;
    if not TRadIADelphiCallSite.TryLocate(
      LSnapshot.Content,
      LReference.StartOffset,
      LReference.Length,
      LCallSite,
      AError
    ) then
      Exit;
    LCallRequest := TRadIADelphiCallRewriteRequest.Create(
      LCallSite.ArgumentText,
      AContext.OldSignature,
      AContext.NewSignature,
      AContext.Delta,
      AContext.Request.Bindings
    );
    if not TRadIADelphiCallRewrite.TryCreate(
      LCallRequest,
      LRewrite,
      AError
    ) then
      Exit;
    AddEdit(
      AMap,
      LReference.FileName,
      TRadIAChangeSignatureEdit.Create(
        LCallSite.ArgumentStart,
        LCallSite.ArgumentLength,
        LRewrite.ArgumentText
      )
    );
  end;
  Result := True;
end;

function TRadIAPrepareChangeSignatureTool.AddRoutineEdits(
  const ANewSignature: TRadIADelphiSignature;
  const ARoutines: TArray<TRadIASemanticLocation>;
  const AMap: TRadIAChangeSignatureEditMap;
  out AError: string
): Boolean;
var
  LQualifiedName: string;
  LRoutine: TRadIASemanticLocation;
  LSnapshot: TRadIAEditorContent;
begin
  Result := False;
  AError := '';
  for LRoutine in ARoutines do
  begin
    LSnapshot := FMutation.ReadContent(LRoutine.FileName, -1);
    if LSnapshot.FileName.IsEmpty or LSnapshot.Truncated then
    begin
      AError := 'A routine declaration file is not fully readable: ' +
        LRoutine.FileName;
      Exit;
    end;
    if Copy(
      LSnapshot.Content,
      LRoutine.StartOffset + 1,
      Length(LRoutine.Signature)
    ) <> LRoutine.Signature then
    begin
      AError := 'A routine declaration changed after semantic indexing.';
      Exit;
    end;
    LQualifiedName := ANewSignature.Name;
    if SameText(LRoutine.DeclarationSection, 'implementation') and
      not LRoutine.ContainerName.IsEmpty then
      LQualifiedName := LRoutine.ContainerName + '.' + LQualifiedName;
    AddEdit(
      AMap,
      LRoutine.FileName,
      TRadIAChangeSignatureEdit.Create(
        LRoutine.StartOffset,
        Length(LRoutine.Signature),
        ANewSignature.RenderCore(LQualifiedName)
      )
    );
  end;
  Result := Length(ARoutines) > 0;
  if not Result then
    AError := 'No matching routine declaration or implementation was found.';
end;

function TRadIAPrepareChangeSignatureTool.BuildContent(
  const ASnapshot: TRadIAEditorContent;
  const AEdits: TRadIAChangeSignatureEditList;
  out AContent: string;
  out AError: string
): Boolean;
var
  LEdit: TRadIAChangeSignatureEdit;
  LLastStart: Integer;
begin
  Result := False;
  AContent := ASnapshot.Content;
  AError := '';
  AEdits.Sort(TComparer<TRadIAChangeSignatureEdit>.Construct(
    CompareChangeEdits
  ));
  LLastStart := Length(AContent) + 1;
  for LEdit in AEdits do
  begin
    if (LEdit.StartOffset < 0) or
      (LEdit.StartOffset + LEdit.Length > Length(AContent)) or
      (LEdit.StartOffset + LEdit.Length > LLastStart) then
    begin
      AError := 'Change Signature produced overlapping or invalid edits.';
      Exit;
    end;
    Delete(AContent, LEdit.StartOffset + 1, LEdit.Length);
    Insert(LEdit.Replacement, AContent, LEdit.StartOffset + 1);
    LLastStart := LEdit.StartOffset;
  end;
  Result := True;
end;

function TRadIAPrepareChangeSignatureTool.BuildResult(
  const ARequest: TRadIAChangeSignatureRequest;
  const APatchResult: TRadIAMultiFilePatchResult;
  const AEditCount: Integer
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
    LRoot.AddPair('symbol', ARequest.SymbolName);
    LRoot.AddPair('editCount', TJSONNumber.Create(AEditCount));
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

function TRadIAPrepareChangeSignatureTool.BuildSpecs(
  const AMap: TRadIAChangeSignatureEditMap;
  out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
  out AError: string
): Boolean;
var
  LContent: string;
  LEntry: TPair<string, TRadIAChangeSignatureEditList>;
  LList: TList<TRadIAMultiFilePatchSpec>;
  LSnapshot: TRadIAEditorContent;
begin
  Result := False;
  ASpecs := nil;
  AError := '';
  LList := TList<TRadIAMultiFilePatchSpec>.Create;
  try
    for LEntry in AMap do
    begin
      LSnapshot := FMutation.ReadContent(LEntry.Key, -1);
      if LSnapshot.FileName.IsEmpty or LSnapshot.Truncated then
      begin
        AError := 'A Change Signature target is not fully readable: ' +
          LEntry.Key;
        Exit;
      end;
      if not BuildContent(LSnapshot, LEntry.Value, LContent, AError) then
        Exit;
      LList.Add(TRadIAMultiFilePatchSpec.Create(
        LSnapshot.FileName,
        LSnapshot.Revision,
        LContent
      ));
    end;
    ASpecs := LList.ToArray;
    Result := Length(ASpecs) > 0;
    if not Result then
      AError := 'Change Signature produced no file changes.';
  finally
    LList.Free;
  end;
end;

function TRadIAPrepareChangeSignatureTool.LoadRequest(
  const AArgumentsJson: string;
  out ARequest: TRadIAChangeSignatureRequest;
  out AError: string
): Boolean;
var
  LBindings: TArray<TRadIADelphiArgumentBinding>;
  LBindingsArray: TJSONArray;
  LDocument: TJSONObject;
  LMappingsArray: TJSONArray;
  LMappings: TArray<TRadIADelphiParameterMapping>;
begin
  Result := False;
  ARequest := Default(TRadIAChangeSignatureRequest);
  AError := '';
  LDocument := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LDocument) then
  begin
    AError := 'Change Signature arguments must be a JSON object.';
    Exit;
  end;
  try
    ARequest := TRadIAChangeSignatureRequest.Create(
      Trim(LDocument.GetValue<string>('symbol', '')),
      Trim(LDocument.GetValue<string>('unit', '')),
      Trim(LDocument.GetValue<string>('container', '')),
      Trim(LDocument.GetValue<string>('oldSignature', '')),
      Trim(LDocument.GetValue<string>('newSignature', ''))
    );
    if ARequest.SymbolName.IsEmpty or ARequest.OldSignature.IsEmpty or
      ARequest.NewSignature.IsEmpty then
    begin
      AError := 'Symbol, oldSignature, and newSignature are required.';
      Exit;
    end;
    LMappingsArray := LDocument.GetValue('mappings') as TJSONArray;
    LBindingsArray := LDocument.GetValue('bindings') as TJSONArray;
    if not ParseMappings(LMappingsArray, LMappings, AError) or
      not ParseBindings(LBindingsArray, LBindings, AError) then
      Exit;
    ARequest := ARequest.WithMappings(LMappings).WithBindings(LBindings);
    Result := True;
  finally
    LDocument.Free;
  end;
end;

function TRadIAPrepareChangeSignatureTool.ResolveRoutineFamily(
  const ARequest: TRadIAChangeSignatureRequest;
  out ARoutines: TArray<TRadIASemanticLocation>;
  out ASymbolId: string;
  out AError: string
): Boolean;
var
  LRoutine: TRadIASemanticLocation;
begin
  Result := FRoutines.FindRoutineSymbols(
    ARequest.SymbolName,
    ARequest.UnitName,
    ARequest.ContainerName,
    ARequest.OldSignature,
    ARoutines,
    AError
  );
  ASymbolId := '';
  if not Result then
    Exit;
  if Length(ARoutines) = 0 then
  begin
    AError := 'No routine family matched the requested old signature.';
    Exit(False);
  end;
  for LRoutine in ARoutines do
  begin
    if LRoutine.SymbolId.IsEmpty then
    begin
      AError := 'A routine declaration has no stable semantic identity.';
      Exit(False);
    end;
    if ASymbolId.IsEmpty then
      ASymbolId := LRoutine.SymbolId
    else if not SameText(ASymbolId, LRoutine.SymbolId) then
    begin
      AError := 'The routine query returned more than one semantic family.';
      Exit(False);
    end;
  end;
  Result := True;
end;

function TRadIAPrepareChangeSignatureTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCallContext: TRadIAChangeSignatureCallContext;
  LChangeRequest: TRadIAChangeSignatureRequest;
  LDelta: TRadIADelphiSignatureDelta;
  LEditCount: Integer;
  LEntry: TPair<string, TRadIAChangeSignatureEditList>;
  LError: string;
  LMap: TRadIAChangeSignatureEditMap;
  LNewSignature: TRadIADelphiSignature;
  LOldSignature: TRadIADelphiSignature;
  LPatchResult: TRadIAMultiFilePatchResult;
  LReferences: TArray<TRadIASemanticReferenceLocation>;
  LRoutines: TArray<TRadIASemanticLocation>;
  LSpecs: TArray<TRadIAMultiFilePatchSpec>;
  LSymbolId: string;
begin
  if not LoadRequest(ARequest.ArgumentsJson, LChangeRequest, LError) then
    Exit(TRadIAToolResult.Failed('invalid_request', LError));
  if not TRadIADelphiSignatureParser.TryParse(
    LChangeRequest.OldSignature,
    LOldSignature,
    LError
  ) or not TRadIADelphiSignatureParser.TryParse(
    LChangeRequest.NewSignature,
    LNewSignature,
    LError
  ) then
    Exit(TRadIAToolResult.Failed('invalid_signature', LError));
  if not SameText(LOldSignature.Name, LChangeRequest.SymbolName) or
    not SameText(LNewSignature.Name, LChangeRequest.SymbolName) then
    Exit(TRadIAToolResult.Failed(
      'invalid_signature',
      'Change Signature cannot rename the routine. Use Rename Symbol first.'
    ));
  if not TRadIADelphiSignatureDelta.TryBuild(
    LOldSignature,
    LNewSignature,
    LChangeRequest.Mappings,
    LDelta,
    LError
  ) then
    Exit(TRadIAToolResult.Failed('invalid_signature_delta', LError));
  if not ResolveRoutineFamily(
    LChangeRequest,
    LRoutines,
    LSymbolId,
    LError
  ) then
    Exit(TRadIAToolResult.Failed('routine_resolution_failed', LError));
  if not FQueries.FindReferences(
    LSymbolId,
    True,
    CReferenceLimit,
    LReferences,
    LError
  ) then
    Exit(TRadIAToolResult.Failed('reference_query_failed', LError));
  if Length(LReferences) >= CReferenceLimit then
    Exit(TRadIAToolResult.Failed(
      'reference_limit',
      'The semantic reference result reached its safety limit.'
    ));
  LMap := TRadIAChangeSignatureEditMap.Create([doOwnsValues]);
  try
    LCallContext := TRadIAChangeSignatureCallContext.Create(
      LChangeRequest,
      LOldSignature,
      LNewSignature,
      LDelta,
      LRoutines,
      LReferences
    );
    if not AddRoutineEdits(LNewSignature, LRoutines, LMap, LError) or
      not AddCallEdits(
        LCallContext,
        LMap,
        LError
      ) or not BuildSpecs(LMap, LSpecs, LError) then
      Exit(TRadIAToolResult.Failed('change_signature_precondition', LError));
    LEditCount := 0;
    for LEntry in LMap do
      Inc(LEditCount, LEntry.Value.Count);
    LPatchResult := FPatches.Prepare(LSpecs);
    Result := BuildResult(LChangeRequest, LPatchResult, LEditCount);
  finally
    LMap.Free;
  end;
end;

function TRadIAPrepareChangeSignatureTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareChangeSignature',
    '1.0.0',
    'Prepares a transactional Delphi routine signature change across declarations, implementations, and calls.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(20000, True);
end;

procedure RegisterRadIASemanticChangeSignatureTools(
  const ARegistry: IRadIAToolRegistry;
  const AQueries: IRadIASemanticQueryService;
  const ARoutines: IRadIASemanticRoutineService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareChangeSignatureTool.Create(
    AQueries,
    ARoutines,
    AMutation,
    APatches
  ));
end;

end.
