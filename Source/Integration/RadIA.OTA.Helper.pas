unit RadIA.OTA.Helper;

interface

uses
  RadIA.Core.Interfaces;

type
  { Helper class for interacting with Delphi Open Tools API (OTA) via Adapter }
  TRadIAOTAHelper = class
  private
    class function FormatTextWithIndent(const AText: string; const AEditor: IRadIAEditorAdapter): string;
    class function GetIndentPrefix(const AEditor: IRadIAEditorAdapter): string;
    class function ApplyPrefixToText(const AText, APrefix: string): string;
    class function ReplaceWholeBufferText(const AEditor: IRadIAEditorAdapter; const ANewText: string): Boolean;
    class function ReplaceOriginalTextMatch(const AEditor: IRadIAEditorAdapter;
      const ANewText, AOriginalText: string): Boolean;
    class function InsertFormattedText(const AEditor: IRadIAEditorAdapter; const ANewText: string): Boolean;
  public
    class function NormalizeLineBreaks(const AText: string): string;
    class function GetActiveEditorText(out AText: string; const ASelectedOnly: Boolean = True): Boolean;
    class function ReplaceActiveEditorText(const ANewText: string; const AReplaceWholeBuffer: Boolean = False;
      const AOriginalText: string = ''): Boolean;
    class function InsertTextAtCursor(const AText: string): Boolean;
    class function InsertTextAtLineColumn(const AText: string; const ALine, AColumn: Integer): Boolean;
    class function GetCurrentCursorLine: Integer;
    class function GetActiveUnitName: string;
    class function GetActiveProjectName: string;
    class function GetActiveProjectFolder: string;
    class function OpenProjectInIDE(const AProjectPath: string): Boolean;
    class function GetDelphiVersionName: string;
    class function GetPreferredLanguageInstruction: string;
    class function CleanCodeResponse(const AResponse: string; const AIndent: string = ''): string;
  end;

implementation

uses
  Winapi.Windows, RadIA.Core.Container, System.SysUtils, System.Classes;

{ TRadIAOTAHelper }

class function TRadIAOTAHelper.NormalizeLineBreaks(const AText: string): string;
var
  LNormalizer: IRadIATextNormalizer;
