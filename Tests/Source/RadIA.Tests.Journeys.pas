unit RadIA.Tests.Journeys;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAJourneys = class
  public
    [Test]
    procedure CatalogContainsFiveEndToEndJourneys;
    [Test]
    procedure JourneyObjectivesPreserveSafetyGates;
    [Test]
    procedure JourneysExposeAuditablePhasesAndEvidence;
    [Test]
    procedure ResolvesOptionalUserContext;
    [Test]
    procedure RejectsOversizedUserContext;
    [Test]
    procedure DextJourneyRequestsMissingInputsInOrder;
    [Test]
    procedure JourneysExposeUsageAndExamples;
    [Test]
    procedure InfersProjectCreationFromNaturalLanguage;
    [Test]
    procedure DoesNotInferOrdinaryCodeGenerationAsProjectCreation;
    [Test]
    procedure CreateJourneyCollectsProjectDestinationAndPlatform;
    [Test]
    procedure CreateJourneyRequiresRuntimeValidation;
    [Test]
    procedure NaturalCreateContextExtractsDestinationNameAndDefaultPlatform;
    [Test]
    procedure NaturalCalculatorHistoryPreservesFunctionalFeature;
    [Test]
    procedure NaturalPromptsNormalizeEverySupportedTemplate;
    [Test]
    procedure ReplacesOnlyCreateDestinationDuringRecovery;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.Journeys;

procedure TTestRadIAJourneys.ReplacesOnlyCreateDestinationDuringRecovery;
var
  LContext: string;
begin
  LContext := TRadIAJourneyCatalog.ReplaceCreateDestination(
    'Create a calculator with operation history ' +
      'destination="D:\Old\Calculator" project="CalculatorApp" ' +
      'type="VCL" platform="Win32" feature="operationHistory"',
    'D:\New\Calculator'
  );
  Assert.Contains(LContext, 'destination="D:\New\Calculator"');
  Assert.DoesNotContain(LContext, 'D:\Old\Calculator');
  Assert.Contains(LContext, 'Create a calculator with operation history');
  Assert.Contains(LContext, 'project="CalculatorApp"');
  Assert.Contains(LContext, 'feature="operationHistory"');
end;

procedure TTestRadIAJourneys.CatalogContainsFiveEndToEndJourneys;
var
  LCount: Integer;
  LDefinition: TRadIAJourneyDefinition;
begin
  LCount := Length(TRadIAJourneyCatalog.All);
  Assert.AreEqual(9, LCount);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey create', LDefinition)
  );
  Assert.AreEqual('Create Delphi Project', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/JOURNEY DEBUG', LDefinition)
  );
  Assert.AreEqual('Debug Failure', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey modernize', LDefinition)
  );
  Assert.AreEqual('Modernize Delphi Project', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey migrate', LDefinition)
  );
  Assert.AreEqual('Migrate Legacy Delphi Code', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey dext-minimal', LDefinition)
  );
  Assert.AreEqual('Create DEXT Minimal API', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey dext-controllers', LDefinition)
  );
  Assert.AreEqual('Create DEXT Controllers API', LDefinition.Name);
end;

procedure TTestRadIAJourneys.JourneyObjectivesPreserveSafetyGates;
var
  LDefinition: TRadIAJourneyDefinition;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey create', LDefinition)
  );
  Assert.Contains(LDefinition.Objective, 'CreateProjectFromTemplate');
  Assert.Contains(LDefinition.Objective, 'OpenCreatedProject succeed');
  Assert.Contains(LDefinition.Objective, 'GetKnowledgeStatus');
  Assert.Contains(LDefinition.Objective, 'project index is ready');
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey fix-build', LDefinition)
  );
  Assert.Contains(LDefinition.Objective, 'Present a minimal repair plan');
  Assert.Contains(LDefinition.Objective, 'reviewable patches');
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey release', LDefinition)
  );
  Assert.Contains(LDefinition.Objective, 'Never push or publish');
  Assert.Contains(LDefinition.Objective, 'explicit user instruction');
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey migrate', LDefinition)
  );
  Assert.Contains(LDefinition.Objective, 'central transaction flow');
  Assert.Contains(LDefinition.Phases[3].Evidence, 'rollback decision');
end;

