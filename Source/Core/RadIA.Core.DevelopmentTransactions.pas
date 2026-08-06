unit RadIA.Core.DevelopmentTransactions;

interface

uses
  System.Generics.Collections,
  RadIA.Core.DesignerComponents,
  RadIA.Core.DesignerEvents,
  RadIA.Core.DesignerMutations,
  RadIA.Core.DesignerProperties,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.ProjectFiles;

type
  TRadIADevelopmentOperationKind = (
    dokMultiFilePatch,
    dokProjectFile,
    dokDesignerComponent,
    dokDesignerLayout,
    dokDesignerProperty,
    dokDesignerEvent
  );

  TRadIADevelopmentOperation = record
  private
    FKind: TRadIADevelopmentOperationKind;
    FLabel: string;
    FPreviewId: string;
  public
    constructor Create(
      const AKind: TRadIADevelopmentOperationKind;
      const APreviewId: string;
      const ALabel: string = ''
    );
    property Kind: TRadIADevelopmentOperationKind read FKind;
    property LabelText: string read FLabel;
    property PreviewId: string read FPreviewId;
  end;

  TRadIADevelopmentStepState = (
    dssPending,
    dssRejected,
    dssApplied,
    dssReverted
  );

  TRadIADevelopmentTransactionState = (
    dtsPrepared,
    dtsApplied,
    dtsPartiallyReverted,
    dtsReverted
  );

  TRadIADevelopmentTransactionPreview = class
  private
    FId: string;
    FOperations: TArray<TRadIADevelopmentOperation>;
    FStepStates: TArray<TRadIADevelopmentStepState>;
    FState: TRadIADevelopmentTransactionState;
    FExpiresAtUtc: TDateTime;
  public
    constructor Create(
      const AId: string;
      const AOperations: TArray<TRadIADevelopmentOperation>;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property Operations: TArray<TRadIADevelopmentOperation>
      read FOperations;
    property StepStates: TArray<TRadIADevelopmentStepState>
      read FStepStates;
    property State: TRadIADevelopmentTransactionState
      read FState write FState;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIADevelopmentTransactionResult = record
  private
    FSuccess: Boolean;
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIADevelopmentTransactionPreview;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIADevelopmentTransactionResult; static;
    class function Succeeded(
      const APreview: TRadIADevelopmentTransactionPreview
    ): TRadIADevelopmentTransactionResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIADevelopmentTransactionPreview read FPreview;
  end;

  IRadIADevelopmentOperationAdapter = interface
    ['{26697E39-AC81-4F24-9DB8-75FCB549947B}']
    function Apply(
      const AOperation: TRadIADevelopmentOperation;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    function Revert(
      const AOperation: TRadIADevelopmentOperation;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
  end;

  IRadIADevelopmentTransactionService = interface
    ['{BA226D6B-E4FC-49D0-B016-82541477B4B7}']
    function Prepare(
      const AOperations: TArray<TRadIADevelopmentOperation>
    ): TRadIADevelopmentTransactionResult;
    function Apply(
      const APreviewId: string
    ): TRadIADevelopmentTransactionResult;
    function Revert(
      const APreviewId: string
    ): TRadIADevelopmentTransactionResult;
    function RejectStep(
      const APreviewId: string;
      const AStepIndex: Integer
    ): TRadIADevelopmentTransactionResult;
    function RevertStep(
      const APreviewId: string;
      const AStepIndex: Integer
    ): TRadIADevelopmentTransactionResult;
    procedure Clear;
  end;

  TRadIADevelopmentOperationAdapter = class(
    TInterfacedObject,
    IRadIADevelopmentOperationAdapter
  )
  private
    FMultiFilePatches: IRadIAMultiFilePatchService;
    FProjectFiles: IRadIAProjectFileService;
    FDesignerComponents: IRadIAComponentChangeService;
    FDesignerLayouts: IRadIAComponentLayoutService;
    FDesignerProperties: IRadIAComponentPropertyService;
    FDesignerEvents: IRadIAFormEventService;
  public
    constructor Create(
      const AMultiFilePatches: IRadIAMultiFilePatchService;
      const AProjectFiles: IRadIAProjectFileService;
      const ADesignerComponents: IRadIAComponentChangeService;
      const ADesignerLayouts: IRadIAComponentLayoutService;
      const ADesignerProperties: IRadIAComponentPropertyService;
      const ADesignerEvents: IRadIAFormEventService
    );
    function Apply(
      const AOperation: TRadIADevelopmentOperation;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    function Revert(
      const AOperation: TRadIADevelopmentOperation;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
  end;

  TRadIADevelopmentTransactionService = class(
    TInterfacedObject,
    IRadIADevelopmentTransactionService
  )
  private
    FAdapter: IRadIADevelopmentOperationAdapter;
    FPreviews: TObjectDictionary<
      string,
      TRadIADevelopmentTransactionPreview
    >;
    FExpirationMinutes: Integer;
    function CompensateApply(
      const APreview: TRadIADevelopmentTransactionPreview;
      const ALastApplied: Integer
    ): Boolean;
    function CompensateRevert(
      const APreview: TRadIADevelopmentTransactionPreview;
      const AFirstReverted: Integer;
      const AOriginalStates: TArray<TRadIADevelopmentStepState>
    ): Boolean;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIADevelopmentTransactionPreview
    ): TRadIADevelopmentTransactionResult;
  public
    constructor Create(
      const AAdapter: IRadIADevelopmentOperationAdapter;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function Prepare(
      const AOperations: TArray<TRadIADevelopmentOperation>
    ): TRadIADevelopmentTransactionResult;
    function Apply(
      const APreviewId: string
    ): TRadIADevelopmentTransactionResult;
    function Revert(
      const APreviewId: string
    ): TRadIADevelopmentTransactionResult;
    function RejectStep(
      const APreviewId: string;
      const AStepIndex: Integer
    ): TRadIADevelopmentTransactionResult;
    function RevertStep(
      const APreviewId: string;
      const AStepIndex: Integer
    ): TRadIADevelopmentTransactionResult;
    procedure Clear;
  end;

function RadIADevelopmentOperationKindName(
  const AKind: TRadIADevelopmentOperationKind
): string;

implementation

uses
  System.DateUtils,
  System.SysUtils;

const
  CCompensationFailed = 'compensation_failed';
  CPreconditionFailed = 'precondition_failed';
  CPreviewExpired = 'preview_expired';
  CPreviewNotFound = 'preview_not_found';
  CResourceLimit = 'resource_limit';
  CMaxOperations = 32;
  CMaxPreviews = 16;

function RadIADevelopmentOperationKindName(
  const AKind: TRadIADevelopmentOperationKind
): string;
begin
  case AKind of
    dokMultiFilePatch: Result := 'multiFilePatch';
    dokProjectFile: Result := 'projectFile';
    dokDesignerComponent: Result := 'designerComponent';
    dokDesignerLayout: Result := 'designerLayout';
    dokDesignerProperty: Result := 'designerProperty';
  else
    Result := 'designerEvent';
  end;
end;

{ TRadIADevelopmentOperation }

constructor TRadIADevelopmentOperation.Create(
  const AKind: TRadIADevelopmentOperationKind;
  const APreviewId: string;
  const ALabel: string
);
begin
  FKind := AKind;
  FPreviewId := APreviewId;
  FLabel := Trim(ALabel);
  if FLabel = '' then
    FLabel := RadIADevelopmentOperationKindName(AKind);
end;

{ TRadIADevelopmentTransactionPreview }

constructor TRadIADevelopmentTransactionPreview.Create(
  const AId: string;
  const AOperations: TArray<TRadIADevelopmentOperation>;
  const AExpiresAtUtc: TDateTime
);
begin
  inherited Create;
  FId := AId;
  FOperations := Copy(AOperations);
  SetLength(FStepStates, Length(FOperations));
  FState := dtsPrepared;
  FExpiresAtUtc := AExpiresAtUtc;
end;

{ TRadIADevelopmentTransactionResult }

class function TRadIADevelopmentTransactionResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIADevelopmentTransactionResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIADevelopmentTransactionResult.Succeeded(
  const APreview: TRadIADevelopmentTransactionPreview
): TRadIADevelopmentTransactionResult;
begin
  Result.FSuccess := True;
  Result.FPreview := APreview;
end;

{ TRadIADevelopmentOperationAdapter }

function TRadIADevelopmentOperationAdapter.Apply(
  const AOperation: TRadIADevelopmentOperation;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
var
  LComponent: TRadIAComponentChangeResult;
  LEvent: TRadIAFormEventResult;
  LLayout: TRadIAComponentLayoutResult;
  LMultiFile: TRadIAMultiFilePatchResult;
  LProjectFile: TRadIAProjectFileResult;
  LProperty: TRadIAComponentPropertyResult;
begin
  case AOperation.Kind of
    dokMultiFilePatch:
      begin
        LMultiFile := FMultiFilePatches.Apply(AOperation.PreviewId);
        Result := LMultiFile.Success;
        AErrorCode := LMultiFile.ErrorCode;
        AErrorMessage := LMultiFile.ErrorMessage;
      end;
    dokProjectFile:
      begin
        LProjectFile := FProjectFiles.Apply(AOperation.PreviewId);
        Result := LProjectFile.Success;
        AErrorCode := LProjectFile.ErrorCode;
        AErrorMessage := LProjectFile.ErrorMessage;
      end;
    dokDesignerComponent:
      begin
        LComponent := FDesignerComponents.Apply(AOperation.PreviewId);
        Result := LComponent.Success;
        AErrorCode := LComponent.ErrorCode;
        AErrorMessage := LComponent.ErrorMessage;
      end;
    dokDesignerLayout:
      begin
        LLayout := FDesignerLayouts.Apply(AOperation.PreviewId);
        Result := LLayout.Success;
        AErrorCode := LLayout.ErrorCode;
        AErrorMessage := LLayout.ErrorMessage;
      end;
    dokDesignerProperty:
      begin
        LProperty := FDesignerProperties.Apply(AOperation.PreviewId);
        Result := LProperty.Success;
        AErrorCode := LProperty.ErrorCode;
        AErrorMessage := LProperty.ErrorMessage;
      end;
  else
    LEvent := FDesignerEvents.Apply(AOperation.PreviewId);
    Result := LEvent.Success;
    AErrorCode := LEvent.ErrorCode;
    AErrorMessage := LEvent.ErrorMessage;
  end;
end;

constructor TRadIADevelopmentOperationAdapter.Create(
  const AMultiFilePatches: IRadIAMultiFilePatchService;
  const AProjectFiles: IRadIAProjectFileService;
  const ADesignerComponents: IRadIAComponentChangeService;
  const ADesignerLayouts: IRadIAComponentLayoutService;
  const ADesignerProperties: IRadIAComponentPropertyService;
  const ADesignerEvents: IRadIAFormEventService
);
begin
  inherited Create;
  if not Assigned(AMultiFilePatches) then
    raise EArgumentNilException.Create('AMultiFilePatches');
  if not Assigned(AProjectFiles) then
    raise EArgumentNilException.Create('AProjectFiles');
  if not Assigned(ADesignerComponents) then
    raise EArgumentNilException.Create('ADesignerComponents');
  if not Assigned(ADesignerLayouts) then
    raise EArgumentNilException.Create('ADesignerLayouts');
  if not Assigned(ADesignerProperties) then
    raise EArgumentNilException.Create('ADesignerProperties');
  if not Assigned(ADesignerEvents) then
    raise EArgumentNilException.Create('ADesignerEvents');
  FMultiFilePatches := AMultiFilePatches;
  FProjectFiles := AProjectFiles;
  FDesignerComponents := ADesignerComponents;
  FDesignerLayouts := ADesignerLayouts;
  FDesignerProperties := ADesignerProperties;
  FDesignerEvents := ADesignerEvents;
end;

function TRadIADevelopmentOperationAdapter.Revert(
  const AOperation: TRadIADevelopmentOperation;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
var
  LComponent: TRadIAComponentChangeResult;
  LEvent: TRadIAFormEventResult;
  LLayout: TRadIAComponentLayoutResult;
  LMultiFile: TRadIAMultiFilePatchResult;
  LProjectFile: TRadIAProjectFileResult;
  LProperty: TRadIAComponentPropertyResult;
begin
  case AOperation.Kind of
    dokMultiFilePatch:
      begin
        LMultiFile := FMultiFilePatches.Revert(AOperation.PreviewId);
        Result := LMultiFile.Success;
        AErrorCode := LMultiFile.ErrorCode;
        AErrorMessage := LMultiFile.ErrorMessage;
      end;
    dokProjectFile:
      begin
        LProjectFile := FProjectFiles.Revert(AOperation.PreviewId);
        Result := LProjectFile.Success;
        AErrorCode := LProjectFile.ErrorCode;
        AErrorMessage := LProjectFile.ErrorMessage;
      end;
    dokDesignerComponent:
      begin
        LComponent := FDesignerComponents.Revert(AOperation.PreviewId);
        Result := LComponent.Success;
        AErrorCode := LComponent.ErrorCode;
        AErrorMessage := LComponent.ErrorMessage;
      end;
    dokDesignerLayout:
      begin
        LLayout := FDesignerLayouts.Revert(AOperation.PreviewId);
        Result := LLayout.Success;
        AErrorCode := LLayout.ErrorCode;
        AErrorMessage := LLayout.ErrorMessage;
      end;
    dokDesignerProperty:
      begin
        LProperty := FDesignerProperties.Revert(AOperation.PreviewId);
        Result := LProperty.Success;
        AErrorCode := LProperty.ErrorCode;
        AErrorMessage := LProperty.ErrorMessage;
      end;
  else
    LEvent := FDesignerEvents.Revert(AOperation.PreviewId);
    Result := LEvent.Success;
    AErrorCode := LEvent.ErrorCode;
    AErrorMessage := LEvent.ErrorMessage;
  end;
end;

{ TRadIADevelopmentTransactionService }

function TRadIADevelopmentTransactionService.Apply(
  const APreviewId: string
): TRadIADevelopmentTransactionResult;
var
  LErrorCode: string;
  LErrorMessage: string;
  LIndex: Integer;
  LPreview: TRadIADevelopmentTransactionPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if LPreview.State <> dtsPrepared then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CPreconditionFailed,
        'Development transaction must be prepared before apply.'
      ));
    for LIndex := Low(LPreview.Operations) to
      High(LPreview.Operations) do
    begin
      if LPreview.FStepStates[LIndex] = dssRejected then
        Continue;
      if not FAdapter.Apply(
        LPreview.Operations[LIndex],
        LErrorCode,
        LErrorMessage
      ) then
      begin
        if not CompensateApply(LPreview, LIndex - 1) then
          Exit(TRadIADevelopmentTransactionResult.Failed(
            CCompensationFailed,
            'Development transaction compensation was incomplete.'
          ));
        Exit(TRadIADevelopmentTransactionResult.Failed(
          LErrorCode,
          LErrorMessage
        ));
      end;
      LPreview.FStepStates[LIndex] := dssApplied;
    end;
    LPreview.State := dtsApplied;
    Result := TRadIADevelopmentTransactionResult.Succeeded(LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

procedure TRadIADevelopmentTransactionService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIADevelopmentTransactionService.CompensateApply(
  const APreview: TRadIADevelopmentTransactionPreview;
  const ALastApplied: Integer
): Boolean;
var
  LErrorCode: string;
  LErrorMessage: string;
  LIndex: Integer;
begin
  Result := True;
  for LIndex := ALastApplied downto Low(APreview.Operations) do
    if APreview.FStepStates[LIndex] = dssApplied then
    begin
      Result := FAdapter.Revert(
        APreview.Operations[LIndex],
        LErrorCode,
        LErrorMessage
      ) and Result;
      if Result then
        APreview.FStepStates[LIndex] := dssPending;
    end;
end;

function TRadIADevelopmentTransactionService.CompensateRevert(
  const APreview: TRadIADevelopmentTransactionPreview;
  const AFirstReverted: Integer;
  const AOriginalStates: TArray<TRadIADevelopmentStepState>
): Boolean;
var
  LErrorCode: string;
  LErrorMessage: string;
  LIndex: Integer;
begin
  Result := True;
  for LIndex := AFirstReverted to High(APreview.Operations) do
    if (AOriginalStates[LIndex] = dssApplied) and
      (APreview.FStepStates[LIndex] = dssReverted) then
    begin
      Result := FAdapter.Apply(
        APreview.Operations[LIndex],
        LErrorCode,
        LErrorMessage
      ) and Result;
      if Result then
        APreview.FStepStates[LIndex] := dssApplied;
    end;
end;

constructor TRadIADevelopmentTransactionService.Create(
  const AAdapter: IRadIADevelopmentOperationAdapter;
  const AExpirationMinutes: Integer
);
begin
  inherited Create;
  if not Assigned(AAdapter) then
    raise EArgumentNilException.Create('AAdapter');
  if AExpirationMinutes <= 0 then
    raise EArgumentOutOfRangeException.Create('AExpirationMinutes');
  FAdapter := AAdapter;
  FExpirationMinutes := AExpirationMinutes;
  FPreviews := TObjectDictionary<
    string,
    TRadIADevelopmentTransactionPreview
  >.Create([doOwnsValues]);
end;

destructor TRadIADevelopmentTransactionService.Destroy;
begin
  FPreviews.Free;
  inherited Destroy;
end;

function TRadIADevelopmentTransactionService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIADevelopmentTransactionPreview
): TRadIADevelopmentTransactionResult;
begin
  APreview := nil;
  if not FPreviews.TryGetValue(APreviewId, APreview) then
    Exit(TRadIADevelopmentTransactionResult.Failed(
      CPreviewNotFound,
      'Development transaction preview was not found.'
    ));
  if TTimeZone.Local.ToUniversalTime(Now) >
    APreview.ExpiresAtUtc then
  begin
    FPreviews.Remove(APreviewId);
    APreview := nil;
    Exit(TRadIADevelopmentTransactionResult.Failed(
      CPreviewExpired,
      'Development transaction preview expired.'
    ));
  end;
  Result := TRadIADevelopmentTransactionResult.Succeeded(APreview);
end;

function TRadIADevelopmentTransactionService.Prepare(
  const AOperations: TArray<TRadIADevelopmentOperation>
): TRadIADevelopmentTransactionResult;
var
  LKey: string;
  LOperation: TRadIADevelopmentOperation;
  LPreview: TRadIADevelopmentTransactionPreview;
  LSeen: TDictionary<string, Boolean>;
begin
  if (Length(AOperations) = 0) or
    (Length(AOperations) > CMaxOperations) then
    Exit(TRadIADevelopmentTransactionResult.Failed(
      CResourceLimit,
      'Development transaction must contain between 1 and 32 operations.'
    ));
  LSeen := TDictionary<string, Boolean>.Create;
  try
    for LOperation in AOperations do
    begin
      if Trim(LOperation.PreviewId) = '' then
        Exit(TRadIADevelopmentTransactionResult.Failed(
          'invalid_operation',
          'Every development operation requires a preview ID.'
        ));
      if Length(LOperation.LabelText) > 120 then
        Exit(TRadIADevelopmentTransactionResult.Failed(
          'invalid_operation',
          'Development operation labels are limited to 120 characters.'
        ));
      LKey := RadIADevelopmentOperationKindName(LOperation.Kind) +
        ':' + LowerCase(LOperation.PreviewId);
      if LSeen.ContainsKey(LKey) then
        Exit(TRadIADevelopmentTransactionResult.Failed(
          'invalid_operation',
          'Development transaction contains a duplicate operation.'
        ));
      LSeen.Add(LKey, True);
    end;
  finally
    LSeen.Free;
  end;
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPreviews then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CResourceLimit,
        'Too many development transaction previews are active.'
      ));
    LPreview := TRadIADevelopmentTransactionPreview.Create(
      TGUID.NewGuid.ToString,
      AOperations,
      IncMinute(
        TTimeZone.Local.ToUniversalTime(Now),
        FExpirationMinutes
      )
    );
    FPreviews.Add(LPreview.Id, LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIADevelopmentTransactionResult.Succeeded(LPreview);
end;

function TRadIADevelopmentTransactionService.Revert(
  const APreviewId: string
): TRadIADevelopmentTransactionResult;
var
  LErrorCode: string;
  LErrorMessage: string;
  LIndex: Integer;
  LOriginalStates: TArray<TRadIADevelopmentStepState>;
  LPreview: TRadIADevelopmentTransactionPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if not (LPreview.State in [dtsApplied, dtsPartiallyReverted]) then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CPreconditionFailed,
        'Development transaction must be applied before revert.'
      ));
    LOriginalStates := Copy(LPreview.FStepStates);
    for LIndex := High(LPreview.Operations) downto
      Low(LPreview.Operations) do
    begin
      if LPreview.FStepStates[LIndex] <> dssApplied then
        Continue;
      if not FAdapter.Revert(
        LPreview.Operations[LIndex],
        LErrorCode,
        LErrorMessage
      ) then
      begin
        if not CompensateRevert(
          LPreview,
          LIndex + 1,
          LOriginalStates
        ) then
          Exit(TRadIADevelopmentTransactionResult.Failed(
            CCompensationFailed,
            'Development transaction revert compensation was incomplete.'
          ));
        Exit(TRadIADevelopmentTransactionResult.Failed(
          LErrorCode,
          LErrorMessage
        ));
      end;
      LPreview.FStepStates[LIndex] := dssReverted;
    end;
    LPreview.State := dtsReverted;
    Result := TRadIADevelopmentTransactionResult.Succeeded(LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIADevelopmentTransactionService.RejectStep(
  const APreviewId: string;
  const AStepIndex: Integer
): TRadIADevelopmentTransactionResult;
var
  LIndex: Integer;
  LPendingCount: Integer;
  LPreview: TRadIADevelopmentTransactionPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if LPreview.State <> dtsPrepared then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CPreconditionFailed,
        'Only a prepared development step can be rejected.'
      ));
    if (AStepIndex < Low(LPreview.Operations)) or
      (AStepIndex > High(LPreview.Operations)) then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        'invalid_step',
        'Development transaction step index is outside the plan.'
      ));
    if LPreview.FStepStates[AStepIndex] <> dssPending then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CPreconditionFailed,
        'Development transaction step is not pending.'
      ));
    LPendingCount := 0;
    for LIndex := Low(LPreview.FStepStates) to
      High(LPreview.FStepStates) do
      if LPreview.FStepStates[LIndex] = dssPending then
        Inc(LPendingCount);
    if LPendingCount = 1 then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CPreconditionFailed,
        'A development plan must retain at least one pending step.'
      ));
    LPreview.FStepStates[AStepIndex] := dssRejected;
    Result := TRadIADevelopmentTransactionResult.Succeeded(LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIADevelopmentTransactionService.RevertStep(
  const APreviewId: string;
  const AStepIndex: Integer
): TRadIADevelopmentTransactionResult;
var
  LErrorCode: string;
  LErrorMessage: string;
  LHasAppliedStep: Boolean;
  LIndex: Integer;
  LPreview: TRadIADevelopmentTransactionPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if not (LPreview.State in [dtsApplied, dtsPartiallyReverted]) then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CPreconditionFailed,
        'Only an applied development step can be reverted.'
      ));
    if (AStepIndex < Low(LPreview.Operations)) or
      (AStepIndex > High(LPreview.Operations)) then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        'invalid_step',
        'Development transaction step index is outside the plan.'
      ));
    if LPreview.FStepStates[AStepIndex] <> dssApplied then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        CPreconditionFailed,
        'Development transaction step is not applied.'
      ));
    for LIndex := AStepIndex + 1 to High(LPreview.Operations) do
      if LPreview.FStepStates[LIndex] = dssApplied then
        Exit(TRadIADevelopmentTransactionResult.Failed(
          CPreconditionFailed,
          'Revert later applied steps before reverting this step.'
        ));
    if not FAdapter.Revert(
      LPreview.Operations[AStepIndex],
      LErrorCode,
      LErrorMessage
    ) then
      Exit(TRadIADevelopmentTransactionResult.Failed(
        LErrorCode,
        LErrorMessage
      ));
    LPreview.FStepStates[AStepIndex] := dssReverted;
    LHasAppliedStep := False;
    for LIndex := Low(LPreview.FStepStates) to
      High(LPreview.FStepStates) do
      if LPreview.FStepStates[LIndex] = dssApplied then
      begin
        LHasAppliedStep := True;
        Break;
      end;
    if LHasAppliedStep then
      LPreview.State := dtsPartiallyReverted
    else
      LPreview.State := dtsReverted;
    Result := TRadIADevelopmentTransactionResult.Succeeded(LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

end.
