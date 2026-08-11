unit RadIA.Core.TerminalScreen;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Terminal;

type
  TRadIATerminalScreenCell = record
  private
    FCharacter: string;
    FStyle: TRadIATerminalTextStyle;
    FWidth: Integer;
  public
    constructor Create(
      const ACharacter: string;
      const AStyle: TRadIATerminalTextStyle;
      const AWidth: Integer = 1
    );
    property Character: string read FCharacter;
    property Style: TRadIATerminalTextStyle read FStyle;
    property Width: Integer read FWidth;
  end;

  TRadIATerminalScreen = class
  private type
    TRadIATerminalParserState = (
      psText,
      psEscape,
      psCsi,
      psOsc,
      psOscEscape
    );
    TRadIATerminalRow = TArray<TRadIATerminalScreenCell>;
  private
    FColumns: Integer;
    FAlternateScreen: Boolean;
    FBracketedPaste: Boolean;
    FCsiPrivate: Boolean;
    FCsiBuffer: string;
    FCursorColumn: Integer;
    FCursorRow: Integer;
    FHardBreaks: TList<Boolean>;
    FMouseMode: Integer;
    FSgrMouse: Boolean;
    FOscBuffer: string;
    FPrimaryBreaks: TArray<Boolean>;
    FPrimaryRows: TArray<TRadIATerminalRow>;
    FPrimaryCursorColumn: Integer;
    FPrimaryCursorRow: Integer;
    FRows: TList<TRadIATerminalRow>;
    FSavedColumn: Integer;
    FSavedRow: Integer;
    FState: TRadIATerminalParserState;
    FStyle: TRadIATerminalTextStyle;
    procedure AddRenderSegment(
      var ASegments: TArray<TRadIATerminalTextSegment>;
      const AText: string;
      const AStyle: TRadIATerminalTextStyle
    );
    procedure ApplyCsi(const AFinalCharacter: Char);
    procedure ApplyPrivateMode(const AEnable: Boolean);
    procedure ApplyOsc;
    procedure ApplyEraseDisplay(const AMode: Integer);
    procedure ApplyEraseLine(const AMode: Integer);
    procedure ApplyExtendedSgr(
      const AParameters: TArray<Integer>;
      var AIndex: Integer;
      const ACode: Integer
    );
    procedure ApplySimpleSgr(const ACode: Integer);
    procedure ApplySgr(const AParameters: TArray<Integer>);
    function Color256ToRgb(const AIndex: Integer): Integer;
    procedure ClearCell(const AColumn: Integer; const ARow: Integer);
    procedure ClearRange(
      const ARow: Integer;
      const AFirstColumn: Integer;
      const ALastColumn: Integer
    );
    procedure EnsureCursor;
    procedure EnsureRow(const ARow: Integer);
    procedure DeleteCharacters(const ACount: Integer);
    procedure InsertBlankCharacters(const ACount: Integer);
    function GetParameter(
      const AParameters: TArray<Integer>;
      const AIndex: Integer;
      const ADefault: Integer
    ): Integer;
    function ParseParameters: TArray<Integer>;
    procedure ProcessCharacter(const ACharacter: Char);
    procedure ProcessCsiCharacter(const ACharacter: Char);
    procedure ProcessEscapeCharacter(const ACharacter: Char);
    procedure ProcessOscCharacter(const ACharacter: Char);
    procedure ProcessTextCharacter(const ACharacter: Char);
    procedure EnterAlternateScreen;
    procedure LeaveAlternateScreen;
    procedure AppendCombiningMark(const AText: string);
    function CharacterWidth(const ACodePoint: Cardinal): Integer;
    function IsCombiningCodePoint(const ACodePoint: Cardinal): Boolean;
    function IsWideBmpFirstRange(const ACodePoint: Cardinal): Boolean;
    function IsWideBmpSecondRange(const ACodePoint: Cardinal): Boolean;
    procedure ReflowCell(const ACell: TRadIATerminalScreenCell);
    procedure ReflowHardBreak;
    procedure ReflowRow(
      const ARow: TRadIATerminalRow;
      const AHardBreak: Boolean
    );
    procedure PutCharacter(const AText: string; const ACodePoint: Cardinal);
    function StylesMatch(
      const ALeft: TRadIATerminalTextStyle;
      const ARight: TRadIATerminalTextStyle
    ): Boolean;
  public
    constructor Create(const AColumns: Integer = 120);
    destructor Destroy; override;
    procedure Clear;
    procedure Feed(const AText: string);
    function RenderSegments: TArray<TRadIATerminalTextSegment>;
    procedure Resize(const AColumns: Integer);
    function PreparePaste(const AText: string): string;
    function EncodeMouse(
      const AButton: Integer;
      const AColumn: Integer;
      const ARow: Integer;
      const APressed: Boolean
    ): string;
    property AlternateScreen: Boolean read FAlternateScreen;
    property BracketedPaste: Boolean read FBracketedPaste;
    property Columns: Integer read FColumns;
    property CursorColumn: Integer read FCursorColumn;
    property MouseMode: Integer read FMouseMode;
  end;

