unit RadIA.Core.RuntimeVclInstrumentation;

interface

uses
  System.Generics.Collections,
  RadIA.Core.GeneratedArtifacts,
  RadIA.Core.IDENavigation,
  RadIA.Core.Patches,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIARuntimeVclTemplate = record
  private
    FContent: string;
    FFileName: string;
  public
    constructor Create(
      const AFileName: string;
      const AContent: string
    );
    property FileName: string read FFileName;
    property Content: string read FContent;
  end;

  IRadIARuntimeVclTemplateSource = interface
    ['{E597B447-8458-455C-AFCB-CFE43A25037F}']
    function LoadTemplates(
      out ATemplates: TArray<TRadIARuntimeVclTemplate>;
      out AErrorMessage: string
    ): Boolean;
  end;

  TRadIARuntimeVclFileTemplateSource = class(
    TInterfacedObject,
    IRadIARuntimeVclTemplateSource
  )
  private
    FRootPath: string;
    function ResolveRootPath: string;
  public
    constructor Create(const ARootPath: string = '');
    function LoadTemplates(
      out ATemplates: TArray<TRadIARuntimeVclTemplate>;
      out AErrorMessage: string
    ): Boolean;
  end;

  TRadIARuntimeVclInstrumentationResult = record
  private
    FContentJson: string;
    FErrorCode: string;
    FErrorMessage: string;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIARuntimeVclInstrumentationResult; static;
    class function Succeeded(
      const AContentJson: string
    ): TRadIARuntimeVclInstrumentationResult; static;
    property ContentJson: string read FContentJson;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Success: Boolean read FSuccess;
  end;

  IRadIARuntimeVclInstrumentationCoordinator = interface
    ['{744E23A2-504F-4881-A8A9-ED600BD65BC9}']
    function Prepare: TRadIARuntimeVclInstrumentationResult;
    function Apply(
      const APreviewId: string
    ): TRadIARuntimeVclInstrumentationResult;
    function Revert(
      const APreviewId: string
    ): TRadIARuntimeVclInstrumentationResult;
  end;

  TRadIARuntimeVclInstrumentationTransformer = class
  private
    class function DetectLineBreak(const AContent: string): string; static;
    class function FindLastMainBegin(const AContent: string): Integer; static;
    class function FindUsesInsertion(const AContent: string): Integer; static;
  public
    class function Instrument(
      const AContent: string;
      out AInstrumentedContent: string
    ): Boolean; static;
  end;

  TRadIARuntimeVclInstrumentationCoordinator = class(
    TInterfacedObject,
    IRadIARuntimeVclInstrumentationCoordinator
  )
  private type
    TRadIAPreviewEntry = class
    private
      FArtifactIds: TArray<string>;
      FPatchId: string;
      FProjectSource: string;
    public
      property ArtifactIds: TArray<string> read FArtifactIds write FArtifactIds;
      property PatchId: string read FPatchId write FPatchId;
      property ProjectSource: string read FProjectSource write FProjectSource;
    end;
  private
    FArtifacts: IRadIAGeneratedArtifactService;
    FEntries: TObjectDictionary<string, TRadIAPreviewEntry>;
    FMutation: IRadIAEditorMutationFacade;
    FNavigation: IRadIAIDENavigationFacade;
    FPatches: IRadIAPatchService;
    FTemplates: IRadIARuntimeVclTemplateSource;
    FWorkspace: IRadIAWorkspaceFacade;
    function ApplyArtifacts(
      const AEntry: TRadIAPreviewEntry;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    function BuildResultJson(
      const APreviewId: string;
      const AEntry: TRadIAPreviewEntry;
      const AState: string
    ): string;
    procedure RevertAppliedArtifacts(
      const AEntry: TRadIAPreviewEntry;
      const ALastIndex: Integer
    );
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AMutation: IRadIAEditorMutationFacade;
      const ANavigation: IRadIAIDENavigationFacade;
      const APatches: IRadIAPatchService;
      const AArtifacts: IRadIAGeneratedArtifactService;
      const ATemplates: IRadIARuntimeVclTemplateSource
    );
    destructor Destroy; override;
    function Prepare: TRadIARuntimeVclInstrumentationResult;
    function Apply(
      const APreviewId: string
    ): TRadIARuntimeVclInstrumentationResult;
    function Revert(
      const APreviewId: string
    ): TRadIARuntimeVclInstrumentationResult;
  end;

