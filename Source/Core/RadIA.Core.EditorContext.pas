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
    property CurrentSymbolKind: string read FCurrentSymbolKind;
    property Imports: TArray<string> read FImports;
    property NearbySymbols: TArray<string> read FNearbySymbols;
    property UnitName: string read FUnitName;
  end;

  TRadIAEditorContextAnalyzer = class
  private
    class function ExtractImports(
      const AContent: string;
      const AMaxImports: Integer
    ): TArray<string>; static;
    class function ExtractUnitName(const AContent: string): string; static;
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
  LIndex: Integer;
  LItem: string;
  LItems: TList<string>;
  LLine: string;
  LLines: TStringList;
  LPart: string;
  LParts: TArray<string>;
  LUsesText: string;
begin
  if AMaxImports <= 0 then
    Exit(nil);
  LItems := TList<string>.Create;
  LLines := TStringList.Create;
  try
    LLines.Text := AContent;
    LCollecting := False;
    LUsesText := '';
    for LLine in LLines do
    begin
      LPart := Trim(LLine);
      if not LCollecting and
        (SameText(LPart, 'uses') or StartsText('uses ', LPart)) then
      begin
        LCollecting := True;
        Delete(LPart, 1, Length('uses'));
      end;
      if not LCollecting then
        Continue;
      LUsesText := LUsesText + ' ' + LPart;
      if Pos(';', LPart) = 0 then
        Continue;
      LUsesText := Copy(LUsesText, 1, Pos(';', LUsesText) - 1);
      LParts := LUsesText.Split([',']);
      for LItem in LParts do
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
      LCollecting := False;
      LUsesText := '';
      if LItems.Count >= AMaxImports then
        Break;
    end;
    Result := LItems.ToArray;
  finally
    LLines.Free;
    LItems.Free;
  end;
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