implementation

uses
  System.Math,
  System.StrUtils,
  System.SysUtils;

{ TRadIATerminalScreenCell }

constructor TRadIATerminalScreenCell.Create(
  const ACharacter: string;
  const AStyle: TRadIATerminalTextStyle;
  const AWidth: Integer
);
begin
  FCharacter := ACharacter;
  FStyle := AStyle;
  FWidth := AWidth;
end;

{ TRadIATerminalScreen }

procedure TRadIATerminalScreen.AddRenderSegment(
  var ASegments: TArray<TRadIATerminalTextSegment>;
  const AText: string;
  const AStyle: TRadIATerminalTextStyle
);
var
  LIndex: Integer;
begin
  if AText = '' then
    Exit;
  LIndex := Length(ASegments);
  if (LIndex > 0) and
    StylesMatch(ASegments[LIndex - 1].Style, AStyle) then
  begin
    ASegments[LIndex - 1] := TRadIATerminalTextSegment.Create(
      ASegments[LIndex - 1].Text + AText,
      AStyle
    );
    Exit;
  end;
  SetLength(ASegments, LIndex + 1);
  ASegments[LIndex] := TRadIATerminalTextSegment.Create(AText, AStyle);
end;

procedure TRadIATerminalScreen.ApplyCsi(const AFinalCharacter: Char);
var
  LColumn: Integer;
  LParameters: TArray<Integer>;
  LRow: Integer;
begin
  LParameters := ParseParameters;
  if FCsiPrivate and CharInSet(AFinalCharacter, ['h', 'l']) then
  begin
    ApplyPrivateMode(AFinalCharacter = 'h');
    Exit;
  end;
  case AFinalCharacter of
    '@':
      InsertBlankCharacters(GetParameter(LParameters, 0, 1));
    'A':
      FCursorRow := Max(
        0,
        FCursorRow - GetParameter(LParameters, 0, 1)
      );
    'B':
      Inc(FCursorRow, GetParameter(LParameters, 0, 1));
    'P':
      DeleteCharacters(GetParameter(LParameters, 0, 1));
    'X':
      ClearRange(
        FCursorRow,
        FCursorColumn,
        FCursorColumn + GetParameter(LParameters, 0, 1) - 1
      );
    'C':
      FCursorColumn := Min(
        FColumns - 1,
        FCursorColumn + GetParameter(LParameters, 0, 1)
      );
    'D':
      FCursorColumn := Max(
        0,
        FCursorColumn - GetParameter(LParameters, 0, 1)
      );
    'E':
      begin
        Inc(FCursorRow, GetParameter(LParameters, 0, 1));
        FCursorColumn := 0;
      end;
    'F':
      begin
        FCursorRow := Max(
          0,
          FCursorRow - GetParameter(LParameters, 0, 1)
        );
        FCursorColumn := 0;
      end;
    'G':
      FCursorColumn := EnsureRange(
        GetParameter(LParameters, 0, 1) - 1,
        0,
        FColumns - 1
      );
    'H', 'f':
      begin
        LRow := Max(1, GetParameter(LParameters, 0, 1));
        LColumn := Max(1, GetParameter(LParameters, 1, 1));
        FCursorRow := LRow - 1;
        FCursorColumn := Min(FColumns - 1, LColumn - 1);
      end;
    'J':
      ApplyEraseDisplay(GetParameter(LParameters, 0, 0));
    'K':
      ApplyEraseLine(GetParameter(LParameters, 0, 0));
    'm':
      ApplySgr(LParameters);
    's':
      begin
        FSavedColumn := FCursorColumn;
        FSavedRow := FCursorRow;
      end;
    'u':
      begin
        FCursorColumn := FSavedColumn;
        FCursorRow := FSavedRow;
      end;
  end;
  EnsureCursor;
