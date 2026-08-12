unit RadIA.Tests.DelphiEnvironment;

interface

implementation

uses
  System.IOUtils,
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Core.DelphiEnvironment,
  RadIA.Core.DelphiEnvironmentTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIADelphiEnvironmentWorkspaceMock = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  private
    FProjectFileName: string;
    FProjectRoot: string;
  public
    constructor Create(
      const AProjectFileName: string;
      const AProjectRoot: string
    );
    function GetIDEState: TRadIAIDEState;
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
    function GetEditorContent(
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetCompilerMessages(
      const AMaxCount: Integer
    ): TArray<TRadIACompilerMessage>;
  end;

  [TestFixture]
  TTestRadIADelphiEnvironment = class
  private
    FProjectFileName: string;
    FTemporaryDirectory: string;
    FWorkspace: IRadIAWorkspaceFacade;
    procedure WriteProjectFixture;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure BuildsSanitizedEnvironmentProfile;
    [Test]
    procedure RegistersReadOnlyEnvironmentTool;
  end;

{ TRadIADelphiEnvironmentWorkspaceMock }

constructor TRadIADelphiEnvironmentWorkspaceMock.Create(
  const AProjectFileName: string;
  const AProjectRoot: string
);
begin
  inherited Create;
  FProjectFileName := AProjectFileName;
  FProjectRoot := AProjectRoot;
end;

function TRadIADelphiEnvironmentWorkspaceMock.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'EnvironmentFixture',
    FProjectFileName,
    FProjectRoot,
    'Debug',
    'Win64'
  );
end;

function TRadIADelphiEnvironmentWorkspaceMock.GetActiveUnit: string;
begin
  Result := 'Environment.Main';
end;

function TRadIADelphiEnvironmentWorkspaceMock.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := nil;
end;

function TRadIADelphiEnvironmentWorkspaceMock.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := TRadIAEditorPosition.Create(1, 1);
end;

function TRadIADelphiEnvironmentWorkspaceMock.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIADelphiEnvironmentWorkspaceMock.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIADelphiEnvironmentWorkspaceMock.GetIDEState:
  TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'Delphi 13',
    'IDE64',
    'Enterprise',
    False,
    ['workspace', 'designer', 'build']
  );
end;

function TRadIADelphiEnvironmentWorkspaceMock.ListOpenFiles:
  TArray<string>;
begin
  Result := nil;
end;

function TRadIADelphiEnvironmentWorkspaceMock.ListProjectUnits:
  TArray<string>;
begin
  Result := [TPath.Combine(FProjectRoot, 'Environment.Main.pas')];
end;

{ TTestRadIADelphiEnvironment }

procedure TTestRadIADelphiEnvironment.BuildsSanitizedEnvironmentProfile;
var
  LProfile: TRadIADelphiEnvironmentProfile;
  LService: IRadIADelphiEnvironmentService;
begin
  LService := TRadIADelphiEnvironmentService.Create(FWorkspace);
  LProfile := LService.BuildProfile;

  Assert.AreEqual('Delphi 13', LProfile.IDEVersion);
  Assert.AreEqual('IDE64', LProfile.IDEArchitecture);
  Assert.AreEqual('Enterprise', LProfile.IDESKU);
  Assert.AreEqual('VCL', LProfile.Framework);
  Assert.AreEqual('Debug', LProfile.Configuration);
  Assert.AreEqual('Win64', LProfile.TargetPlatform);
  Assert.Contains(string.Join(';', LProfile.Libraries), 'FireDAC');
  Assert.Contains(string.Join(';', LProfile.Libraries), 'DUnitX');
  Assert.Contains(string.Join(';', LProfile.Packages), 'designide');
  Assert.Contains(string.Join(';', LProfile.Defines), 'DEBUG');
  Assert.Contains(string.Join(';', LProfile.Defines), 'TRACE');
  Assert.Contains(string.Join(';', LProfile.UnitScopes), 'System');
  Assert.Contains(string.Join(';', LProfile.UnitScopes), 'Vcl');
  Assert.Contains(string.Join(';', LProfile.SearchPaths), '{workspace}');
  Assert.Contains(string.Join(';', LProfile.SearchPaths), '<external>');
  Assert.Contains(string.Join(';', LProfile.IncludePaths), '{workspace}');
  Assert.Contains(string.Join(';', LProfile.LibraryPaths), '$(BDS)');
  Assert.DoesNotContain(
    string.Join(';', LProfile.SearchPaths),
    'PrivateLibrary'
  );
