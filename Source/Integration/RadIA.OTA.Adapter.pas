unit RadIA.OTA.Adapter;

interface

uses  RadIA.Core.Interfaces;

type
  TRadIAConcreteIDEAdapter = class(TInterfacedObject, IRadIAIDEAdapter)
  public
    function GetActiveEditorText(out AText: string; const ASelectedOnly: Boolean = True): Boolean;
    function ReplaceActiveEditorText(const ANewText: string; const AReplaceWholeBuffer: Boolean = False;
      const AOriginalText: string = ''): Boolean;
    function InsertTextAtCursor(const AText: string): Boolean;
    function InsertTextAtLineColumn(const AText: string; const ALine, AColumn: Integer): Boolean;
    function GetCurrentCursorLine: Integer;
    function GetActiveUnitName: string;
    function GetActiveProjectName: string;
    function GetActiveProjectFolder: string;
    function OpenProjectInIDE(const AProjectPath: string): Boolean;
    function GetDelphiVersionName: string;
    function GetPreferredLanguageInstruction(
      const APreferredLanguage: string
    ): string;
    function GetLastCompilerError(out AErrorMsg: string; out AFileName: string; out ALine: Integer): Boolean;
  end;

implementation

uses
  RadIA.OTA.Helper, RadIA.OTA.MessageViewHook;

{ TRadIAConcreteIDEAdapter }

function TRadIAConcreteIDEAdapter.GetActiveEditorText(out AText: string; const ASelectedOnly: Boolean): Boolean;
begin
  Result := TRadIAOTAHelper.GetActiveEditorText(AText, ASelectedOnly);
end;

function TRadIAConcreteIDEAdapter.ReplaceActiveEditorText(const ANewText: string; const AReplaceWholeBuffer: Boolean;
  const AOriginalText: string): Boolean;
begin
  Result := TRadIAOTAHelper.ReplaceActiveEditorText(ANewText, AReplaceWholeBuffer, AOriginalText);
end;

function TRadIAConcreteIDEAdapter.InsertTextAtCursor(const AText: string): Boolean;
begin
  Result := TRadIAOTAHelper.InsertTextAtCursor(AText);
end;

function TRadIAConcreteIDEAdapter.InsertTextAtLineColumn(const AText: string; const ALine, AColumn: Integer): Boolean;
begin
  Result := TRadIAOTAHelper.InsertTextAtLineColumn(AText, ALine, AColumn);
end;

function TRadIAConcreteIDEAdapter.GetCurrentCursorLine: Integer;
begin
  Result := TRadIAOTAHelper.GetCurrentCursorLine;
end;

function TRadIAConcreteIDEAdapter.GetActiveUnitName: string;
begin
  Result := TRadIAOTAHelper.GetActiveUnitName;
end;

function TRadIAConcreteIDEAdapter.GetActiveProjectName: string;
begin
  Result := TRadIAOTAHelper.GetActiveProjectName;
end;

function TRadIAConcreteIDEAdapter.GetActiveProjectFolder: string;
begin
  Result := TRadIAOTAHelper.GetActiveProjectFolder;
end;

function TRadIAConcreteIDEAdapter.OpenProjectInIDE(const AProjectPath: string): Boolean;
begin
  Result := TRadIAOTAHelper.OpenProjectInIDE(AProjectPath);
end;

function TRadIAConcreteIDEAdapter.GetDelphiVersionName: string;
begin
  Result := TRadIAOTAHelper.GetDelphiVersionName;
end;

function TRadIAConcreteIDEAdapter.GetPreferredLanguageInstruction(
  const APreferredLanguage: string
): string;
begin
  Result := TRadIAOTAHelper.GetPreferredLanguageInstruction(
    APreferredLanguage
  );
end;

function TRadIAConcreteIDEAdapter.GetLastCompilerError(out AErrorMsg: string; out AFileName: string;
    out ALine: Integer): Boolean;
begin
  Result := TRadIAMessageViewHook.GetLastCompilerError(AErrorMsg, AFileName, ALine);
end;

end.