procedure TTestRadIAJourneys.JourneysExposeAuditablePhasesAndEvidence;
var
  LDefinition: TRadIAJourneyDefinition;
  LObjective: string;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey debug', LDefinition)
  );
  Assert.AreEqual(NativeInt(4), Length(LDefinition.Phases));
  Assert.AreEqual('Reproduce', LDefinition.Phases[0].Name);
  Assert.Contains(LDefinition.Phases[1].Evidence, 'failure evidence');
  Assert.AreEqual(NativeInt(5), Length(LDefinition.SuccessCriteria));

  LObjective := LDefinition.BuildAgentObjective(
    'Access violation after saving an invoice'
  );
  Assert.Contains(LObjective, 'Required journey phases:');
  Assert.Contains(LObjective, 'Evidence:');
  Assert.Contains(LObjective, 'Completion criteria:');
  Assert.Contains(
    LObjective,
    'User-provided context: Access violation after saving an invoice'
  );
end;

procedure TTestRadIAJourneys.ResolvesOptionalUserContext;
var
  LContext: string;
  LDefinition: TRadIAJourneyDefinition;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Resolve(
      '/journey create VCL inventory app with SQLite',
      LDefinition,
      LContext
    )
  );
  Assert.AreEqual('/journey create', LDefinition.Command);
  Assert.AreEqual('VCL inventory app with SQLite', LContext);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Resolve(
      '/JOURNEY FIX-BUILD',
      LDefinition,
      LContext
    )
  );
  Assert.AreEqual('', LContext);
end;

procedure TTestRadIAJourneys.RejectsOversizedUserContext;
var
  LContext: string;
  LDefinition: TRadIAJourneyDefinition;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TRadIAJourneyCatalog.Resolve(
      '/journey tests ' + StringOfChar('x', 4001),
      LDefinition,
      LContext
    );
  except
    on E: EArgumentException do
    begin
      LRaised := True;
      Assert.Contains(E.Message, '4000');
    end;
  end;
  Assert.IsTrue(LRaised);
end;

procedure TTestRadIAJourneys.DextJourneyRequestsMissingInputsInOrder;
var
  LDefinition: TRadIAJourneyDefinition;
  LField: string;
  LQuestion: string;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey dext-minimal', LDefinition)
  );
  Assert.IsTrue(
    LDefinition.NextRequiredInput('products get post', LField, LQuestion)
  );
  Assert.AreEqual('project', LField);
  Assert.Contains(LQuestion, 'project');
  Assert.IsTrue(
    LDefinition.NextRequiredInput(
      'project=Catalog destination=D:\Projects platform=Win32 port=8080 ' +
      'health=/health',
      LField,
      LQuestion
    )
  );
  Assert.AreEqual('endpoints', LField);
  Assert.IsFalse(
    LDefinition.NextRequiredInput(
      'project=Catalog destination=D:\Projects platform=Win32 port=8080 ' +
      'health=/health endpoints="GET /products group=Products status=200 purpose=List"',
      LField,
      LQuestion
    )
  );
end;

procedure TTestRadIAJourneys.JourneysExposeUsageAndExamples;
var
  LDefinition: TRadIAJourneyDefinition;
begin
  for LDefinition in TRadIAJourneyCatalog.All do
  begin
    Assert.Contains(LDefinition.Usage, LDefinition.Command);
    Assert.Contains(LDefinition.Example, LDefinition.Command);
    Assert.Contains(LDefinition.InputHelpText, 'Usage:');
    Assert.Contains(LDefinition.InputHelpText, 'Example:');
  end;
end;

procedure TTestRadIAJourneys.CreateJourneyRequiresRuntimeValidation;
var
  LDefinition: TRadIAJourneyDefinition;
begin
  Assert.IsTrue(TRadIAJourneyCatalog.Find('/journey create', LDefinition));
  Assert.Contains(LDefinition.Objective, 'start the application');
  Assert.Contains(LDefinition.Objective, 'exercise the primary user scenario');
  Assert.AreEqual(NativeInt(4), Length(LDefinition.SuccessCriteria));
  Assert.Contains(LDefinition.SuccessCriteria[2], 'primary user scenario passes');
end;

procedure TTestRadIAJourneys.InfersProjectCreationFromNaturalLanguage;
var
  LCommand: string;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.TryInferCreateProject(
      'crie uma calculadora com operacoes basicas em VCL',
      LCommand
    )
  );
  Assert.AreEqual(
    '/journey create crie uma calculadora com operacoes basicas em VCL',
    LCommand
  );
  Assert.IsTrue(
    TRadIAJourneyCatalog.TryInferCreateProject(
      'faça uma calculadora básica',
      LCommand
    )
  );
  Assert.AreEqual(
    '/journey create faça uma calculadora básica',
    LCommand
  );
  Assert.IsTrue(
    TRadIAJourneyCatalog.TryInferCreateProject(
      'Create a new DUnitX project for the customer service',
      LCommand
    )
  );
  Assert.IsTrue(
    TRadIAJourneyCatalog.TryInferCreateProject(
      'crie um sistema de estoque em D:\Projetos\Estoque',
      LCommand
    )
  );
  Assert.IsTrue(
    TRadIAJourneyCatalog.TryInferCreateProject(
      'generate a desktop app in C:\Work\CustomerApp',
      LCommand
    )
  );
