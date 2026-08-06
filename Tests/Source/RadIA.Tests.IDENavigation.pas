unit RadIA.Tests.IDENavigation;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.IDENavigation,
  RadIA.Core.Tools;

type
  TRadIAFakeIDENavigationFacade = class(
    TInterfacedObject,
    IRadIAIDENavigationFacade
  )
  private
    FExecutedAction: string;
    FNavigatedFile: string;
    FNavigatedSurface: TRadIADevelopmentSurface;
    FNavigatedSymbol: string;
  public
    function ListProjectGroupProjects: TArray<string>;
    function GetProjectDependencies: TArray<string>;
    function GetUnitSymbols(
      const AMaxSymbols: Integer
    ): TArray<TRadIAUnitSymbol>;
    function NavigateToFile(
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer
    ): TRadIANavigationResult;
    function NavigateToSymbol(
      const ASymbol: string
    ): TRadIANavigationResult;
    function NavigateToDevelopmentSurface(
      const AFileName: string;
      const ASurface: TRadIADevelopmentSurface
    ): TRadIANavigationResult;
    function ListIDEActions: TArray<TRadIAIDEAction>;
    function ExecuteIDEAction(
      const AActionName: string
    ): TRadIANavigationResult;
    property ExecutedAction: string read FExecutedAction;
    property NavigatedFile: string read FNavigatedFile;
    property NavigatedSurface: TRadIADevelopmentSurface
      read FNavigatedSurface;
    property NavigatedSymbol: string read FNavigatedSymbol;
  end;

  [TestFixture]
  TRadIAIDENavigationTests = class
  private
    FFacade: TRadIAFakeIDENavigationFacade;
    FFacadeReference: IRadIAIDENavigationFacade;
    FRegistry: IRadIAToolRegistry;
    function ExecuteTool(
      const AName: string;
      const AArguments: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure RegistersCompleteNavigationCatalog;
    [Test]
    procedure ListsProjectGroupAndDependencies;
    [Test]
    procedure ListsStructuredUnitSymbols;
    [Test]
    procedure NavigatesToFileAndSymbol;
    [Test]
    procedure NavigatesBetweenCodeAndDesign;
    [Test]
    procedure ListsAndExecutesSafeActions;
    [Test]
    procedure RejectsInvalidArguments;
    [Test]
    procedure ScannerRecognizesTypesAndRoutines;
    [Test]
    procedure ScannerHonorsMaximum;
    [Test]
    procedure ScannerFindsSymbolAtCursorLine;
    [Test]
    procedure ScannerRejectsLineBeforeFirstSymbol;
    [Test]
    procedure NavigationFailureIsStructured;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.IDENavigationTools,
  RadIA.Core.ToolRegistry;

{ TRadIAFakeIDENavigationFacade }

function TRadIAFakeIDENavigationFacade.ExecuteIDEAction(
  const AActionName: string
): TRadIANavigationResult;
begin
  FExecutedAction := AActionName;
  if SameText(AActionName, 'Unavailable') then
    Exit(TRadIANavigationResult.Failed('Action unavailable.'));
  Result := TRadIANavigationResult.Succeeded(
    '',
    0,
    0,
    'Action executed.'
  );
end;

function TRadIAFakeIDENavigationFacade.GetProjectDependencies:
  TArray<string>;
begin
  Result := ['C:\Work\Library.dproj'];
end;

function TRadIAFakeIDENavigationFacade.GetUnitSymbols(
  const AMaxSymbols: Integer
): TArray<TRadIAUnitSymbol>;
begin
  if AMaxSymbols <= 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  Result := [
    TRadIAUnitSymbol.Create('class', 'TRadIAMainForm', 12),
    TRadIAUnitSymbol.Create('procedure', 'TRadIAMainForm.Save', 42)
  ];
end;

function TRadIAFakeIDENavigationFacade.ListIDEActions:
  TArray<TRadIAIDEAction>;
begin
  Result := [
    TRadIAIDEAction.Create(
      'ViewProjectManager',
      'Project Manager',
      True
    )
  ];
end;

function TRadIAFakeIDENavigationFacade.ListProjectGroupProjects:
  TArray<string>;
begin
  Result := [
    'C:\Work\Application.dproj',
    'C:\Work\Library.dproj'
  ];
end;

function TRadIAFakeIDENavigationFacade.NavigateToFile(
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer
): TRadIANavigationResult;
begin
  FNavigatedFile := AFileName;
  Result := TRadIANavigationResult.Succeeded(
    AFileName,
    ALine,
    AColumn,
    'Position selected.'
  );
end;

function TRadIAFakeIDENavigationFacade.NavigateToDevelopmentSurface(
  const AFileName: string;
  const ASurface: TRadIADevelopmentSurface
): TRadIANavigationResult;
begin
  FNavigatedFile := AFileName;
  FNavigatedSurface := ASurface;
  Result := TRadIANavigationResult.Succeeded(
    AFileName,
    0,
    0,
    'Development surface selected.'
  );
end;

function TRadIAFakeIDENavigationFacade.NavigateToSymbol(
  const ASymbol: string
): TRadIANavigationResult;
begin
  FNavigatedSymbol := ASymbol;
  if SameText(ASymbol, 'Missing') then
    Exit(TRadIANavigationResult.Failed('Symbol not found.'));
  Result := TRadIANavigationResult.Succeeded(
    'Main.pas',
    42,
    1,
    'Symbol selected.'
  );
end;

{ TRadIAIDENavigationTests }

function TRadIAIDENavigationTests.ExecuteTool(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
begin
  Result := FRegistry.Resolve(AName).Execute(
    TRadIAToolRequest.Create(AName, AArguments, 'test')
  );
end;

procedure TRadIAIDENavigationTests.ListsAndExecutesSafeActions;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('ListIDEActions', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'ViewProjectManager');
  Assert.Contains(LResult.ContentJson, '"enabled":true');

  LResult := ExecuteTool(
    'ExecuteIDEAction',
    '{"actionName":"ViewProjectManager"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual('ViewProjectManager', FFacade.ExecutedAction);
end;

procedure TRadIAIDENavigationTests.ListsProjectGroupAndDependencies;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('ListProjectGroupProjects', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'Application.dproj');
  Assert.Contains(LResult.ContentJson, 'Library.dproj');

  LResult := ExecuteTool('GetProjectDependencies', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'Library.dproj');
end;

procedure TRadIAIDENavigationTests.ListsStructuredUnitSymbols;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('GetUnitSymbols', '{"maxSymbols":20}');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'TRadIAMainForm');
  Assert.Contains(LResult.ContentJson, '"line":42');
end;

procedure TRadIAIDENavigationTests.NavigatesToFileAndSymbol;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'NavigateToFile',
    '{"fileName":"C:\\Work\\Main.pas","line":20,"column":3}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual('C:\Work\Main.pas', FFacade.NavigatedFile);
  Assert.Contains(LResult.ContentJson, '"line":20');

  LResult := ExecuteTool(
    'NavigateToSymbol',
    '{"symbol":"TRadIAMainForm.Save"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual('TRadIAMainForm.Save', FFacade.NavigatedSymbol);
end;

procedure TRadIAIDENavigationTests.NavigatesBetweenCodeAndDesign;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'NavigateToDevelopmentSurface',
    '{"fileName":"C:\\Work\\Main.pas","surface":"design"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(dsDesign, FFacade.NavigatedSurface);
  Assert.AreEqual('C:\Work\Main.pas', FFacade.NavigatedFile);

  LResult := ExecuteTool(
    'NavigateToDevelopmentSurface',
    '{"fileName":"C:\\Work\\Main.pas","surface":"code"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(dsCode, FFacade.NavigatedSurface);
end;

procedure TRadIAIDENavigationTests.NavigationFailureIsStructured;
var
  LResult: TRadIAToolResult;
  LNavigationResult: TRadIANavigationResult;
begin
  LResult := ExecuteTool(
    'NavigateToSymbol',
    '{"symbol":"Missing"}'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('navigation_failed', LResult.ErrorCode);
  LNavigationResult := TRadIANavigationResult.Failed('failure');
  Assert.Contains(LNavigationResult.ToDiagnosticText, 'failure');
end;

procedure TRadIAIDENavigationTests.RegistersCompleteNavigationCatalog;
var
  LTool: IRadIATool;
begin
  Assert.AreEqual(8, FRegistry.Count);
  Assert.IsTrue(FRegistry.TryResolve('ListProjectGroupProjects', LTool));
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);
  Assert.IsTrue(FRegistry.TryResolve('NavigateToFile', LTool));
  Assert.AreEqual(trReversibleWrite, LTool.Descriptor.Risk);
  Assert.IsTrue(
    FRegistry.TryResolve('NavigateToDevelopmentSurface', LTool)
  );
  Assert.AreEqual(trReversibleWrite, LTool.Descriptor.Risk);
  Assert.IsTrue(FRegistry.TryResolve('ExecuteIDEAction', LTool));
  Assert.AreEqual(trExecution, LTool.Descriptor.Risk);
end;

procedure TRadIAIDENavigationTests.RejectsInvalidArguments;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('NavigateToFile', '{}');
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_arguments', LResult.ErrorCode);

  LResult := ExecuteTool('GetUnitSymbols', '{"maxSymbols":"many"}');
  Assert.IsFalse(LResult.Success);

  LResult := ExecuteTool('NavigateToSymbol', '[]');
  Assert.IsFalse(LResult.Success);
end;

procedure TRadIAIDENavigationTests.ScannerHonorsMaximum;
var
  LSymbols: TArray<TRadIAUnitSymbol>;
begin
  LSymbols := TRadIAUnitSymbolScanner.Scan(
    'procedure First;' + sLineBreak +
    'procedure Second;',
    1
  );
  Assert.AreEqual<Integer>(1, Length(LSymbols));
  Assert.AreEqual('First', LSymbols[0].Name);
  Assert.AreEqual<Integer>(
    0,
    Length(TRadIAUnitSymbolScanner.Scan('procedure X;', 0))
  );
end;

procedure TRadIAIDENavigationTests.ScannerFindsSymbolAtCursorLine;
var
  LSymbol: TRadIAUnitSymbol;
begin
  Assert.IsTrue(
    TRadIAUnitSymbolScanner.TryFindAtLine(
      '  TRadIAItem = class' + sLineBreak +
      '  end;' + sLineBreak +
      sLineBreak +
      'procedure TRadIAItem.Save;' + sLineBreak +
      'begin' + sLineBreak +
      '  DoWork;' + sLineBreak +
      'end;',
      6,
      LSymbol
    )
  );
  Assert.AreEqual('procedure', LSymbol.Kind);
  Assert.AreEqual('TRadIAItem.Save', LSymbol.Name);
  Assert.AreEqual(4, LSymbol.Line);
end;

procedure TRadIAIDENavigationTests.ScannerRejectsLineBeforeFirstSymbol;
var
  LSymbol: TRadIAUnitSymbol;
begin
  Assert.IsFalse(
    TRadIAUnitSymbolScanner.TryFindAtLine(
      'unit Sample;' + sLineBreak +
      sLineBreak +
      'procedure Execute;',
      2,
      LSymbol
    )
  );
  Assert.AreEqual('', LSymbol.Name);
end;

procedure TRadIAIDENavigationTests.ScannerRecognizesTypesAndRoutines;
var
  LSymbols: TArray<TRadIAUnitSymbol>;
begin
  LSymbols := TRadIAUnitSymbolScanner.Scan(
    '  TRadIAItem = class(TObject)' + sLineBreak +
    '  TRadIAData = record' + sLineBreak +
    '  IRadIAService = interface' + sLineBreak +
    'class function TRadIAItem.Create: TObject;' + sLineBreak +
    'procedure TRadIAItem.Save;',
    20
  );
  Assert.AreEqual<Integer>(5, Length(LSymbols));
  Assert.AreEqual('class', LSymbols[0].Kind);
  Assert.AreEqual('TRadIAItem', LSymbols[0].Name);
  Assert.AreEqual('function', LSymbols[3].Kind);
  Assert.AreEqual(4, LSymbols[3].Line);
end;

procedure TRadIAIDENavigationTests.Setup;
begin
  FFacade := TRadIAFakeIDENavigationFacade.Create;
  FFacadeReference := FFacade;
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAIDENavigationTools(FRegistry, FFacadeReference);
end;

procedure TRadIAIDENavigationTests.TearDown;
begin
  FRegistry := nil;
  FFacadeReference := nil;
  FFacade := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAIDENavigationTests);

end.
