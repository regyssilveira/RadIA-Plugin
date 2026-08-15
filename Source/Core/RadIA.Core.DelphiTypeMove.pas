unit RadIA.Core.DelphiTypeMove;

interface

type
  TRadIADelphiMovableTypeKind = (
    mtkUnknown,
    mtkClass,
    mtkInterface,
    mtkRecord,
    mtkObject,
    mtkClassHelper,
    mtkRecordHelper
  );

  TRadIADelphiMovableType = record
  private
    FContent: string;
    FKind: TRadIADelphiMovableTypeKind;
  public
    constructor Create(
      const AKind: TRadIADelphiMovableTypeKind;
      const AContent: string
    );
    property Content: string read FContent;
    property Kind: TRadIADelphiMovableTypeKind read FKind;
  end;

  TRadIADelphiTypeMoveAnalyzer = class
  public
    class function TryAnalyze(
      const ASource: string;
      const ATypeName: string;
      const AIndexedStartOffset: Integer;
      out AMovableType: TRadIADelphiMovableType;
      out AError: string
    ): Boolean; static;
  end;

  TRadIADelphiTypeMoveEditor = class
  public
    class function TryEnsureUsesUnit(
      const ASource: string;
      const AUnitName: string;
      const AInterfaceSection: Boolean;
      out AContent: string;
      out AError: string
    ): Boolean; static;
    class function TryInsertDeclaration(
      const ASource: string;
      const ADeclaration: string;
      out AContent: string;
      out AError: string
    ): Boolean; static;
    class function TryInsertImplementations(
      const ASource: string;
      const AImplementations: TArray<string>;
      out AContent: string;
      out AError: string
    ): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils,
  RadIA.Semantic.Lexer,
  RadIA.Semantic.Parser;

constructor TRadIADelphiMovableType.Create(
  const AKind: TRadIADelphiMovableTypeKind;
  const AContent: string
);
begin
  FKind := AKind;
  FContent := AContent;
end;

function SignificantTokens(
  const ASource: string
): TArray<TRadIASemanticToken>;
var
  LList: TList<TRadIASemanticToken>;
  LToken: TRadIASemanticToken;
begin
  LList := TList<TRadIASemanticToken>.Create;
  try
    for LToken in TRadIASemanticLexer.Tokenize(ASource) do
      if not (LToken.Kind in [stkWhitespace, stkComment, stkDirective]) then
        LList.Add(LToken);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function FindTypeToken(
  const ATokens: TArray<TRadIASemanticToken>;
  const ATypeName: string;
  const AOffset: Integer
): Integer;
var
  LIndex: Integer;
begin
  for LIndex := Low(ATokens) to High(ATokens) do
    if (ATokens[LIndex].StartOffset = AOffset) and
      SameText(ATokens[LIndex].Text, ATypeName) then
      Exit(LIndex);
  Result := -1;
end;

function ResolveTypeKind(
  const ATokens: TArray<TRadIASemanticToken>;
  const AKindIndex: Integer
): TRadIADelphiMovableTypeKind;
var
  LHelper: Boolean;
begin
  LHelper := (AKindIndex < High(ATokens)) and
    SameText(ATokens[AKindIndex + 1].Text, 'helper');
  if SameText(ATokens[AKindIndex].Text, 'class') then
    if LHelper then
      Result := mtkClassHelper
    else
      Result := mtkClass
  else if SameText(ATokens[AKindIndex].Text, 'interface') then
    Result := mtkInterface
  else if SameText(ATokens[AKindIndex].Text, 'record') then
    if LHelper then
      Result := mtkRecordHelper
    else
      Result := mtkRecord
  else if SameText(ATokens[AKindIndex].Text, 'object') then
    Result := mtkObject
  else
    Result := mtkUnknown;
end;

function IsNestedTypeOpening(
  const ATokens: TArray<TRadIASemanticToken>;
  const AIndex: Integer
): Boolean;
begin
  Result := SameText(ATokens[AIndex].Text, 'record') or
    ((AIndex > Low(ATokens)) and (ATokens[AIndex - 1].Text = '=') and
      (SameText(ATokens[AIndex].Text, 'class') or
       SameText(ATokens[AIndex].Text, 'interface') or
       SameText(ATokens[AIndex].Text, 'object')));
end;

function FindTypeEnd(
  const ATokens: TArray<TRadIASemanticToken>;
  const AKindIndex: Integer;
  out AEndOffset: Integer;
  out AError: string
): Boolean;
var
  LDepth: Integer;
  LIndex: Integer;
