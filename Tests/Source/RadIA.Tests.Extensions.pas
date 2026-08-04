unit RadIA.Tests.Extensions;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Extensions,
  RadIA.Core.Tools;

type
  TRadIATestExtensionTool = class(TInterfacedObject, IRadIATool)
  private
    FDescriptor: TRadIAToolDescriptor;
  public
    constructor Create(const AName: string);
    function GetDescriptor: TRadIAToolDescriptor;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

  TRadIATestToolExtension = class(
    TInterfacedObject,
    IRadIAToolExtension
  )
  private
    FDescriptor: TRadIAToolExtensionDescriptor;
    FToolName: string;
  public
    constructor Create(
      const AId: string;
      const AToolPrefix: string;
      const AToolName: string;
      const AMinimumApiVersion: Integer = 1;
      const AMaximumApiVersion: Integer = 1
    );
    function GetDescriptor: TRadIAToolExtensionDescriptor;
    procedure RegisterTools(
      const ARegistrar: IRadIAToolExtensionRegistrar
    );
  end;

  [TestFixture]
  TTestRadIAToolExtensions = class
  private
    FHost: IRadIAToolExtensionHost;
    FRegistry: IRadIAToolRegistry;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestRegistersAndListsExtension;
    [Test]
    procedure TestRegistrationTokenUnregistersOwnedTools;
    [Test]
    procedure TestRejectsIncompatibleApiVersion;
    [Test]
    procedure TestRejectsToolOutsideOwnedPrefix;
    [Test]
    procedure TestDuplicateExtensionDoesNotChangeRegistry;
    [Test]
    procedure TestRejectsDuplicateToolPrefix;
    [Test]
    procedure TestPublicRegistrationUsesBoundHost;
    [Test]
    procedure TestPublicRegistrationRejectsUnavailableHost;
  end;

implementation

uses
  RadIA.Core.ToolRegistry;

const
  CEmptyObjectSchema = '{"type":"object"}';

{ TRadIATestExtensionTool }

constructor TRadIATestExtensionTool.Create(const AName: string);
begin
  inherited Create;
  FDescriptor := TRadIAToolDescriptor.Create(
    AName,
    '1.0.0',
    'Returns a deterministic extension test result.',
    CEmptyObjectSchema,
    CEmptyObjectSchema,
    trReadOnly
  );
end;

function TRadIATestExtensionTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded('{}');
end;

function TRadIATestExtensionTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := FDescriptor;
end;

{ TRadIATestToolExtension }

constructor TRadIATestToolExtension.Create(
  const AId: string;
  const AToolPrefix: string;
  const AToolName: string;
  const AMinimumApiVersion: Integer;
  const AMaximumApiVersion: Integer
);
begin
  inherited Create;
  FDescriptor := TRadIAToolExtensionDescriptor.Create(
    AId,
    '1.0.0',
    AToolPrefix,
    AMinimumApiVersion,
    AMaximumApiVersion
  );
  FToolName := AToolName;
end;

function TRadIATestToolExtension.GetDescriptor:
  TRadIAToolExtensionDescriptor;
begin
  Result := FDescriptor;
end;

procedure TRadIATestToolExtension.RegisterTools(
  const ARegistrar: IRadIAToolExtensionRegistrar
);
begin
  ARegistrar.AddTool(TRadIATestExtensionTool.Create(FToolName));
end;

{ TTestRadIAToolExtensions }

procedure TTestRadIAToolExtensions.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
  FHost := TRadIAToolExtensionHost.Create(FRegistry);
end;

procedure TTestRadIAToolExtensions.TearDown;
begin
  SetRadIAToolExtensionHost(nil);
  FHost := nil;
  FRegistry := nil;
end;

procedure TTestRadIAToolExtensions.TestDuplicateExtensionDoesNotChangeRegistry;
var
  LFirstRegistration: IRadIAToolExtensionRegistration;
  LSecondRegistration: IRadIAToolExtensionRegistration;
begin
  LFirstRegistration := FHost.RegisterExtension(
    TRadIATestToolExtension.Create(
      'SampleExtension',
      'Sample',
      'SampleEcho'
    )
  );

  Assert.WillRaise(
    procedure
    begin
      LSecondRegistration := FHost.RegisterExtension(
        TRadIATestToolExtension.Create(
          'SampleExtension',
          'Other',
          'OtherEcho'
        )
      );
    end,
    ERadIAToolExtensionAlreadyRegistered
  );
  Assert.AreEqual(1, FRegistry.Count);
  Assert.IsTrue(Assigned(LFirstRegistration));
  Assert.IsFalse(Assigned(LSecondRegistration));
end;

