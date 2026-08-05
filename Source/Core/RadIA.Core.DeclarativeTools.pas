unit RadIA.Core.DeclarativeTools;

interface

uses
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.Tools;

type
  TRadIADeclarativeToolBinder = class
  private
    FRegistry: IRadIAToolRegistry;
    FRegisteredNames: TArray<string>;
    FRegisteredTools: TArray<IRadIATool>;
    function BuildTools(
      const ADefinitions: TArray<TRadIADeclarativeTool>
    ): TArray<IRadIATool>;
  public
    constructor Create(const ARegistry: IRadIAToolRegistry);
    destructor Destroy; override;
    procedure Reload(
      const ADefinitions: TArray<TRadIADeclarativeTool>
    );
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
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

{ TRadIADeclarativeToolBinder }

function TRadIADeclarativeToolBinder.BuildTools(
  const ADefinitions: TArray<TRadIADeclarativeTool>
): TArray<IRadIATool>;
var
  LDefinition: TRadIADeclarativeTool;
  LDefinitionsByName: TDictionary<string, Byte>;
  LIndex: Integer;
  LTarget: IRadIATool;
begin
  LDefinitionsByName := TDictionary<string, Byte>.Create(
    TIStringComparer.Ordinal
  );
  try
    for LDefinition in ADefinitions do
    begin
      if LDefinitionsByName.ContainsKey(LDefinition.Name) then
        raise EArgumentException.Create(
          'Declarative tool name is duplicated across extensions.'
        );
      LDefinitionsByName.Add(LDefinition.Name, 0);
    end;
    SetLength(Result, Length(ADefinitions));
    for LIndex := Low(ADefinitions) to High(ADefinitions) do
    begin
      LDefinition := ADefinitions[LIndex];
      if LDefinitionsByName.ContainsKey(LDefinition.TargetTool) then
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
  finally
    LDefinitionsByName.Free;
  end;
end;

constructor TRadIADeclarativeToolBinder.Create(
  const ARegistry: IRadIAToolRegistry
);
begin
  inherited Create;
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  FRegistry := ARegistry;
end;

destructor TRadIADeclarativeToolBinder.Destroy;
begin
  FRegistry.UnregisterTools(FRegisteredNames);
  FRegisteredTools := nil;
  FRegisteredNames := nil;
  FRegistry := nil;
  inherited Destroy;
end;

procedure TRadIADeclarativeToolBinder.Reload(
  const ADefinitions: TArray<TRadIADeclarativeTool>
);
var
  LIndex: Integer;
  LNewNames: TArray<string>;
  LNewTools: TArray<IRadIATool>;
begin
  LNewTools := BuildTools(ADefinitions);
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
