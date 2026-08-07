unit RadIA.Core.RuntimeScenarioTools;

interface

uses
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools;

procedure RegisterRadIARuntimeScenarioTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator
);
function TryParseRadIARuntimeScenarioDefinition(
  const AJson: TObject;
  const ASession: TRadIARuntimeSessionIdentity;
  out AScenario: TRadIARuntimeScenario
): Boolean;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils;

type
  TRadIARuntimeScenarioToolKind = (
    rstkPrepare,
    rstkRun,
    rstkCancel,
    rstkGetStatus
  );

  TRadIARuntimeScenarioTool = class(TInterfacedObject, IRadIATool)
  private
    FDebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FKind: TRadIARuntimeScenarioToolKind;
    FScenarioCoordinator: IRadIARuntimeScenarioCoordinator;
    function ExecutePrepare(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteRun(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIARuntimeScenarioToolKind;
      const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
      const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CPrepareInputSchema =
    '{"type":"object","required":["name","limits","actions"],' +
    '"properties":{"name":{"type":"string","minLength":1},' +
    '"limits":{"type":"object"},"actions":{"type":"array",' +
    '"minItems":1}},"additionalProperties":false}';
  CRunInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string","minLength":32,"maxLength":64}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';
  CMaxRuntimeValueLength = 4096;

function RuntimeActionKind(
  const AName: string;
  out AKind: TRadIARuntimeActionKind
): Boolean;
begin
  Result := True;
  if SameText(AName, 'invoke') then
    AKind := rakInvoke
  else if SameText(AName, 'setValue') then
    AKind := rakSetValue
  else if SameText(AName, 'select') then
    AKind := rakSelect
  else if SameText(AName, 'close') then
    AKind := rakClose
  else if SameText(AName, 'cancel') then
    AKind := rakCancel
  else if SameText(AName, 'wait') then
    AKind := rakWait
  else if SameText(AName, 'assert') then
    AKind := rakAssert
  else
    Result := False;
end;

function ParseAction(
  const AJson: TJSONObject;
  out AAction: TRadIARuntimeScenarioAction
): Boolean;
var
  LKind: TRadIARuntimeActionKind;
  LSelectorJson: TJSONObject;
  LSelectorValue: TJSONValue;
  LSelector: TRadIARuntimeSelector;
  LTargetId: string;
  LTimeoutMs: Integer;
  LValue: string;
begin
  Result := False;
  if not Assigned(AJson) or not RuntimeActionKind(
    AJson.GetValue<string>('kind', ''),
    LKind
  ) then
    Exit;
  LTargetId := Trim(AJson.GetValue<string>('targetId', ''));
  LSelectorJson := nil;
  LSelectorValue := AJson.GetValue('selector');
  if LSelectorValue is TJSONObject then
    LSelectorJson := TJSONObject(LSelectorValue);
  LTimeoutMs := AJson.GetValue<Integer>('timeoutMs', 0);
  if (LTimeoutMs < 100) or (LTimeoutMs > 300000) then
    Exit;
  LValue := AJson.GetValue<string>('value', '');
  if Length(LValue) > CMaxRuntimeValueLength then
    Exit;
  if Assigned(LSelectorJson) then
    LSelector := TRadIARuntimeSelector.Create(
      LTargetId,
      Trim(LSelectorJson.GetValue<string>('className', '')),
      Trim(LSelectorJson.GetValue<string>('controlName', '')),
      Trim(LSelectorJson.GetValue<string>('text', '')),
      Trim(LSelectorJson.GetValue<string>('parentPath', ''))
    )
  else
    LSelector := TRadIARuntimeSelector.Create(
      LTargetId,
      '',
      '',
      '',
      ''
    );
  if (LKind <> rakWait) and
    (Length(LTargetId) <> 64) and
    not LSelector.HasStableIdentity then
    Exit;
  AAction := TRadIARuntimeScenarioAction.Create(
    LKind,
    LSelector,
    LValue,
    LTimeoutMs
  );
  Result := True;
end;

function TryParseRadIARuntimeScenarioDefinition(
  const AJson: TObject;
  const ASession: TRadIARuntimeSessionIdentity;
  out AScenario: TRadIARuntimeScenario
): Boolean;
var
  LAction: TRadIARuntimeScenarioAction;
  LActionsJson: TJSONArray;
  LActions: TArray<TRadIARuntimeScenarioAction>;
  LItem: TJSONValue;
  LItems: TList<TRadIARuntimeScenarioAction>;
  LJson: TJSONObject;
  LLimitsJson: TJSONObject;
  LLimits: TRadIARuntimeScenarioLimits;
  LMaxActions: Integer;
  LMaxDurationMs: Integer;
  LMaxRepetitions: Integer;
  LName: string;
begin
  Result := False;
  LActions := [];
  LLimits := Default(TRadIARuntimeScenarioLimits);
  if not (AJson is TJSONObject) then
    Exit;
  LJson := TJSONObject(AJson);
  LName := Trim(LJson.GetValue<string>('name', ''));
  if not (LJson.GetValue('limits') is TJSONObject) or
    not (LJson.GetValue('actions') is TJSONArray) then
    Exit;
  LLimitsJson := TJSONObject(LJson.GetValue('limits'));
  LActionsJson := TJSONArray(LJson.GetValue('actions'));
  LMaxActions := LLimitsJson.GetValue<Integer>('maxActions', 0);
  LMaxDurationMs := LLimitsJson.GetValue<Integer>('maxDurationMs', 0);
  LMaxRepetitions := LLimitsJson.GetValue<Integer>(
    'maxRepetitions',
    0
  );
  if LMaxDurationMs < 0 then
    Exit;
  LLimits := TRadIARuntimeScenarioLimits.Create(
    LMaxActions,
    LMaxDurationMs,
    LMaxRepetitions
  );
  if (LName = '') or not LLimits.IsValid then
    Exit;
  LItems := TList<TRadIARuntimeScenarioAction>.Create;
  try
    for LItem in LActionsJson do
    begin
      if not (LItem is TJSONObject) or
        not ParseAction(TJSONObject(LItem), LAction) then
        Exit;
      LItems.Add(LAction);
    end;
    LActions := LItems.ToArray;
  finally
    LItems.Free;
  end;
  if Length(LActions) = 0 then
    Exit;
  AScenario := TRadIARuntimeScenario.Create(
    LName,
    ASession,
    LLimits,
    LActions
  );
  Result := AScenario.IsExecutable;
end;

function StatusJson(
  const AStatus: TRadIARuntimeScenarioStatus
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AStatus.PreviewId);
    LJson.AddPair(
      'state',
      RadIARuntimeScenarioStateName(AStatus.State)
    );
    LJson.AddPair(
      'repetition',
      TJSONNumber.Create(AStatus.Repetition)
    );
    LJson.AddPair(
      'actionIndex',
      TJSONNumber.Create(AStatus.ActionIndex)
    );
    LJson.AddPair(
      'completedActions',
      TJSONNumber.Create(AStatus.CompletedActions)
    );
    LJson.AddPair('errorCode', AStatus.ErrorCode);
    LJson.AddPair('message', AStatus.Message);
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

{ TRadIARuntimeScenarioTool }

constructor TRadIARuntimeScenarioTool.Create(
  const AKind: TRadIARuntimeScenarioToolKind;
  const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator
);
begin
  inherited Create;
  if not Assigned(ADebugCoordinator) then
    raise EArgumentNilException.Create('ADebugCoordinator');
  if not Assigned(AScenarioCoordinator) then
    raise EArgumentNilException.Create('AScenarioCoordinator');
  FKind := AKind;
  FDebugCoordinator := ADebugCoordinator;
  FScenarioCoordinator := AScenarioCoordinator;
end;

function TRadIARuntimeScenarioTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCancelled: Boolean;
begin
  try
    case FKind of
      rstkPrepare:
        Result := ExecutePrepare(ARequest);
      rstkRun:
        Result := ExecuteRun(ARequest);
      rstkCancel:
        begin
          LCancelled := FScenarioCoordinator.Cancel;
          Result := TRadIAToolResult.Succeeded(
            '{"cancelRequested":' +
            LowerCase(BoolToStr(LCancelled, True)) + '}'
          );
        end;
      rstkGetStatus:
        Result := TRadIAToolResult.Succeeded(
          StatusJson(FScenarioCoordinator.GetStatus)
        );
    else
      Result := TRadIAToolResult.Failed(
        'unsupported_tool',
        'Runtime scenario tool kind is unsupported.'
      );
    end;
  except
    on E: EArgumentException do
      Result := TRadIAToolResult.Failed(
        'invalid_runtime_scenario',
        E.Message
      );
    on E: EInvalidOp do
      Result := TRadIAToolResult.Failed(
        'runtime_scenario_conflict',
        E.Message
      );
  end;
end;

function TRadIARuntimeScenarioTool.ExecutePrepare(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LPreview: TRadIARuntimeScenarioPreview;
  LResult: TJSONObject;
  LScenario: TRadIARuntimeScenario;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime scenario arguments must be a JSON object.'
    ));
  try
    if not TryParseRadIARuntimeScenarioDefinition(
      LJson,
      FDebugCoordinator.GetCurrentSession,
      LScenario
    ) then
      Exit(TRadIAToolResult.Failed(
        'invalid_runtime_scenario',
        'Runtime scenario name, limits, or actions are invalid.'
      ));
    LPreview := FScenarioCoordinator.Prepare(LScenario);
    LResult := TJSONObject.Create;
    try
      LResult.AddPair('previewId', LPreview.PreviewId);
      LResult.AddPair('fingerprint', LPreview.Fingerprint);
      LResult.AddPair('name', LPreview.Name);
      LResult.AddPair('sessionId', LPreview.SessionId);
      LResult.AddPair(
        'actionCount',
        TJSONNumber.Create(LPreview.ActionCount)
      );
      LResult.AddPair(
        'repetitions',
        TJSONNumber.Create(LPreview.Repetitions)
      );
      LResult.AddPair('consentRequired', TJSONBool.Create(True));
      Result := TRadIAToolResult.Succeeded(LResult.ToJSON);
    finally
      LResult.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeScenarioTool.ExecuteRun(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LPreviewId: string;
  LStatus: TRadIARuntimeScenarioStatus;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime scenario run arguments must be a JSON object.'
    ));
  try
    LPreviewId := Trim(
      LJson.GetValue<string>('previewId', '')
    );
    if LPreviewId = '' then
      Exit(TRadIAToolResult.Failed(
        'invalid_preview_id',
        'Runtime scenario preview id is required.'
      ));
    LStatus := FScenarioCoordinator.Run(
      LPreviewId,
      FDebugCoordinator.GetCurrentSession,
      ARequest.CancellationToken
    );
    if LStatus.State = rssSucceeded then
      Result := TRadIAToolResult.Succeeded(StatusJson(LStatus))
    else
      Result := TRadIAToolResult.Failed(
        LStatus.ErrorCode,
        LStatus.Message
      );
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeScenarioTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    rstkPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareRuntimeScenario',
        '1.0.0',
        'Validate and preview a bounded runtime scenario without executing it.',
        CPrepareInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    rstkRun:
      Result := TRadIAToolDescriptor.Create(
        'RunRuntimeScenario',
        '1.0.0',
        'Execute one prepared runtime scenario after explicit consent.',
        CRunInputSchema,
        CObjectOutputSchema,
        trExecution
      ).WithExecutionOptions(300000, False).WithConsentEveryTime;
    rstkCancel:
      Result := TRadIAToolDescriptor.Create(
        'CancelRuntimeScenario',
        '1.0.0',
        'Immediately stop the active runtime scenario without consent.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    rstkGetStatus:
      Result := TRadIAToolDescriptor.Create(
        'GetRuntimeScenarioStatus',
        '1.0.0',
        'Return progress and outcome for the current runtime scenario.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  end;
end;

procedure RegisterRadIARuntimeScenarioTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator
);
var
  LKind: TRadIARuntimeScenarioToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  for LKind := Low(TRadIARuntimeScenarioToolKind) to
    High(TRadIARuntimeScenarioToolKind) do
    ARegistry.RegisterTool(
      TRadIARuntimeScenarioTool.Create(
        LKind,
        ADebugCoordinator,
        AScenarioCoordinator
      )
    );
end;

end.
