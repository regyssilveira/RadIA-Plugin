unit RadIA.Core.MemoryInstrumentation;

interface

uses
  RadIA.Core.IDENavigation,
  RadIA.Core.Patches,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIAMemoryInstrumentationMode = (
    mimSession,
    mimPersistentDebug
  );

  TRadIAMemoryInstrumentationResult = record
  private
    FContentJson: string;
    FErrorCode: string;
    FErrorMessage: string;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAMemoryInstrumentationResult; static;
    class function Succeeded(
      const AContentJson: string
    ): TRadIAMemoryInstrumentationResult; static;
    property ContentJson: string read FContentJson;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Success: Boolean read FSuccess;
  end;

  IRadIAMemoryInstrumentationCoordinator = interface
    ['{8AF6AC89-D02A-460B-BB03-7829968D15BC}']
    function Prepare(
      const AMode: TRadIAMemoryInstrumentationMode
    ): TRadIAMemoryInstrumentationResult;
    function Apply(
      const APreviewId: string
    ): TRadIAMemoryInstrumentationResult;
    function Revert(
      const APreviewId: string
    ): TRadIAMemoryInstrumentationResult;
  end;

  TRadIAMemoryInstrumentationTransformer = class
  private
    class function DetectLineBreak(
      const AContent: string
    ): string; static;
    class function FindUsesInsertion(
      const AContent: string
    ): Integer; static;
  public
    class function Instrument(
      const AContent: string;
      const AFastMMUnitPath: string;
      out AInstrumentedContent: string
    ): Boolean; static;
  end;

  TRadIAMemoryInstrumentationCoordinator = class(
    TInterfacedObject,
    IRadIAMemoryInstrumentationCoordinator
  )
  private
    FEntries: TObject;
    FMutation: IRadIAEditorMutationFacade;
    FNavigation: IRadIAIDENavigationFacade;
    FPatches: IRadIAPatchService;
    FWorkspace: IRadIAWorkspaceFacade;
    function BuildResultJson(
      const APreview: TRadIAPatchPreview;
      const AMode: TRadIAMemoryInstrumentationMode;
      const AState: string
    ): string;
    function ParseModeName(
      const AMode: TRadIAMemoryInstrumentationMode
    ): string;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AMutation: IRadIAEditorMutationFacade;
      const ANavigation: IRadIAIDENavigationFacade;
      const APatches: IRadIAPatchService
    );
    destructor Destroy; override;
    function Prepare(
      const AMode: TRadIAMemoryInstrumentationMode
    ): TRadIAMemoryInstrumentationResult;
    function Apply(
      const APreviewId: string
    ): TRadIAMemoryInstrumentationResult;
    function Revert(
      const APreviewId: string
    ): TRadIAMemoryInstrumentationResult;
  end;

procedure RegisterRadIAMemoryInstrumentationTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIAMemoryInstrumentationCoordinator
);

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.FastMM5,
  RadIA.Core.MemoryDiagnostics;

