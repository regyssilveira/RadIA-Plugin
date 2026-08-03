unit RadIA.Core.EditorAdapter;

interface

uses
  RadIA.Core.Interfaces;

type
  TRadIAOTAEditorAdapter = class(TInterfacedObject, IRadIAEditorAdapter)
  private
    function GetCurrentEditBuffer: Pointer;
    function GetCurrentEditView: Pointer;
    function ReadFallbackText: string;
  public
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
  end;

implementation

uses
  ToolsAPI, RadIA.Core.Logger, System.SysUtils, System.Classes,
  RadIA.OTA.TextReader;

{ TRadIAOTAEditorAdapter }

function TRadIAOTAEditorAdapter.GetCurrentEditBuffer: Pointer;
var
  LEditorServices: IOTAEditorServices;
begin
  Result := nil;
  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
    Result := LEditorServices.TopBuffer;
end;

function TRadIAOTAEditorAdapter.GetCurrentEditView: Pointer;
var
  LEditorServices: IOTAEditorServices;
begin
  Result := nil;
  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
    Result := LEditorServices.TopView;
end;

function TRadIAOTAEditorAdapter.ReadFallbackText: string;
var
  LModuleServices: IOTAModuleServices;
  LModule: IOTAModule;
  LSourceEditor: IOTASourceEditor;
  I: Integer;
begin
  Result := '';
  if not Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    Exit;

  LModule := LModuleServices.CurrentModule;
  if not Assigned(LModule) then
    Exit;

  for I := 0 to LModule.GetModuleFileCount - 1 do
  begin
    if Supports(LModule.GetModuleFileEditor(I), IOTASourceEditor, LSourceEditor) then
    begin
      Result := ReadRadIAEditReaderText(
        LSourceEditor.CreateReader
      );
      Break;
    end;
  end;
end;

function TRadIAOTAEditorAdapter.GetText: string;
var
  LEditBuffer: IOTAEditBuffer;
begin
  Result := '';
  LEditBuffer := IOTAEditBuffer(GetCurrentEditBuffer);
  if Assigned(LEditBuffer) then
    Result := ReadRadIAEditReaderText(
      LEditBuffer.CreateReader
    );

  if Result.IsEmpty then
    Result := ReadFallbackText;
end;

function TRadIAOTAEditorAdapter.GetSelectedText: string;
var
  LView: IOTAEditView;
  LEditBlock: IOTAEditBlock;
begin
  Result := '';
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LView) then
  begin
    LEditBlock := LView.Block;
    if Assigned(LEditBlock) and (LEditBlock.Size > 0) and
       ((LEditBlock.StartingColumn <> LEditBlock.EndingColumn) or
        (LEditBlock.StartingRow <> LEditBlock.EndingRow)) then
      Result := LEditBlock.Text;
  end;
end;

procedure TRadIAOTAEditorAdapter.ReplaceSelection(const AText: string);
var
  LEditBuffer: IOTAEditBuffer;
  LEditBlock: IOTAEditBlock;
  LView: IOTAEditView;
  LPosition: IOTAEditPosition;
begin
  LEditBuffer := IOTAEditBuffer(GetCurrentEditBuffer);
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LEditBuffer) and Assigned(LView) then
  begin
    LEditBlock := LEditBuffer.EditBlock;
    if Assigned(LEditBlock) and (LEditBlock.Size > 0) then
    begin
      LPosition := LView.Position;
      LPosition.Move(LEditBlock.StartingRow, LEditBlock.StartingColumn);
      LEditBlock.Delete;
    end;
    InsertText(AText);
    if Assigned(LEditBlock) then
      LEditBlock.Reset;
    if Assigned(LView.Position) then
      LView.Position.Move(LView.Position.Row, LView.Position.Column);
  end;
end;

procedure TRadIAOTAEditorAdapter.ReplaceText(const AOffset, ALength: Integer; const AText: string);
var
  LEditBuffer: IOTAEditBuffer;
  LView: IOTAEditView;
  LEditWriter: IOTAEditWriter;
  LUtf8Text: UTF8String;
begin
  LEditBuffer := IOTAEditBuffer(GetCurrentEditBuffer);
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LEditBuffer) and Assigned(LView) then
  begin
    LEditWriter := LEditBuffer.CreateUndoableWriter;
    if Assigned(LEditWriter) then
    begin
      LEditWriter.CopyTo(AOffset);
      if ALength > 0 then
        LEditWriter.DeleteTo(AOffset + ALength);

      LUtf8Text := UTF8Encode(AText);
      LEditWriter.Insert(PAnsiChar(LUtf8Text));
      if Assigned(LEditBuffer.EditBlock) then
        LEditBuffer.EditBlock.Reset;
      if Assigned(LView.Position) then
        LView.Position.Move(LView.Position.Row, LView.Position.Column);
      RefreshView;
    end;
  end;
end;

