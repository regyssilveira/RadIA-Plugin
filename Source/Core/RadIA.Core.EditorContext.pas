unit RadIA.Core.EditorContext;

interface

type
  TRadIAEditorSemanticContext = record
  private
    FCurrentSymbol: string;
    FCurrentSymbolKind: string;
    FImports: TArray<string>;
    FNearbySymbols: TArray<string>;
    FUnitName: string;
  public
    constructor Create(
      const AUnitName: string;
      const ACurrentSymbol: string;
      const ACurrentSymbolKind: string;
      const AImports: TArray<string>;
      const ANearbySymbols: TArray<string>
    );
    function ToPromptContext: string;
    property CurrentSymbol: string read FCurrentSymbol;
    property Imports: TArray<string> read FImports;
    property NearbySymbols: TArray<string> read FNearbySymbols;
    property UnitName: string read FUnitName;
  end;

  TRadIAEditorContextAnalyzer = class
  private
    class procedure AddImports(
      const AUsesText: string;
      const AMaxImports: Integer;
      var AItems: TArray<string>
    ); static;
    class function ExtractImports(
      const AContent: string;
      const AMaxImports: Integer
    ): TArray<string>; static;
    class function ExtractUnitName(const AContent: string): string; static;
    class function TryCompleteUsesClause(
      const ALine: string;
      var ACollecting: Boolean;
      var AUsesText: string
    ): Boolean; static;
    class function NearbySymbols(
      const AContent: string;
      const ACursorLine: Integer;
      const AMaxSymbols: Integer;
      out ACurrentSymbol: string;
      out ACurrentKind: string
    ): TArray<string>; static;
  public
    class function Analyze(
      const AContent: string;
      const ACursorLine: Integer;
      const AMaxImports: Integer = 24;
      const AMaxNearbySymbols: Integer = 7
    ): TRadIAEditorSemanticContext; static;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.IDENavigation;

constructor TRadIAEditorSemanticContext.Create(
  const AUnitName: string;
  const ACurrentSymbol: string;
  const ACurrentSymbolKind: string;
  const AImports: TArray<string>;
  const ANearbySymbols: TArray<string>
);
begin
  FUnitName := AUnitName;
  FCurrentSymbol := ACurrentSymbol;
  FCurrentSymbolKind := ACurrentSymbolKind;
  FImports := AImports;
  FNearbySymbols := ANearbySymbols;
end;

class procedure TRadIAEditorContextAnalyzer.AddImports(
  const AUsesText: string;
  const AMaxImports: Integer;
  var AItems: TArray<string>
);
var
  LIndex: Integer;
  LItem: string;
  LItems: TList<string>;
  LPart: string;
begin
  LItems := TList<string>.Create;
  try
    for LItem in AItems do
      LItems.Add(LItem);
    for LItem in AUsesText.Split([',']) do
    begin
      LPart := Trim(LItem);
      LIndex := Pos(' in ', LowerCase(LPart));
      if LIndex > 0 then
        LPart := Trim(Copy(LPart, 1, LIndex - 1));
      if (LPart <> '') and (LItems.IndexOf(LPart) < 0) then
        LItems.Add(LPart);
      if LItems.Count >= AMaxImports then
        Break;
    end;
    AItems := LItems.ToArray;
  finally
    LItems.Free;
  end;
end;

function TRadIAEditorSemanticContext.ToPromptContext: string;
begin
  Result := 'Unit: ' + FUnitName;
  if FCurrentSymbol <> '' then
    Result := Result + sLineBreak + 'Current symbol: ' +
      FCurrentSymbolKind + ' ' + FCurrentSymbol;
  if Length(FImports) > 0 then
    Result := Result + sLineBreak + 'Imports: ' + string.Join(', ', FImports);
  if Length(FNearbySymbols) > 0 then
    Result := Result + sLineBreak + 'Nearby symbols: ' +
      string.Join('; ', FNearbySymbols);
end;

class function TRadIAEditorContextAnalyzer.Analyze(
  const AContent: string;
  const ACursorLine: Integer;
  const AMaxImports: Integer;
  const AMaxNearbySymbols: Integer
): TRadIAEditorSemanticContext;
var
  LCurrentKind: string;
  LCurrentSymbol: string;
  LNearbySymbols: TArray<string>;
