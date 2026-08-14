unit RadIA.Tests.ThreadingAssistant;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAThreadingAssistantTests = class
  public
    [Test]
    procedure DetectsUnsafeBackgroundWork;
    [Test]
    procedure RejectsReplacementWithoutSafeguards;
    [Test]
    procedure PreparesReplacementWithSafeguards;
  end;

implementation

uses
  RadIA.Core.Patches,
  RadIA.Core.ThreadingAssistant,
  RadIA.Core.Workspace,
  System.DateUtils,
  System.SysUtils;

type
  TRadIAThreadWorkspaceStub = class(TInterfacedObject, IRadIAWorkspaceFacade)
  public
    Content: string;
    constructor Create(const AContent: string);
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

  TRadIAThreadPatchStub = class(TInterfacedObject, IRadIAPatchService)
  public
    Prepared: Boolean;
    function Apply(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
    function Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
  end;

constructor TRadIAThreadWorkspaceStub.Create(const AContent: string);
begin
  inherited Create;
  Content := AContent;
end;

function TRadIAThreadWorkspaceStub.GetActiveProject: TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create('Test', '', '', '', '');
end;

function TRadIAThreadWorkspaceStub.GetActiveUnit: string;
begin
  Result := 'Worker.pas';
end;

function TRadIAThreadWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAThreadWorkspaceStub.GetCursorPosition: TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIAThreadWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := TRadIAEditorContent.Create('Worker', 'Worker.pas', Content, 'revision', Length(Content), False);
end;

function TRadIAThreadWorkspaceStub.GetEditorSelection: TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAThreadWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Test', 'Win32', False, []);
end;

function TRadIAThreadWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := [];
end;

function TRadIAThreadWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := [];
end;

function TRadIAThreadPatchStub.Apply(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('', '');
end;

procedure TRadIAThreadPatchStub.Clear;
begin
end;

function TRadIAThreadPatchStub.Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
begin
  Prepared := True;
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    'thread-preview',
    ASpec,
    ASpec.OriginalText,
    ASpec.ReplacementText,
    'new-revision',
    IncMinute(Now, 10)
  ));
end;

function TRadIAThreadPatchStub.Revert(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('', '');
end;

procedure TRadIAThreadingAssistantTests.DetectsUnsafeBackgroundWork;
var
  LAnalysis: TRadIAThreadAnalysis;
  LService: IRadIAThreadingAssistantService;
begin
  LService := TRadIAThreadingAssistantService.Create(
    TRadIAThreadWorkspaceStub.Create(
      'TTask.Run(procedure begin Form1.Caption := ''Done''; end);'
    ),
    TRadIAThreadPatchStub.Create
  );
  LAnalysis := LService.Analyze;
  Assert.IsTrue(LAnalysis.BackgroundWork);
  Assert.AreEqual(3, Length(LAnalysis.Risks));
end;

procedure TRadIAThreadingAssistantTests.RejectsReplacementWithoutSafeguards;
var
  LPatch: TRadIAThreadPatchStub;
  LResult: TRadIAThreadPreparation;
  LService: IRadIAThreadingAssistantService;
begin
  LPatch := TRadIAThreadPatchStub.Create;
  LService := TRadIAThreadingAssistantService.Create(
    TRadIAThreadWorkspaceStub.Create('OldCall;'),
    LPatch
  );
  LResult := LService.PrepareReplacement(
    'OldCall;',
    'TTask.Run(procedure begin Form1.Caption := ''Done''; end);'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('unsafe_replacement', LResult.ErrorCode);
  Assert.IsFalse(LPatch.Prepared);
end;

procedure TRadIAThreadingAssistantTests.PreparesReplacementWithSafeguards;
var
  LPatch: TRadIAThreadPatchStub;
  LReplacement: string;
  LResult: TRadIAThreadPreparation;
  LService: IRadIAThreadingAssistantService;
begin
  LPatch := TRadIAThreadPatchStub.Create;
  LService := TRadIAThreadingAssistantService.Create(
    TRadIAThreadWorkspaceStub.Create('OldCall;'),
    LPatch
  );
  LReplacement :=
    'TTask.Run(procedure begin try if CancellationToken.IsCancellationRequested then Exit; ' +
    'TThread.Queue(nil, procedure begin Form1.Caption := ''Done''; end); except end; end);';
  LResult := LService.PrepareReplacement('OldCall;', LReplacement);
  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(LPatch.Prepared);
  Assert.AreEqual('thread-preview', LResult.Patch.Preview.Id);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAThreadingAssistantTests);

end.