type
  TRadIAMemoryInstrumentationEntry = record
    Mode: TRadIAMemoryInstrumentationMode;
    Preview: TRadIAPatchPreview;
  end;

  TRadIAMemoryInstrumentationToolKind = (
    mitPrepare,
    mitApply,
    mitRevert
  );

  TRadIAMemoryInstrumentationTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FCoordinator: IRadIAMemoryInstrumentationCoordinator;
    FKind: TRadIAMemoryInstrumentationToolKind;
    function ParsePreviewId(const AArgumentsJson: string): string;
    function ToToolResult(
      const AResult: TRadIAMemoryInstrumentationResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const ACoordinator: IRadIAMemoryInstrumentationCoordinator;
      const AKind: TRadIAMemoryInstrumentationToolKind
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CPreviewInputSchema =
    '{"type":"object","properties":{"mode":{"type":"string",' +
    '"enum":["session","persistentDebug"]}},"additionalProperties":false}';
  CPreviewIdInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string","minLength":1}},"additionalProperties":false}';
  CInstrumentationOutputSchema =
    '{"type":"object","required":["previewId","state","mode","fileName",' +
    '"fingerprint"],"properties":{"previewId":{"type":"string"},' +
    '"state":{"type":"string"},"mode":{"type":"string"},' +
    '"fileName":{"type":"string"},"fingerprint":{"type":"string"}}}';

class function TRadIAMemoryInstrumentationResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAMemoryInstrumentationResult;
begin
  Result := Default(TRadIAMemoryInstrumentationResult);
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIAMemoryInstrumentationResult.Succeeded(
  const AContentJson: string
): TRadIAMemoryInstrumentationResult;
begin
  Result := Default(TRadIAMemoryInstrumentationResult);
  Result.FSuccess := True;
  Result.FContentJson := AContentJson;
end;

class function TRadIAMemoryInstrumentationTransformer.DetectLineBreak(
  const AContent: string
): string;
begin
  if Pos(#13#10, AContent) > 0 then
    Exit(#13#10);
  if Pos(#10, AContent) > 0 then
    Exit(#10);
  Result := sLineBreak;
end;

class function TRadIAMemoryInstrumentationTransformer.FindUsesInsertion(
  const AContent: string
): Integer;
var
  LLowerContent: string;
  LSearchIndex: Integer;
begin
  Result := 0;
  LLowerContent := LowerCase(AContent);
  LSearchIndex := Pos('uses', LLowerContent);
  while LSearchIndex > 0 do
  begin
    if ((LSearchIndex = 1) or
      not CharInSet(LLowerContent[LSearchIndex - 1], ['a'..'z', '0'..'9', '_'])) and
      ((LSearchIndex + 4 > Length(LLowerContent)) or
      not CharInSet(LLowerContent[LSearchIndex + 4], ['a'..'z', '0'..'9', '_'])) then
      Exit(LSearchIndex + 4);
    LSearchIndex := PosEx('uses', LLowerContent, LSearchIndex + 4);
  end;
end;

class function TRadIAMemoryInstrumentationTransformer.Instrument(
  const AContent: string;
  const AFastMMUnitPath: string;
  out AInstrumentedContent: string
): Boolean;
var
  LDefines: string;
  LHeaderEnd: Integer;
  LLineBreak: string;
  LUnitEntry: string;
  LUsesInsertion: Integer;
begin
  Result := False;
  AInstrumentedContent := '';
  if AContent.IsEmpty or AFastMMUnitPath.IsEmpty then
    Exit;
  if ContainsText(AContent, 'FastMM5 in') or
    ContainsText(AContent, '{$DEFINE FastMM_FullDebugModeWhenDLLAvailable}') then
    Exit;
  LHeaderEnd := Pos(';', AContent);
  if LHeaderEnd = 0 then
    Exit;
  LUsesInsertion := FindUsesInsertion(AContent);
  if LUsesInsertion = 0 then
    Exit;
  LLineBreak := DetectLineBreak(AContent);
  LDefines :=
    LLineBreak +
    '{$DEFINE FastMM_FullDebugModeWhenDLLAvailable}' + LLineBreak +
    '{$DEFINE FastMM_EnableMemoryLeakReporting}' + LLineBreak;
  AInstrumentedContent :=
    Copy(AContent, 1, LHeaderEnd) +
    LDefines +
    Copy(AContent, LHeaderEnd + 1, MaxInt);
  LUsesInsertion := FindUsesInsertion(AInstrumentedContent);
  LUnitEntry :=
    LLineBreak +
    '  FastMM5 in ''' +
    StringReplace(AFastMMUnitPath, '''', '''''', [rfReplaceAll]) +
    ''',';
  Insert(LUnitEntry, AInstrumentedContent, LUsesInsertion);
  Result := True;
end;

constructor TRadIAMemoryInstrumentationCoordinator.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const ANavigation: IRadIAIDENavigationFacade;
  const APatches: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(ANavigation) then
    raise EArgumentNilException.Create('ANavigation');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FWorkspace := AWorkspace;
  FMutation := AMutation;
  FNavigation := ANavigation;
  FPatches := APatches;
  FEntries :=
    TDictionary<string, TRadIAMemoryInstrumentationEntry>.Create;
end;

destructor TRadIAMemoryInstrumentationCoordinator.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

function TRadIAMemoryInstrumentationCoordinator.ParseModeName(
  const AMode: TRadIAMemoryInstrumentationMode
): string;
begin
  if AMode = mimPersistentDebug then
    Result := 'persistentDebug'
  else
    Result := 'session';
end;

function TRadIAMemoryInstrumentationCoordinator.BuildResultJson(
  const APreview: TRadIAPatchPreview;
  const AMode: TRadIAMemoryInstrumentationMode;
  const AState: string
): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('previewId', APreview.Id);
    LRoot.AddPair('state', AState);
    LRoot.AddPair('mode', ParseModeName(AMode));
    LRoot.AddPair('fileName', APreview.Spec.TargetFile);
    LRoot.AddPair(
      'fingerprint',
      THashSHA2.GetHashString(APreview.OriginalContent)
    );
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAMemoryInstrumentationCoordinator.Prepare(
  const AMode: TRadIAMemoryInstrumentationMode
): TRadIAMemoryInstrumentationResult;
var
  LEntry: TRadIAMemoryInstrumentationEntry;
  LFastMMDetector: TRadIAFastMM5Detector;
  LFastMMSettings: TRadIAFastMM5Settings;
  LFastMMStatus: TRadIAMemoryBackendStatus;
  LFastMMStore: TRadIAFastMM5SettingsStore;
  LInstrumentedContent: string;
  LNavigationResult: TRadIANavigationResult;
  LPatchResult: TRadIAPatchResult;
  LProject: TRadIAProjectSnapshot;
  LProjectSource: string;
  LSnapshot: TRadIAEditorContent;
  LSpec: TRadIAPatchSpec;
begin
  LProject := FWorkspace.GetActiveProject;
  if LProject.FileName.IsEmpty then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'project_unavailable',
        'No active Delphi project is available.'
      )
    );
  if not SameText(LProject.Configuration, 'Debug') then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'debug_configuration_required',
        'Memory instrumentation is restricted to the Debug configuration.'
      )
    );
  if not SameText(LProject.Platform, 'Win32') and
    not SameText(LProject.Platform, 'Win64') then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'unsupported_platform',
        'Memory instrumentation supports only Win32 and Win64.'
      )
    );
  LFastMMStore := TRadIAFastMM5SettingsStore.Create;
  try
    LFastMMSettings := LFastMMStore.Load;
  finally
    LFastMMStore.Free;
  end;
  LFastMMDetector := TRadIAFastMM5Detector.Create;
  try
    LFastMMStatus := LFastMMDetector.Detect(
      LFastMMSettings,
      LProject.Platform
    );
  finally
    LFastMMDetector.Free;
  end;
  if not LFastMMStatus.IsReady then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'fastmm5_not_ready',
        LFastMMStatus.Message
      )
    );
  LProjectSource := ChangeFileExt(LProject.FileName, '.dpr');
  LNavigationResult := FNavigation.NavigateToFile(LProjectSource, 1, 1);
  if not LNavigationResult.Success then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'project_source_unavailable',
        LNavigationResult.Message
      )
    );
  LSnapshot := FMutation.ReadContent(LProjectSource, 2 * 1024 * 1024);
  if LSnapshot.Truncated or LSnapshot.Content.IsEmpty then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'project_source_unavailable',
        'The project source could not be read safely from the IDE buffer.'
      )
    );
  if not TRadIAMemoryInstrumentationTransformer.Instrument(
    LSnapshot.Content,
    TPath.Combine(LFastMMSettings.RootPath, 'FastMM5.pas'),
    LInstrumentedContent
  ) then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'instrumentation_not_applicable',
        'The project source is already instrumented or has an unsupported structure.'
      )
    );
  LSpec := TRadIAPatchSpec.Create(
    LProjectSource,
    LSnapshot.Revision,
    LSnapshot.Content,
    LInstrumentedContent
  );
  LPatchResult := FPatches.Prepare(LSpec);
  if not LPatchResult.Success then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        LPatchResult.ErrorCode,
        LPatchResult.ErrorMessage
      )
    );
  LEntry.Mode := AMode;
  LEntry.Preview := LPatchResult.Preview;
  TDictionary<string, TRadIAMemoryInstrumentationEntry>(FEntries)
    .AddOrSetValue(LPatchResult.Preview.Id, LEntry);
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    BuildResultJson(LPatchResult.Preview, AMode, 'prepared')
  );
