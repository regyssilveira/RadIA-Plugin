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
    FLength: Integer;
    FStartOffset: Integer;
  public
    constructor Create(
      const AKind: TRadIADelphiMovableTypeKind;
      const AContent: string;
      const AStartOffset: Integer;
      const ALength: Integer
    );
    property Content: string read FContent;
    property Kind: TRadIADelphiMovableTypeKind read FKind;
    property Length: Integer read FLength;
    property StartOffset: Integer read FStartOffset;
  end;

  TRadIADelphiMoveBlock = record
  private
    FContent: string;
    FLength: Integer;
    FStartOffset: Integer;
  public
    constructor Create(
      const AStartOffset: Integer;
      const ALength: Integer;
      const AContent: string
    );
    property Content: string read FContent;
    property Length: Integer read FLength;
    property StartOffset: Integer read FStartOffset;
  end;

  TRadIADelphiUnitSource = record
  private
    FContent: string;
    FUnitName: string;
  public
    constructor Create(const AUnitName: string; const AContent: string);
    property Content: string read FContent;
    property UnitName: string read FUnitName;
  end;

  TRadIADelphiUnitDependencyGraph = class
  public
    class function TryValidateAcyclic(
      const AUnits: TArray<TRadIADelphiUnitSource>;
      out ACycle: string
    ): Boolean; static;
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
    class function TryFindImplementations(
      const ASource: string;
      const ATypeName: string;
      out ABlocks: TArray<TRadIADelphiMoveBlock>;
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
    class function TryRemoveMoveBlocks(
      const ASource: string;
      const AMovableType: TRadIADelphiMovableType;
      const AImplementations: TArray<TRadIADelphiMoveBlock>;
      out AContent: string;
      out AError: string
    ): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.DelphiExtraction,
  RadIA.Semantic.Lexer,
  RadIA.Semantic.Parser;

constructor TRadIADelphiMovableType.Create(
  const AKind: TRadIADelphiMovableTypeKind;
  const AContent: string;
  const AStartOffset: Integer;
  const ALength: Integer
);
begin
  FKind := AKind;
  FContent := AContent;
  FStartOffset := AStartOffset;
  FLength := ALength;
end;

constructor TRadIADelphiMoveBlock.Create(
  const AStartOffset: Integer;
  const ALength: Integer;
  const AContent: string
);
begin
  FStartOffset := AStartOffset;
  FLength := ALength;
  FContent := AContent;
end;

constructor TRadIADelphiUnitSource.Create(
  const AUnitName: string;
  const AContent: string
);
begin
  FUnitName := AUnitName;
  FContent := AContent;
end;

type
  TRadIADelphiUnitCycleDetector = class
  private
    FEdges: TObjectDictionary<string, TList<string>>;
    FPath: TList<string>;
    FStates: TDictionary<string, Integer>;
    function BuildCycle(const AUnitName: string): string;
    function Visit(const AUnitName: string; out ACycle: string): Boolean;
  public
    constructor Create(const AUnits: TArray<TRadIADelphiUnitSource>);
    destructor Destroy; override;
    function TryValidate(out ACycle: string): Boolean;
  end;

constructor TRadIADelphiUnitCycleDetector.Create(
  const AUnits: TArray<TRadIADelphiUnitSource>
);
var
  LEdges: TList<string>;
  LParsed: TRadIASemanticParseResult;
  LSymbol: TRadIASemanticSymbol;
  LUnit: TRadIADelphiUnitSource;
  LUnitKey: string;
begin
  inherited Create;
  FEdges := TObjectDictionary<string, TList<string>>.Create([doOwnsValues]);
  FStates := TDictionary<string, Integer>.Create;
  FPath := TList<string>.Create;
  for LUnit in AUnits do
    if not LUnit.UnitName.IsEmpty and
      not FEdges.ContainsKey(LowerCase(LUnit.UnitName)) then
      FEdges.Add(LowerCase(LUnit.UnitName), TList<string>.Create);
  for LUnit in AUnits do
  begin
    LUnitKey := LowerCase(LUnit.UnitName);
    if not FEdges.TryGetValue(LUnitKey, LEdges) then
      Continue;
    LParsed := TRadIASemanticParser.Parse(LUnit.Content, []);
    for LSymbol in LParsed.Symbols do
      if (LSymbol.Kind = sskUnitReference) and
        (LSymbol.DeclarationSection = sdsInterface) and
        FEdges.ContainsKey(LowerCase(LSymbol.Name)) and
        not LEdges.Contains(LowerCase(LSymbol.Name)) then
        LEdges.Add(LowerCase(LSymbol.Name));
  end;
end;

destructor TRadIADelphiUnitCycleDetector.Destroy;
begin
  FPath.Free;
  FStates.Free;
  FEdges.Free;
  inherited Destroy;
end;

function TRadIADelphiUnitCycleDetector.BuildCycle(
  const AUnitName: string
): string;
var
  LIndex: NativeInt;
begin
  Result := '';
  LIndex := FPath.IndexOf(AUnitName);
  if LIndex < 0 then
    Exit(AUnitName);
  while LIndex < FPath.Count do
  begin
    if not Result.IsEmpty then
      Result := Result + ' -> ';
    Result := Result + FPath[LIndex];
    Inc(LIndex);
  end;
  Result := Result + ' -> ' + AUnitName;
end;

function TRadIADelphiUnitCycleDetector.Visit(
  const AUnitName: string;
  out ACycle: string
): Boolean;
var
  LDependency: string;
  LEdges: TList<string>;
  LState: Integer;
begin
  if FStates.TryGetValue(AUnitName, LState) then
  begin
    if LState = 1 then
    begin
      ACycle := BuildCycle(AUnitName);
      Exit(False);
    end;
    Exit(True);
  end;
  FStates.Add(AUnitName, 1);
  FPath.Add(AUnitName);
  if FEdges.TryGetValue(AUnitName, LEdges) then
    for LDependency in LEdges do
      if not Visit(LDependency, ACycle) then
        Exit(False);
  FPath.Delete(FPath.Count - 1);
  FStates[AUnitName] := 2;
  Result := True;
end;

function TRadIADelphiUnitCycleDetector.TryValidate(
  out ACycle: string
): Boolean;
var
  LUnitName: string;
begin
  ACycle := '';
  for LUnitName in FEdges.Keys do
    if not Visit(LUnitName, ACycle) then
      Exit(False);
  Result := True;
end;

class function TRadIADelphiUnitDependencyGraph.TryValidateAcyclic(
  const AUnits: TArray<TRadIADelphiUnitSource>;
  out ACycle: string
): Boolean;
var
  LDetector: TRadIADelphiUnitCycleDetector;
begin
  LDetector := TRadIADelphiUnitCycleDetector.Create(AUnits);
  try
    Result := LDetector.TryValidate(ACycle);
  finally
    LDetector.Free;
  end;
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

function MatchesMoveBlock(
  const ASource: string;
  const AStartOffset: Integer;
  const ALength: Integer;
  const AContent: string
): Boolean;
begin
  Result := (AStartOffset >= 0) and (ALength > 0) and
    (AStartOffset + ALength <= Length(ASource)) and
    (Copy(ASource, AStartOffset + 1, ALength) = AContent);
end;

class function TRadIADelphiTypeMoveEditor.TryRemoveMoveBlocks(
  const ASource: string;
  const AMovableType: TRadIADelphiMovableType;
  const AImplementations: TArray<TRadIADelphiMoveBlock>;
  out AContent: string;
  out AError: string
): Boolean;
var
  LBlock: TRadIADelphiMoveBlock;
  LIndex: Integer;
  LNextOffset: Integer;
begin
  Result := False;
  AContent := ASource;
  AError := '';
  if not MatchesMoveBlock(
    ASource,
    AMovableType.StartOffset,
    AMovableType.Length,
    AMovableType.Content
  ) then
  begin
    AError := 'The Delphi type declaration changed before composition.';
    Exit;
  end;
  LNextOffset := Length(ASource) + 1;
  for LIndex := High(AImplementations) downto Low(AImplementations) do
  begin
    LBlock := AImplementations[LIndex];
    if not MatchesMoveBlock(
      ASource,
      LBlock.StartOffset,
      LBlock.Length,
      LBlock.Content
    ) or (LBlock.StartOffset + LBlock.Length > LNextOffset) or
      (LBlock.StartOffset <= AMovableType.StartOffset) then
    begin
      AError := 'A Delphi type implementation changed or overlaps another block.';
      Exit;
    end;
    Delete(AContent, LBlock.StartOffset + 1, LBlock.Length);
    LNextOffset := LBlock.StartOffset;
  end;
  Delete(
    AContent,
    AMovableType.StartOffset + 1,
    AMovableType.Length
  );
  Result := True;
end;

class function TRadIADelphiTypeMoveAnalyzer.TryFindImplementations(
  const ASource: string;
  const ATypeName: string;
  out ABlocks: TArray<TRadIADelphiMoveBlock>;
  out AError: string
): Boolean;
var
  LBlock: TRadIADelphiMoveBlock;
  LBlocks: TList<TRadIADelphiMoveBlock>;
  LEndOffset: Integer;
  LParsed: TRadIASemanticParseResult;
  LStartOffset: Integer;
  LSymbol: TRadIASemanticSymbol;
begin
  Result := False;
  ABlocks := nil;
  AError := '';
  if Trim(ATypeName).IsEmpty then
  begin
    AError := 'The Delphi type name is required.';
    Exit;
  end;
  LParsed := TRadIASemanticParser.Parse(ASource, []);
  LBlocks := TList<TRadIADelphiMoveBlock>.Create;
  try
    for LSymbol in LParsed.Symbols do
    begin
      if (LSymbol.Kind <> sskMethod) or
        (LSymbol.DeclarationSection <> sdsImplementation) or
        not SameText(LSymbol.ContainerName, ATypeName) then
        Continue;
      if not TRadIADelphiExtractionAnalyzer.TryFindRoutineExtent(
        ASource,
        LSymbol.Signature,
        LSymbol.StartOffset,
        LStartOffset,
        LEndOffset,
        AError
      ) then
        Exit;
      if (LBlocks.Count > 0) and
        (LStartOffset < LBlocks.Last.StartOffset + LBlocks.Last.Length) then
      begin
        AError := 'The Delphi type implementations overlap or are ambiguous.';
        Exit;
      end;
      LBlock := TRadIADelphiMoveBlock.Create(
        LStartOffset,
        LEndOffset - LStartOffset,
        Copy(ASource, LStartOffset + 1, LEndOffset - LStartOffset)
      );
      LBlocks.Add(LBlock);
    end;
    ABlocks := LBlocks.ToArray;
    Result := True;
  finally
    LBlocks.Free;
  end;
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
    LContent,
    AIndexedStartOffset,
    LEndOffset - AIndexedStartOffset
  );
  Result := True;
end;

end.
