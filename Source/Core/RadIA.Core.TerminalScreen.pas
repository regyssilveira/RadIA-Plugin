unit RadIA.Core.TerminalScreen;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Terminal;

type
  TRadIATerminalScreenCell = record
  private
    FCharacter: Char;
    FStyle: TRadIATerminalTextStyle;
  public
    constructor Create(
      const ACharacter: Char;
      const AStyle: TRadIATerminalTextStyle
    );
    property Character: Char read FCharacter;
    property Style: TRadIATerminalTextStyle read FStyle;
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
    FCsiBuffer: string;
    FCursorColumn: Integer;
    FCursorRow: Integer;
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
    procedure ApplyEraseDisplay(const AMode: Integer);
    procedure ApplyEraseLine(const AMode: Integer);
    procedure ApplySgr(const AParameters: TArray<Integer>);
    procedure ClearCell(const AColumn: Integer; const ARow: Integer);
    procedure ClearRange(
      const ARow: Integer;
      const AFirstColumn: Integer;
      const ALastColumn: Integer
    );
    procedure EnsureCursor;
    procedure EnsureRow(const ARow: Integer);
    function GetParameter(
      const AParameters: TArray<Integer>;
      const AIndex: Integer;
      const ADefault: Integer
    ): Integer;
    function ParseParameters: TArray<Integer>;
    procedure ProcessCharacter(const ACharacter: Char);
    procedure ProcessCsiCharacter(const ACharacter: Char);
    procedure ProcessTextCharacter(const ACharacter: Char);
    procedure PutCharacter(const ACharacter: Char);
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
    property Columns: Integer read FColumns;
    property CursorColumn: Integer read FCursorColumn;
  end;

implementation

uses
  System.Math,
  System.SysUtils;

{ TRadIATerminalScreenCell }

constructor TRadIATerminalScreenCell.Create(
  const ACharacter: Char;
  const AStyle: TRadIATerminalTextStyle
);
begin
  FCharacter := ACharacter;
  FStyle := AStyle;
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
  case AFinalCharacter of
    'A':
      FCursorRow := Max(
        0,
        FCursorRow - GetParameter(LParameters, 0, 1)
      );
    'B':
      Inc(FCursorRow, GetParameter(LParameters, 0, 1));
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
begin
  if Length(AParameters) = 0 then
  begin
    FStyle := TRadIATerminalTextStyle.Default;
    Exit;
  end;
  for LCode in AParameters do
    case LCode of
      0:
        FStyle := TRadIATerminalTextStyle.Default;
      1:
        FStyle := TRadIATerminalTextStyle.Create(
          FStyle.Foreground,
          True
        );
      22:
        FStyle := TRadIATerminalTextStyle.Create(
          FStyle.Foreground,
          False
        );
      30..37:
        FStyle := TRadIATerminalTextStyle.Create(
          TRadIATerminalColor(Ord(tcBlack) + LCode - 30),
          FStyle.Bold
        );
      39:
        FStyle := TRadIATerminalTextStyle.Create(
          tcDefault,
          FStyle.Bold
        );
      90..97:
        FStyle := TRadIATerminalTextStyle.Create(
          TRadIATerminalColor(Ord(tcBrightBlack) + LCode - 90),
          FStyle.Bold
        );
    end;
end;

procedure TRadIATerminalScreen.Clear;
begin
  FRows.Clear;
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
  Resize(AColumns);
  Clear;
end;

destructor TRadIATerminalScreen.Destroy;
begin
  FRows.Free;
  inherited Destroy;
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
  end;
end;

procedure TRadIATerminalScreen.Feed(const AText: string);
var
  LCharacter: Char;
begin
  for LCharacter in AText do
    ProcessCharacter(LCharacter);
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
      if ACharacter = '[' then
      begin
        FCsiBuffer := '';
        FState := psCsi;
      end
      else if ACharacter = ']' then
        FState := psOsc
      else
        FState := psText;
    psCsi:
      ProcessCsiCharacter(ACharacter);
    psOsc:
      if ACharacter = #7 then
        FState := psText
      else if ACharacter = #27 then
        FState := psOscEscape;
    psOscEscape:
      if ACharacter = '\' then
        FState := psText
      else
        FState := psOsc;
  end;
end;

procedure TRadIATerminalScreen.ProcessCsiCharacter(
  const ACharacter: Char
);
begin
  if CharInSet(ACharacter, ['0'..'9', ';', '?']) then
  begin
    if ACharacter <> '?' then
      FCsiBuffer := FCsiBuffer + ACharacter;
    Exit;
  end;
  if CharInSet(ACharacter, ['@'..'~']) then
    ApplyCsi(ACharacter);
  FCsiBuffer := '';
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
        Inc(FCursorRow);
        EnsureCursor;
      end;
    #13:
      FCursorColumn := 0;
    #27:
      FState := psEscape;
  else
    if ACharacter >= ' ' then
      PutCharacter(ACharacter);
  end;
end;

procedure TRadIATerminalScreen.PutCharacter(
  const ACharacter: Char
);
var
  LRow: TRadIATerminalRow;
begin
  EnsureCursor;
  LRow := FRows[FCursorRow];
  LRow[FCursorColumn] := TRadIATerminalScreenCell.Create(
    ACharacter,
    FStyle
  );
  FRows[FCursorRow] := LRow;
  Inc(FCursorColumn);
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
  LLastRow: Integer;
  LRow: Integer;
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
  LColumn: Integer;
  LIndex: Integer;
  LOldLength: Integer;
  LRow: TRadIATerminalRow;
begin
  if AColumns < 20 then
    raise EArgumentOutOfRangeException.Create(
      'The terminal width must be at least 20 columns.'
    );
  FColumns := AColumns;
  for LIndex := 0 to FRows.Count - 1 do
  begin
    LRow := FRows[LIndex];
    LOldLength := Length(LRow);
    SetLength(LRow, FColumns);
    for LColumn := LOldLength to FColumns - 1 do
      LRow[LColumn] := TRadIATerminalScreenCell.Create(
        ' ',
        TRadIATerminalTextStyle.Default
      );
    FRows[LIndex] := LRow;
  end;
  if FCursorColumn >= FColumns then
    FCursorColumn := FColumns - 1;
end;

function TRadIATerminalScreen.StylesMatch(
  const ALeft: TRadIATerminalTextStyle;
  const ARight: TRadIATerminalTextStyle
): Boolean;
begin
  Result := (ALeft.Foreground = ARight.Foreground) and
    (ALeft.Bold = ARight.Bold);
end;

end.
