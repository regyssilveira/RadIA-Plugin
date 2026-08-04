unit RadIA.Tests.ToolRegistry;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Tools;

type
  TRadIAMockTool = class(TInterfacedObject, IRadIATool)
  private
    FDescriptor: TRadIAToolDescriptor;
    FResult: TRadIAToolResult;
    FRaiseOnExecute: Boolean;
  public
    constructor Create(
      const ADescriptor: TRadIAToolDescriptor;
      const AResult: TRadIAToolResult;
      const ARaiseOnExecute: Boolean = False
    );
    function GetDescriptor: TRadIAToolDescriptor;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

  [TestFixture]
  TTestRadIAToolRegistry = class
  private
    FRegistry: IRadIAToolRegistry;
    function CreateDescriptor(
      const AName: string
    ): TRadIAToolDescriptor;
    function CreateTool(
      const AName: string
    ): IRadIATool;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure TestRegisterAndResolve;
    [Test]
    procedure TestResolveIsCaseInsensitive;
    [Test]
    procedure TestDuplicateNameRaises;
    [Test]
    procedure TestInvalidNameRaises;
    [Test]
    procedure TestInvalidSchemaRaises;
    [Test]
    procedure TestDescriptorsAreSorted;
    [Test]
    procedure TestClearRemovesAllTools;
    [Test]
    procedure TestBatchRegistrationIsAtomic;
    [Test]
    procedure TestBatchUnregisterRemovesOnlyNamedTools;
  end;

  [TestFixture]
  TTestRadIAToolExecutor = class
  private
    FRegistry: IRadIAToolRegistry;
    FExecutor: IRadIAToolExecutor;
    function CreateDescriptor: TRadIAToolDescriptor;
    procedure RegisterTool(
      const AResult: TRadIAToolResult;
      const ARaiseOnExecute: Boolean = False
    );
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure TestExecuteReturnsToolResult;
    [Test]
    procedure TestUnknownToolReturnsStructuredError;
    [Test]
    procedure TestInvalidArgumentsReturnStructuredError;
    [Test]
    procedure TestMissingCorrelationIdReturnsStructuredError;
    [Test]
    procedure TestToolExceptionReturnsStructuredError;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.ToolRegistry;

const
  CObjectSchema = '{"type":"object"}';

{ TRadIAMockTool }

constructor TRadIAMockTool.Create(
  const ADescriptor: TRadIAToolDescriptor;
  const AResult: TRadIAToolResult;
  const ARaiseOnExecute: Boolean
);
begin
  inherited Create;
  FDescriptor := ADescriptor;
  FResult := AResult;
  FRaiseOnExecute := ARaiseOnExecute;
end;

function TRadIAMockTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  if FRaiseOnExecute then
    raise Exception.Create('Mock execution failure.');
  Result := FResult;
end;

function TRadIAMockTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := FDescriptor;
end;

{ TTestRadIAToolRegistry }

function TTestRadIAToolRegistry.CreateDescriptor(
  const AName: string
): TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    AName,
    '1.0',
    'Test tool.',
    CObjectSchema,
    CObjectSchema,
    trReadOnly
  );
end;

function TTestRadIAToolRegistry.CreateTool(
  const AName: string
): IRadIATool;
begin
  Result := TRadIAMockTool.Create(
    CreateDescriptor(AName),
    TRadIAToolResult.Succeeded('{}')
  );
end;

procedure TTestRadIAToolRegistry.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
end;

procedure TTestRadIAToolRegistry.TestBatchRegistrationIsAtomic;
var
  LTools: TArray<IRadIATool>;
begin
  FRegistry.RegisterTool(CreateTool('ExistingTool'));
  SetLength(LTools, 2);
  LTools[0] := CreateTool('NewTool');
  LTools[1] := CreateTool('ExistingTool');

  Assert.WillRaise(
    procedure
    begin
      FRegistry.RegisterTools(LTools);
    end,
    ERadIAToolAlreadyRegistered
  );
  Assert.AreEqual(1, FRegistry.Count);
  Assert.IsFalse(FRegistry.TryResolve('NewTool', LTools[0]));
end;

procedure TTestRadIAToolRegistry.TestBatchUnregisterRemovesOnlyNamedTools;
var
  LNames: TArray<string>;
  LTool: IRadIATool;
begin
  FRegistry.RegisterTool(CreateTool('FirstTool'));
  FRegistry.RegisterTool(CreateTool('SecondTool'));
  FRegistry.RegisterTool(CreateTool('ThirdTool'));
  LNames := TArray<string>.Create('FirstTool', 'ThirdTool');

  FRegistry.UnregisterTools(LNames);

  Assert.AreEqual(1, FRegistry.Count);
  Assert.IsFalse(FRegistry.TryResolve('FirstTool', LTool));
  Assert.IsTrue(FRegistry.TryResolve('SecondTool', LTool));
  Assert.IsFalse(FRegistry.TryResolve('ThirdTool', LTool));
end;

procedure TTestRadIAToolRegistry.TestClearRemovesAllTools;
begin
  FRegistry.RegisterTool(CreateTool('FirstTool'));
  FRegistry.RegisterTool(CreateTool('SecondTool'));

  FRegistry.Clear;

  Assert.AreEqual(0, FRegistry.Count);
end;

procedure TTestRadIAToolRegistry.TestDescriptorsAreSorted;
var
  LDescriptors: TArray<TRadIAToolDescriptor>;