begin
  LNearbySymbols := NearbySymbols(
    AContent,
    ACursorLine,
    AMaxNearbySymbols,
    LCurrentSymbol,
    LCurrentKind
  );
  Result := TRadIAEditorSemanticContext.Create(
    ExtractUnitName(AContent),
    LCurrentSymbol,
    LCurrentKind,
    ExtractImports(AContent, AMaxImports),
    LNearbySymbols
  );
end;

class function TRadIAEditorContextAnalyzer.ExtractImports(
  const AContent: string;
  const AMaxImports: Integer
): TArray<string>;
var
  LCollecting: Boolean;
  LItems: TArray<string>;
  LLine: string;
  LLines: TStringList;
  LUsesText: string;
begin
  if AMaxImports <= 0 then
    Exit(nil);
  LLines := TStringList.Create;
  try
    LLines.Text := AContent;
    LCollecting := False;
    LUsesText := '';
    for LLine in LLines do
    begin
      if not TryCompleteUsesClause(LLine, LCollecting, LUsesText) then
        Continue;
      AddImports(LUsesText, AMaxImports, LItems);
      LCollecting := False;
      LUsesText := '';
      if Length(LItems) >= AMaxImports then
        Break;
    end;
    Result := LItems;
  finally
    LLines.Free;
  end;
end;

class function TRadIAEditorContextAnalyzer.TryCompleteUsesClause(
  const ALine: string;
  var ACollecting: Boolean;
  var AUsesText: string
): Boolean;
var
  LPart: string;
  LTerminator: Integer;
begin
  LPart := Trim(ALine);
  if not ACollecting and
    (SameText(LPart, 'uses') or StartsText('uses ', LPart)) then
  begin
    ACollecting := True;
    Delete(LPart, 1, Length('uses'));
  end;
  if not ACollecting then
    Exit(False);
  AUsesText := AUsesText + ' ' + LPart;
  LTerminator := Pos(';', AUsesText);
  Result := LTerminator > 0;
  if Result then
    AUsesText := Copy(AUsesText, 1, LTerminator - 1);
end;

class function TRadIAEditorContextAnalyzer.ExtractUnitName(
  const AContent: string
): string;
var
  LLine: string;
  LLines: TStringList;
  LTrimmed: string;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AContent;
    for LLine in LLines do
    begin
      LTrimmed := Trim(LLine);
      if not StartsText('unit ', LTrimmed) then
        Continue;
      Result := Trim(Copy(LTrimmed, Length('unit ') + 1, MaxInt));
      if EndsText(';', Result) then
        Delete(Result, Length(Result), 1);
      Exit;
    end;
  finally
    LLines.Free;
  end;
end;

class function TRadIAEditorContextAnalyzer.NearbySymbols(
  const AContent: string;
  const ACursorLine: Integer;
  const AMaxSymbols: Integer;
  out ACurrentSymbol: string;
  out ACurrentKind: string
): TArray<string>;
var
  LCurrentIndex: Integer;
  LEndIndex: Integer;
  LIndex: Integer;
  LResult: TList<string>;
  LStartIndex: Integer;
  LSymbol: TRadIAUnitSymbol;
  LSymbols: TArray<TRadIAUnitSymbol>;
begin
  ACurrentSymbol := '';
  ACurrentKind := '';
  if AMaxSymbols <= 0 then
    Exit(nil);
  LSymbols := TRadIAUnitSymbolScanner.Scan(AContent, MaxInt);
  LCurrentIndex := -1;
  for LIndex := Low(LSymbols) to High(LSymbols) do
  begin
    if LSymbols[LIndex].Line > ACursorLine then
      Break;
    LCurrentIndex := LIndex;
  end;
  if LCurrentIndex >= 0 then
  begin
    ACurrentSymbol := LSymbols[LCurrentIndex].Name;
    ACurrentKind := LSymbols[LCurrentIndex].Kind;
  end;
  LStartIndex := Max(0, LCurrentIndex - (AMaxSymbols div 2));
  LEndIndex := Min(High(LSymbols), LStartIndex + AMaxSymbols - 1);
  LStartIndex := Max(0, LEndIndex - AMaxSymbols + 1);
  LResult := TList<string>.Create;
  try
    for LIndex := LStartIndex to LEndIndex do
    begin
      LSymbol := LSymbols[LIndex];
      LResult.Add(
        LSymbol.Kind + ' ' + LSymbol.Name + ' at line ' +
        LSymbol.Line.ToString
      );
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

end.
