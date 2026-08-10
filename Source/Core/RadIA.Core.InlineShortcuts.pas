unit RadIA.Core.InlineShortcuts;

interface

type
  TRadIAInlineShortcutAction = (
    isaRequest,
    isaAcceptAll,
    isaAcceptNextWord,
    isaAlternative,
    isaCompletionNext,
    isaCompletionPrevious,
    isaReject,
    isaTerminal,
    isaReviewAccept,
    isaReviewReject,
    isaReviewNext,
    isaReviewPrevious,
    isaReviewEdit,
    isaReviewExplain,
    isaReviewApply,
    isaReviewClear
  );

  TRadIAInlineShortcutProfile = record
  private
    FShortcuts: array[TRadIAInlineShortcutAction] of Word;
  public
    class function ActionName(
      const AAction: TRadIAInlineShortcutAction
    ): string; static;
    class function Default: TRadIAInlineShortcutProfile; static;
    class function DefaultText: string; static;
    class function TryParse(
      const AText: string;
      out AProfile: TRadIAInlineShortcutProfile;
      out AError: string
    ): Boolean; static;
    function ShortcutFor(
      const AAction: TRadIAInlineShortcutAction
    ): Word;
    function ToText: string;
  end;

  IRadIAInlineShortcutConfig = interface
    ['{1DB8E1C4-1772-4905-942D-C8EFEEA2A411}']
    function GetInlineShortcutProfile: string;
    procedure SetInlineShortcutProfile(const AValue: string);
    property InlineShortcutProfile: string
      read GetInlineShortcutProfile
      write SetInlineShortcutProfile;
  end;

implementation

uses
  System.Classes,
  System.StrUtils,
  System.SysUtils,
  Vcl.Menus,
  Winapi.Windows;

type
  TRadIAInlineShortcutSeen = array[TRadIAInlineShortcutAction] of Boolean;

function TryResolveInlineShortcutAction(
  const AName: string;
  out AAction: TRadIAInlineShortcutAction
): Boolean;
var
  LAction: TRadIAInlineShortcutAction;
begin
  for LAction := Low(TRadIAInlineShortcutAction) to
    High(TRadIAInlineShortcutAction) do
    if SameText(
      AName,
      TRadIAInlineShortcutProfile.ActionName(LAction)
    ) then
    begin
      AAction := LAction;
      Exit(True);
    end;
  Result := False;
end;

function TryParseInlineShortcutPair(
  const APair: string;
  var AProfile: TRadIAInlineShortcutProfile;
  var ASeen: TRadIAInlineShortcutSeen;
  out AError: string
): Boolean;
var
  LAction: TRadIAInlineShortcutAction;
  LIndex: Integer;
  LName: string;
  LShortcut: TShortCut;
  LValue: string;
begin
  LIndex := Pos('=', APair);
  if LIndex <= 1 then
  begin
    AError := 'Each shortcut must use action=keys.';
    Exit(False);
  end;
  LName := Trim(Copy(APair, 1, LIndex - 1));
  LValue := Trim(Copy(APair, LIndex + 1, MaxInt));
  if not TryResolveInlineShortcutAction(LName, LAction) then
  begin
    AError := 'Unknown RadIA shortcut action: ' + LName;
    Exit(False);
  end;
  if ASeen[LAction] then
  begin
    AError := 'Duplicate inline shortcut action: ' + LName;
    Exit(False);
  end;
  LShortcut := TextToShortCut(
    ReplaceText(LValue, 'Backspace', 'BkSp')
  );
  if LShortcut = 0 then
  begin
    AError := 'Invalid shortcut for ' + LName + ': ' + LValue;
    Exit(False);
  end;
  AProfile.FShortcuts[LAction] := LShortcut;
  ASeen[LAction] := True;
  Result := True;
end;

function ValidateInlineShortcutProfile(
  const AProfile: TRadIAInlineShortcutProfile;
  const ASeen: TRadIAInlineShortcutSeen;
  out AError: string
): Boolean;
var
  LAction: TRadIAInlineShortcutAction;
  LIndex: Integer;
begin
  for LAction := Low(TRadIAInlineShortcutAction) to
    High(TRadIAInlineShortcutAction) do
    if not ASeen[LAction] then
    begin
      if not (LAction in [
        isaTerminal,
        isaCompletionNext,
        isaCompletionPrevious,
        isaReviewAccept,
        isaReviewReject,
        isaReviewNext,
        isaReviewPrevious,
        isaReviewEdit,
        isaReviewExplain,
        isaReviewApply,
        isaReviewClear
      ]) then
      begin
        AError := 'Missing RadIA shortcut action: ' +
          TRadIAInlineShortcutProfile.ActionName(LAction);
        Exit(False);
      end;
    end;
  for LAction := Low(TRadIAInlineShortcutAction) to
    High(TRadIAInlineShortcutAction) do
    for LIndex := Ord(LAction) + 1 to
      Ord(High(TRadIAInlineShortcutAction)) do
      if AProfile.FShortcuts[LAction] =
        AProfile.FShortcuts[TRadIAInlineShortcutAction(LIndex)] then
      begin
        AError := 'RadIA shortcuts must be unique.';
        Exit(False);
      end;
  Result := True;
