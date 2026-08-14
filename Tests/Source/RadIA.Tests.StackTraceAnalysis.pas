unit RadIA.Tests.StackTraceAnalysis;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.StackTraceAnalysis;

type
  [TestFixture]
  TRadIAStackTraceAnalysisTests = class
  private
    FService: IRadIAStackTraceAnalysisService;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure ResolvesMadExceptFramesAcrossProjectUnits;
    [Test]
    procedure ResolvesEurekaLogFramesAndLimitsOutput;
    [Test]
    procedure KeepsUnknownFramesExplicit;
  end;

implementation

uses
  RadIA.Core.SemanticQueries,
  RadIA.Core.Workspace,
  System.SysUtils;

type
  TRadIAStackWorkspaceStub = class(TInterfacedObject, IRadIAWorkspaceFacade)
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

  TRadIAStackQueryStub = class(TInterfacedObject, IRadIASemanticQueryService)
  public
    function BuildContext(
      const ASymbolName: string;
      const AMaxCharacters: Integer;
      out AContext: string;
      out AError: string
    ): Boolean;
    function FindResolvedMembers(
      const AContainerName: string;
      out AMembers: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindSymbols(
      const AName: string;
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function HasResolvedMember(
      const AContainerName: string;
      const AMemberName: string
    ): Boolean;
    function ListPublicApiSymbols(
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
  end;

function TRadIAStackQueryStub.BuildContext(
  const ASymbolName: string;
  const AMaxCharacters: Integer;
  out AContext: string;
  out AError: string
): Boolean;
begin
  AContext := '';
  AError := '';
  Result := False;
end;

function TRadIAStackQueryStub.FindResolvedMembers(
  const AContainerName: string;
  out AMembers: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  AMembers := [];
  AError := '';
  Result := True;
end;

function TRadIAStackQueryStub.FindSymbols(
  const AName: string;
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  AError := '';
  if SameText(AName, 'Execute') then
    ASymbols := [TRadIASemanticLocation.Create(
      'Execute',
      'method',
      'TWorker',
      'D:\Project\Worker.pas',
      'procedure Execute;',
      100
    )]
  else
    ASymbols := [];
  Result := True;
end;

function TRadIAStackQueryStub.HasResolvedMember(
  const AContainerName: string;
  const AMemberName: string
): Boolean;
begin
  Result := False;
end;

function TRadIAStackQueryStub.ListPublicApiSymbols(
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  ASymbols := [];
  AError := '';
  Result := True;
end;

function TRadIAStackWorkspaceStub.GetActiveProject: TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create('Project', 'D:\Project\Project.dproj', 'D:\Project', '', '');
end;

function TRadIAStackWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAStackWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAStackWorkspaceStub.GetCursorPosition: TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIAStackWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIAStackWorkspaceStub.GetEditorSelection: TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAStackWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Test', 'Win32', False, []);
end;

function TRadIAStackWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := [];
end;

function TRadIAStackWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := ['D:\Project\Orders.pas', 'D:\Project\Worker.pas'];
end;

procedure TRadIAStackTraceAnalysisTests.KeepsUnknownFramesExplicit;
var
  LAnalysis: TRadIAStackTraceAnalysis;
begin
  LAnalysis := FService.Analyze('Unknown.pas:17 TMissing.Run', 10);
  Assert.AreEqual(NativeInt(1), Length(LAnalysis.Frames));
  Assert.IsFalse(LAnalysis.Frames[0].Resolved);
  Assert.AreEqual('low', LAnalysis.Frames[0].Confidence);
end;

procedure TRadIAStackTraceAnalysisTests.ResolvesEurekaLogFramesAndLimitsOutput;
var
  LAnalysis: TRadIAStackTraceAnalysis;
begin
  LAnalysis := FService.Analyze(
    'EurekaLog Exception Thread' + sLineBreak +
    'Orders.pas (20) TOrders.Load' + sLineBreak +
    'Worker.pas (30) TWorker.Execute',
    1
  );
  Assert.AreEqual('eurekalog', LAnalysis.DetectedFormat);
  Assert.AreEqual(NativeInt(1), Length(LAnalysis.Frames));
  Assert.IsTrue(LAnalysis.Frames[0].Resolved);
end;

procedure TRadIAStackTraceAnalysisTests.ResolvesMadExceptFramesAcrossProjectUnits;
var
  LAnalysis: TRadIAStackTraceAnalysis;
begin
  LAnalysis := FService.Analyze(
    'madExcept' + sLineBreak +
    '[0042ABCD] Orders.pas.42 TOrders.Load' + sLineBreak +
    '[0042ABEF] Worker.pas:88 TWorker.Execute',
    10
  );
  Assert.AreEqual('madexcept', LAnalysis.DetectedFormat);
  Assert.AreEqual(NativeInt(2), Length(LAnalysis.Frames));
  Assert.AreEqual('D:\Project\Orders.pas', LAnalysis.Frames[0].FileName);
  Assert.AreEqual(42, LAnalysis.Frames[0].Line);
  Assert.AreEqual('high', LAnalysis.Frames[0].Confidence);
end;

procedure TRadIAStackTraceAnalysisTests.Setup;
begin
  FService := TRadIAStackTraceAnalysisService.Create(
    TRadIAStackWorkspaceStub.Create,
    TRadIAStackQueryStub.Create
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAStackTraceAnalysisTests);

end.
