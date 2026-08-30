unit RadIA.Tests.OTAHelper;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces;

type
  TMockEditorAdapter = class(TInterfacedObject, IRadIAEditorAdapter)
  private
    FText: string;
    FSelectedText: string;
    FCursorLine: Integer;
    FCursorColumn: Integer;
    FAutoIndent: Boolean;
    FActiveUnitName: string;
    FActiveProjectName: string;
    FActiveProjectFolder: string;
    FOpenProjectCalled: Boolean;
    FOpenProjectPath: string;
  public
    constructor Create;
    function GetText: string;
    function GetSelectedText: string;
    procedure ReplaceSelection(const AText: string);
    procedure ReplaceText(const AOffset, ALength: Integer; const AText: string);
    procedure InsertText(const AText: string);
    procedure InsertTextAt(const ALine, AColumn: Integer; const AText: string);
    function GetCursorLine: Integer;
    function GetCursorColumn: Integer;
    procedure SetCursorPosition(const ALine, AColumn: Integer);
    function GetLineText(const ALine: Integer): string;
    function GetAutoIndent: Boolean;
    procedure SetAutoIndent(const AValue: Boolean);
    procedure RefreshView;
    function GetActiveUnitName: string;
    function GetActiveProjectName: string;
    function GetActiveProjectFolder: string;
    function OpenProject(const AProjectPath: string): Boolean;

    property Text: string read FText write FText;
    property SelectedText: string read FSelectedText write FSelectedText;
    property CursorLine: Integer read FCursorLine write FCursorLine;
    property CursorColumn: Integer read FCursorColumn write FCursorColumn;
    property ActiveUnitName: string read FActiveUnitName write FActiveUnitName;
    property ActiveProjectName: string read FActiveProjectName write FActiveProjectName;
    property ActiveProjectFolder: string read FActiveProjectFolder write FActiveProjectFolder;
    property OpenProjectCalled: Boolean read FOpenProjectCalled;
    property OpenProjectPath: string read FOpenProjectPath;
  end;

  [TestFixture]
  TTestOTAHelper = class
  private
    FMockEditor: TMockEditorAdapter;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestNormalizeLineBreaks;
    [Test]
    procedure TestGetActiveEditorText;
    [Test]
    procedure TestReplaceActiveEditorText;
    [Test]
    procedure TestReplaceActiveEditorTextMatchesDifferentLineBreaks;
    [Test]
    procedure TestReplaceActiveEditorTextDoesNotInsertWhenTargetChanged;
    [Test]
    procedure TestInsertTextAtCursor;
    [Test]
    procedure TestInsertTextAtLineColumn;
    [Test]
    procedure TestGetIndentPrefix;
    [Test]
    procedure TestMetadata;
  end;

implementation

uses
  RadIA.OTA.Helper, RadIA.Core.Container, System.SysUtils, System.Classes;

{ TMockEditorAdapter }

constructor TMockEditorAdapter.Create;
begin
  inherited Create;
  FCursorLine := 1;
  FCursorColumn := 1;
  FAutoIndent := True;
end;

function TMockEditorAdapter.GetText: string;
begin
  Result := FText;
end;

function TMockEditorAdapter.GetSelectedText: string;
begin
  Result := FSelectedText;
end;

procedure TMockEditorAdapter.ReplaceSelection(const AText: string);
begin
  if not FSelectedText.IsEmpty then
  begin
    FText := FText.Replace(FSelectedText, AText);
    FSelectedText := '';
  end
  else
  begin
    InsertText(AText);
  end;
end;

procedure TMockEditorAdapter.ReplaceText(const AOffset, ALength: Integer; const AText: string);
var
  LUtf8Text: UTF8String;
  LInsertUtf8: UTF8String;
  LNewUtf8: UTF8String;
begin
  LUtf8Text := UTF8Encode(FText);
  LInsertUtf8 := UTF8Encode(AText);
  LNewUtf8 := Copy(LUtf8Text, 1, AOffset) + LInsertUtf8 + Copy(LUtf8Text, AOffset + ALength + 1, MaxInt);
  FText := string(LNewUtf8);
