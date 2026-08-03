unit RadIA.Tests.DebuggerControlTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Debugger,
  RadIA.Core.Tools;

type
  TRadIAFakeDebuggerControlFacade = class(
    TInterfacedObject,
    IRadIADebuggerControlFacade
  )
  private
    FAccept: Boolean;
    FLastAction: TRadIADebuggerAction;
  public
    function ExecuteAction(
      const AAction: TRadIADebuggerAction
    ): TRadIADebuggerActionResult;
    property Accept: Boolean read FAccept write FAccept;
    property LastAction: TRadIADebuggerAction read FLastAction;
  end;

  [TestFixture]
  TTestRadIADebuggerControlTools = class
  private
    FExecutor: IRadIAToolExecutor;
    FFacade: TRadIAFakeDebuggerControlFacade;
    FRegistry: IRadIAToolRegistry;
    function ExecuteTool(
      const AName: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RegistersExecutionTools;
    [Test]
    procedure ExecutesDebuggerAction;
    [Test]
    procedure ReturnsStructuredFailure;
  end;

implementation

uses
  RadIA.Core.DebuggerControlTools,
  RadIA.Core.ToolRegistry;

{ TRadIAFakeDebuggerControlFacade }

function TRadIAFakeDebuggerControlFacade.ExecuteAction(
  const AAction: TRadIADebuggerAction
): TRadIADebuggerActionResult;
begin
  FLastAction := AAction;
  if not FAccept then
    Exit(TRadIADebuggerActionResult.Failed(
      'invalid_debugger_state',
      'The requested action is not available.',
      'running'
    ));
  Result := TRadIADebuggerActionResult.Succeeded(
    'Action accepted.',
    'stopped',
    'running'
  );
end;

{ TTestRadIADebuggerControlTools }

function TTestRadIADebuggerControlTools.ExecuteTool(
  const AName: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      '{}',
      'debugger-control-test'
    )
  );
end;

procedure TTestRadIADebuggerControlTools.ExecutesDebuggerAction;
var
  LResult: TRadIAToolResult;
begin
  FFacade.Accept := True;

  LResult := ExecuteTool('StepOver');

  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(daStepOver, FFacade.LastAction);
  Assert.Contains(LResult.ContentJson, '"accepted":true');
  Assert.Contains(LResult.ContentJson, '"stateBefore":"stopped"');
  Assert.Contains(LResult.ContentJson, '"stateAfter":"running"');
end;

procedure TTestRadIADebuggerControlTools.RegistersExecutionTools;
var
  LDescriptor: TRadIAToolDescriptor;
  LNames: TArray<string>;
  LName: string;
begin
  LNames := [
    'PauseDebugging',
    'ContinueDebugging',
    'StepInto',
    'StepOver',
    'StepOut',
    'StopDebugging'
  ];
  Assert.AreEqual(Integer(Length(LNames)), FRegistry.Count);
  for LName in LNames do
  begin
    LDescriptor := FRegistry.Resolve(LName).Descriptor;
    if LName = 'StopDebugging' then
      Assert.AreEqual(trDestructive, LDescriptor.Risk)
    else
      Assert.AreEqual(trExecution, LDescriptor.Risk);
    Assert.IsFalse(LDescriptor.Idempotent);
  end;
end;

procedure TTestRadIADebuggerControlTools.ReturnsStructuredFailure;
var
  LResult: TRadIAToolResult;
begin
  FFacade.Accept := False;

  LResult := ExecuteTool('PauseDebugging');

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_debugger_state', LResult.ErrorCode);
end;

procedure TTestRadIADebuggerControlTools.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
  FFacade := TRadIAFakeDebuggerControlFacade.Create;
  RegisterRadIADebuggerControlTools(FRegistry, FFacade);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADebuggerControlTools);

end.
