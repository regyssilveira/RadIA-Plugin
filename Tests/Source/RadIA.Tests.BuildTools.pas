unit RadIA.Tests.BuildTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Build,
  RadIA.Core.Tools;

type
  TTestRadIABuildFacade = class(
    TInterfacedObject,
    IRadIABuildFacade
  )
  private
    FCancelResult: Boolean;
    FExecuteCount: Integer;
    FLastRequest: TRadIABuildRequest;
    FResult: TRadIABuildResult;
    FStatus: TRadIABuildStatus;
  public
    function Execute(
      const ARequest: TRadIABuildRequest
    ): TRadIABuildResult;
    function Cancel: Boolean;
    function GetStatus: TRadIABuildStatus;
    property CancelResult: Boolean
      read FCancelResult write FCancelResult;
    property ExecuteCount: Integer read FExecuteCount;
    property LastRequest: TRadIABuildRequest read FLastRequest;
    property BuildResult: TRadIABuildResult
      read FResult write FResult;
    property CurrentStatus: TRadIABuildStatus
      read FStatus write FStatus;
  end;

  [TestFixture]
  TTestRadIABuildTools = class
  private
    FBuildFacade: TTestRadIABuildFacade;
    FRegistry: IRadIAToolRegistry;
    function ExecuteTool(
      const AName: string;
      const AArguments: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure BuildToolDeclaresExecutionRisk;
    [Test]
    procedure BuildToolPassesValidatedRequest;
    [Test]
    procedure BuildToolRejectsInvalidTimeout;
    [Test]
    procedure StatusToolIsReadOnly;
    [Test]
    procedure CancelToolReturnsStructuredResult;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.BuildTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Workspace;

{ TTestRadIABuildFacade }

function TTestRadIABuildFacade.Cancel: Boolean;
begin
  Result := FCancelResult;
end;

function TTestRadIABuildFacade.Execute(
  const ARequest: TRadIABuildRequest
): TRadIABuildResult;
begin
  Inc(FExecuteCount);
  FLastRequest := ARequest;
  Result := FResult;
end;

function TTestRadIABuildFacade.GetStatus: TRadIABuildStatus;
begin
  Result := FStatus;
end;

{ TTestRadIABuildTools }

procedure TTestRadIABuildTools.BuildToolDeclaresExecutionRisk;
var
  LTool: IRadIATool;
begin
  LTool := FRegistry.Resolve('BuildProject');

  Assert.AreEqual(trExecution, LTool.Descriptor.Risk);
  Assert.IsFalse(LTool.Descriptor.Idempotent);
  Assert.AreEqual(Cardinal(600000), LTool.Descriptor.TimeoutMs);
end;

procedure TTestRadIABuildTools.BuildToolPassesValidatedRequest;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'BuildProject',
    '{"mode":"check","timeoutMs":45000,"clearMessages":false}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(1, FBuildFacade.ExecuteCount);
  Assert.AreEqual(bmCheck, FBuildFacade.LastRequest.Mode);
  Assert.AreEqual(
    Cardinal(45000),
    FBuildFacade.LastRequest.TimeoutMs
  );
  Assert.IsFalse(FBuildFacade.LastRequest.ClearMessages);
  Assert.Contains(LResult.ContentJson, '"status":"succeeded"');
end;

procedure TTestRadIABuildTools.BuildToolRejectsInvalidTimeout;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'BuildProject',
    '{"mode":"build","timeoutMs":10}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_request', LResult.ErrorCode);
  Assert.AreEqual(0, FBuildFacade.ExecuteCount);
end;

procedure TTestRadIABuildTools.CancelToolReturnsStructuredResult;
var
  LResult: TRadIAToolResult;
begin
  FBuildFacade.CancelResult := True;

  LResult := ExecuteTool('CancelBuild', '{}');

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"cancelRequested":true');
end;

function TTestRadIABuildTools.ExecuteTool(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
var
  LExecutor: IRadIAToolExecutor;
begin
  LExecutor := TRadIAToolExecutor.Create(FRegistry);
  Result := LExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      AArguments,
      TGUID.NewGuid.ToString
    )
  );
end;

procedure TTestRadIABuildTools.Setup;
var
  LProject: TRadIAProjectSnapshot;
begin
  FBuildFacade := TTestRadIABuildFacade.Create;
  LProject := TRadIAProjectSnapshot.Create(
    'ProjectOne',
    'C:\Project\ProjectOne.dproj',
    'C:\Project',
    'Debug',
    'Win32'
  );
  FBuildFacade.BuildResult := TRadIABuildResult.Completed(
    bsSucceeded,
    LProject,
    250,
    []
  );
  FBuildFacade.CurrentStatus := bsIdle;
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIABuildTools(FRegistry, FBuildFacade);
end;

procedure TTestRadIABuildTools.StatusToolIsReadOnly;
var
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  LTool := FRegistry.Resolve('GetBuildStatus');
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);

  FBuildFacade.CurrentStatus := bsRunning;
  LResult := ExecuteTool('GetBuildStatus', '{}');
  Assert.Contains(LResult.ContentJson, '"status":"running"');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIABuildTools);

end.