begin
  if TRadIAContainer.TryResolve<IRadIATextNormalizer>(LNormalizer) then
    Result := LNormalizer.NormalizeLineBreaks(AText)
  else
    Result := AText.Replace(#13#10, #10).Replace(#13, #10).Replace(#10, #13#10);
end;

class function TRadIAOTAHelper.GetActiveEditorText(out AText: string; const ASelectedOnly: Boolean): Boolean;
var
  LEditor: IRadIAEditorAdapter;
begin
  Result := False;
  AText := '';
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
  begin
    if ASelectedOnly then
    begin
      AText := LEditor.GetSelectedText;
      Result := not AText.Trim.IsEmpty;
    end
    else
    begin
      AText := LEditor.GetText;
      Result := not AText.Trim.IsEmpty;
    end;
  end;
end;

class function TRadIAOTAHelper.GetIndentPrefix(const AEditor: IRadIAEditorAdapter): string;
var
  LLineText: string;
  LCol: Integer;
  I: Integer;
begin
  Result := '';
  if not Assigned(AEditor) then
    Exit;

  LLineText := AEditor.GetLineText(AEditor.GetCursorLine);
  LCol := AEditor.GetCursorColumn;

  for I := 1 to LCol - 1 do
  begin
    if I <= Length(LLineText) then
    begin
      if LLineText[I] = #9 then
        Result := Result + #9
      else if LLineText[I] = ' ' then
        Result := Result + ' '
      else
        Break;
    end
    else
      Break;
  end;
end;

class function TRadIAOTAHelper.ApplyPrefixToText(const AText, APrefix: string): string;
var
  LLines: TStringList;
  I: Integer;
begin
  Result := AText;
  if APrefix = '' then
    Exit;

  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    if LLines.Count > 1 then
    begin
      for I := 1 to LLines.Count - 1 do
      begin
        if LLines[I] <> '' then
          LLines[I] := APrefix + LLines[I];
      end;
      Result := LLines.Text;
      if (Length(AText) > 0) and (AText[Length(AText)] <> #10) and
         (Length(Result) >= 2) and (Result[Length(Result) - 1] = #13) and
         (Result[Length(Result)] = #10) then
      begin
        SetLength(Result, Length(Result) - 2);
      end;
    end;
  finally
    LLines.Free;
  end;
end;

class function TRadIAOTAHelper.FormatTextWithIndent(const AText: string;
  const AEditor: IRadIAEditorAdapter): string;
var
  LPrefix: string;
begin
  Result := AText;
  if not Assigned(AEditor) then
    Exit;

  LPrefix := GetIndentPrefix(AEditor);
  Result := ApplyPrefixToText(AText, LPrefix);
end;

class function TRadIAOTAHelper.ReplaceWholeBufferText(const AEditor: IRadIAEditorAdapter;
  const ANewText: string): Boolean;
var
  LBufferText: string;
  LBufferSize: Integer;
begin
  Result := False;
  if not Assigned(AEditor) then
    Exit;

  LBufferText := AEditor.GetText;
  LBufferSize := System.SysUtils.TEncoding.UTF8.GetByteCount(LBufferText);

  AEditor.ReplaceText(0, LBufferSize, NormalizeLineBreaks(ANewText));
  Result := True;
end;

class function TRadIAOTAHelper.ReplaceOriginalTextMatch(const AEditor: IRadIAEditorAdapter;
  const ANewText, AOriginalText: string): Boolean;
var
  LBufferText: string;
  LMatchPos, LStartOffset, LLengthBytes: Integer;
begin
  Result := False;
  if not Assigned(AEditor) then
    Exit;

  LBufferText := AEditor.GetText;
  LMatchPos := Pos(AOriginalText, LBufferText);
  if LMatchPos <= 0 then
    Exit;

  LStartOffset := System.SysUtils.TEncoding.UTF8.GetByteCount(Copy(LBufferText, 1, LMatchPos - 1));
  LLengthBytes := System.SysUtils.TEncoding.UTF8.GetByteCount(AOriginalText);

  AEditor.ReplaceText(LStartOffset, LLengthBytes, NormalizeLineBreaks(ANewText));
  Result := True;
end;

class function TRadIAOTAHelper.InsertFormattedText(const AEditor: IRadIAEditorAdapter;
  const ANewText: string): Boolean;
var
  LFormattedText: string;
  LSaveAutoIndent: Boolean;
begin
  Result := False;
  if not Assigned(AEditor) then
    Exit;

  LFormattedText := FormatTextWithIndent(ANewText, AEditor);
  LSaveAutoIndent := AEditor.GetAutoIndent;
  AEditor.SetAutoIndent(False);
  try
    AEditor.InsertText(NormalizeLineBreaks(LFormattedText));
    Result := True;
  finally
    AEditor.SetAutoIndent(LSaveAutoIndent);
  end;
end;

class function TRadIAOTAHelper.ReplaceActiveEditorText(const ANewText: string;
  const AReplaceWholeBuffer: Boolean; const AOriginalText: string): Boolean;
var
  LEditor: IRadIAEditorAdapter;
  LSelectedText: string;
begin
  Result := False;
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
  begin
    if AReplaceWholeBuffer then
      Exit(ReplaceWholeBufferText(LEditor, ANewText));

    LSelectedText := LEditor.GetSelectedText;
    if not LSelectedText.IsEmpty then
    begin
      LEditor.ReplaceSelection('');
    end;

    if LSelectedText.IsEmpty and not AOriginalText.Trim.IsEmpty then
    begin
      if ReplaceOriginalTextMatch(LEditor, ANewText, AOriginalText) then
        Exit(True);
    end;

    Result := InsertFormattedText(LEditor, ANewText);
  end;
end;

class function TRadIAOTAHelper.InsertTextAtCursor(const AText: string): Boolean;
var
  LEditor: IRadIAEditorAdapter;
begin
  Result := False;
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
  begin
    Result := InsertFormattedText(LEditor, AText);
  end;
end;

class function TRadIAOTAHelper.InsertTextAtLineColumn(const AText: string;
  const ALine, AColumn: Integer): Boolean;
var
  LEditor: IRadIAEditorAdapter;
  LSaveAutoIndent: Boolean;
begin
  Result := False;
  if (ALine <= 0) or (AColumn <= 0) then
    Exit;

  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
  begin
    LEditor.SetCursorPosition(ALine, AColumn);
    LSaveAutoIndent := LEditor.GetAutoIndent;
    LEditor.SetAutoIndent(False);
    try
      LEditor.InsertText(NormalizeLineBreaks(AText));
      Result := True;
    finally
      LEditor.SetAutoIndent(LSaveAutoIndent);
    end;
  end;
end;

class function TRadIAOTAHelper.GetCurrentCursorLine: Integer;
var
  LEditor: IRadIAEditorAdapter;
begin
  Result := 0;
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
    Result := LEditor.GetCursorLine;
end;

class function TRadIAOTAHelper.GetActiveUnitName: string;
var
  LEditor: IRadIAEditorAdapter;
begin
  Result := '';
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
    Result := LEditor.GetActiveUnitName;
end;

class function TRadIAOTAHelper.GetActiveProjectName: string;
var
  LEditor: IRadIAEditorAdapter;
begin
  Result := '';
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
    Result := LEditor.GetActiveProjectName;
end;

class function TRadIAOTAHelper.GetActiveProjectFolder: string;
var
  LEditor: IRadIAEditorAdapter;
begin
  Result := '';
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
    Result := LEditor.GetActiveProjectFolder;
end;

class function TRadIAOTAHelper.OpenProjectInIDE(const AProjectPath: string): Boolean;
var
  LEditor: IRadIAEditorAdapter;
begin
  Result := False;
  if TRadIAContainer.TryResolve<IRadIAEditorAdapter>(LEditor) then
    Result := LEditor.OpenProject(AProjectPath);
end;

class function TRadIAOTAHelper.GetDelphiVersionName: string;
begin
{$IF CompilerVersion >= 37.0}
  Result := 'Delphi 13 Florence';
{$ELSE}
  Result := 'Delphi 12 Athens';
{$ENDIF}
end;

class function TRadIAOTAHelper.GetPreferredLanguageInstruction: string;
var
  LLangID: LANGID;
  LPrimaryLang: Byte;
begin
  LLangID := GetUserDefaultUILanguage;
  LPrimaryLang := LLangID and $3FF;

  case LPrimaryLang of
    $16: Result := 'Please reply in Brazilian Portuguese.';
    $0A: Result := 'Please reply in Spanish.';
    $0C: Result := 'Please reply in French.';
    $07: Result := 'Please reply in German.';
    $10: Result := 'Please reply in Italian.';
    else
      Result := 'Please reply in English.';
  end;
end;

function HasCodeFence(const ALines: TStrings): Boolean;
var
  K: Integer;
begin
  Result := False;
  for K := 0 to ALines.Count - 1 do
  begin
    if ALines[K].Trim.StartsWith('```') then
      Exit(True);
  end;
end;

procedure ExtractFenceContent(const ALines, AOutput: TStrings; const AHasFence: Boolean);
var
  K: Integer;
  LLine, LTrimmed: string;
  LInFence, LFoundFence: Boolean;
begin
  LInFence := False;
  LFoundFence := False;
  for K := 0 to ALines.Count - 1 do
  begin
    LLine := ALines[K];
    LTrimmed := LLine.Trim;
    if LTrimmed.StartsWith('```') then
    begin
      if not LInFence then
      begin
        LInFence := True;
        LFoundFence := True;
        Continue;
      end;
      Break;
    end;

    if (AHasFence and LInFence) or ((not AHasFence) and (not LFoundFence)) then
      AOutput.Add(LLine);
  end;
end;

function CountLeadingWhitespace(const ALine: string): Integer;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := Low(ALine) to High(ALine) do
  begin
    if not CharInSet(ALine[LIndex], [' ', #9]) then
      Exit;
    Inc(Result);
  end;
end;

function RemoveLeadingWhitespace(const ALine: string; const ACount: Integer): string;
var
  LIndex: Integer;
  LRemoved: Integer;
begin
  LIndex := Low(ALine);
  LRemoved := 0;
  while (LIndex <= High(ALine)) and (LRemoved < ACount) and CharInSet(ALine[LIndex], [' ', #9]) do
  begin
    Inc(LIndex);
    Inc(LRemoved);
  end;

  Result := Copy(ALine, LIndex, MaxInt);
end;

class function TRadIAOTAHelper.CleanCodeResponse(const AResponse: string; const AIndent: string): string;
var
  LLines: TStringList;
  LOutput: TStringList;
  I: Integer;
  LHasFence: Boolean;
  LMinIndent: Integer;
  LIndentCount: Integer;
begin
  Result := '';
  LLines := TStringList.Create;
  LOutput := TStringList.Create;
  try
    LLines.Text := AResponse;

    LHasFence := HasCodeFence(LLines);
    ExtractFenceContent(LLines, LOutput, LHasFence);

    while (LOutput.Count > 0) and LOutput[0].Trim.IsEmpty do
      LOutput.Delete(0);

    while (LOutput.Count > 0) and LOutput[LOutput.Count - 1].Trim.IsEmpty do
      LOutput.Delete(LOutput.Count - 1);

    LMinIndent := MaxInt;
    for I := 0 to LOutput.Count - 1 do
    begin
      if LOutput[I].Trim.IsEmpty then
        Continue;

      LIndentCount := CountLeadingWhitespace(LOutput[I]);
      if LIndentCount < LMinIndent then
        LMinIndent := LIndentCount;
    end;

    if LMinIndent = MaxInt then
      Exit('');

    for I := 0 to LOutput.Count - 1 do
    begin
      if LOutput[I].Trim.IsEmpty then
        LOutput[I] := ''
      else
        LOutput[I] := AIndent + RemoveLeadingWhitespace(LOutput[I], LMinIndent);
    end;

    Result := LOutput.Text.TrimRight;
  finally
    LOutput.Free;
    LLines.Free;
  end;
end;

end.