end;

procedure TRadIATerminalScreen.ApplyEraseDisplay(const AMode: Integer);
var
  LRow: Integer;
begin
  case AMode of
    1:
      begin
        for LRow := 0 to FCursorRow - 1 do
          ClearRange(LRow, 0, FColumns - 1);
        ClearRange(FCursorRow, 0, FCursorColumn);
      end;
    2, 3:
      begin
        FRows.Clear;
        FCursorColumn := 0;
        FCursorRow := 0;
        EnsureCursor;
      end;
  else
    ClearRange(FCursorRow, FCursorColumn, FColumns - 1);
    for LRow := FCursorRow + 1 to FRows.Count - 1 do
      ClearRange(LRow, 0, FColumns - 1);
  end;
end;

procedure TRadIATerminalScreen.ApplyEraseLine(const AMode: Integer);
begin
  case AMode of
    1:
      ClearRange(FCursorRow, 0, FCursorColumn);
    2:
      ClearRange(FCursorRow, 0, FColumns - 1);
  else
    ClearRange(FCursorRow, FCursorColumn, FColumns - 1);
  end;
end;

procedure TRadIATerminalScreen.ApplySgr(
  const AParameters: TArray<Integer>
);
var
  LCode: Integer;
  LIndex: Integer;
begin
  if Length(AParameters) = 0 then
  begin
    FStyle := TRadIATerminalTextStyle.Default;
    Exit;
  end;
  LIndex := 0;
  while LIndex < Length(AParameters) do
  begin
    LCode := AParameters[LIndex];
    if (LCode = 38) or (LCode = 48) then
      ApplyExtendedSgr(AParameters, LIndex, LCode)
    else
      ApplySimpleSgr(LCode);
    Inc(LIndex);
  end;
end;

procedure TRadIATerminalScreen.ApplyExtendedSgr(
  const AParameters: TArray<Integer>;
  var AIndex: Integer;
  const ACode: Integer
);
var
  LRgb: Integer;
begin
  LRgb := -1;
  if (AIndex + 2 < Length(AParameters)) and
    (AParameters[AIndex + 1] = 5) then
  begin
    LRgb := Color256ToRgb(AParameters[AIndex + 2]);
    Inc(AIndex, 2);
  end
  else if (AIndex + 4 < Length(AParameters)) and
    (AParameters[AIndex + 1] = 2) then
  begin
    LRgb := (EnsureRange(AParameters[AIndex + 2], 0, 255) shl 16) or
      (EnsureRange(AParameters[AIndex + 3], 0, 255) shl 8) or
      EnsureRange(AParameters[AIndex + 4], 0, 255);
    Inc(AIndex, 4);
  end;
  if LRgb < 0 then
    Exit;
  if ACode = 38 then
    FStyle := FStyle.WithForegroundRgb(LRgb)
  else
    FStyle := FStyle.WithBackgroundRgb(LRgb);
end;

procedure TRadIATerminalScreen.ApplySimpleSgr(const ACode: Integer);
begin
  case ACode of
    0: FStyle := TRadIATerminalTextStyle.Default;
    1: FStyle := FStyle.WithBold(True);
    3: FStyle := FStyle.WithItalic(True);
    4: FStyle := FStyle.WithUnderline(True);
    7: FStyle := FStyle.WithInverse(True);
    22: FStyle := FStyle.WithBold(False);
    23: FStyle := FStyle.WithItalic(False);
    24: FStyle := FStyle.WithUnderline(False);
    27: FStyle := FStyle.WithInverse(False);
    30..37:
      FStyle := FStyle.WithForeground(
        TRadIATerminalColor(Ord(tcBlack) + ACode - 30)
      );
    39: FStyle := FStyle.WithForeground(tcDefault);
    40..47:
      FStyle := FStyle.WithBackground(
        TRadIATerminalColor(Ord(tcBlack) + ACode - 40)
      );
    49: FStyle := FStyle.WithBackground(tcDefault);
    90..97:
      FStyle := FStyle.WithForeground(
        TRadIATerminalColor(Ord(tcBrightBlack) + ACode - 90)
      );
    100..107:
      FStyle := FStyle.WithBackground(
        TRadIATerminalColor(Ord(tcBrightBlack) + ACode - 100)
      );
  end;