end;

procedure TMockEditorAdapter.InsertText(const AText: string);
begin
  InsertTextAt(FCursorLine, FCursorColumn, AText);
end;

procedure TMockEditorAdapter.InsertTextAt(const ALine, AColumn: Integer; const AText: string);
var
  LLines: TStringList;
  LLineText: string;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := FText;
    while LLines.Count < ALine do
      LLines.Add('');

    LLineText := LLines[ALine - 1];
    if AColumn > Length(LLineText) then
      LLineText := LLineText + StringOfChar(' ', AColumn - Length(LLineText) - 1);

    Insert(AText, LLineText, AColumn);
    LLines[ALine - 1] := LLineText;
    FText := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function TMockEditorAdapter.GetCursorLine: Integer;
begin
  Result := FCursorLine;
end;

function TMockEditorAdapter.GetCursorColumn: Integer;
begin
  Result := FCursorColumn;
end;

procedure TMockEditorAdapter.SetCursorPosition(const ALine, AColumn: Integer);
begin
  FCursorLine := ALine;
  FCursorColumn := AColumn;
end;

function TMockEditorAdapter.GetLineText(const ALine: Integer): string;
var
  LLines: TStringList;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := FText;
    if (ALine > 0) and (ALine <= LLines.Count) then
      Result := LLines[ALine - 1];
  finally
    LLines.Free;
  end;
end;

function TMockEditorAdapter.GetAutoIndent: Boolean;
begin
  Result := FAutoIndent;
end;

procedure TMockEditorAdapter.SetAutoIndent(const AValue: Boolean);
begin
  FAutoIndent := AValue;
end;

procedure TMockEditorAdapter.RefreshView;
begin
  // No action required in mock editor adapter
end;

function TMockEditorAdapter.GetActiveUnitName: string;
begin
  Result := FActiveUnitName;
end;

function TMockEditorAdapter.GetActiveProjectName: string;
begin
  Result := FActiveProjectName;
end;

function TMockEditorAdapter.GetActiveProjectFolder: string;
begin
  Result := FActiveProjectFolder;
end;

function TMockEditorAdapter.OpenProject(const AProjectPath: string): Boolean;
begin
  FOpenProjectCalled := True;
  FOpenProjectPath := AProjectPath;
  Result := True;
end;

{ TTestOTAHelper }

procedure TTestOTAHelper.Setup;
begin
  FMockEditor := TMockEditorAdapter.Create;
  TRadIAContainer.Register<IRadIAEditorAdapter>(FMockEditor);
end;

procedure TTestOTAHelper.TearDown;
begin
  TRadIAContainer.Clear;
end;

