unit RadIA.Tests.OpenApiRetrofit;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAOpenApiRetrofitTests = class
  public
    [Test]
    procedure InventoriesMinimalAndControllerRoutes;
    [Test]
    procedure PreparesSwaggerWithoutRecreatingProject;
  end;

implementation

uses
  RadIA.Core.OpenApiRetrofit,
  RadIA.Core.Patches,
  RadIA.Core.Workspace,
  System.DateUtils,
  System.IOUtils,
  System.SysUtils;

type
  TRadIAOpenApiWorkspaceStub = class(TInterfacedObject, IRadIAWorkspaceFacade)
  private
    FContent: string;
    FUnits: TArray<string>;
  public
    constructor Create(const AContent: string; const AUnits: TArray<string>);
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function GetCompilerMessages(const AMaxCount: Integer): TArray<TRadIACompilerMessage>;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetEditorContent(const AMaxCharacters: Integer): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetIDEState: TRadIAIDEState;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
  end;

  TRadIAOpenApiPatchStub = class(TInterfacedObject, IRadIAPatchService)
  public
    Spec: TRadIAPatchSpec;
    function Apply(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
    function Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
  end;

constructor TRadIAOpenApiWorkspaceStub.Create(
  const AContent: string;
  const AUnits: TArray<string>
);
begin
  inherited Create;
  FContent := AContent;
  FUnits := Copy(AUnits);
end;

function TRadIAOpenApiWorkspaceStub.GetActiveProject: TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create('ExistingApi', '', '', '', '');
end;

function TRadIAOpenApiWorkspaceStub.GetActiveUnit: string;
begin
  Result := 'ExistingApi.Startup.pas';
end;

function TRadIAOpenApiWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAOpenApiWorkspaceStub.GetCursorPosition: TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIAOpenApiWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := TRadIAEditorContent.Create(
    'ExistingApi.Startup',
    'ExistingApi.Startup.pas',
    FContent,
    'revision',
    Length(FContent),
    False
  );
end;

function TRadIAOpenApiWorkspaceStub.GetEditorSelection: TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAOpenApiWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Test', 'Win32', False, []);
end;

function TRadIAOpenApiWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := [];
end;

function TRadIAOpenApiWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := Copy(FUnits);
end;

function TRadIAOpenApiPatchStub.Apply(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('', '');
end;

procedure TRadIAOpenApiPatchStub.Clear;
begin
end;

function TRadIAOpenApiPatchStub.Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
begin
  Spec := ASpec;
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    'openapi-preview',
    ASpec,
    ASpec.OriginalText,
    ASpec.ReplacementText,
    'new-revision',
    IncMinute(Now, 10)
  ));
end;

function TRadIAOpenApiPatchStub.Revert(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('', '');
end;

procedure TRadIAOpenApiRetrofitTests.InventoriesMinimalAndControllerRoutes;
var
  LFileName: string;
  LRoutes: TArray<TRadIAExistingApiRoute>;
  LService: IRadIAOpenApiRetrofitService;
begin
  LFileName := TPath.Combine(TPath.GetTempPath, 'RadIA.Retrofit.Routes.pas');
  TFile.WriteAllText(
    LFileName,
    'Builder.MapGet(''/health'', Handler);' + sLineBreak +
    '[HttpPost(''/orders'')] procedure CreateOrder;'
  );
  try
    LService := TRadIAOpenApiRetrofitService.Create(
      TRadIAOpenApiWorkspaceStub.Create('', [LFileName]),
      TRadIAOpenApiPatchStub.Create
    );
    LRoutes := LService.InventoryRoutes;
    Assert.AreEqual(2, Length(LRoutes));
    Assert.AreEqual('GET', LRoutes[0].Method);
    Assert.AreEqual('/orders', LRoutes[1].Path);
  finally
    TFile.Delete(LFileName);
  end;
end;

procedure TRadIAOpenApiRetrofitTests.PreparesSwaggerWithoutRecreatingProject;
var
  LContent: string;
  LPatch: TRadIAOpenApiPatchStub;
  LResult: TRadIAOpenApiRetrofitResult;
  LService: IRadIAOpenApiRetrofitService;
begin
  LContent :=
    'unit ExistingApi.Startup;' + sLineBreak + 'interface' + sLineBreak +
    'uses Dext.Web;' + sLineBreak +
    'procedure ConfigureApplication(const AApplication: IWebApplication);' + sLineBreak +
    'implementation' + sLineBreak + 'uses ExistingApi.Endpoints;' + sLineBreak +
    'procedure ConfigureApplication(const AApplication: IWebApplication);' + sLineBreak +
    'begin' + sLineBreak + '  MapEndpoints(AApplication.Builder);' + sLineBreak +
    'end;' + sLineBreak + 'end.';
  LPatch := TRadIAOpenApiPatchStub.Create;
  LService := TRadIAOpenApiRetrofitService.Create(
    TRadIAOpenApiWorkspaceStub.Create(LContent, []),
    LPatch
  );
  LResult := LService.Prepare('Existing API', '2.0.0');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LPatch.Spec.ReplacementText, 'Dext.Swagger.Middleware');
  Assert.Contains(LPatch.Spec.ReplacementText, 'TSwaggerExtensions.UseSwagger');
  Assert.Contains(LPatch.Spec.ReplacementText, 'MapEndpoints(AApplication.Builder)');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAOpenApiRetrofitTests);

end.
