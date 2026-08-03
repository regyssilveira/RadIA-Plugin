unit RadIA.Core.DebuggerControlTools;

interface

uses
  RadIA.Core.Debugger,
  RadIA.Core.Tools;

procedure RegisterRadIADebuggerControlTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugger: IRadIADebuggerControlFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIADebuggerControlTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FAction: TRadIADebuggerAction;
    FDebugger: IRadIADebuggerControlFacade;
    function ActionDescription: string;
    function ActionName: string;
    function GetDescriptor: TRadIAToolDescriptor;
  public
    constructor Create(
      const AAction: TRadIADebuggerAction;
      const ADebugger: IRadIADebuggerControlFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["accepted","message","stateBefore","stateAfter"],' +
    '"properties":{"accepted":{"type":"boolean"},"message":{"type":"string"},' +
    '"stateBefore":{"type":"string"},"stateAfter":{"type":"string"}}}';

procedure RegisterRadIADebuggerControlTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugger: IRadIADebuggerControlFacade
);
var
  LAction: TRadIADebuggerAction;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');

  for LAction := Low(TRadIADebuggerAction) to
    High(TRadIADebuggerAction) do
    ARegistry.RegisterTool(
      TRadIADebuggerControlTool.Create(LAction, ADebugger)
    );
end;

{ TRadIADebuggerControlTool }

function TRadIADebuggerControlTool.ActionDescription: string;
begin
  case FAction of
    daPause:
      Result := 'Pauses the current debug process.';
    daContinue:
      Result := 'Continues the current stopped debug process.';
    daStepInto:
      Result := 'Executes the next source statement and steps into calls.';
    daStepOver:
      Result := 'Executes the next source statement without entering calls.';
    daStepOut:
      Result := 'Continues until the current routine returns.';
    daStop:
      Result := 'Terminates the current debug process.';
  else
    Result := 'Controls the current debug process.';
  end;
end;

function TRadIADebuggerControlTool.ActionName: string;
begin
  case FAction of
    daPause:
      Result := 'PauseDebugging';
    daContinue:
      Result := 'ContinueDebugging';
    daStepInto:
      Result := 'StepInto';
    daStepOver:
      Result := 'StepOver';
    daStepOut:
      Result := 'StepOut';
    daStop:
      Result := 'StopDebugging';
  else
    Result := '';
  end;
end;

constructor TRadIADebuggerControlTool.Create(
  const AAction: TRadIADebuggerAction;
  const ADebugger: IRadIADebuggerControlFacade
);
begin
  inherited Create;
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');
  FAction := AAction;
  FDebugger := ADebugger;
end;

function TRadIADebuggerControlTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LActionResult: TRadIADebuggerActionResult;
  LJson: TJSONObject;
begin
  LActionResult := FDebugger.ExecuteAction(FAction);
  if not LActionResult.Accepted then
    Exit(TRadIAToolResult.Failed(
      LActionResult.ErrorCode,
      LActionResult.Message
    ));

  LJson := TJSONObject.Create;
  try
    LJson.AddPair(
      'accepted',
      TJSONBool.Create(LActionResult.Accepted)
    );
    LJson.AddPair('message', LActionResult.Message);
    LJson.AddPair('stateBefore', LActionResult.StateBefore);
    LJson.AddPair('stateAfter', LActionResult.StateAfter);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIADebuggerControlTool.GetDescriptor:
  TRadIAToolDescriptor;
var
  LRisk: TRadIAToolRisk;
begin
  if FAction = daStop then
    LRisk := trDestructive
  else
    LRisk := trExecution;
  Result := TRadIAToolDescriptor.Create(
    ActionName,
    '1.0',
    ActionDescription,
    CEmptyInputSchema,
    COutputSchema,
    LRisk
  ).WithExecutionOptions(10000, False);
end;

end.
