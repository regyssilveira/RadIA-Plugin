unit RadIA.Core.RuntimeRegressionTools;

interface

uses
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeRegression,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools;

procedure RegisterRadIARuntimeRegressionTools(
  const ARegistry: IRadIAToolRegistry;
  const ARegression: IRadIARuntimeRegressionCoordinator;
  const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator
);

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeScenarioTools;

type
  TRadIARuntimeRegressionToolKind = (
    rrtkPrepareSave,
    rrtkSave,
    rrtkRevert,
    rrtkList,
    rrtkPrepareScenario
  );

  TRadIARuntimeRegressionTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FDebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FKind: TRadIARuntimeRegressionToolKind;
    FRegression: IRadIARuntimeRegressionCoordinator;
    FScenarioCoordinator: IRadIARuntimeScenarioCoordinator;
    function ExecutePrepareSave(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecutePrepareScenario(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteSingleId(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIARuntimeRegressionToolKind;
      const ARegression: IRadIARuntimeRegressionCoordinator;
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
  CPrepareSaveInputSchema =
    '{"type":"object","required":["regressionId","scenario"],' +
    '"properties":{"regressionId":{"type":"string","minLength":3,' +
    '"maxLength":64},"scenario":{"type":"object"}},' +
    '"additionalProperties":false}';
  CPreviewIdInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string","minLength":32,"maxLength":32}},' +
    '"additionalProperties":false}';
  CApplicationIdInputSchema =
    '{"type":"object","required":["applicationId"],"properties":{' +
    '"applicationId":{"type":"string","minLength":32,"maxLength":32}},' +
    '"additionalProperties":false}';
  CRegressionIdInputSchema =
    '{"type":"object","required":["regressionId"],"properties":{' +
    '"regressionId":{"type":"string","minLength":3,"maxLength":64}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

function ScenarioIsReplayable(
  const AScenario: TRadIARuntimeScenario
): Boolean;
var
  LAction: TRadIARuntimeScenarioAction;
begin
  Result := True;
  for LAction in AScenario.Actions do
    if (LAction.Kind <> rakWait) and
      (
        (LAction.Selector.AutomationId <> '') or
        not LAction.Selector.HasReplayableIdentity
      ) then
      Exit(False);
end;

function PreviewJson(
  const APreview: TRadIARuntimeScenarioPreview;
  const ARegressionId: string
): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('regressionId', ARegressionId);
    LRoot.AddPair('previewId', APreview.PreviewId);
    LRoot.AddPair('fingerprint', APreview.Fingerprint);
    LRoot.AddPair('name', APreview.Name);
    LRoot.AddPair(
      'actionCount',
      TJSONNumber.Create(APreview.ActionCount)
    );
    LRoot.AddPair(
      'repetitions',
      TJSONNumber.Create(APreview.Repetitions)
    );
    LRoot.AddPair('consentRequired', TJSONBool.Create(True));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

{ TRadIARuntimeRegressionTool }

constructor TRadIARuntimeRegressionTool.Create(
  const AKind: TRadIARuntimeRegressionToolKind;
  const ARegression: IRadIARuntimeRegressionCoordinator;
  const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator
);
begin
  inherited Create;
  if not Assigned(ARegression) then
    raise EArgumentNilException.Create('ARegression');
  if not Assigned(ADebugCoordinator) then
    raise EArgumentNilException.Create('ADebugCoordinator');
  if not Assigned(AScenarioCoordinator) then
    raise EArgumentNilException.Create('AScenarioCoordinator');
  FKind := AKind;
  FRegression := ARegression;
  FDebugCoordinator := ADebugCoordinator;
  FScenarioCoordinator := AScenarioCoordinator;
end;

function TRadIARuntimeRegressionTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  try
    case FKind of
      rrtkPrepareSave:
        Result := ExecutePrepareSave(ARequest);
      rrtkSave,
      rrtkRevert:
        Result := ExecuteSingleId(ARequest);
      rrtkList:
        Result := TRadIAToolResult.Succeeded(FRegression.List);
      rrtkPrepareScenario:
        Result := ExecutePrepareScenario(ARequest);
    else
      Result := TRadIAToolResult.Failed(
        'unsupported_tool',
        'Runtime regression tool kind is unsupported.'
      );
    end;
  except
    on E: EArgumentException do
      Result := TRadIAToolResult.Failed(
        'invalid_runtime_regression',
        E.Message
      );
    on E: EInvalidOp do
      Result := TRadIAToolResult.Failed(
        'runtime_regression_unavailable',
        E.Message
      );
  end;
end;

function TRadIARuntimeRegressionTool.ExecutePrepareSave(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LRegressionId: string;
  LScenario: TRadIARuntimeScenario;
  LScenarioJson: TJSONObject;
  LScenarioValue: TJSONValue;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime regression arguments must be a JSON object.'
    ));
  try
    LRegressionId := LJson.GetValue<string>('regressionId', '');
    LScenarioValue := LJson.GetValue('scenario');
    if not (LScenarioValue is TJSONObject) then
      Exit(TRadIAToolResult.Failed(
        'invalid_runtime_regression',
        'Runtime regression scenario must be a JSON object.'
      ));
    LScenarioJson := TJSONObject(LScenarioValue);
    if not TryParseRadIARuntimeScenarioDefinition(
      LScenarioJson,
      FDebugCoordinator.GetCurrentSession,
      LScenario
    ) or not ScenarioIsReplayable(LScenario) then
      Exit(TRadIAToolResult.Failed(
        'runtime_regression_not_replayable',
        'Every runtime regression target requires a stable selector.'
      ));
    Result := TRadIAToolResult.Succeeded(
      FRegression.Prepare(
        LRegressionId,
        LScenarioJson.ToJSON
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeRegressionTool.ExecutePrepareScenario(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArtifact: TJSONObject;
  LJson: TJSONObject;
  LPreview: TRadIARuntimeScenarioPreview;
  LRegressionId: string;
  LScenario: TRadIARuntimeScenario;
  LScenarioValue: TJSONValue;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime regression arguments must be a JSON object.'
    ));
  try
    LRegressionId := LJson.GetValue<string>('regressionId', '');
    LArtifact := TJSONObject.ParseJSONValue(
      FRegression.Get(LRegressionId)
    ) as TJSONObject;
    if not Assigned(LArtifact) then
      Exit(TRadIAToolResult.Failed(
        'invalid_runtime_regression',
        'Runtime regression artifact is invalid.'
      ));
    try
      LScenarioValue := LArtifact.GetValue('scenario');
      if not TryParseRadIARuntimeScenarioDefinition(
        LScenarioValue,
        FDebugCoordinator.GetCurrentSession,
        LScenario
      ) then
        Exit(TRadIAToolResult.Failed(
          'invalid_runtime_regression',
          'Runtime regression scenario is invalid.'
        ));
      LPreview := FScenarioCoordinator.Prepare(LScenario);
      Result := TRadIAToolResult.Succeeded(
        PreviewJson(LPreview, LRegressionId)
      );
    finally
      LArtifact.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeRegressionTool.ExecuteSingleId(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LId: string;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime regression arguments must be a JSON object.'
    ));
  try
    if FKind = rrtkSave then
    begin
      LId := LJson.GetValue<string>('previewId', '');
      Result := TRadIAToolResult.Succeeded(FRegression.Apply(LId));
    end
    else
    begin
      LId := LJson.GetValue<string>('applicationId', '');
      Result := TRadIAToolResult.Succeeded(FRegression.Revert(LId));
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeRegressionTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    rrtkPrepareSave:
      Result := TRadIAToolDescriptor.Create(
        'PrepareRuntimeRegression',
        '1.0.0',
        'Validate a replayable visual scenario and preview its artifact.',
        CPrepareSaveInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    rrtkSave:
      Result := TRadIAToolDescriptor.Create(
        'SaveRuntimeRegression',
        '1.0.0',
        'Save the reviewed runtime regression under the active project.',
        CPreviewIdInputSchema,
        CObjectOutputSchema,
        trReversibleWrite
      );
    rrtkRevert:
      Result := TRadIAToolDescriptor.Create(
        'RevertRuntimeRegression',
        '1.0.0',
        'Restore or remove the artifact written by a regression save.',
        CApplicationIdInputSchema,
        CObjectOutputSchema,
        trReversibleWrite
      );
    rrtkList:
      Result := TRadIAToolDescriptor.Create(
        'ListRuntimeRegressions',
        '1.0.0',
        'List versioned visual regressions in the active project.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    rrtkPrepareScenario:
      Result := TRadIAToolDescriptor.Create(
        'PrepareSavedRuntimeScenario',
        '1.0.0',
        'Load a saved regression and prepare it for the current session.',
        CRegressionIdInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  end;
end;

procedure RegisterRadIARuntimeRegressionTools(
  const ARegistry: IRadIAToolRegistry;
  const ARegression: IRadIARuntimeRegressionCoordinator;
  const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator
);
var
  LKind: TRadIARuntimeRegressionToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  for LKind := Low(TRadIARuntimeRegressionToolKind) to
    High(TRadIARuntimeRegressionToolKind) do
    ARegistry.RegisterTool(
      TRadIARuntimeRegressionTool.Create(
        LKind,
        ARegression,
        ADebugCoordinator,
        AScenarioCoordinator
      )
    );
end;

end.