procedure TTestRadIAToolExtensions.TestPublicRegistrationRejectsUnavailableHost;
begin
  SetRadIAToolExtensionHost(nil);
  Assert.WillRaise(
    procedure
    begin
      RegisterRadIAToolExtension(
        TRadIATestToolExtension.Create(
          'SampleExtension',
          'Sample',
          'SampleEcho'
        )
      );
    end,
    ERadIAToolExtensionHostUnavailable
  );
end;

procedure TTestRadIAToolExtensions.TestRejectsDuplicateToolPrefix;
var
  LFirstRegistration: IRadIAToolExtensionRegistration;
  LSecondRegistration: IRadIAToolExtensionRegistration;
begin
  LFirstRegistration := FHost.RegisterExtension(
    TRadIATestToolExtension.Create(
      'FirstExtension',
      'Sample',
      'SampleFirst'
    )
  );

  Assert.WillRaise(
    procedure
    begin
      LSecondRegistration := FHost.RegisterExtension(
        TRadIATestToolExtension.Create(
          'SecondExtension',
          'Sample',
          'SampleSecond'
        )
      );
    end,
    ERadIAToolExtensionPrefixAlreadyRegistered
  );
  Assert.AreEqual(1, FRegistry.Count);
  Assert.IsTrue(Assigned(LFirstRegistration));
  Assert.IsFalse(Assigned(LSecondRegistration));
end;

procedure TTestRadIAToolExtensions.TestPublicRegistrationUsesBoundHost;
var
  LRegistration: IRadIAToolExtensionRegistration;
begin
  SetRadIAToolExtensionHost(FHost);
  LRegistration := RegisterRadIAToolExtension(
    TRadIATestToolExtension.Create(
      'SampleExtension',
      'Sample',
      'SampleEcho'
    )
  );

  Assert.AreEqual('SampleExtension', LRegistration.ExtensionId);
  Assert.AreEqual(1, FHost.Count);
  Assert.AreEqual(1, FRegistry.Count);
end;

procedure TTestRadIAToolExtensions.TestRegistrationTokenUnregistersOwnedTools;
var
  LRegistration: IRadIAToolExtensionRegistration;
begin
  LRegistration := FHost.RegisterExtension(
    TRadIATestToolExtension.Create(
      'SampleExtension',
      'Sample',
      'SampleEcho'
    )
  );
  Assert.AreEqual(1, FRegistry.Count);

  LRegistration := nil;

  Assert.AreEqual(0, FHost.Count);
  Assert.AreEqual(0, FRegistry.Count);
end;

procedure TTestRadIAToolExtensions.TestRegistersAndListsExtension;
var
  LDescriptors: TArray<TRadIAToolExtensionDescriptor>;
  LRegistration: IRadIAToolExtensionRegistration;
  LTool: IRadIATool;
begin
  LRegistration := FHost.RegisterExtension(
    TRadIATestToolExtension.Create(
      'SampleExtension',
      'Sample',
      'SampleEcho'
    )
  );

  Assert.AreEqual(1, FHost.Count);
  Assert.IsTrue(FRegistry.TryResolve('SampleEcho', LTool));
  LDescriptors := FHost.GetDescriptors;
  Assert.AreEqual<Integer>(1, Length(LDescriptors));
  Assert.AreEqual('SampleExtension', LDescriptors[0].Id);
  Assert.AreEqual('1.0.0', LDescriptors[0].Version);
  Assert.AreEqual('Sample', LDescriptors[0].ToolPrefix);
  Assert.IsTrue(Assigned(LRegistration));
end;

procedure TTestRadIAToolExtensions.TestRejectsIncompatibleApiVersion;
var
  LRegistration: IRadIAToolExtensionRegistration;
begin
  Assert.WillRaise(
    procedure
    begin
      LRegistration := FHost.RegisterExtension(
        TRadIATestToolExtension.Create(
          'FutureExtension',
          'Future',
          'FutureEcho',
          2,
          3
        )
      );
    end,
    ERadIAInvalidToolExtension
  );
  Assert.AreEqual(0, FRegistry.Count);
  Assert.IsFalse(Assigned(LRegistration));
end;

procedure TTestRadIAToolExtensions.TestRejectsToolOutsideOwnedPrefix;
var
  LRegistration: IRadIAToolExtensionRegistration;
begin
  Assert.WillRaise(
    procedure
    begin
      LRegistration := FHost.RegisterExtension(
        TRadIATestToolExtension.Create(
          'SampleExtension',
          'Sample',
          'ForeignEcho'
        )
      );
    end,
    ERadIAInvalidToolExtension
  );
  Assert.AreEqual(0, FRegistry.Count);
  Assert.IsFalse(Assigned(LRegistration));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAToolExtensions);

end.