begin
  Result := False;
  AEndOffset := -1;
  LDepth := 1;
  for LIndex := AKindIndex + 1 to High(ATokens) do
  begin
    if IsNestedTypeOpening(ATokens, LIndex) then
      Inc(LDepth)
    else if SameText(ATokens[LIndex].Text, 'end') then
    begin
      Dec(LDepth);
      if LDepth = 0 then
      begin
        if (LIndex = High(ATokens)) or (ATokens[LIndex + 1].Text <> ';') then
        begin
          AError := 'The Delphi type closing end is not followed by a semicolon.';
          Exit;
        end;
        AEndOffset := ATokens[LIndex + 1].StartOffset +
          ATokens[LIndex + 1].Length;
        Exit(True);
      end;
    end;
  end;
  AError := 'The Delphi type declaration is not structurally closed.';
end;

function HasConditionalDirective(const AContent: string): Boolean;
begin
  Result := ContainsText(AContent, '{$IF') or
    ContainsText(AContent, '(*$IF') or
    ContainsText(AContent, '{$ELSE') or
    ContainsText(AContent, '{$ENDIF');
end;

function DetectLineBreak(const ASource: string): string;
begin
  if Pos(#13#10, ASource) > 0 then
    Result := #13#10
  else
    Result := #10;
end;

function IsIdentifierStart(const ACharacter: Char): Boolean;
begin
  Result := CharInSet(ACharacter, ['A'..'Z', 'a'..'z', '_']);
end;

function IsIdentifierPart(const ACharacter: Char): Boolean;
begin
  Result := IsIdentifierStart(ACharacter) or
    CharInSet(ACharacter, ['0'..'9']);
end;

function IsUnitNameSegment(
  const AValue: string;
  const AStartIndex: Integer;
  const AEndIndex: Integer
): Boolean;
var
  LIndex: Integer;
begin
  if (AStartIndex > AEndIndex) or
    not IsIdentifierStart(AValue[AStartIndex]) then
    Exit(False);
  for LIndex := AStartIndex + 1 to AEndIndex do
    if not IsIdentifierPart(AValue[LIndex]) then
      Exit(False);
  Result := True;
end;

function IsUnitName(const AValue: string): Boolean;
var
  LIndex: Integer;
  LSegmentStart: Integer;
begin
  if AValue.IsEmpty then
    Exit(False);
  LSegmentStart := Low(AValue);
  for LIndex := Low(AValue) to High(AValue) do
    if AValue[LIndex] = '.' then
    begin
      if not IsUnitNameSegment(AValue, LSegmentStart, LIndex - 1) then
        Exit(False);
      LSegmentStart := LIndex + 1;
    end;
  Result := IsUnitNameSegment(AValue, LSegmentStart, High(AValue));
end;

function HasUnitDependency(
  const ASource: string;
  const AUnitName: string;
  const AInterfaceSection: Boolean
): Boolean;
var
  LExpected: TRadIASemanticDeclarationSection;
  LParsed: TRadIASemanticParseResult;
  LSymbol: TRadIASemanticSymbol;
begin
  if AInterfaceSection then
    LExpected := sdsInterface
  else
    LExpected := sdsImplementation;
  LParsed := TRadIASemanticParser.Parse(ASource, []);
  for LSymbol in LParsed.Symbols do
    if (LSymbol.Kind = sskUnitReference) and
      (LSymbol.DeclarationSection = LExpected) and
      SameText(LSymbol.Name, AUnitName) then
      Exit(True);
  Result := False;
end;

function FindSectionIndex(
  const ATokens: TArray<TRadIASemanticToken>;
  const AInterfaceSection: Boolean
): Integer;
var
  LIndex: Integer;
  LSectionName: string;
begin
  if AInterfaceSection then
    LSectionName := 'interface'
  else
    LSectionName := 'implementation';
  for LIndex := Low(ATokens) to High(ATokens) do
    if SameText(ATokens[LIndex].Text, LSectionName) then
      Exit(LIndex);
  Result := -1;
end;

function FindUsesIndex(
  const ATokens: TArray<TRadIASemanticToken>;
  const ASectionIndex: Integer
): Integer;
var
  LIndex: Integer;
begin
  for LIndex := ASectionIndex + 1 to High(ATokens) do
  begin
    if SameText(ATokens[LIndex].Text, 'interface') or
      SameText(ATokens[LIndex].Text, 'implementation') or
      SameText(ATokens[LIndex].Text, 'initialization') or
      SameText(ATokens[LIndex].Text, 'finalization') then
      Exit(-1);
    if SameText(ATokens[LIndex].Text, 'uses') then
      Exit(LIndex);
  end;
  Result := -1;
end;

function FindSemicolonIndex(
  const ATokens: TArray<TRadIASemanticToken>;
  const AStartIndex: Integer
): Integer;
var
  LIndex: Integer;
begin
  for LIndex := AStartIndex + 1 to High(ATokens) do
    if ATokens[LIndex].Text = ';' then
      Exit(LIndex);
  Result := -1;
end;

function OffsetAfterLine(
  const ASource: string;
  const AToken: TRadIASemanticToken
): Integer;
var
  LLineFeed: Integer;
  LTokenEnd: Integer;
begin
  LTokenEnd := AToken.StartOffset + AToken.Length;
  LLineFeed := Pos(#10, Copy(ASource, LTokenEnd + 1, MaxInt));
  if LLineFeed > 0 then
    Result := LTokenEnd + LLineFeed
  else
    Result := LTokenEnd;
end;

function LineStartOffset(const ASource: string; const AOffset: Integer): Integer;
begin
  Result := AOffset;
  while (Result > 0) and
    not CharInSet(ASource[Result], [#10, #13]) do
    Dec(Result);
end;

function IndentBlock(
  const AContent: string;
  const AIndent: string;
  const ALineBreak: string
): string;
begin
  Result := AIndent + StringReplace(
    Trim(AContent),
    ALineBreak,
    ALineBreak + AIndent,
    [rfReplaceAll]
  );
end;

function FindImplementationInsertionOffset(
  const ASource: string;
  const ATokens: TArray<TRadIASemanticToken>;
  const AImplementationIndex: Integer
): Integer;
var
  LIndex: Integer;
begin
  for LIndex := AImplementationIndex + 1 to High(ATokens) do
    if SameText(ATokens[LIndex].Text, 'initialization') or
      SameText(ATokens[LIndex].Text, 'finalization') then
      Exit(LineStartOffset(ASource, ATokens[LIndex].StartOffset));
  for LIndex := High(ATokens) - 1 downto AImplementationIndex + 1 do
    if SameText(ATokens[LIndex].Text, 'end') and
      (ATokens[LIndex + 1].Text = '.') then
      Exit(LineStartOffset(ASource, ATokens[LIndex].StartOffset));
  Result := -1;
end;

class function TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
  const ASource: string;
  const AUnitName: string;
  const AInterfaceSection: Boolean;
  out AContent: string;
  out AError: string
): Boolean;
var
  LInsertOffset: Integer;
  LLineBreak: string;
  LSectionIndex: Integer;
  LSemicolonIndex: Integer;
  LTokens: TArray<TRadIASemanticToken>;
  LUsesIndex: Integer;
begin
  Result := False;
  AContent := ASource;
  AError := '';
  if not IsUnitName(AUnitName) then
  begin
    AError := 'The requested Delphi unit name is invalid.';
    Exit;
  end;
  if HasUnitDependency(ASource, AUnitName, AInterfaceSection) then
    Exit(True);
  LTokens := SignificantTokens(ASource);
  LSectionIndex := FindSectionIndex(LTokens, AInterfaceSection);
  if LSectionIndex < 0 then
  begin
    AError := 'The requested Delphi unit section was not found.';
    Exit;
  end;
  LLineBreak := DetectLineBreak(ASource);
  LUsesIndex := FindUsesIndex(LTokens, LSectionIndex);
  if LUsesIndex >= 0 then
  begin
    LSemicolonIndex := FindSemicolonIndex(LTokens, LUsesIndex);
    if LSemicolonIndex < 0 then
    begin
      AError := 'The Delphi uses clause is not closed.';
      Exit;
    end;
    LInsertOffset := LTokens[LSemicolonIndex].StartOffset;
    Insert(
      ',' + LLineBreak + '  ' + AUnitName,
      AContent,
      LInsertOffset + 1
    );
  end
  else
  begin
    LInsertOffset := OffsetAfterLine(ASource, LTokens[LSectionIndex]);
    Insert(
      'uses' + LLineBreak + '  ' + AUnitName + ';' + LLineBreak,
      AContent,
      LInsertOffset + 1
    );
  end;
  Result := True;
end;

class function TRadIADelphiTypeMoveEditor.TryInsertDeclaration(
  const ASource: string;
  const ADeclaration: string;
  out AContent: string;
  out AError: string
): Boolean;
var
  LImplementationIndex: Integer;
  LInsertOffset: Integer;
  LLineBreak: string;
  LTokens: TArray<TRadIASemanticToken>;
begin
  Result := False;
  AContent := ASource;
  AError := '';
  if Trim(ADeclaration).IsEmpty then
  begin
    AError := 'The Delphi type declaration is empty.';
    Exit;
  end;
  LTokens := SignificantTokens(ASource);
  LImplementationIndex := FindSectionIndex(LTokens, False);
  if LImplementationIndex < 0 then
  begin
    AError := 'The destination implementation section was not found.';
    Exit;
  end;
  LLineBreak := DetectLineBreak(ASource);
  LInsertOffset := LineStartOffset(
    ASource,
    LTokens[LImplementationIndex].StartOffset
  );
  AContent := ASource;
  Insert(
    'type' + LLineBreak + IndentBlock(
      ADeclaration,
      '  ',
      LLineBreak
    ) + LLineBreak + LLineBreak,
    AContent,
    LInsertOffset + 1
  );
  Result := True;
end;

class function TRadIADelphiTypeMoveEditor.TryInsertImplementations(
  const ASource: string;
  const AImplementations: TArray<string>;
  out AContent: string;
  out AError: string
): Boolean;
var
  LBlock: string;
  LImplementation: string;
  LImplementationIndex: Integer;
  LInsertOffset: Integer;
  LLineBreak: string;
  LTokens: TArray<TRadIASemanticToken>;
begin
  Result := False;
  AContent := ASource;
  AError := '';
  if Length(AImplementations) = 0 then
    Exit(True);
  LTokens := SignificantTokens(ASource);
  LImplementationIndex := FindSectionIndex(LTokens, False);
  if LImplementationIndex < 0 then
  begin
    AError := 'The destination implementation section was not found.';
    Exit;
  end;
  LInsertOffset := FindImplementationInsertionOffset(
    ASource,
    LTokens,
    LImplementationIndex
  );
  if LInsertOffset < 0 then
  begin
    AError := 'The destination implementation insertion point was not found.';
    Exit;
  end;
  LLineBreak := DetectLineBreak(ASource);
  LBlock := '';
  for LImplementation in AImplementations do
  begin
    if Trim(LImplementation).IsEmpty then
    begin
      AError := 'A Delphi method implementation is empty.';
      Exit;
    end;
    if not LBlock.IsEmpty then
      LBlock := LBlock + LLineBreak + LLineBreak;
    LBlock := LBlock + Trim(LImplementation);
  end;
  Insert(
    LBlock + LLineBreak + LLineBreak,
    AContent,
    LInsertOffset + 1
  );
  Result := True;
end;

class function TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
  const ASource: string;
  const ATypeName: string;
  const AIndexedStartOffset: Integer;
  out AMovableType: TRadIADelphiMovableType;
  out AError: string
): Boolean;
var
  LContent: string;
  LEndOffset: Integer;
  LKind: TRadIADelphiMovableTypeKind;
  LKindIndex: Integer;
  LTypeIndex: Integer;
  LTokens: TArray<TRadIASemanticToken>;
begin
  Result := False;
  AMovableType := Default(TRadIADelphiMovableType);
  AError := '';
  LTokens := SignificantTokens(ASource);
  LTypeIndex := FindTypeToken(LTokens, ATypeName, AIndexedStartOffset);
  if LTypeIndex < 0 then
  begin
    AError := 'The indexed Delphi type changed or no longer exists.';
    Exit;
  end;
  if (LTypeIndex = High(LTokens)) or (LTokens[LTypeIndex + 1].Text <> '=') then
  begin
    AError := 'The indexed symbol is not a complete Delphi type declaration.';
    Exit;
  end;
  LKindIndex := LTypeIndex + 2;
  if (LKindIndex <= High(LTokens)) and
    SameText(LTokens[LKindIndex].Text, 'packed') then
    Inc(LKindIndex);
  if LKindIndex > High(LTokens) then
  begin
    AError := 'The Delphi type kind is missing.';
    Exit;
  end;
  LKind := ResolveTypeKind(LTokens, LKindIndex);
  if LKind = mtkUnknown then
  begin
    AError := 'Move Type supports top-level classes, interfaces, records, and helpers.';
    Exit;
  end;
  if not FindTypeEnd(LTokens, LKindIndex, LEndOffset, AError) then
    Exit;
  LContent := Copy(
    ASource,
    AIndexedStartOffset + 1,
    LEndOffset - AIndexedStartOffset
  );
  if HasConditionalDirective(LContent) then
  begin
    AError := 'Move Type does not cross conditional compiler directives.';
    Exit;
  end;
  AMovableType := TRadIADelphiMovableType.Create(
    LKind,
    LContent
  );
  Result := True;
end;

end.
