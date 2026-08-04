unit RadIA.Tests.WorkspaceTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIAFakeWorkspaceFacade = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  public
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
  TTestRadIAWorkspaceTools = class
  private
    FExecutor: IRadIAToolExecutor;
    FRegistry: IRadIAToolRegistry;
    function ExecuteTool(
      const AName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestRegistersCompleteReadOnlySlice;
    [Test]
    procedure TestGetIDEStateReturnsStructuredJson;
    [Test]
    procedure TestGetEditorContentReportsTruncation;
    [Test]
    procedure TestGetCompilerMessagesReturnsStructuredMessages;
    [Test]
    procedure TestInvalidLimitReturnsExecutionError;
    [Test]
    procedure TestListOpenFilesReturnsItems;
  end;

implementation

uses
  System.JSON,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceTools;

{ TRadIAFakeWorkspaceFacade }

function TRadIAFakeWorkspaceFacade.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'SampleProject',
    'C:\Sample\SampleProject.dproj',
    'C:\Sample\',
    'Debug',
    'Win32'
  );
end;

function TRadIAFakeWorkspaceFacade.GetActiveUnit: string;
begin
  Result := 'Sample.Unit';
end;

function TRadIAFakeWorkspaceFacade.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  if AMaxCount <= 0 then
    Exit(nil);
  Result := [
    TRadIACompilerMessage.Create(
      cmsError,
      'Undeclared identifier.',
      'Sample.Unit.pas',
      42,
      7
    )
  ];
end;

function TRadIAFakeWorkspaceFacade.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := TRadIAEditorPosition.Create(42, 7);
end;

function TRadIAFakeWorkspaceFacade.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
const
  CContent = 'abcdef';
var
  LContent: string;
  LTruncated: Boolean;
begin
  LTruncated := Length(CContent) > AMaxCharacters;
  if LTruncated then
    LContent := Copy(CContent, Low(CContent), AMaxCharacters)
  else
    LContent := CContent;
  Result := TRadIAEditorContent.Create(
    'Sample.Unit',
    'C:\Sample\Sample.Unit.pas',
    LContent,
    'revision-1',
    Length(CContent),
    LTruncated
  );
end;

function TRadIAFakeWorkspaceFacade.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := TRadIAEditorSelection.Create('selected', 42, 7);
end;

function TRadIAFakeWorkspaceFacade.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'Delphi 12 Athens',
    'Win32',
    False,
    ['EditorRead', 'ProjectRead']
  );
end;

function TRadIAFakeWorkspaceFacade.ListOpenFiles: TArray<string>;
begin
  Result := [
    'C:\Sample\First.pas',
    'C:\Sample\Second.pas'
  ];
end;

function TRadIAFakeWorkspaceFacade.ListProjectUnits: TArray<string>;
begin
  Result := [
    'C:\Sample\Sample.Unit.pas'
  ];
end;

{ TTestRadIAWorkspaceTools }

function TTestRadIAWorkspaceTools.ExecuteTool(
  const AName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
var
  LRequest: TRadIAToolRequest;
begin
  LRequest := TRadIAToolRequest.Create(
    AName,
    AArgumentsJson,
    'workspace-test'
  );
  Result := FExecutor.Execute(LRequest);
end;

procedure TTestRadIAWorkspaceTools.Setup;
var
  LWorkspace: IRadIAWorkspaceFacade;
begin
  FRegistry := TRadIAToolRegistry.Create;
  LWorkspace := TRadIAFakeWorkspaceFacade.Create;
  RegisterRadIAWorkspaceTools(FRegistry, LWorkspace);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

procedure TTestRadIAWorkspaceTools.TearDown;
begin
  FExecutor := nil;
  FRegistry := nil;
end;

procedure TTestRadIAWorkspaceTools.TestGetCompilerMessagesReturnsStructuredMessages;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'GetCompilerMessages',
    '{"maxCount":10}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"severity":"error"');
  Assert.Contains(LResult.ContentJson, '"line":42');
  Assert.Contains(LResult.ContentJson, 'Undeclared identifier.');
end;

procedure TTestRadIAWorkspaceTools.TestGetEditorContentReportsTruncation;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'GetEditorContent',
    '{"maxCharacters":3}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(LResult.Truncated);
  Assert.Contains(LResult.ContentJson, '"content":"abc"');
  Assert.Contains(LResult.ContentJson, '"originalLength":6');
  Assert.Contains(LResult.ContentJson, '"truncated":true');
end;

procedure TTestRadIAWorkspaceTools.TestGetIDEStateReturnsStructuredJson;
var
  LJson: TJSONValue;
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('GetIDEState', '{}');

  Assert.IsTrue(LResult.Success);
  LJson := TJSONObject.ParseJSONValue(LResult.ContentJson);
  try
    Assert.IsNotNull(LJson);
    Assert.AreEqual(
      'Delphi 12 Athens',
      LJson.GetValue<string>('versionName')
    );
    Assert.AreEqual('Win32', LJson.GetValue<string>('platform'));
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIAWorkspaceTools.TestInvalidLimitReturnsExecutionError;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'GetEditorContent',
    '{"maxCharacters":0}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('tool_execution_failed', LResult.ErrorCode);
end;

procedure TTestRadIAWorkspaceTools.TestListOpenFilesReturnsItems;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('ListOpenFiles', '{}');

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'First.pas');
  Assert.Contains(LResult.ContentJson, 'Second.pas');
end;

procedure TTestRadIAWorkspaceTools.TestRegistersCompleteReadOnlySlice;
var
  LTool: IRadIATool;
begin
  Assert.AreEqual(9, FRegistry.Count);
  Assert.IsTrue(FRegistry.TryResolve('GetIDEState', LTool));
  Assert.IsTrue(FRegistry.TryResolve('GetActiveProject', LTool));
  Assert.IsTrue(FRegistry.TryResolve('GetActiveUnit', LTool));
  Assert.IsTrue(FRegistry.TryResolve('ListOpenFiles', LTool));
  Assert.IsTrue(FRegistry.TryResolve('ListProjectUnits', LTool));
  Assert.IsTrue(FRegistry.TryResolve('GetEditorContent', LTool));
  Assert.IsTrue(FRegistry.TryResolve('GetEditorSelection', LTool));
  Assert.IsTrue(FRegistry.TryResolve('GetCursorPosition', LTool));
  Assert.IsTrue(FRegistry.TryResolve('GetCompilerMessages', LTool));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAWorkspaceTools);

end.
