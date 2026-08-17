unit RadIA.Tests.FireDACGeneration;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACGenerationTests = class
  private
    FArtifacts: IInterface;
    FRootPath: string;
    function ExecuteTool(
      const AToolName: string;
      const AArgumentsJson: string
    ): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure RegistersFiveReadOnlyPreviewTools;
    [Test]
    procedure RepositoryPreviewIsDeterministicAndDoesNotWrite;
    [Test]
    procedure DataModulePreviewOwnsConnectionSafely;
    [Test]
    procedure BuildsDtoQueryAndTestPreviews;
    [Test]
    procedure RejectsUnsafeNamesAndTableExpressions;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.FireDAC.Generation,
  RadIA.Core.GeneratedArtifacts,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary,
  RadIA.Tests.ProjectFiles;

function CreateRegistry(
  const AArtifacts: IRadIAGeneratedArtifactService
): IRadIAToolRegistry;
begin
  Result := TRadIAToolRegistry.Create;
  RegisterRadIAFireDACGenerationTools(Result, AArtifacts);
end;

function TRadIAFireDACGenerationTests.ExecuteTool(
  const AToolName: string;
  const AArgumentsJson: string
): string;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := CreateRegistry(FArtifacts as IRadIAGeneratedArtifactService);
  LResult := LRegistry.Resolve(AToolName).Execute(
    TRadIAToolRequest.Create(AToolName, AArgumentsJson, 'firedac-generation-test')
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Result := LResult.ContentJson;
end;

procedure TRadIAFireDACGenerationTests.Setup;
var
  LFacade: TRadIAProjectFileFacadeStub;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-FireDAC-Generation-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  LWorkspace := TRadIAProjectFileWorkspaceStub.Create(FRootPath);
  LFacade := TRadIAProjectFileFacadeStub.Create;
  FArtifacts := TRadIAGeneratedArtifactService.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create,
    LFacade
  );
end;

procedure TRadIAFireDACGenerationTests.TearDown;
begin
  FArtifacts := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TRadIAFireDACGenerationTests.RegistersFiveReadOnlyPreviewTools;
const
  CToolNames: array[0..4] of string = (
    'GenerateFireDACRepositoryPreview',
    'GenerateFireDACDataModulePreview',
    'GenerateFireDACQueryPreview',
    'GenerateFireDACDTOPreview',
    'GenerateFireDACTests'
  );
var
  LRegistry: IRadIAToolRegistry;
  LToolName: string;
begin
  LRegistry := CreateRegistry(FArtifacts as IRadIAGeneratedArtifactService);
  for LToolName in CToolNames do
    Assert.AreEqual(trReadOnly, LRegistry.Resolve(LToolName).Descriptor.Risk);
end;

procedure TRadIAFireDACGenerationTests.
  RepositoryPreviewIsDeterministicAndDoesNotWrite;
var
  LContent: string;
begin
  LContent := ExecuteTool(
    'GenerateFireDACRepositoryPreview',
    '{"unitName":"RadIA.Data.CustomerRepository",' +
    '"entityName":"Customer","tableName":"customer"}'
  );
  Assert.Contains(LContent, 'TRadIACustomerRepository');
  Assert.Contains(LContent, 'TFDConnection');
  Assert.Contains(LContent, 'select * from customer');
  Assert.Contains(LContent, '"state":"prepared"');
  Assert.Contains(LContent, '"sha256"');
  Assert.IsFalse(TFile.Exists(
    TPath.Combine(FRootPath, 'Source\RadIA.Data.CustomerRepository.pas')
  ));
end;

procedure TRadIAFireDACGenerationTests.DataModulePreviewOwnsConnectionSafely;
var
  LContent: string;
begin
  LContent := ExecuteTool(
    'GenerateFireDACDataModulePreview',
    '{"unitName":"RadIA.Data.CustomerDataModule","entityName":"Customer"}'
  );
  Assert.Contains(LContent, 'TFDConnection.Create(nil)');
  Assert.Contains(LContent, 'FConnection.Free');
  Assert.Contains(LContent, 'destructor TRadIACustomerDataModule.Destroy');
end;

procedure TRadIAFireDACGenerationTests.BuildsDtoQueryAndTestPreviews;
var
  LContent: string;
begin
  LContent := ExecuteTool(
    'GenerateFireDACDTOPreview',
    '{"unitName":"RadIA.Data.CustomerDTO","entityName":"Customer"}'
  );
  Assert.Contains(LContent, 'TRadIACustomerDTO = record');
  LContent := ExecuteTool(
    'GenerateFireDACQueryPreview',
    '{"unitName":"RadIA.Data.CustomerQuery",' +
    '"entityName":"Customer","tableName":"customer"}'
  );
  Assert.Contains(LContent, 'TRadIACustomerQuery.Configure');
  LContent := ExecuteTool(
    'GenerateFireDACTests',
    '{"unitName":"RadIA.Tests.CustomerRepository",' +
    '"entityName":"CustomerRepository","registerInProject":false}'
  );
  Assert.Contains(LContent, 'TRadIACustomerRepositoryTests');
  Assert.Contains(LContent, 'TDUnitX.RegisterTestFixture');
end;

procedure TRadIAFireDACGenerationTests.
  RejectsUnsafeNamesAndTableExpressions;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := CreateRegistry(FArtifacts as IRadIAGeneratedArtifactService);
  LResult := LRegistry.Resolve('GenerateFireDACQueryPreview').Execute(
    TRadIAToolRequest.Create(
      'GenerateFireDACQueryPreview',
      '{"unitName":"Unsafe.Query","entityName":"Customer",' +
      '"tableName":"customer;drop table customer"}',
      'firedac-generation-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_name', LResult.ErrorCode);
  LResult := LRegistry.Resolve('GenerateFireDACQueryPreview').Execute(
    TRadIAToolRequest.Create(
      'GenerateFireDACQueryPreview',
      '{"unitName":"RadIA.Data.CustomerQuery","entityName":"Customer",' +
      '"tableName":"customer;drop table customer"}',
      'firedac-generation-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_table', LResult.ErrorCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACGenerationTests);

end.
