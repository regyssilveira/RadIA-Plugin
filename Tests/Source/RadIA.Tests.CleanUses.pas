unit RadIA.Tests.CleanUses;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIACleanUsesTests = class
  public
    [Test]
    procedure PreparesOnlySemanticallyUnusedProjectUnit;
  end;

implementation

uses
  RadIA.Core.CleanUses,
  RadIA.Core.Patches,
  RadIA.Core.SemanticQueries,
  RadIA.Core.Workspace,
  System.DateUtils,
  System.IOUtils,
  System.SysUtils;

type
  TRadIACleanWorkspaceStub = class(TInterfacedObject, IRadIAWorkspaceFacade)
  public
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

  TRadIACleanQueryStub = class(TInterfacedObject, IRadIASemanticQueryService)
  public
    function BuildContext(const ASymbolName: string; const AMaxCharacters: Integer;
      out AContext: string; out AError: string): Boolean;
    function FindResolvedMembers(const AContainerName: string;
      out AMembers: TArray<TRadIASemanticLocation>; out AError: string): Boolean;
    function FindSymbols(const AName: string; out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string): Boolean;
    function HasResolvedMember(const AContainerName: string; const AMemberName: string): Boolean;
    function ListPublicApiSymbols(out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string): Boolean;
  end;

  TRadIACleanPatchStub = class(TInterfacedObject, IRadIAPatchService)
  private
    FSpec: TRadIAPatchSpec;
  public
    function Apply(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
    function Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
    property Spec: TRadIAPatchSpec read FSpec;
  end;

function TRadIACleanPatchStub.Apply(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('', '');
end;

procedure TRadIACleanPatchStub.Clear;
begin
end;

function TRadIACleanPatchStub.Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
begin
  FSpec := ASpec;
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    'clean-preview',
    ASpec,
    ASpec.OriginalText,
    ASpec.ReplacementText,
    'new-revision',
    IncMinute(Now, 10)
  ));
end;

function TRadIACleanPatchStub.Revert(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('', '');
end;

function TRadIACleanQueryStub.BuildContext(const ASymbolName: string;
  const AMaxCharacters: Integer; out AContext: string; out AError: string): Boolean;
begin
  AContext := '';
  AError := '';
  Result := False;
end;

function TRadIACleanQueryStub.FindResolvedMembers(const AContainerName: string;
  out AMembers: TArray<TRadIASemanticLocation>; out AError: string): Boolean;
begin
  AMembers := [];
  AError := '';
  Result := True;
end;

function TRadIACleanQueryStub.FindSymbols(const AName: string;
  out ASymbols: TArray<TRadIASemanticLocation>; out AError: string): Boolean;
begin
  ASymbols := [];
  AError := '';
  Result := True;
end;

function TRadIACleanQueryStub.HasResolvedMember(const AContainerName: string;
  const AMemberName: string): Boolean;
begin
  Result := False;
end;

function TRadIACleanQueryStub.ListPublicApiSymbols(
  out ASymbols: TArray<TRadIASemanticLocation>; out AError: string): Boolean;
begin
  ASymbols := [
    TRadIASemanticLocation.Create('TUsedType', 'class', '', 'UsedUnit.pas', '', 1),
    TRadIASemanticLocation.Create('TUnusedType', 'class', '', 'UnusedUnit.pas', '', 1)
  ];
  AError := '';
  Result := True;
end;

function TRadIACleanWorkspaceStub.GetActiveProject: TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create('Project', '', '', '', '');
end;

function TRadIACleanWorkspaceStub.GetActiveUnit: string;
begin
  Result := 'Consumer.pas';
end;

function TRadIACleanWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIACleanWorkspaceStub.GetCursorPosition: TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIACleanWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer): TRadIAEditorContent;
var
  LContent: string;
begin
  LContent :=
    'unit Consumer;' + sLineBreak + 'interface' + sLineBreak +
    'uses' + sLineBreak + '  UsedUnit,' + sLineBreak + '  UnusedUnit;' + sLineBreak +
    'type TConsumer = class' + sLineBreak + '  FValue: TUsedType;' + sLineBreak +
    'end;' + sLineBreak + 'implementation' + sLineBreak + 'end.';
  Result := TRadIAEditorContent.Create(
    'Consumer',
    'Consumer.pas',
    LContent,
    'base-revision',
    Length(LContent),
    False
  );
end;

function TRadIACleanWorkspaceStub.GetEditorSelection: TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIACleanWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Test', 'Win32', False, []);
end;

function TRadIACleanWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := [];
end;

function TRadIACleanWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := [
    TPath.Combine(TPath.GetTempPath, 'UsedUnit.pas'),
    TPath.Combine(TPath.GetTempPath, 'UnusedUnit.pas')
  ];
end;

procedure TRadIACleanUsesTests.PreparesOnlySemanticallyUnusedProjectUnit;
var
  LPatch: TRadIACleanPatchStub;
  LResult: TRadIACleanUsesResult;
  LService: IRadIACleanUsesService;
begin
  TFile.WriteAllText(
    TPath.Combine(TPath.GetTempPath, 'UsedUnit.pas'),
    'unit UsedUnit; interface end.'
  );
  TFile.WriteAllText(
    TPath.Combine(TPath.GetTempPath, 'UnusedUnit.pas'),
    'unit UnusedUnit; interface end.'
  );
  LPatch := TRadIACleanPatchStub.Create;
  try
    LService := TRadIACleanUsesService.Create(
      TRadIACleanWorkspaceStub.Create,
      TRadIACleanQueryStub.Create,
      LPatch
    );
    LResult := LService.Prepare;
    Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
    Assert.AreEqual(1, Length(LResult.Candidates));
    Assert.AreEqual('UnusedUnit', LResult.Candidates[0]);
    Assert.Contains(LPatch.Spec.ReplacementText, 'UsedUnit');
    Assert.DoesNotContain(LPatch.Spec.ReplacementText, 'UnusedUnit');
  finally
    TFile.Delete(TPath.Combine(TPath.GetTempPath, 'UsedUnit.pas'));
    TFile.Delete(TPath.Combine(TPath.GetTempPath, 'UnusedUnit.pas'));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIACleanUsesTests);

end.