procedure RegisterRadIARuntimeVclInstrumentationTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeVclInstrumentationCoordinator
);

implementation

uses
  System.IOUtils,
  System.JSON,
  System.StrUtils,
  System.SysUtils;

const
  CTemplateCount = 4;
  CTemplateFileNames: array[0..CTemplateCount - 1] of string = (
    'RadIA.Core.RuntimeAutomation.pas',
    'RadIA.Core.RuntimeVclAdapter.pas',
    'RadIA.Runtime.VclAdapter.pas',
    'RadIA.Runtime.VclServer.pas'
  );
  CRelativeRuntimePath = '.radia\runtime';
  CPreviewIdSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string","minLength":1}},' +
    '"additionalProperties":false}';
  CPrepareSchema = '{"type":"object","additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state",' +
    '"projectSource","generatedUnitCount","reversible"],"properties":{' +
    '"previewId":{"type":"string"},"state":{"type":"string"},' +
    '"projectSource":{"type":"string"},"generatedUnitCount":{' +
    '"type":"integer"},"scope":{"type":"string"},"reversible":{' +
    '"type":"boolean"}}}';

type
  TRadIARuntimeVclInstrumentationToolKind = (
    rvitPrepare,
    rvitApply,
    rvitRevert
  );

  TRadIARuntimeVclInstrumentationTool = class(TInterfacedObject, IRadIATool)
  private
    FCoordinator: IRadIARuntimeVclInstrumentationCoordinator;
    FKind: TRadIARuntimeVclInstrumentationToolKind;
    function ParsePreviewId(const AArgumentsJson: string): string;
    function ToToolResult(
      const AResult: TRadIARuntimeVclInstrumentationResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIARuntimeVclInstrumentationToolKind;
      const ACoordinator: IRadIARuntimeVclInstrumentationCoordinator
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIARuntimeVclTemplate.Create(
  const AFileName: string;
  const AContent: string
);
begin
  FFileName := AFileName;
  FContent := AContent;
end;

constructor TRadIARuntimeVclFileTemplateSource.Create(
  const ARootPath: string
);
begin
  inherited Create;
  FRootPath := Trim(ARootPath);
end;

function TRadIARuntimeVclFileTemplateSource.ResolveRootPath: string;
var
  LCandidate: string;
begin
  if FRootPath <> '' then
    Exit(TPath.GetFullPath(FRootPath));
  LCandidate := TPath.Combine(
    ExtractFilePath(GetModuleName(HInstance)),
    'RuntimeAdapter'
  );
  if TDirectory.Exists(LCandidate) then
    Exit(LCandidate);
  LCandidate := TPath.Combine(TDirectory.GetCurrentDirectory, 'RuntimeAdapter');
  if TDirectory.Exists(LCandidate) then
    Exit(LCandidate);
  Result := TPath.Combine(TDirectory.GetCurrentDirectory, 'Source');
end;

function TRadIARuntimeVclFileTemplateSource.LoadTemplates(
  out ATemplates: TArray<TRadIARuntimeVclTemplate>;
  out AErrorMessage: string
): Boolean;
var
  LFileName: string;
  LIndex: Integer;
  LRootPath: string;
begin
  SetLength(ATemplates, 0);
  AErrorMessage := '';
  LRootPath := ResolveRootPath;
  SetLength(ATemplates, CTemplateCount);
  for LIndex := Low(CTemplateFileNames) to High(CTemplateFileNames) do
  begin
    LFileName := TPath.Combine(LRootPath, CTemplateFileNames[LIndex]);
    if not TFile.Exists(LFileName) then
    begin
      AErrorMessage := 'Runtime VCL template is missing: ' + LFileName;
      SetLength(ATemplates, 0);
      Exit(False);
    end;
    ATemplates[LIndex] := TRadIARuntimeVclTemplate.Create(
      CTemplateFileNames[LIndex],
      TFile.ReadAllText(LFileName, TEncoding.UTF8)
    );
  end;
  Result := True;
end;

class function TRadIARuntimeVclInstrumentationResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIARuntimeVclInstrumentationResult;
begin
  Result := Default(TRadIARuntimeVclInstrumentationResult);
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIARuntimeVclInstrumentationResult.Succeeded(
  const AContentJson: string
): TRadIARuntimeVclInstrumentationResult;
begin
  Result := Default(TRadIARuntimeVclInstrumentationResult);
  Result.FContentJson := AContentJson;
  Result.FSuccess := True;
end;

class function TRadIARuntimeVclInstrumentationTransformer.DetectLineBreak(
  const AContent: string
): string;
begin
  if Pos(#13#10, AContent) > 0 then
    Exit(#13#10);
  if Pos(#10, AContent) > 0 then
    Exit(#10);
  Result := sLineBreak;
end;

class function TRadIARuntimeVclInstrumentationTransformer.FindLastMainBegin(
  const AContent: string
): Integer;
var
  LLower: string;
  LPosition: Integer;
begin
  Result := 0;
  LLower := LowerCase(AContent);
  LPosition := Pos('begin', LLower);
  while LPosition > 0 do
  begin
    if ((LPosition = 1) or not CharInSet(
      LLower[LPosition - 1], ['a'..'z', '0'..'9', '_']
    )) and ((LPosition + 5 > Length(LLower)) or not CharInSet(
      LLower[LPosition + 5], ['a'..'z', '0'..'9', '_']
    )) then
      Result := LPosition;
    LPosition := PosEx('begin', LLower, LPosition + 5);
  end;
end;

class function TRadIARuntimeVclInstrumentationTransformer.FindUsesInsertion(
  const AContent: string
): Integer;
var
  LLower: string;
  LPosition: Integer;
begin
  Result := 0;
  LLower := LowerCase(AContent);
  LPosition := Pos('uses', LLower);
  while LPosition > 0 do
  begin
    if ((LPosition = 1) or not CharInSet(
      LLower[LPosition - 1], ['a'..'z', '0'..'9', '_']
    )) and ((LPosition + 4 > Length(LLower)) or not CharInSet(
      LLower[LPosition + 4], ['a'..'z', '0'..'9', '_']
    )) then
      Exit(LPosition + 4);
    LPosition := PosEx('uses', LLower, LPosition + 4);
  end;
end;

class function TRadIARuntimeVclInstrumentationTransformer.Instrument(
  const AContent: string;
  out AInstrumentedContent: string
): Boolean;
var
  LBegin: Integer;
  LEnd: Integer;
  LLineBreak: string;
  LPrefix: string;
  LUses: Integer;
begin
  Result := False;
  AInstrumentedContent := '';
  if (Trim(AContent) = '') or ContainsText(
    AContent,
    'RadIA.Runtime.VclServer in'
  ) then
    Exit;
  LUses := FindUsesInsertion(AContent);
  LBegin := FindLastMainBegin(AContent);
  LEnd := LastDelimiter('.', AContent);
  if (LUses = 0) or (LBegin = 0) or
    (LEnd < LBegin) or not SameText(
      Trim(Copy(AContent, LEnd - 3, 4)),
      'end.'
    ) then
    Exit;
  LLineBreak := DetectLineBreak(AContent);
  AInstrumentedContent := AContent;
  LPrefix :=
    LLineBreak +
    '  RadIA.Core.RuntimeAutomation in ''.radia\runtime\' +
    'RadIA.Core.RuntimeAutomation.pas'',' + LLineBreak +
    '  RadIA.Core.RuntimeVclAdapter in ''.radia\runtime\' +
    'RadIA.Core.RuntimeVclAdapter.pas'',' + LLineBreak +
    '  RadIA.Runtime.VclAdapter in ''.radia\runtime\' +
    'RadIA.Runtime.VclAdapter.pas'',' + LLineBreak +
    '  RadIA.Runtime.VclServer in ''.radia\runtime\' +
    'RadIA.Runtime.VclServer.pas'',';
  Insert(LPrefix, AInstrumentedContent, LUses);
  LBegin := FindLastMainBegin(AInstrumentedContent);
  Insert(
    'var' + LLineBreak +
    '  RadIARuntimeVclServer: TRadIARuntimeVclServer;' + LLineBreak,
    AInstrumentedContent,
    LBegin
  );
  LBegin := FindLastMainBegin(AInstrumentedContent) + Length('begin');
  Insert(
    LLineBreak +
    '  RadIARuntimeVclServer := TRadIARuntimeVclServer.Create;' + LLineBreak +
    '  try' + LLineBreak +
    '    RadIARuntimeVclServer.Start;',
    AInstrumentedContent,
    LBegin
  );
  LEnd := LastDelimiter('.', AInstrumentedContent);
  Insert(
    '  finally' + LLineBreak +
    '    RadIARuntimeVclServer.Free;' + LLineBreak +
    '  end;' + LLineBreak,
    AInstrumentedContent,
    LEnd - 3
  );
  Result := True;
end;

constructor TRadIARuntimeVclInstrumentationCoordinator.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const ANavigation: IRadIAIDENavigationFacade;
  const APatches: IRadIAPatchService;
  const AArtifacts: IRadIAGeneratedArtifactService;
  const ATemplates: IRadIARuntimeVclTemplateSource
);
begin
  inherited Create;
  if not Assigned(AWorkspace) or not Assigned(AMutation) or
    not Assigned(ANavigation) or not Assigned(APatches) or
    not Assigned(AArtifacts) or not Assigned(ATemplates) then
    raise EArgumentNilException.Create('Runtime VCL instrumentation dependency');
  FWorkspace := AWorkspace;
  FMutation := AMutation;
  FNavigation := ANavigation;
  FPatches := APatches;
  FArtifacts := AArtifacts;
  FTemplates := ATemplates;
  FEntries := TObjectDictionary<string, TRadIAPreviewEntry>.Create([doOwnsValues]);
end;

destructor TRadIARuntimeVclInstrumentationCoordinator.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

function TRadIARuntimeVclInstrumentationCoordinator.ApplyArtifacts(
  const AEntry: TRadIAPreviewEntry;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
var
  LIndex: Integer;
  LResult: TRadIAGeneratedArtifactResult;
begin
  for LIndex := Low(AEntry.ArtifactIds) to High(AEntry.ArtifactIds) do
  begin
    LResult := FArtifacts.Apply(AEntry.ArtifactIds[LIndex]);
    if not LResult.Success then
    begin
      AErrorCode := LResult.ErrorCode;
      AErrorMessage := LResult.ErrorMessage;
      RevertAppliedArtifacts(AEntry, LIndex - 1);
      Exit(False);
    end;
  end;
  Result := True;
end;

function TRadIARuntimeVclInstrumentationCoordinator.BuildResultJson(
  const APreviewId: string;
  const AEntry: TRadIAPreviewEntry;
  const AState: string
): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('previewId', APreviewId);
    LRoot.AddPair('state', AState);
    LRoot.AddPair('projectSource', AEntry.ProjectSource);
    LRoot.AddPair('generatedUnitCount', TJSONNumber.Create(Length(AEntry.ArtifactIds)));
    LRoot.AddPair('scope', 'debug-runtime-only');
    LRoot.AddPair('reversible', TJSONBool.Create(True));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIARuntimeVclInstrumentationCoordinator.RevertAppliedArtifacts(
  const AEntry: TRadIAPreviewEntry;
  const ALastIndex: Integer
);
var
  LIndex: Integer;
begin
  for LIndex := ALastIndex downto Low(AEntry.ArtifactIds) do
    FArtifacts.Revert(AEntry.ArtifactIds[LIndex]);
end;

function TRadIARuntimeVclInstrumentationCoordinator.Prepare:
  TRadIARuntimeVclInstrumentationResult;
var
  LArtifact: TRadIAGeneratedArtifactResult;
  LArtifactIds: TArray<string>;
  LEntry: TRadIAPreviewEntry;
  LErrorMessage: string;
  LIndex: Integer;
  LInstrumented: string;
  LNavigation: TRadIANavigationResult;
  LPatch: TRadIAPatchResult;
  LProject: TRadIAProjectSnapshot;
  LSnapshot: TRadIAEditorContent;
  LTemplates: TArray<TRadIARuntimeVclTemplate>;
begin
  LProject := FWorkspace.GetActiveProject;
  if (LProject.FileName = '') or not SameText(LProject.Configuration, 'Debug') then
    Exit(TRadIARuntimeVclInstrumentationResult.Failed(
      'debug_project_required',
      'An active Delphi project using the Debug configuration is required.'
    ));
  if not FTemplates.LoadTemplates(LTemplates, LErrorMessage) then
    Exit(TRadIARuntimeVclInstrumentationResult.Failed(
      'runtime_templates_unavailable',
      LErrorMessage
    ));
  LEntry := TRadIAPreviewEntry.Create;
  try
    LEntry.ProjectSource := ChangeFileExt(LProject.FileName, '.dpr');
    LNavigation := FNavigation.NavigateToFile(LEntry.ProjectSource, 1, 1);
    if not LNavigation.Success then
      Exit(TRadIARuntimeVclInstrumentationResult.Failed(
        'project_source_unavailable', LNavigation.Message
      ));
    LSnapshot := FMutation.ReadContent(LEntry.ProjectSource, 2 * 1024 * 1024);
    if LSnapshot.Truncated or (LSnapshot.Content = '') or
      not TRadIARuntimeVclInstrumentationTransformer.Instrument(
        LSnapshot.Content, LInstrumented
      ) then
      Exit(TRadIARuntimeVclInstrumentationResult.Failed(
        'instrumentation_not_applicable',
        'The project source is already instrumented or has an unsupported structure.'
      ));
    SetLength(LArtifactIds, Length(LTemplates));
    for LIndex := Low(LTemplates) to High(LTemplates) do
    begin
      LArtifact := FArtifacts.Prepare(
        TPath.Combine(CRelativeRuntimePath, LTemplates[LIndex].FileName),
        LTemplates[LIndex].Content,
        False
      );
      if not LArtifact.Success then
        Exit(TRadIARuntimeVclInstrumentationResult.Failed(
          LArtifact.ErrorCode, LArtifact.ErrorMessage
        ));
      LArtifactIds[LIndex] := LArtifact.Preview.Id;
    end;
    LEntry.ArtifactIds := LArtifactIds;
    LPatch := FPatches.Prepare(TRadIAPatchSpec.Create(
      LEntry.ProjectSource,
      LSnapshot.Revision,
      LSnapshot.Content,
      LInstrumented
    ));
    if not LPatch.Success then
      Exit(TRadIARuntimeVclInstrumentationResult.Failed(
        LPatch.ErrorCode, LPatch.ErrorMessage
      ));
    LEntry.PatchId := LPatch.Preview.Id;
    FEntries.Add(LPatch.Preview.Id, LEntry);
    Result := TRadIARuntimeVclInstrumentationResult.Succeeded(
      BuildResultJson(LPatch.Preview.Id, LEntry, 'prepared')
    );
    LEntry := nil;
  finally
    LEntry.Free;
  end;
end;

function TRadIARuntimeVclInstrumentationCoordinator.Apply(
  const APreviewId: string
): TRadIARuntimeVclInstrumentationResult;
var
  LEntry: TRadIAPreviewEntry;
  LErrorCode: string;
  LErrorMessage: string;
  LPatch: TRadIAPatchResult;
begin
  if not FEntries.TryGetValue(APreviewId, LEntry) then
    Exit(TRadIARuntimeVclInstrumentationResult.Failed(
      'preview_not_found', 'Runtime VCL instrumentation preview was not found.'
    ));
  if not ApplyArtifacts(LEntry, LErrorCode, LErrorMessage) then
    Exit(TRadIARuntimeVclInstrumentationResult.Failed(LErrorCode, LErrorMessage));
  LPatch := FPatches.Apply(LEntry.PatchId);
  if not LPatch.Success then
  begin
    RevertAppliedArtifacts(LEntry, High(LEntry.ArtifactIds));
    Exit(TRadIARuntimeVclInstrumentationResult.Failed(
      LPatch.ErrorCode, LPatch.ErrorMessage
    ));
  end;
  Result := TRadIARuntimeVclInstrumentationResult.Succeeded(
    BuildResultJson(APreviewId, LEntry, 'applied')
  );
end;

function TRadIARuntimeVclInstrumentationCoordinator.Revert(
  const APreviewId: string
): TRadIARuntimeVclInstrumentationResult;
var
  LEntry: TRadIAPreviewEntry;
  LIndex: Integer;
  LPatch: TRadIAPatchResult;
  LResult: TRadIAGeneratedArtifactResult;
begin
  if not FEntries.TryGetValue(APreviewId, LEntry) then
    Exit(TRadIARuntimeVclInstrumentationResult.Failed(
      'preview_not_found', 'Runtime VCL instrumentation preview was not found.'
    ));
  LPatch := FPatches.Revert(LEntry.PatchId);
  if not LPatch.Success then
    Exit(TRadIARuntimeVclInstrumentationResult.Failed(
      LPatch.ErrorCode, LPatch.ErrorMessage
    ));
  for LIndex := High(LEntry.ArtifactIds) downto Low(LEntry.ArtifactIds) do
  begin
    LResult := FArtifacts.Revert(LEntry.ArtifactIds[LIndex]);
    if not LResult.Success then
      Exit(TRadIARuntimeVclInstrumentationResult.Failed(
        LResult.ErrorCode, LResult.ErrorMessage
      ));
  end;
  Result := TRadIARuntimeVclInstrumentationResult.Succeeded(
    BuildResultJson(APreviewId, LEntry, 'reverted')
  );
  FEntries.Remove(APreviewId);
end;

constructor TRadIARuntimeVclInstrumentationTool.Create(
  const AKind: TRadIARuntimeVclInstrumentationToolKind;
  const ACoordinator: IRadIARuntimeVclInstrumentationCoordinator
);
begin
  inherited Create;
  if not Assigned(ACoordinator) then
    raise EArgumentNilException.Create('ACoordinator');
  FKind := AKind;
  FCoordinator := ACoordinator;
end;

function TRadIARuntimeVclInstrumentationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LPreviewId: string;
begin
  if FKind = rvitPrepare then
    Exit(ToToolResult(FCoordinator.Prepare));
  LPreviewId := ParsePreviewId(ARequest.ArgumentsJson);
  if LPreviewId = '' then
    Exit(TRadIAToolResult.Failed(
      'missing_preview_id', 'previewId is required.'
    ));
  if FKind = rvitApply then
    Result := ToToolResult(FCoordinator.Apply(LPreviewId))
  else
    Result := ToToolResult(FCoordinator.Revert(LPreviewId));
end;

function TRadIARuntimeVclInstrumentationTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    rvitPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareRuntimeVclInstrumentation',
        '1.0.0',
        'Previews reversible VCL runtime instrumentation for the active Debug project.',
        CPrepareSchema,
        COutputSchema,
        trReadOnly
      );
    rvitApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyRuntimeVclInstrumentation',
        '1.0.0',
        'Adds the reviewed runtime adapter units and starts them only in the instrumented application.',
        CPreviewIdSchema,
        COutputSchema,
        trStructuralWrite
      );
  else
    Result := TRadIAToolDescriptor.Create(
      'RevertRuntimeVclInstrumentation',
      '1.0.0',
      'Removes unchanged runtime adapter units and restores the reviewed project source.',
      CPreviewIdSchema,
      COutputSchema,
      trReversibleWrite
    );
  end;
end;

function TRadIARuntimeVclInstrumentationTool.ParsePreviewId(
  const AArgumentsJson: string
): string;
var
  LRoot: TJSONObject;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    Result := Trim(LRoot.GetValue<string>('previewId', ''));
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimeVclInstrumentationTool.ToToolResult(
  const AResult: TRadIARuntimeVclInstrumentationResult
): TRadIAToolResult;
begin
  if AResult.Success then
    Result := TRadIAToolResult.Succeeded(AResult.ContentJson)
  else
    Result := TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    );
end;

procedure RegisterRadIARuntimeVclInstrumentationTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeVclInstrumentationCoordinator
);
var
  LKind: TRadIARuntimeVclInstrumentationToolKind;
begin
  if not Assigned(ARegistry) or not Assigned(ACoordinator) then
    Exit;
  for LKind := Low(TRadIARuntimeVclInstrumentationToolKind) to
    High(TRadIARuntimeVclInstrumentationToolKind) do
    ARegistry.RegisterTool(
      TRadIARuntimeVclInstrumentationTool.Create(LKind, ACoordinator)
    );
end;

end.