end;

procedure TTestRadIADelphiEnvironment.RegistersReadOnlyEnvironmentTool;
var
  LExecutor: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
  LService: IRadIADelphiEnvironmentService;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LService := TRadIADelphiEnvironmentService.Create(FWorkspace);
  RegisterRadIADelphiEnvironmentTools(LRegistry, LService);

  Assert.AreEqual(1, LRegistry.Count);
  Assert.IsTrue(LRegistry.TryResolve('GetDelphiEnvironmentProfile', LTool));
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);

  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LRequest := TRadIAToolRequest.Create(
    'GetDelphiEnvironmentProfile',
    '{}',
    'environment-test'
  );
  LResult := LExecutor.Execute(LRequest);
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"architecture":"IDE64"');
  Assert.Contains(LResult.ContentJson, '"framework":"VCL"');
  Assert.Contains(LResult.ContentJson, '"sku":"Enterprise"');
  Assert.Contains(LResult.ContentJson, '"defines":["DEBUG","TRACE"]');
  Assert.Contains(LResult.ContentJson, '"unitScopes":["System","Vcl"]');
end;

procedure TTestRadIADelphiEnvironment.Setup;
begin
  FTemporaryDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-Environment-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FTemporaryDirectory);
  FProjectFileName := TPath.Combine(
    FTemporaryDirectory,
    'EnvironmentFixture.dproj'
  );
  WriteProjectFixture;
  FWorkspace := TRadIADelphiEnvironmentWorkspaceMock.Create(
    FProjectFileName,
    FTemporaryDirectory
  );
end;

procedure TTestRadIADelphiEnvironment.TearDown;
begin
  FWorkspace := nil;
  if TDirectory.Exists(FTemporaryDirectory) then
    TDirectory.Delete(FTemporaryDirectory, True);
end;

procedure TTestRadIADelphiEnvironment.WriteProjectFixture;
var
  LContent: string;
  LWorkspaceLibrary: string;
begin
  LWorkspaceLibrary := TPath.Combine(FTemporaryDirectory, 'lib');
  LContent :=
    '<Project>' + sLineBreak +
    '  <FrameworkType>VCL</FrameworkType>' + sLineBreak +
    '  <DCC_UnitSearchPath>' + LWorkspaceLibrary +
    ';C:\PrivateLibrary;$(BDS)\lib</DCC_UnitSearchPath>' + sLineBreak +
    '  <DCC_IncludePath>include;$(BDS)\include</DCC_IncludePath>' +
    sLineBreak +
    '  <DCC_LibraryPath>$(BDS)\lib;C:\PrivateLibrary</DCC_LibraryPath>' +
    sLineBreak +
    '  <DCC_Define>TRACE;DEBUG;$(DCC_Define)</DCC_Define>' + sLineBreak +
    '  <DCC_Namespace>System;Vcl;$(DCC_Namespace)</DCC_Namespace>' +
    sLineBreak +
    '  <DCC_UsePackage>designide;vcl;$(DCC_UsePackage)</DCC_UsePackage>' +
    sLineBreak +
    '  <Unit>FireDAC.Comp.Client</Unit>' + sLineBreak +
    '  <Unit>DUnitX.TestFramework</Unit>' + sLineBreak +
    '</Project>';
  TFile.WriteAllText(FProjectFileName, LContent, TEncoding.UTF8);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADelphiEnvironment);

end.