procedure TRadIAOTAEditorAdapter.InsertText(const AText: string);
var
  LView: IOTAEditView;
  LPosition: IOTAEditPosition;
begin
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LView) and Assigned(LView.Position) then
  begin
    LPosition := LView.Position;
    LPosition.InsertText(AText);
    RefreshView;
  end;
end;

procedure TRadIAOTAEditorAdapter.InsertTextAt(const ALine, AColumn: Integer; const AText: string);
var
  LView: IOTAEditView;
  LPosition: IOTAEditPosition;
begin
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LView) and Assigned(LView.Position) then
  begin
    LPosition := LView.Position;
    LPosition.Move(ALine, AColumn);
    LPosition.InsertText(AText);
    RefreshView;
  end;
end;

function TRadIAOTAEditorAdapter.GetCursorLine: Integer;
var
  LView: IOTAEditView;
begin
  Result := 0;
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LView) and Assigned(LView.Position) then
    Result := LView.Position.GetRow;
end;

function TRadIAOTAEditorAdapter.GetCursorColumn: Integer;
var
  LView: IOTAEditView;
begin
  Result := 0;
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LView) and Assigned(LView.Position) then
    Result := LView.Position.GetColumn;
end;

procedure TRadIAOTAEditorAdapter.SetCursorPosition(const ALine, AColumn: Integer);
var
  LView: IOTAEditView;
begin
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LView) and Assigned(LView.Position) then
    LView.Position.Move(ALine, AColumn);
end;

function TRadIAOTAEditorAdapter.GetLineText(const ALine: Integer): string;
var
  LEditBuffer: IOTAEditBuffer;
  LEditReader: IOTAEditReader;
  LText: string;
  LLines: TStringList;
begin
  Result := '';
  LEditBuffer := IOTAEditBuffer(GetCurrentEditBuffer);
  if Assigned(LEditBuffer) then
  begin
    LEditReader := LEditBuffer.CreateReader;
    if Assigned(LEditReader) then
    begin
      LText := ReadRadIAEditReaderText(LEditReader);
      LLines := TStringList.Create;
      try
        LLines.Text := LText;
        if (ALine > 0) and (ALine <= LLines.Count) then
          Result := LLines[ALine - 1];
      finally
        LLines.Free;
      end;
    end;
  end;
end;

function TRadIAOTAEditorAdapter.GetAutoIndent: Boolean;
var
  LEditBuffer: IOTAEditBuffer;
  LOptions: IOTABufferOptions;
begin
  Result := False;
  LEditBuffer := IOTAEditBuffer(GetCurrentEditBuffer);
  if Assigned(LEditBuffer) then
  begin
    LOptions := LEditBuffer.BufferOptions;
    if Assigned(LOptions) then
      Result := LOptions.AutoIndent;
  end;
end;

procedure TRadIAOTAEditorAdapter.SetAutoIndent(const AValue: Boolean);
var
  LEditBuffer: IOTAEditBuffer;
  LOptions: IOTABufferOptions;
begin
  LEditBuffer := IOTAEditBuffer(GetCurrentEditBuffer);
  if Assigned(LEditBuffer) then
  begin
    LOptions := LEditBuffer.BufferOptions;
    if Assigned(LOptions) then
      LOptions.AutoIndent := AValue;
  end;
end;

procedure TRadIAOTAEditorAdapter.RefreshView;
var
  LView: IOTAEditView;
begin
  LView := IOTAEditView(GetCurrentEditView);
  if Assigned(LView) then
  begin
    try
      LView.MoveCursorToView;
      LView.MoveViewToCursor;
      LView.Paint;
    except
      on E: Exception do
        TLogger.Log('RefreshView error: ' + E.Message, 'Editor');
    end;
  end;
end;

function TRadIAOTAEditorAdapter.GetActiveUnitName: string;
var
  LEditBuffer: IOTAEditBuffer;
begin
  Result := '';
  LEditBuffer := IOTAEditBuffer(GetCurrentEditBuffer);
  if Assigned(LEditBuffer) then
    Result := ChangeFileExt(ExtractFileName(LEditBuffer.FileName), '');
end;

function TRadIAOTAEditorAdapter.GetActiveProjectName: string;
var
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LProject := LModuleServices.GetActiveProject;
    if Assigned(LProject) then
      Result := ChangeFileExt(ExtractFileName(LProject.FileName), '');
  end;
end;

function TRadIAOTAEditorAdapter.GetActiveProjectFolder: string;
var
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LProject := LModuleServices.GetActiveProject;
    if Assigned(LProject) then
      Result := ExtractFilePath(LProject.FileName);
  end;
end;

function TRadIAOTAEditorAdapter.OpenProject(const AProjectPath: string): Boolean;
var
  LModuleServices: IOTAModuleServices;
begin
  Result := False;
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LModuleServices.OpenModule(AProjectPath);
    Result := True;
  end;
end;

end.