begin
  FRegistry.RegisterTool(CreateTool('ZuluTool'));
  FRegistry.RegisterTool(CreateTool('AlphaTool'));

  LDescriptors := FRegistry.GetDescriptors;

  Assert.AreEqual<Integer>(2, Length(LDescriptors));
  Assert.AreEqual('AlphaTool', LDescriptors[0].Name);
  Assert.AreEqual('ZuluTool', LDescriptors[1].Name);
end;

procedure TTestRadIAToolRegistry.TestDuplicateNameRaises;
begin
  FRegistry.RegisterTool(CreateTool('DuplicateTool'));

  Assert.WillRaise(
    procedure
    begin
      FRegistry.RegisterTool(CreateTool('DUPlicateTool'));
    end,
    ERadIAToolAlreadyRegistered
  );
end;

procedure TTestRadIAToolRegistry.TestInvalidNameRaises;
begin
  Assert.WillRaise(
    procedure
    begin
      FRegistry.RegisterTool(CreateTool('invalid_tool'));
    end,
    ERadIAInvalidToolDescriptor
  );
end;

procedure TTestRadIAToolRegistry.TestInvalidSchemaRaises;
var
  LDescriptor: TRadIAToolDescriptor;
  LTool: IRadIATool;
begin
  LDescriptor := TRadIAToolDescriptor.Create(
    'InvalidSchemaTool',
    '1.0',
    'Test tool.',
    'not-json',
    CObjectSchema,
    trReadOnly
  );
  LTool := TRadIAMockTool.Create(
    LDescriptor,
    TRadIAToolResult.Succeeded('{}')
  );

  Assert.WillRaise(
    procedure
    begin
      FRegistry.RegisterTool(LTool);
    end,
    ERadIAInvalidToolDescriptor
  );
end;

procedure TTestRadIAToolRegistry.TestRegisterAndResolve;
var
  LResolved: IRadIATool;
begin
  FRegistry.RegisterTool(CreateTool('SampleTool'));

  LResolved := FRegistry.Resolve('SampleTool');

  Assert.IsNotNull(LResolved);
  Assert.AreEqual('SampleTool', LResolved.Descriptor.Name);
  Assert.AreEqual(1, FRegistry.Count);
end;

procedure TTestRadIAToolRegistry.TestResolveIsCaseInsensitive;
var
  LResolved: IRadIATool;
begin
  FRegistry.RegisterTool(CreateTool('CaseTool'));

  LResolved := FRegistry.Resolve('casetool');

  Assert.AreEqual('CaseTool', LResolved.Descriptor.Name);
end;

{ TTestRadIAToolExecutor }

function TTestRadIAToolExecutor.CreateDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'SampleTool',
    '1.0',
    'Test tool.',
    CObjectSchema,
    CObjectSchema,
    trReadOnly
  );
end;

procedure TTestRadIAToolExecutor.RegisterTool(
  const AResult: TRadIAToolResult;
  const ARaiseOnExecute: Boolean
);
begin
  FRegistry.RegisterTool(
    TRadIAMockTool.Create(
      CreateDescriptor,
      AResult,
      ARaiseOnExecute
    )
  );
end;

procedure TTestRadIAToolExecutor.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

procedure TTestRadIAToolExecutor.TestExecuteReturnsToolResult;
var
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  RegisterTool(TRadIAToolResult.Succeeded('{"value":42}'));
  LRequest := TRadIAToolRequest.Create(
    'SampleTool',
    '{}',
    'correlation-1'
  );

  LResult := FExecutor.Execute(LRequest);

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"value":42');
  Assert.Contains(LResult.ContentJson, '"_radiaView"');
  Assert.Contains(LResult.ContentJson, '"sourceTool":"SampleTool"');
end;

procedure TTestRadIAToolExecutor.TestInvalidArgumentsReturnStructuredError;
var
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  RegisterTool(TRadIAToolResult.Succeeded('{}'));
  LRequest := TRadIAToolRequest.Create(
    'SampleTool',
    'invalid-json',
    'correlation-2'
  );

  LResult := FExecutor.Execute(LRequest);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_request', LResult.ErrorCode);
end;

procedure TTestRadIAToolExecutor.TestMissingCorrelationIdReturnsStructuredError;
var
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  RegisterTool(TRadIAToolResult.Succeeded('{}'));
  LRequest := TRadIAToolRequest.Create(
    'SampleTool',
    '{}',
    ''
  );

  LResult := FExecutor.Execute(LRequest);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_request', LResult.ErrorCode);
end;

procedure TTestRadIAToolExecutor.TestToolExceptionReturnsStructuredError;
var
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  RegisterTool(TRadIAToolResult.Succeeded('{}'), True);
  LRequest := TRadIAToolRequest.Create(
    'SampleTool',
    '{}',
    'correlation-3'
  );

  LResult := FExecutor.Execute(LRequest);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('tool_execution_failed', LResult.ErrorCode);
  Assert.AreEqual('Mock execution failure.', LResult.ErrorMessage);
end;

procedure TTestRadIAToolExecutor.TestUnknownToolReturnsStructuredError;
var
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  LRequest := TRadIAToolRequest.Create(
    'UnknownTool',
    '{}',
    'correlation-4'
  );

  LResult := FExecutor.Execute(LRequest);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('tool_not_found', LResult.ErrorCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAToolRegistry);
  TDUnitX.RegisterTestFixture(TTestRadIAToolExecutor);

end.