end;

procedure TTestRadIAJourneys.DoesNotInferOrdinaryCodeGenerationAsProjectCreation;
var
  LCommand: string;
begin
  Assert.IsFalse(
    TRadIAJourneyCatalog.TryInferCreateProject(
      'crie uma funcao para somar dois valores',
      LCommand
    )
  );
  Assert.IsFalse(
    TRadIAJourneyCatalog.TryInferCreateProject('/createproject', LCommand)
  );
end;

procedure TTestRadIAJourneys.CreateJourneyCollectsProjectDestinationAndPlatform;
var
  LDefinition: TRadIAJourneyDefinition;
  LField: string;
  LQuestion: string;
begin
  Assert.IsTrue(TRadIAJourneyCatalog.Find('/journey create', LDefinition));
  Assert.IsTrue(
    LDefinition.NextRequiredInput(
      'crie uma calculadora em VCL',
      LField,
      LQuestion
    )
  );
  Assert.AreEqual('project', LField);
  Assert.IsTrue(
    LDefinition.NextRequiredInput(
      'goal="calculator" project="CalculatorApp"',
      LField,
      LQuestion
    )
  );
  Assert.AreEqual('type', LField);
  Assert.IsTrue(
    LDefinition.NextRequiredInput(
      'goal="calculator" project="CalculatorApp" type="VCL"',
      LField,
      LQuestion
    )
  );
  Assert.AreEqual('destination', LField);
  Assert.IsFalse(
    LDefinition.NextRequiredInput(
      'goal="calculator" project="CalculatorApp" type="VCL" ' +
      'destination="D:\Projects" platform="Win32"',
      LField,
      LQuestion
    )
  );
end;

procedure TTestRadIAJourneys.
  NaturalCreateContextExtractsDestinationNameAndDefaultPlatform;
var
  LContext: string;
  LDefinition: TRadIAJourneyDefinition;
  LField: string;
  LQuestion: string;
begin
  LContext := TRadIAJourneyCatalog.NormalizeCreateContext(
    'crie uma calculadora vcl com as 4 operacoes basicas em d:\calculadora, ' +
    'crie o diretorio se necessario'
  );
  Assert.Contains(LContext, 'destination="d:\calculadora"');
  Assert.Contains(LContext, 'project="calculadora"');
  Assert.Contains(LContext, 'type="VCL"');
  Assert.Contains(LContext, 'platform="Win32"');
  Assert.IsTrue(TRadIAJourneyCatalog.Find('/journey create', LDefinition));
  Assert.IsFalse(LDefinition.NextRequiredInput(LContext, LField, LQuestion));
end;

procedure TTestRadIAJourneys.
  NaturalCalculatorHistoryPreservesFunctionalFeature;
var
  LContext: string;
begin
  LContext := TRadIAJourneyCatalog.NormalizeCreateContext(
    'crie uma calculadora com histórico de operações em D:\HistoryCalculator'
  );
  Assert.Contains(LContext, 'feature="operationHistory"');
  Assert.Contains(LContext, 'type="VCL"');
end;

procedure TTestRadIAJourneys.NaturalPromptsNormalizeEverySupportedTemplate;
const
  CPrompts: array[0..13] of string = (
    'crie um aplicativo console',
    'create a console application',
    'crie uma aplicação VCL',
    'create a Windows desktop application',
    'crie uma aplicação FireMonkey multiplataforma',
    'create an FMX application',
    'crie uma biblioteca dinâmica DLL',
    'create a library DLL',
    'crie um pacote de componentes BPL',
    'create a package BPL',
    'crie um projeto de testes unitários DUnitX',
    'create a DUnitX unit test project',
    'crie um serviço Windows',
    'create a Windows service application'
  );
  CExpectedTypes: array[0..13] of string = (
    'Console', 'Console',
    'VCL', 'VCL',
    'FMX', 'FMX',
    'Library', 'Library',
    'Package', 'Package',
    'DUnitX', 'DUnitX',
    'Service', 'Service'
  );
var
  LIndex: Integer;
  LNormalized: string;
begin
  for LIndex := Low(CPrompts) to High(CPrompts) do
  begin
    LNormalized := TRadIAJourneyCatalog.NormalizeCreateContext(
      CPrompts[LIndex]
    );
    Assert.Contains(
      LNormalized,
      'type="' + CExpectedTypes[LIndex] + '"',
      CPrompts[LIndex]
    );
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAJourneys);

end.
