unit RadIA.Tests.DebuggerTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Debugger,
  RadIA.Core.Tools;

type
  TRadIAFakeDebuggerFacade = class(
    TInterfacedObject,
    IRadIADebuggerFacade
  )
  public
    function GetDebuggerState: TRadIADebuggerSnapshot;
    function ListBreakpoints(
      const AMaxCount: Integer
    ): TArray<TRadIABreakpointSnapshot>;
    function GetCallStack(
      const AMaxCount: Integer
    ): TRadIACallStackSnapshot;
  end;

  [TestFixture]
  TTestRadIADebuggerTools = class
  private
    FExecutor: IRadIAToolExecutor;
    FRegistry: IRadIAToolRegistry;
    function ExecuteTool(
      const AName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RegistersReadOnlyTools;
    [Test]
    procedure GetsDebuggerState;
    [Test]
    procedure ListsBreakpoints;
    [Test]
    procedure RejectsInvalidBreakpointLimit;
    [Test]
    procedure GetsCallStack;
  end;

implementation

uses
  RadIA.Core.DebuggerTools,
  RadIA.Core.ToolRegistry;

{ TRadIAFakeDebuggerFacade }

function TRadIAFakeDebuggerFacade.GetCallStack(
  const AMaxCount: Integer
): TRadIACallStackSnapshot;
var
  LFrames: TArray<TRadIACallStackFrame>;
begin
  if AMaxCount <= 0 then
    Exit(TRadIACallStackSnapshot.Create(False, 'invalid_limit', nil));
  LFrames := [
    TRadIACallStackFrame.Create(
      1,
      'Sample.Unit.TWorker.Execute',
      'C:\Sample\Sample.Unit.pas',
      42
    ),
    TRadIACallStackFrame.Create(
      2,
      'System.Classes.ThreadProc',
      '',
      0
    )
  ];
  Result := TRadIACallStackSnapshot.Create(
    True,
    'accessible',
    LFrames
  );
end;

function TRadIAFakeDebuggerFacade.GetDebuggerState:
  TRadIADebuggerSnapshot;
begin
  Result := TRadIADebuggerSnapshot.Create(
    True,
    'stopped',
    10,
    'Sample.exe',
    3,
    1
  );
  Result.SetProcessDetails(
    1234,
    'Sample.Unit.pas:42',
    'Stopped at breakpoint'
  );
end;

function TRadIAFakeDebuggerFacade.ListBreakpoints(
  const AMaxCount: Integer
): TArray<TRadIABreakpointSnapshot>;
begin
  if AMaxCount <= 0 then
    Exit(nil);
  Result := [
    TRadIABreakpointSnapshot.Create(
      'C:\Sample\Sample.Unit.pas',
      42,
      True,
      True
    )
  ];
end;

{ TTestRadIADebuggerTools }

function TTestRadIADebuggerTools.ExecuteTool(
  const AName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      AArgumentsJson,
      'debugger-test'
    )
  );
end;

procedure TTestRadIADebuggerTools.GetsDebuggerState;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('GetDebuggerState', '{}');

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"state":"stopped"');
  Assert.Contains(LResult.ContentJson, '"osProcessId":1234');
  Assert.Contains(LResult.ContentJson, '"threadCount":3');
end;

procedure TTestRadIADebuggerTools.GetsCallStack;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'GetCallStack',
    '{"maxCount":10}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"accessible":true');
  Assert.Contains(LResult.ContentJson, 'TWorker.Execute');
  Assert.Contains(LResult.ContentJson, '"lineNumber":42');
  Assert.Contains(LResult.ContentJson, '"count":2');
end;

procedure TTestRadIADebuggerTools.ListsBreakpoints;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'ListBreakpoints',
    '{"maxCount":10}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'Sample.Unit.pas');
  Assert.Contains(LResult.ContentJson, '"lineNumber":42');
  Assert.Contains(LResult.ContentJson, '"valid":true');
end;

procedure TTestRadIADebuggerTools.RegistersReadOnlyTools;
var
  LDescriptor: TRadIAToolDescriptor;
begin
  Assert.AreEqual(3, FRegistry.Count);
  LDescriptor := FRegistry.Resolve(
    'GetDebuggerState'
  ).Descriptor;
  Assert.AreEqual(trReadOnly, LDescriptor.Risk);
  LDescriptor := FRegistry.Resolve(
    'ListBreakpoints'
  ).Descriptor;
  Assert.AreEqual(trReadOnly, LDescriptor.Risk);
  LDescriptor := FRegistry.Resolve(
    'GetCallStack'
  ).Descriptor;
  Assert.AreEqual(trReadOnly, LDescriptor.Risk);
end;

procedure TTestRadIADebuggerTools.RejectsInvalidBreakpointLimit;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'ListBreakpoints',
    '{"maxCount":0}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('tool_execution_failed', LResult.ErrorCode);
end;

procedure TTestRadIADebuggerTools.Setup;
var
  LDebugger: IRadIADebuggerFacade;
begin
  FRegistry := TRadIAToolRegistry.Create;
  LDebugger := TRadIAFakeDebuggerFacade.Create;
  RegisterRadIADebuggerTools(FRegistry, LDebugger);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADebuggerTools);

end.
