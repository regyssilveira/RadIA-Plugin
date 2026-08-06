unit RadIA.Core.DeclarativeTools;

interface

uses
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.Tools;

type
  TRadIADeclarativeToolBinder = class
  private
    FRegistry: IRadIAToolRegistry;
    FExecutor: IRadIAToolExecutor;
    FRegisteredNames: TArray<string>;
    FRegisteredTools: TArray<IRadIATool>;
    function BuildTools(
      const ADefinitions: TArray<TRadIADeclarativeTool>;
      const AWorkflows: TArray<TRadIADeclarativeWorkflow>
    ): TArray<IRadIATool>;
  public
    constructor Create(
      const ARegistry: IRadIAToolRegistry;
      const AExecutor: IRadIAToolExecutor
    );
    destructor Destroy; override;
    procedure Reload(
      const ADefinitions: TArray<TRadIADeclarativeTool>;
      const AWorkflows: TArray<TRadIADeclarativeWorkflow>
    );
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.JSON,
  System.Math,
  System.SysUtils;

type
  TRadIADeclarativeAliasTool = class(TInterfacedObject, IRadIATool)
  private
    FDescriptor: TRadIAToolDescriptor;
    FTarget: IRadIATool;
    FTargetName: string;
  public
    constructor Create(
      const ADefinition: TRadIADeclarativeTool;
      const ATarget: IRadIATool
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIADeclarativeWorkflowTool = class(TInterfacedObject, IRadIATool)
  private
    FDescriptor: TRadIAToolDescriptor;
    FExecutor: IRadIAToolExecutor;
    FSteps: TArray<TRadIADeclarativeWorkflowStep>;
  public
    constructor Create(
      const ADefinition: TRadIADeclarativeWorkflow;
      const ADescriptors: TArray<TRadIAToolDescriptor>;
      const AExecutor: IRadIAToolExecutor
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

{ TRadIADeclarativeAliasTool }

constructor TRadIADeclarativeAliasTool.Create(
  const ADefinition: TRadIADeclarativeTool;
  const ATarget: IRadIATool
);
var
  LTargetDescriptor: TRadIAToolDescriptor;
begin
  inherited Create;
  FTarget := ATarget;
  FTargetName := ADefinition.TargetTool;
  LTargetDescriptor := ATarget.Descriptor;
  FDescriptor := TRadIAToolDescriptor.Create(
    ADefinition.Name,
    LTargetDescriptor.Version,
    ADefinition.Description,
    LTargetDescriptor.InputSchema,
    LTargetDescriptor.OutputSchema,
    LTargetDescriptor.Risk
  ).WithExecutionOptions(
    LTargetDescriptor.TimeoutMs,
    LTargetDescriptor.Idempotent
  );
end;

function TRadIADeclarativeAliasTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LTargetRequest: TRadIAToolRequest;
begin
  LTargetRequest := TRadIAToolRequest.Create(
    FTargetName,
    ARequest.ArgumentsJson,
    ARequest.CorrelationId,
    ARequest.Origin,
    ARequest.SessionId,
    ARequest.ProjectId,
    ARequest.Scope
  ).WithCancellation(ARequest.CancellationToken);
  Result := FTarget.Execute(LTargetRequest);
end;

function TRadIADeclarativeAliasTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := FDescriptor;
end;

{ TRadIADeclarativeWorkflowTool }

constructor TRadIADeclarativeWorkflowTool.Create(
  const ADefinition: TRadIADeclarativeWorkflow;
  const ADescriptors: TArray<TRadIAToolDescriptor>;
  const AExecutor: IRadIAToolExecutor
);
var
  LDescriptor: TRadIAToolDescriptor;
  LIdempotent: Boolean;
  LRisk: TRadIAToolRisk;
  LTimeoutMs: UInt64;
begin
  inherited Create;
  if not Assigned(AExecutor) then
    raise EArgumentNilException.Create('AExecutor');
  if Length(ADefinition.Steps) <> Length(ADescriptors) then
    raise EArgumentException.Create(
      'Workflow steps and descriptors must have the same length.'
    );
  FExecutor := AExecutor;
  FSteps := Copy(ADefinition.Steps);
  LRisk := trReadOnly;
  LIdempotent := True;
  LTimeoutMs := 0;
  for LDescriptor in ADescriptors do
  begin
    if Ord(LDescriptor.Risk) > Ord(LRisk) then
      LRisk := LDescriptor.Risk;
    LIdempotent := LIdempotent and LDescriptor.Idempotent;
    Inc(LTimeoutMs, LDescriptor.TimeoutMs);
  end;
  LTimeoutMs := Min(LTimeoutMs, UInt64(600000));
  FDescriptor := TRadIAToolDescriptor.Create(
    ADefinition.Name,
    '1.0.0',
    ADefinition.Description,
    '{"type":"object","additionalProperties":false}',
    '{"type":"object","required":["steps"],' +
      '"properties":{"steps":{"type":"array"}}}',
    LRisk
  ).WithExecutionOptions(
    Cardinal(LTimeoutMs),
    LIdempotent
  );
end;

function TRadIADeclarativeWorkflowTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
const
  CMaximumResultCharacters = 524288;
var
  LContent: TJSONValue;
  LIndex: Integer;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
  LResultCharacters: Integer;
  LRoot: TJSONObject;
  LStepJson: TJSONObject;
  LStepsJson: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LStepsJson := TJSONArray.Create;
    LRoot.AddPair('steps', LStepsJson);
    LResultCharacters := 0;
    for LIndex := Low(FSteps) to High(FSteps) do
    begin
      LRequest := TRadIAToolRequest.Create(
        FSteps[LIndex].TargetTool,
        FSteps[LIndex].ArgumentsJson,
        ARequest.CorrelationId + '.workflow.' + IntToStr(LIndex + 1),
        ARequest.Origin,
        ARequest.SessionId,
        ARequest.ProjectId,
        ARequest.Scope
      ).WithCancellation(ARequest.CancellationToken);
      LResult := FExecutor.Execute(LRequest);
      if not LResult.Success then
        Exit(
          TRadIAToolResult.Failed(
            'workflow_step_failed',
            Format(
              'Workflow step %d (%s) failed [%s]: %s',
              [
                LIndex + 1,
                FSteps[LIndex].TargetTool,
                LResult.ErrorCode,
                LResult.ErrorMessage
              ]
            )
          )
        );
      Inc(LResultCharacters, Length(LResult.ContentJson));
      if LResultCharacters > CMaximumResultCharacters then
        Exit(
          TRadIAToolResult.Failed(
            'workflow_result_limit',
            'Workflow results exceed the 1 MiB UTF-16 limit.'
          )
        );
      LStepJson := TJSONObject.Create;
      LStepJson.AddPair('index', TJSONNumber.Create(LIndex + 1));
      LStepJson.AddPair('tool', FSteps[LIndex].TargetTool);
      LContent := TJSONObject.ParseJSONValue(LResult.ContentJson);
      if Assigned(LContent) then
        LStepJson.AddPair('result', LContent)
      else
        LStepJson.AddPair('resultText', LResult.ContentJson);
      LStepsJson.AddElement(LStepJson);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIADeclarativeWorkflowTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := FDescriptor;
end;

{ TRadIADeclarativeToolBinder }

function TRadIADeclarativeToolBinder.BuildTools(
  const ADefinitions: TArray<TRadIADeclarativeTool>;
  const AWorkflows: TArray<TRadIADeclarativeWorkflow>
): TArray<IRadIATool>;
var
  LCurrentNames: TDictionary<string, Byte>;
  LDefinition: TRadIADeclarativeTool;
  LDefinitionsByName: TDictionary<string, Byte>;
  LDescriptors: TArray<TRadIAToolDescriptor>;
  LIndex: Integer;
  LRegisteredName: string;
  LStepIndex: Integer;
  LTarget: IRadIATool;
  LWorkflow: TRadIADeclarativeWorkflow;
begin
  LCurrentNames := TDictionary<string, Byte>.Create(
    TIStringComparer.Ordinal
  );
  LDefinitionsByName := TDictionary<string, Byte>.Create(
    TIStringComparer.Ordinal
  );
  try
    for LRegisteredName in FRegisteredNames do
      LCurrentNames.AddOrSetValue(LRegisteredName, 0);
    for LDefinition in ADefinitions do
    begin
      if LDefinitionsByName.ContainsKey(LDefinition.Name) then
        raise EArgumentException.Create(
          'Declarative tool name is duplicated across extensions.'
        );
      LDefinitionsByName.Add(LDefinition.Name, 0);
    end;
    for LWorkflow in AWorkflows do
    begin
      if LDefinitionsByName.ContainsKey(LWorkflow.Name) then
        raise EArgumentException.Create(
          'Declarative capability name is duplicated across extensions.'
        );
      LDefinitionsByName.Add(LWorkflow.Name, 0);
    end;
    SetLength(Result, Length(ADefinitions) + Length(AWorkflows));
    for LIndex := Low(ADefinitions) to High(ADefinitions) do
    begin
      LDefinition := ADefinitions[LIndex];
      if LDefinitionsByName.ContainsKey(LDefinition.TargetTool) or
        LCurrentNames.ContainsKey(LDefinition.TargetTool) then
        raise EArgumentException.Create(
          'Declarative tools cannot target another declarative tool.'
        );
      if not FRegistry.TryResolve(LDefinition.TargetTool, LTarget) then
        raise EArgumentException.CreateFmt(
          'Declarative target tool "%s" is not registered.',
          [LDefinition.TargetTool]
        );
      Result[LIndex] := TRadIADeclarativeAliasTool.Create(
        LDefinition,
        LTarget
      );
    end;
    for LIndex := Low(AWorkflows) to High(AWorkflows) do
    begin
      LWorkflow := AWorkflows[LIndex];
      SetLength(LDescriptors, Length(LWorkflow.Steps));
      for LStepIndex := Low(LWorkflow.Steps) to
        High(LWorkflow.Steps) do
      begin
        if LDefinitionsByName.ContainsKey(
          LWorkflow.Steps[LStepIndex].TargetTool
        ) or LCurrentNames.ContainsKey(
          LWorkflow.Steps[LStepIndex].TargetTool
        ) then
          raise EArgumentException.Create(
            'Declarative workflows cannot target declarative tools.'
          );
        if not FRegistry.TryResolve(
          LWorkflow.Steps[LStepIndex].TargetTool,
          LTarget
        ) then
          raise EArgumentException.CreateFmt(
            'Workflow target tool "%s" is not registered.',
            [LWorkflow.Steps[LStepIndex].TargetTool]
          );
        LDescriptors[LStepIndex] := LTarget.Descriptor;
      end;
      Result[Length(ADefinitions) + LIndex] :=
        TRadIADeclarativeWorkflowTool.Create(
          LWorkflow,
          LDescriptors,
          FExecutor
        );
    end;
  finally
    LDefinitionsByName.Free;
    LCurrentNames.Free;
  end;
end;

constructor TRadIADeclarativeToolBinder.Create(
  const ARegistry: IRadIAToolRegistry;
  const AExecutor: IRadIAToolExecutor
);
begin
  inherited Create;
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AExecutor) then
    raise EArgumentNilException.Create('AExecutor');
  FRegistry := ARegistry;
  FExecutor := AExecutor;
end;

destructor TRadIADeclarativeToolBinder.Destroy;
begin
  FRegistry.UnregisterTools(FRegisteredNames);
  FRegisteredTools := nil;
  FRegisteredNames := nil;
  FExecutor := nil;
  FRegistry := nil;
  inherited Destroy;
end;

procedure TRadIADeclarativeToolBinder.Reload(
  const ADefinitions: TArray<TRadIADeclarativeTool>;
  const AWorkflows: TArray<TRadIADeclarativeWorkflow>
);
var
  LIndex: Integer;
  LNewNames: TArray<string>;
  LNewTools: TArray<IRadIATool>;
begin
  LNewTools := BuildTools(ADefinitions, AWorkflows);
  SetLength(LNewNames, Length(LNewTools));
  for LIndex := Low(LNewTools) to High(LNewTools) do
    LNewNames[LIndex] := LNewTools[LIndex].Descriptor.Name;

  FRegistry.UnregisterTools(FRegisteredNames);
  try
    FRegistry.RegisterTools(LNewTools);
  except
    FRegistry.RegisterTools(FRegisteredTools);
    raise;
  end;
  FRegisteredTools := LNewTools;
  FRegisteredNames := LNewNames;
end;

end.