end;

function TRadIAMemoryInstrumentationCoordinator.Apply(
  const APreviewId: string
): TRadIAMemoryInstrumentationResult;
var
  LEntry: TRadIAMemoryInstrumentationEntry;
  LPatchResult: TRadIAPatchResult;
begin
  if not TDictionary<string, TRadIAMemoryInstrumentationEntry>(FEntries)
    .TryGetValue(APreviewId, LEntry) then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'preview_not_found',
        'Memory instrumentation preview was not found.'
      )
    );
  LPatchResult := FPatches.Apply(APreviewId);
  if not LPatchResult.Success then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        LPatchResult.ErrorCode,
        LPatchResult.ErrorMessage
      )
    );
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    BuildResultJson(LEntry.Preview, LEntry.Mode, 'applied')
  );
end;

function TRadIAMemoryInstrumentationCoordinator.Revert(
  const APreviewId: string
): TRadIAMemoryInstrumentationResult;
var
  LEntry: TRadIAMemoryInstrumentationEntry;
  LPatchResult: TRadIAPatchResult;
begin
  if not TDictionary<string, TRadIAMemoryInstrumentationEntry>(FEntries)
    .TryGetValue(APreviewId, LEntry) then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        'preview_not_found',
        'Memory instrumentation preview was not found.'
      )
    );
  LPatchResult := FPatches.Revert(APreviewId);
  if not LPatchResult.Success then
    Exit(
      TRadIAMemoryInstrumentationResult.Failed(
        LPatchResult.ErrorCode,
        LPatchResult.ErrorMessage
      )
    );
  TDictionary<string, TRadIAMemoryInstrumentationEntry>(FEntries)
    .Remove(APreviewId);
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    BuildResultJson(LEntry.Preview, LEntry.Mode, 'reverted')
  );