end;

function TRadIATerminalScreen.Color256ToRgb(const AIndex: Integer): Integer;
const
  CBasic: array[0..15] of Integer = (
    $000000, $800000, $008000, $808000,
    $000080, $800080, $008080, $C0C0C0,
    $808080, $FF0000, $00FF00, $FFFF00,
    $0000FF, $FF00FF, $00FFFF, $FFFFFF
  );
  CLevels: array[0..5] of Integer = (0, 95, 135, 175, 215, 255);
var
  LBlue: Integer;
  LGreen: Integer;
  LIndex: Integer;
  LRed: Integer;
begin
  LIndex := EnsureRange(AIndex, 0, 255);
  if LIndex < 16 then
    Exit(CBasic[LIndex]);
  if LIndex >= 232 then
  begin
    LRed := 8 + ((LIndex - 232) * 10);
    Exit((LRed shl 16) or (LRed shl 8) or LRed);
  end;
  Dec(LIndex, 16);
  LRed := CLevels[LIndex div 36];
  LGreen := CLevels[(LIndex div 6) mod 6];
  LBlue := CLevels[LIndex mod 6];
  Result := (LRed shl 16) or (LGreen shl 8) or LBlue;
end;

procedure TRadIATerminalScreen.Clear;
begin
  FRows.Clear;
  FHardBreaks.Clear;
  FCsiBuffer := '';
  FCursorColumn := 0;
  FCursorRow := 0;
  FSavedColumn := 0;
  FSavedRow := 0;
  FState := psText;
  FStyle := TRadIATerminalTextStyle.Default;
  EnsureCursor;
end;

procedure TRadIATerminalScreen.ClearCell(
  const AColumn: Integer;
  const ARow: Integer
);
var
  LRow: TRadIATerminalRow;
begin
  EnsureRow(ARow);
  LRow := FRows[ARow];
  LRow[AColumn] := TRadIATerminalScreenCell.Create(
    ' ',
    TRadIATerminalTextStyle.Default
  );
  FRows[ARow] := LRow;
end;

procedure TRadIATerminalScreen.ClearRange(
  const ARow: Integer;
  const AFirstColumn: Integer;
  const ALastColumn: Integer
);
var
  LColumn: Integer;
begin
  if (ARow < 0) or (ARow >= FRows.Count) then
    Exit;
  for LColumn := Max(0, AFirstColumn) to
    Min(FColumns - 1, ALastColumn) do
    ClearCell(LColumn, ARow);
end;

constructor TRadIATerminalScreen.Create(const AColumns: Integer);
begin
  inherited Create;
  FRows := TList<TRadIATerminalRow>.Create;
  FHardBreaks := TList<Boolean>.Create;
  Resize(AColumns);
  Clear;
end;

destructor TRadIATerminalScreen.Destroy;
begin
  FHardBreaks.Free;
  FRows.Free;
  inherited Destroy;
end;

function TRadIATerminalScreen.EncodeMouse(
  const AButton: Integer;
  const AColumn: Integer;
  const ARow: Integer;
  const APressed: Boolean
): string;
var
  LFinal: Char;
begin
  Result := '';
  if (FMouseMode = 0) or not FSgrMouse then
    Exit;
  if APressed then
    LFinal := 'M'
  else
    LFinal := 'm';
  Result := #27'[<' + IntToStr(Max(0, AButton)) + ';' +
    IntToStr(Max(1, AColumn)) + ';' + IntToStr(Max(1, ARow)) + LFinal;
end;

procedure TRadIATerminalScreen.EnterAlternateScreen;
begin
  if FAlternateScreen then
    Exit;
  FPrimaryRows := FRows.ToArray;
  FPrimaryBreaks := FHardBreaks.ToArray;
  FPrimaryCursorColumn := FCursorColumn;
  FPrimaryCursorRow := FCursorRow;
  FAlternateScreen := True;
  FRows.Clear;
  FHardBreaks.Clear;
  FCursorColumn := 0;
  FCursorRow := 0;
  EnsureCursor;
end;