procedure TTestOTAHelper.TestNormalizeLineBreaks;
begin
  Assert.AreEqual('a'#13#10'b'#13#10'c', TRadIAOTAHelper.NormalizeLineBreaks('a'#10'b'#13'c'));
end;

procedure TTestOTAHelper.TestGetActiveEditorText;
var
  LText: string;
begin
  FMockEditor.Text := 'Unit content';
  FMockEditor.SelectedText := 'content';

  Assert.IsTrue(TRadIAOTAHelper.GetActiveEditorText(LText, True));
  Assert.AreEqual('content', LText);

  Assert.IsTrue(TRadIAOTAHelper.GetActiveEditorText(LText, False));
  Assert.AreEqual('Unit content', LText);
end;

procedure TTestOTAHelper.TestReplaceActiveEditorText;
begin
  FMockEditor.Text := 'Original content text';

  // Substituição de todo o buffer
  Assert.IsTrue(TRadIAOTAHelper.ReplaceActiveEditorText('New whole text', True));
  Assert.AreEqual('New whole text', FMockEditor.Text);

  // Substituição de match de texto original
  FMockEditor.Text := 'Original content text';
  Assert.IsTrue(TRadIAOTAHelper.ReplaceActiveEditorText('replaced', False, 'content'));
  Assert.AreEqual('Original replaced text', FMockEditor.Text);

  // Substituição com seleção
  FMockEditor.Text := 'Original content text';
  FMockEditor.SelectedText := 'content';
  FMockEditor.CursorColumn := 10;
  Assert.IsTrue(TRadIAOTAHelper.ReplaceActiveEditorText('selected'));
  Assert.AreEqual('Original selected text'#13#10, FMockEditor.Text);
end;

procedure TTestOTAHelper.TestReplaceActiveEditorTextMatchesDifferentLineBreaks;
const
  COriginalMethod = 'procedure DoWork;'#13#10'begin'#13#10'  // implement'#13#10'end;';
  CGeneratedMethod = 'procedure DoWork;'#13#10'begin'#13#10'  Run;'#13#10'end;';
begin
  FMockEditor.Text := 'implementation'#10#10 +
    'procedure DoWork;'#10'begin'#10'  // implement'#10'end;'#10#10'end.';

  Assert.IsTrue(
    TRadIAOTAHelper.ReplaceActiveEditorText(CGeneratedMethod, False, COriginalMethod)
  );
  Assert.AreEqual(
    'implementation'#10#10 + CGeneratedMethod + #10#10'end.',
    FMockEditor.Text
  );
  Assert.Contains(FMockEditor.Text, '  Run;');
  Assert.IsFalse(FMockEditor.Text.Contains('// implement'));
end;

procedure TTestOTAHelper.TestReplaceActiveEditorTextDoesNotInsertWhenTargetChanged;
const
  CChangedBuffer = 'procedure DoWork;'#13#10'begin'#13#10'  ExistingCode;'#13#10'end;';
  COriginalMethod = 'procedure DoWork;'#13#10'begin'#13#10'  // implement'#13#10'end;';
begin
  FMockEditor.Text := CChangedBuffer;
  FMockEditor.CursorLine := 3;
  FMockEditor.CursorColumn := 3;

  Assert.IsFalse(
    TRadIAOTAHelper.ReplaceActiveEditorText('procedure DoWork; begin Run; end;', False, COriginalMethod)
  );
  Assert.AreEqual(CChangedBuffer, FMockEditor.Text);
end;

procedure TTestOTAHelper.TestInsertTextAtCursor;
begin
  FMockEditor.Text := 'Line 1';
  FMockEditor.CursorLine := 1;
  FMockEditor.CursorColumn := 7; // Fim de 'Line 1'

  Assert.IsTrue(TRadIAOTAHelper.InsertTextAtCursor(' inserted'));
  Assert.AreEqual('Line 1 inserted'#13#10, FMockEditor.Text);
end;

procedure TTestOTAHelper.TestInsertTextAtLineColumn;
begin
  FMockEditor.Text := 'Line 1'#13#10'Line 2';

  Assert.IsTrue(TRadIAOTAHelper.InsertTextAtLineColumn(' inserted', 2, 7));
  Assert.AreEqual('Line 1'#13#10'Line 2 inserted'#13#10, FMockEditor.Text);
end;

procedure TTestOTAHelper.TestGetIndentPrefix;
begin
  FMockEditor.Text := '  MyIndentedCode';
  FMockEditor.CursorLine := 1;
  FMockEditor.CursorColumn := 5;

  Assert.IsTrue(TRadIAOTAHelper.InsertTextAtCursor('// '));
end;

procedure TTestOTAHelper.TestMetadata;
begin
  FMockEditor.ActiveUnitName := 'MyUnit';
  FMockEditor.ActiveProjectName := 'MyProj';
  FMockEditor.ActiveProjectFolder := 'C:\Proj\';

  Assert.AreEqual('MyUnit', TRadIAOTAHelper.GetActiveUnitName);
  Assert.AreEqual('MyProj', TRadIAOTAHelper.GetActiveProjectName);
  Assert.AreEqual('C:\Proj\', TRadIAOTAHelper.GetActiveProjectFolder);

  Assert.IsTrue(TRadIAOTAHelper.OpenProjectInIDE('dummy.dproj'));
  Assert.IsTrue(FMockEditor.OpenProjectCalled);
  Assert.AreEqual('dummy.dproj', FMockEditor.OpenProjectPath);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestOTAHelper);

end.
