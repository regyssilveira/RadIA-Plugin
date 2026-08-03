unit RadIA.Tests.DebuggerBreakpointTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Debugger,
  RadIA.Core.Tools;

type
  TRadIAFakeDebuggerBreakpointFacade = class(
    TInterfacedObject,
    IRadIADebuggerBreakpointFacade
  )
  private
    FExists: Boolean;
  public
    function HasSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function AddSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function RemoveSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    property Exists: Boolean read FExists write FExists;
  end;

  [TestFixture]
  TTestRadIADebuggerBreakpointTools = class
  private
    FDebugger: TRadIAFakeDebuggerBreakpointFacade;
    FExecutor: IRadIAToolExecutor;
    FRegistry: IRadIAToolRegistry;
    function ExecuteTool(
      const AName: string;
      const AFileName: string;
      const ALineNumber: Integer
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RegistersRiskLevels;
    [Test]
    procedure AddsAndRemovesBreakpoint;
    [Test]
    procedure RejectsDuplicateBreakpoint;
    [Test]
    procedure RejectsOutsideWorkspace;
    [Test]
    procedure RejectsUnsupportedFile;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DebuggerBreakpointTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary,
  RadIA.Tests.WorkspaceTools;

{ TRadIAFakeDebuggerBreakpointFacade }

function TRadIAFakeDebuggerBreakpointFacade.AddSourceBreakpoint(
  const AFileName: string;
  const ALineNumber: Integer
): Boolean;
begin
  Result := SameText(AFileName, 'C:\Sample\Sample.Unit.pas') and
    (ALineNumber = 42) and
    not FExists;
  if Result then
    FExists := True;
end;

function TRadIAFakeDebuggerBreakpointFacade.HasSourceBreakpoint(
  const AFileName: string;
  const ALineNumber: Integer
): Boolean;
begin
  Result := SameText(AFileName, 'C:\Sample\Sample.Unit.pas') and
    (ALineNumber = 42) and
    FExists;
end;

function TRadIAFakeDebuggerBreakpointFacade.RemoveSourceBreakpoint(
  const AFileName: string;
  const ALineNumber: Integer
): Boolean;
begin
  Result := HasSourceBreakpoint(AFileName, ALineNumber);
  if Result then
    FExists := False;
end;

{ TTestRadIADebuggerBreakpointTools }

procedure TTestRadIADebuggerBreakpointTools.AddsAndRemovesBreakpoint;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'AddBreakpoint',
    'C:\Sample\Sample.Unit.pas',
    42
  );
  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(FDebugger.Exists);
  Assert.Contains(LResult.ContentJson, '"inverseTool":"RemoveBreakpoint"');

  LResult := ExecuteTool(
    'RemoveBreakpoint',
    'C:\Sample\Sample.Unit.pas',
    42
  );
  Assert.IsTrue(LResult.Success);
  Assert.IsFalse(FDebugger.Exists);
end;

function TTestRadIADebuggerBreakpointTools.ExecuteTool(
  const AName: string;
  const AFileName: string;
  const ALineNumber: Integer
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      Format(
        '{"fileName":"%s","lineNumber":%d}',
        [StringReplace(AFileName, '\', '\\', [rfReplaceAll]), ALineNumber]
      ),
      'debugger-breakpoint-test'
    )
  );
end;

procedure TTestRadIADebuggerBreakpointTools.RegistersRiskLevels;
begin
  Assert.AreEqual(2, FRegistry.Count);
  Assert.AreEqual(
    trReversibleWrite,
    FRegistry.Resolve('AddBreakpoint').Descriptor.Risk
  );
  Assert.AreEqual(
    trDestructive,
    FRegistry.Resolve('RemoveBreakpoint').Descriptor.Risk
  );
end;

procedure TTestRadIADebuggerBreakpointTools.RejectsDuplicateBreakpoint;
var
  LResult: TRadIAToolResult;
begin
  FDebugger.Exists := True;

  LResult := ExecuteTool(
    'AddBreakpoint',
    'C:\Sample\Sample.Unit.pas',
    42
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('breakpoint_exists', LResult.ErrorCode);
end;

procedure TTestRadIADebuggerBreakpointTools.RejectsOutsideWorkspace;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'AddBreakpoint',
    'D:\External\Sample.Unit.pas',
    42
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
end;

procedure TTestRadIADebuggerBreakpointTools.RejectsUnsupportedFile;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'AddBreakpoint',
    'C:\Sample\Readme.txt',
    42
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('unsupported_source_file', LResult.ErrorCode);
end;

procedure TTestRadIADebuggerBreakpointTools.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
  FDebugger := TRadIAFakeDebuggerBreakpointFacade.Create;
  RegisterRadIADebuggerBreakpointTools(
    FRegistry,
    FDebugger,
    TRadIAFakeWorkspaceFacade.Create,
    TRadIAWorkspaceBoundary.Create
  );
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADebuggerBreakpointTools);

end.