procedure TRadIATerminalScreen.LeaveAlternateScreen;
begin
  if not FAlternateScreen then
    Exit;
  FRows.Clear;
  FHardBreaks.Clear;
  FRows.AddRange(FPrimaryRows);
  FHardBreaks.AddRange(FPrimaryBreaks);
  FCursorColumn := FPrimaryCursorColumn;
  FCursorRow := FPrimaryCursorRow;
  FPrimaryRows := nil;
  FPrimaryBreaks := nil;
  FAlternateScreen := False;
  EnsureCursor;
end;

function TRadIATerminalScreen.PreparePaste(const AText: string): string;
begin
  if FBracketedPaste then
    Result := #27'[200~' + AText + #27'[201~'
  else
    Result := AText;
end;

procedure TRadIATerminalScreen.ApplyPrivateMode(const AEnable: Boolean);
var
  LMode: Integer;
begin
  for LMode in ParseParameters do
    case LMode of
      1000, 1002, 1003:
        if AEnable then
          FMouseMode := LMode
        else if FMouseMode = LMode then
          FMouseMode := 0;
      1006:
        FSgrMouse := AEnable;
      1047, 1049:
        if AEnable then
          EnterAlternateScreen
        else
          LeaveAlternateScreen;
      2004:
        FBracketedPaste := AEnable;
    end;
end;

procedure TRadIATerminalScreen.ApplyOsc;
var
  LSeparator: Integer;
  LUri: string;
begin
  if not FOscBuffer.StartsWith('8;') then
    Exit;
  LSeparator := PosEx(';', FOscBuffer, 3);
  if LSeparator = 0 then
    Exit;
  LUri := Copy(FOscBuffer, LSeparator + 1, MaxInt);
  FStyle := FStyle.WithHyperlink(LUri);
end;

procedure TRadIATerminalScreen.DeleteCharacters(const ACount: Integer);
var
  LColumn: Integer;
  LOffset: Integer;
  LRow: TRadIATerminalRow;
begin
  LOffset := Min(Max(1, ACount), FColumns - FCursorColumn);
  LRow := FRows[FCursorRow];
  for LColumn := FCursorColumn to FColumns - LOffset - 1 do
    LRow[LColumn] := LRow[LColumn + LOffset];
  for LColumn := FColumns - LOffset to FColumns - 1 do
    LRow[LColumn] := TRadIATerminalScreenCell.Create(
      ' ',
      TRadIATerminalTextStyle.Default
    );
  FRows[FCursorRow] := LRow;
end;

procedure TRadIATerminalScreen.EnsureCursor;
begin
  FCursorColumn := EnsureRange(FCursorColumn, 0, FColumns - 1);
  FCursorRow := Max(0, FCursorRow);
  EnsureRow(FCursorRow);
end;

procedure TRadIATerminalScreen.EnsureRow(const ARow: Integer);
var
  LColumn: Integer;
  LRow: TRadIATerminalRow;
begin
  while FRows.Count <= ARow do
  begin
    SetLength(LRow, FColumns);
    for LColumn := 0 to FColumns - 1 do
      LRow[LColumn] := TRadIATerminalScreenCell.Create(
        ' ',
        TRadIATerminalTextStyle.Default
      );
    FRows.Add(LRow);
    FHardBreaks.Add(False);
  end;
end;

procedure TRadIATerminalScreen.Feed(const AText: string);
var
  LCodePoint: Cardinal;
  LCharacter: Char;
  LIndex: Integer;
  LText: string;