end;

constructor TRadIAMemoryInstrumentationTool.Create(
  const ACoordinator: IRadIAMemoryInstrumentationCoordinator;
  const AKind: TRadIAMemoryInstrumentationToolKind
);
begin
  inherited Create;
  if not Assigned(ACoordinator) then
    raise EArgumentNilException.Create('ACoordinator');
  FCoordinator := ACoordinator;
  FKind := AKind;
end;

function TRadIAMemoryInstrumentationTool.ParsePreviewId(
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
    Result := LRoot.GetValue<string>('previewId', '');
  finally
    LRoot.Free;
  end;
end;

function TRadIAMemoryInstrumentationTool.ToToolResult(
  const AResult: TRadIAMemoryInstrumentationResult
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

function TRadIAMemoryInstrumentationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LMode: TRadIAMemoryInstrumentationMode;
  LModeName: string;
  LPreviewId: string;
  LRoot: TJSONObject;
begin
  if FKind = mitPrepare then
  begin
    LMode := mimSession;
    LRoot := TJSONObject.ParseJSONValue(
      ARequest.ArgumentsJson
    ) as TJSONObject;
    try
      if Assigned(LRoot) then
      begin
        LModeName := LRoot.GetValue<string>('mode', 'session');
        if SameText(LModeName, 'persistentDebug') then
          LMode := mimPersistentDebug;
      end;
    finally
      LRoot.Free;
    end;
    Exit(ToToolResult(FCoordinator.Prepare(LMode)));
  end;
  LPreviewId := ParsePreviewId(ARequest.ArgumentsJson);
  if LPreviewId.IsEmpty then
    Exit(
      TRadIAToolResult.Failed(
        'missing_preview_id',
        'previewId is required.'
      )
    );
  if FKind = mitApply then
    Result := ToToolResult(FCoordinator.Apply(LPreviewId))
  else
    Result := ToToolResult(FCoordinator.Revert(LPreviewId));
end;

function TRadIAMemoryInstrumentationTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    mitPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareMemoryInstrumentation',
        '1.0.0',
        'Previews reversible FastMM5 instrumentation for the active Debug project without changing its IDE buffer.',
        CPreviewInputSchema,
        CInstrumentationOutputSchema,
        trReadOnly
      );
    mitApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyMemoryInstrumentation',
        '1.0.0',
        'Applies a fresh FastMM5 instrumentation preview to the live project source buffer.',
        CPreviewIdInputSchema,
        CInstrumentationOutputSchema,
        trStructuralWrite
      );
    mitRevert:
      Result := TRadIAToolDescriptor.Create(
        'RevertMemoryInstrumentation',
        '1.0.0',
        'Restores the exact project source captured before FastMM5 instrumentation.',
        CPreviewIdInputSchema,
        CInstrumentationOutputSchema,
        trReversibleWrite
      );
  end;
end;

procedure RegisterRadIAMemoryInstrumentationTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIAMemoryInstrumentationCoordinator
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(
    TRadIAMemoryInstrumentationTool.Create(ACoordinator, mitPrepare)
  );
  ARegistry.RegisterTool(
    TRadIAMemoryInstrumentationTool.Create(ACoordinator, mitApply)
  );
  ARegistry.RegisterTool(
    TRadIAMemoryInstrumentationTool.Create(ACoordinator, mitRevert)
  );
end;

end.