end;

class function TRadIAInlineShortcutProfile.ActionName(
  const AAction: TRadIAInlineShortcutAction
): string;
begin
  case AAction of
    isaRequest:
      Result := 'request';
    isaAcceptAll:
      Result := 'accept';
    isaAcceptNextWord:
      Result := 'nextWord';
    isaAlternative:
      Result := 'alternative';
    isaCompletionNext:
      Result := 'completionNext';
    isaCompletionPrevious:
      Result := 'completionPrevious';
    isaReject:
      Result := 'reject';
    isaTerminal:
      Result := 'terminal';
    isaReviewAccept:
      Result := 'reviewAccept';
    isaReviewReject:
      Result := 'reviewReject';
    isaReviewNext:
      Result := 'reviewNext';
    isaReviewPrevious:
      Result := 'reviewPrevious';
    isaReviewEdit:
      Result := 'reviewEdit';
    isaReviewExplain:
      Result := 'reviewExplain';
    isaReviewApply:
      Result := 'reviewApply';
    isaReviewClear:
      Result := 'reviewClear';
  else
    Result := '';
  end;
end;

class function TRadIAInlineShortcutProfile.Default:
  TRadIAInlineShortcutProfile;
begin
  Result.FShortcuts[isaRequest] := ShortCut(VK_SPACE, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaAcceptAll] := ShortCut(VK_RIGHT, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaAcceptNextWord] :=
    ShortCut(VK_DOWN, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaAlternative] :=
    ShortCut(VK_OEM_6, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaCompletionNext] :=
    ShortCut(VK_DOWN, [ssCtrl, ssShift]);
  Result.FShortcuts[isaCompletionPrevious] :=
    ShortCut(VK_UP, [ssCtrl, ssShift]);
  Result.FShortcuts[isaReject] := ShortCut(VK_BACK, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaTerminal] := ShortCut(Ord('T'), [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewAccept] :=
    ShortCut(VK_RETURN, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewReject] :=
    ShortCut(Ord('R'), [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewNext] :=
    ShortCut(VK_NEXT, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewPrevious] :=
    ShortCut(VK_PRIOR, [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewEdit] :=
    ShortCut(Ord('E'), [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewExplain] :=
    ShortCut(Ord('I'), [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewApply] :=
    ShortCut(Ord('A'), [ssCtrl, ssAlt]);
  Result.FShortcuts[isaReviewClear] :=
    ShortCut(VK_DELETE, [ssCtrl, ssAlt]);
end;

class function TRadIAInlineShortcutProfile.DefaultText: string;
begin
  Result := Default.ToText;
end;

function TRadIAInlineShortcutProfile.ShortcutFor(
  const AAction: TRadIAInlineShortcutAction
): Word;
begin
  Result := FShortcuts[AAction];
end;

function TRadIAInlineShortcutProfile.ToText: string;
var
  LAction: TRadIAInlineShortcutAction;
begin
  Result := '';
  for LAction := Low(TRadIAInlineShortcutAction) to
    High(TRadIAInlineShortcutAction) do
  begin
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + ActionName(LAction) + '=' +
      ShortCutToText(FShortcuts[LAction]);
  end;
end;

class function TRadIAInlineShortcutProfile.TryParse(
  const AText: string;
  out AProfile: TRadIAInlineShortcutProfile;
  out AError: string
): Boolean;
var
  LPair: string;
  LPairs: TStringList;
  LSeen: TRadIAInlineShortcutSeen;
begin
  AProfile := TRadIAInlineShortcutProfile.Default;
  AError := '';
  FillChar(LSeen, SizeOf(LSeen), 0);
  LPairs := TStringList.Create;
  try
    LPairs.StrictDelimiter := True;
    LPairs.Delimiter := ';';
    LPairs.DelimitedText := AText;
    for LPair in LPairs do
      if not TryParseInlineShortcutPair(
        LPair,
        AProfile,
        LSeen,
        AError
      ) then
        Exit(False);
    Result := ValidateInlineShortcutProfile(AProfile, LSeen, AError);
  finally
    LPairs.Free;
  end;
end;

end.