begin
  LIndex := Low(AText);
  while LIndex <= High(AText) do
  begin
    LCharacter := AText[LIndex];
    if (LCharacter >= #$D800) and (LCharacter <= #$DBFF) and
      (LIndex < High(AText)) and (AText[LIndex + 1] >= #$DC00) and
      (AText[LIndex + 1] <= #$DFFF) then
    begin
      LCodePoint := $10000 +
        (Cardinal(Ord(LCharacter) - $D800) shl 10) +
        Cardinal(Ord(AText[LIndex + 1]) - $DC00);
      LText := Copy(AText, LIndex, 2);
      Inc(LIndex, 2);
      if FState = psText then
        PutCharacter(LText, LCodePoint)
      else
      begin
        ProcessCharacter(LCharacter);
        ProcessCharacter(AText[LIndex - 1]);
      end;
      Continue;
    end;
    ProcessCharacter(LCharacter);
    Inc(LIndex);
  end;
end;

procedure TRadIATerminalScreen.InsertBlankCharacters(
  const ACount: Integer
);
var
  LColumn: Integer;
  LOffset: Integer;
  LRow: TRadIATerminalRow;
begin
  LOffset := Min(Max(1, ACount), FColumns - FCursorColumn);
  LRow := FRows[FCursorRow];
  for LColumn := FColumns - 1 downto FCursorColumn + LOffset do
    LRow[LColumn] := LRow[LColumn - LOffset];
  for LColumn := FCursorColumn to FCursorColumn + LOffset - 1 do
    LRow[LColumn] := TRadIATerminalScreenCell.Create(
      ' ',
      TRadIATerminalTextStyle.Default
    );
  FRows[FCursorRow] := LRow;
end;

function TRadIATerminalScreen.GetParameter(
  const AParameters: TArray<Integer>;
  const AIndex: Integer;
  const ADefault: Integer
): Integer;
begin
  if (AIndex < 0) or (AIndex >= Length(AParameters)) or
    (AParameters[AIndex] = 0) then
    Exit(ADefault);
  Result := AParameters[AIndex];
end;

function TRadIATerminalScreen.ParseParameters: TArray<Integer>;
var
  LIndex: Integer;
  LPart: string;
  LParts: TArray<string>;
begin
  Result := [];
  if FCsiBuffer = '' then
    Exit;
  LParts := FCsiBuffer.Split([';']);
  SetLength(Result, Length(LParts));
  for LIndex := Low(LParts) to High(LParts) do
  begin
    LPart := LParts[LIndex];
    if not TryStrToInt(LPart, Result[LIndex]) then
      Result[LIndex] := 0;
  end;
end;

procedure TRadIATerminalScreen.ProcessCharacter(
  const ACharacter: Char
);
begin
  case FState of
    psText:
      ProcessTextCharacter(ACharacter);
    psEscape:
      ProcessEscapeCharacter(ACharacter);
    psCsi:
      ProcessCsiCharacter(ACharacter);
    psOsc:
      ProcessOscCharacter(ACharacter);
    psOscEscape:
      if ACharacter = '\' then
      begin
        ApplyOsc;
        FState := psText;
      end
      else
      begin
        FOscBuffer := FOscBuffer + #27 + ACharacter;
        FState := psOsc;
      end;
  end;
end;

procedure TRadIATerminalScreen.ProcessCsiCharacter(
  const ACharacter: Char
);
begin
  if CharInSet(ACharacter, ['0'..'9', ';', '?']) then
  begin
    if ACharacter = '?' then
      FCsiPrivate := True
    else
      FCsiBuffer := FCsiBuffer + ACharacter;
    Exit;
  end;
  if CharInSet(ACharacter, ['@'..'~']) then
    ApplyCsi(ACharacter);
  FCsiBuffer := '';
  FCsiPrivate := False;
  FState := psText;
end;

procedure TRadIATerminalScreen.ProcessTextCharacter(
  const ACharacter: Char
);
begin
  case ACharacter of
    #8:
      FCursorColumn := Max(0, FCursorColumn - 1);
    #9:
      FCursorColumn := Min(
        FColumns - 1,
        ((FCursorColumn div 8) + 1) * 8
      );
    #10:
      begin
        FHardBreaks[FCursorRow] := True;
        Inc(FCursorRow);
        EnsureCursor;
      end;
    #13:
      FCursorColumn := 0;
    #27:
      FState := psEscape;
  else
    if ACharacter >= ' ' then
      PutCharacter(ACharacter, Ord(ACharacter));
  end;
end;

procedure TRadIATerminalScreen.ProcessEscapeCharacter(
  const ACharacter: Char
);
begin
  if ACharacter = '[' then
  begin
    FCsiBuffer := '';
    FCsiPrivate := False;
    FState := psCsi;
  end
  else if ACharacter = ']' then
  begin
    FOscBuffer := '';
    FState := psOsc;
  end
  else
    FState := psText;
end;

procedure TRadIATerminalScreen.ProcessOscCharacter(
  const ACharacter: Char
);
begin
  if ACharacter = #7 then
  begin
    ApplyOsc;
    FState := psText;
  end
  else if ACharacter = #27 then
    FState := psOscEscape
  else
    FOscBuffer := FOscBuffer + ACharacter;
end;

procedure TRadIATerminalScreen.AppendCombiningMark(const AText: string);
var
  LCell: TRadIATerminalScreenCell;
  LColumn: Integer;
  LRow: TRadIATerminalRow;
begin
  LColumn := FCursorColumn - 1;
  if LColumn < 0 then
    Exit;
  LRow := FRows[FCursorRow];
  while (LColumn > 0) and (LRow[LColumn].Width = 0) do
    Dec(LColumn);
  LCell := LRow[LColumn];
  LRow[LColumn] := TRadIATerminalScreenCell.Create(
    LCell.Character + AText,
    LCell.Style,
    LCell.Width
  );
  FRows[FCursorRow] := LRow;
end;

function TRadIATerminalScreen.CharacterWidth(
  const ACodePoint: Cardinal
): Integer;
begin
  if IsCombiningCodePoint(ACodePoint) then
    Exit(0);
  if IsWideBmpFirstRange(ACodePoint) or
    IsWideBmpSecondRange(ACodePoint) or
    ((ACodePoint >= $1F300) and (ACodePoint <= $1FAFF)) then
    Exit(2);
  Result := 1;
end;

function TRadIATerminalScreen.IsWideBmpFirstRange(
  const ACodePoint: Cardinal
): Boolean;
begin
  Result := ((ACodePoint >= $1100) and (ACodePoint <= $115F)) or
    ((ACodePoint >= $2E80) and (ACodePoint <= $A4CF)) or
    ((ACodePoint >= $AC00) and (ACodePoint <= $D7A3));
end;

function TRadIATerminalScreen.IsWideBmpSecondRange(
  const ACodePoint: Cardinal
): Boolean;
begin
  Result := ((ACodePoint >= $F900) and (ACodePoint <= $FAFF)) or
    ((ACodePoint >= $FE10) and (ACodePoint <= $FE6F)) or
    ((ACodePoint >= $FF00) and (ACodePoint <= $FF60)) or
    ((ACodePoint >= $FFE0) and (ACodePoint <= $FFE6));
end;

function TRadIATerminalScreen.IsCombiningCodePoint(
  const ACodePoint: Cardinal
): Boolean;
begin
  Result := ((ACodePoint >= $0300) and (ACodePoint <= $036F)) or
    ((ACodePoint >= $1AB0) and (ACodePoint <= $1AFF)) or
    ((ACodePoint >= $1DC0) and (ACodePoint <= $1DFF)) or
    ((ACodePoint >= $20D0) and (ACodePoint <= $20FF)) or
    ((ACodePoint >= $FE20) and (ACodePoint <= $FE2F));
end;

procedure TRadIATerminalScreen.PutCharacter(
  const AText: string;
  const ACodePoint: Cardinal
);
var
  LRow: TRadIATerminalRow;
  LWidth: Integer;
begin
  LWidth := CharacterWidth(ACodePoint);
  if LWidth = 0 then
  begin
    AppendCombiningMark(AText);
    Exit;
  end;
  EnsureCursor;
  if (LWidth = 2) and (FCursorColumn = FColumns - 1) then
  begin
    FCursorColumn := 0;
    Inc(FCursorRow);
    EnsureCursor;
  end;
  LRow := FRows[FCursorRow];
  LRow[FCursorColumn] := TRadIATerminalScreenCell.Create(
    AText,
    FStyle,
    LWidth
  );
  if LWidth = 2 then
    LRow[FCursorColumn + 1] := TRadIATerminalScreenCell.Create(
      '',
      FStyle,
      0
    );
  FRows[FCursorRow] := LRow;
  Inc(FCursorColumn, LWidth);
  if FCursorColumn >= FColumns then
  begin
    FCursorColumn := 0;
    Inc(FCursorRow);
    EnsureCursor;
  end;
end;

function TRadIATerminalScreen.RenderSegments:
  TArray<TRadIATerminalTextSegment>;
var
  LCell: TRadIATerminalScreenCell;
  LColumn: Integer;
  LLastColumn: Integer;
  LLastRow: NativeInt;
  LRow: NativeInt;
begin
  Result := [];
  LLastRow := FRows.Count - 1;
  while LLastRow > 0 do
  begin
    LLastColumn := FColumns - 1;
    while (LLastColumn >= 0) and
      (FRows[LLastRow][LLastColumn].Character = ' ') do
      Dec(LLastColumn);
    if LLastColumn >= 0 then
      Break;
    Dec(LLastRow);
  end;
  for LRow := 0 to LLastRow do
  begin
    LLastColumn := FColumns - 1;
    while (LLastColumn >= 0) and
      (FRows[LRow][LLastColumn].Character = ' ') do
      Dec(LLastColumn);
    for LColumn := 0 to LLastColumn do
    begin
      LCell := FRows[LRow][LColumn];
      AddRenderSegment(Result, LCell.Character, LCell.Style);
    end;
    if LRow < LLastRow then
      AddRenderSegment(
        Result,
        sLineBreak,
        TRadIATerminalTextStyle.Default
      );
  end;
end;

procedure TRadIATerminalScreen.Resize(const AColumns: Integer);
var
  LOldBreaks: TArray<Boolean>;
  LOldRows: TArray<TRadIATerminalRow>;
  LRowIndex: Integer;
begin
  if AColumns < 20 then
    raise EArgumentOutOfRangeException.Create(
      'The terminal width must be at least 20 columns.'
    );
  if (FColumns = AColumns) and (FRows.Count > 0) then
    Exit;
  LOldRows := FRows.ToArray;
  LOldBreaks := FHardBreaks.ToArray;
  FRows.Clear;
  FHardBreaks.Clear;
  FColumns := AColumns;
  FCursorColumn := 0;
  FCursorRow := 0;
  EnsureCursor;
  for LRowIndex := 0 to High(LOldRows) do
    ReflowRow(
      LOldRows[LRowIndex],
      (LRowIndex <= High(LOldBreaks)) and LOldBreaks[LRowIndex]
    );
end;

procedure TRadIATerminalScreen.ReflowCell(
  const ACell: TRadIATerminalScreenCell
);
var
  LRow: TRadIATerminalRow;
begin
  if ACell.Width = 0 then
    Exit;
  if FCursorColumn + ACell.Width > FColumns then
  begin
    FCursorColumn := 0;
    Inc(FCursorRow);
    EnsureCursor;
  end;
  LRow := FRows[FCursorRow];
  LRow[FCursorColumn] := ACell;
  if ACell.Width = 2 then
    LRow[FCursorColumn + 1] := TRadIATerminalScreenCell.Create(
      '',
      ACell.Style,
      0
    );
  FRows[FCursorRow] := LRow;
  Inc(FCursorColumn, ACell.Width);
  if FCursorColumn < FColumns then
    Exit;
  FCursorColumn := 0;
  Inc(FCursorRow);
  EnsureCursor;
end;

procedure TRadIATerminalScreen.ReflowHardBreak;
begin
  FHardBreaks[FCursorRow] := True;
  FCursorColumn := 0;
  Inc(FCursorRow);
  EnsureCursor;
end;

procedure TRadIATerminalScreen.ReflowRow(
  const ARow: TRadIATerminalRow;
  const AHardBreak: Boolean
);
var
  LColumn: Integer;
  LLastColumn: Integer;
begin
  LLastColumn := High(ARow);
  while (LLastColumn >= 0) and
    ((ARow[LLastColumn].Character = ' ') or
    (ARow[LLastColumn].Width = 0)) do
    Dec(LLastColumn);
  for LColumn := 0 to LLastColumn do
    ReflowCell(ARow[LColumn]);
  if AHardBreak then
    ReflowHardBreak;
end;

function TRadIATerminalScreen.StylesMatch(
  const ALeft: TRadIATerminalTextStyle;
  const ARight: TRadIATerminalTextStyle
): Boolean;
begin
  Result := (ALeft.Foreground = ARight.Foreground) and
    (ALeft.Background = ARight.Background) and
    (ALeft.ForegroundRgb = ARight.ForegroundRgb) and
    (ALeft.BackgroundRgb = ARight.BackgroundRgb) and
    (ALeft.Bold = ARight.Bold) and
    (ALeft.Italic = ARight.Italic) and
    (ALeft.Underline = ARight.Underline) and
    (ALeft.Inverse = ARight.Inverse) and
    (ALeft.Hyperlink = ARight.Hyperlink);
end;

end.
