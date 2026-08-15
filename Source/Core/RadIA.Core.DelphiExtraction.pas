unit RadIA.Core.DelphiExtraction;

interface

type
  TRadIADelphiExtractParameterKind = (
    epkValue,
    epkConst,
    epkVar,
    epkOut
  );

  TRadIADelphiExtractParameter = record
  private
    FKind: TRadIADelphiExtractParameterKind;
    FName: string;
    FTypeName: string;
  public
    constructor Create(
      const AName: string;
      const ATypeName: string;
      const AKind: TRadIADelphiExtractParameterKind
    );
    property Kind: TRadIADelphiExtractParameterKind read FKind;
    property Name: string read FName;
    property TypeName: string read FTypeName;
  end;

  TRadIADelphiExtractSelection = record
  private
    FContent: string;
    FLength: Integer;
    FStartOffset: Integer;
  public
    constructor Create(
      const AContent: string;
      const AStartOffset: Integer
    );
    property Content: string read FContent;
    property Length: Integer read FLength;
    property StartOffset: Integer read FStartOffset;
  end;

  TRadIADelphiExtractionAnalyzer = class
  public
    class function TryAnalyze(
      const ASource: string;
      const ASelectedText: string;
      const ACursorLine: Integer;
      const ACursorColumn: Integer;
      out ASelection: TRadIADelphiExtractSelection;
      out AError: string
    ): Boolean; static;
    class function TryInferParameters(
      const ASource: string;
      const ASelection: TRadIADelphiExtractSelection;
      const ARoutineSignature: string;
      const ARoutineStartOffset: Integer;
      out AParameters: TArray<TRadIADelphiExtractParameter>;
      out AError: string
    ): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.DelphiSignatures,
  RadIA.Semantic.Lexer;

const
  CMaxSelectionCharacters = 65536;

constructor TRadIADelphiExtractSelection.Create(
  const AContent: string;
  const AStartOffset: Integer
);
begin
  FContent := AContent;
  FStartOffset := AStartOffset;
  FLength := System.Length(AContent);
end;

constructor TRadIADelphiExtractParameter.Create(
  const AName: string;
  const ATypeName: string;
  const AKind: TRadIADelphiExtractParameterKind
);
begin
  FName := AName;
  FTypeName := ATypeName;
  FKind := AKind;
end;

type
  TRadIADelphiVariableUsage = class
  private
    FAssigned: Boolean;
    FFirstUse: Integer;
    FModifier: string;
    FName: string;
    FRead: Boolean;
    FTypeName: string;
  public
    constructor Create(
      const AName: string;
      const ATypeName: string;
      const AModifier: string
    );
    property Assigned: Boolean read FAssigned write FAssigned;
    property FirstUse: Integer read FFirstUse write FFirstUse;
    property Modifier: string read FModifier;
    property Name: string read FName;
    property Read: Boolean read FRead write FRead;
    property TypeName: string read FTypeName;
  end;

  TRadIADelphiVariableMap = TObjectDictionary<string, TRadIADelphiVariableUsage>;

constructor TRadIADelphiVariableUsage.Create(
  const AName: string;
  const ATypeName: string;
  const AModifier: string
);
begin
  inherited Create;
  FName := AName;
  FTypeName := ATypeName;
  FModifier := AModifier;
  FFirstUse := MaxInt;
end;

function OffsetForPosition(
  const ASource: string;
  const ALine: Integer;
  const AColumn: Integer
): Integer;
var
  LColumn: Integer;
  LIndex: Integer;
  LLine: Integer;
begin
  Result := -1;
  if (ALine < 1) or (AColumn < 1) then
    Exit;
  LIndex := 1;
  LLine := 1;
  while (LIndex <= Length(ASource)) and (LLine < ALine) do
  begin
    if ASource[LIndex] = #10 then
      Inc(LLine);
    Inc(LIndex);
  end;
  if LLine <> ALine then
    Exit;
  LColumn := 1;
  while (LIndex <= Length(ASource)) and (LColumn < AColumn) and
    not CharInSet(ASource[LIndex], [#10, #13]) do
  begin
    Inc(LIndex);
    Inc(LColumn);
  end;
  if LColumn = AColumn then
    Result := LIndex - 1;
end;

function FindSelectionOffset(
  const ASource: string;
  const ASelectedText: string;
  const ACursorOffset: Integer;
  out AOffset: Integer;
  out AError: string
): Boolean;
var
  LCandidate: Integer;
  LMatchCount: Integer;
  LSearchOffset: Integer;
begin
  Result := False;
  AOffset := -1;
  AError := '';
  LMatchCount := 0;
  LSearchOffset := 1;
  repeat
    LCandidate := PosEx(ASelectedText, ASource, LSearchOffset);
    if LCandidate = 0 then
      Break;
    if (ACursorOffset >= LCandidate - 1) and
      (ACursorOffset <= LCandidate - 1 + Length(ASelectedText)) then
    begin
      AOffset := LCandidate - 1;
      Inc(LMatchCount);
    end;
    LSearchOffset := LCandidate + 1;
  until LSearchOffset > Length(ASource);
  if LMatchCount = 1 then
    Exit(True);
  if LMatchCount = 0 then
    AError := 'The selected text does not contain the current editor cursor.'
  else
    AError := 'The selected text is ambiguous at the current editor cursor.';
end;

function IsForbiddenControlFlow(const AText: string): Boolean;
begin
  Result := SameText(AText, 'exit') or SameText(AText, 'break') or
    SameText(AText, 'continue') or SameText(AText, 'goto');
end;

function OpeningKind(const AText: string): string;
begin
  if SameText(AText, 'begin') or SameText(AText, 'case') or
    SameText(AText, 'try') or SameText(AText, 'asm') or
    SameText(AText, 'record') then
    Result := 'end'
  else if SameText(AText, 'repeat') then
    Result := 'until'
  else
    Result := '';
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

function MatchesIndexedRoutine(
  const ASource: string;
  const ARoutineSignature: string;
  const ARoutineStartOffset: Integer
): Boolean;
begin
  Result := (ARoutineStartOffset >= 0) and
    (ARoutineStartOffset + Length(ARoutineSignature) <= Length(ASource)) and
    (Copy(
      ASource,
      ARoutineStartOffset + 1,
      Length(ARoutineSignature)
    ) = ARoutineSignature);
end;

function IsRoutineDeclaration(const AText: string): Boolean;
begin
  Result := SameText(AText, 'procedure') or SameText(AText, 'function') or
    SameText(AText, 'constructor') or SameText(AText, 'destructor');
end;

function TryFindBodyOpening(
  const ATokens: TArray<TRadIASemanticToken>;
  out ATokenIndex: Integer;
  out AError: string
): Boolean;
var
  LIndex: Integer;
  LToken: TRadIASemanticToken;
begin
  Result := False;
  ATokenIndex := -1;
  for LIndex := Low(ATokens) to High(ATokens) do
  begin
    LToken := ATokens[LIndex];
    if IsRoutineDeclaration(LToken.Text) then
    begin
      AError := 'Extract Method does not cross a nested routine declaration.';
      Exit;
    end;
    if SameText(LToken.Text, 'begin') then
    begin
      ATokenIndex := LIndex;
      Exit(True);
    end;
  end;
  AError := 'The enclosing routine body was not found.';
end;

function TryFindBodyClosing(
  const ATokens: TArray<TRadIASemanticToken>;
  const AOpeningIndex: Integer;
  out AClosingToken: TRadIASemanticToken;
  out AError: string
): Boolean;
var
  LBlocks: TStack<string>;
  LIndex: Integer;
  LOpening: string;
  LToken: TRadIASemanticToken;
begin
  Result := False;
  LBlocks := TStack<string>.Create;
  try
    for LIndex := AOpeningIndex to High(ATokens) do
    begin
      LToken := ATokens[LIndex];
      LOpening := OpeningKind(LToken.Text);
      if not LOpening.IsEmpty then
        LBlocks.Push(LOpening)
      else if SameText(LToken.Text, 'end') or
        SameText(LToken.Text, 'until') then
      begin
        if (LBlocks.Count = 0) or
          not SameText(LBlocks.Peek, LToken.Text) then
        begin
          AError := 'The enclosing routine has unbalanced control flow.';
          Exit;
        end;
        LBlocks.Pop;
        if LBlocks.Count = 0 then
        begin
          AClosingToken := LToken;
          Exit(True);
        end;
      end;
    end;
  finally
    LBlocks.Free;
  end;
  AError := 'The enclosing routine body is not closed.';
end;

function TryFindRoutineBody(
  const ASource: string;
  const ARoutineSignature: string;
  const ARoutineStartOffset: Integer;
  out ABodyStart: Integer;
  out ABodyEnd: Integer;
  out AError: string
): Boolean;
var
  LClosingToken: TRadIASemanticToken;
  LHeaderEnd: Integer;
  LOpeningIndex: Integer;
  LTokens: TArray<TRadIASemanticToken>;
begin
  Result := False;
  ABodyStart := -1;
  ABodyEnd := -1;
  AError := '';
  if not MatchesIndexedRoutine(
    ASource,
    ARoutineSignature,
    ARoutineStartOffset
  ) then
  begin
    AError := 'The enclosing routine changed after semantic indexing.';
    Exit;
  end;
  LHeaderEnd := ARoutineStartOffset + Length(ARoutineSignature);
  LTokens := SignificantTokens(Copy(ASource, LHeaderEnd + 1, MaxInt));
  if not TryFindBodyOpening(LTokens, LOpeningIndex, AError) then
    Exit;
  if not TryFindBodyClosing(
    LTokens,
    LOpeningIndex,
    LClosingToken,
    AError
  ) then
    Exit;
  ABodyStart := LHeaderEnd + LTokens[LOpeningIndex].StartOffset;
  ABodyEnd := LHeaderEnd + LClosingToken.StartOffset + LClosingToken.Length;
  Result := True;
end;

procedure AddSignatureParameters(
  const ASignature: TRadIADelphiSignature;
  const AVariables: TRadIADelphiVariableMap
);
var
  LParameter: TRadIADelphiParameter;
begin
  for LParameter in ASignature.Parameters do
    AVariables.AddOrSetValue(
      LowerCase(LParameter.Name),
      TRadIADelphiVariableUsage.Create(
        LParameter.Name,
        LParameter.TypeName,
        LParameter.Modifier
      )
    );
end;

function StripLocalInitializer(const ATypeName: string): string;
var
  LEquals: Integer;
begin
  LEquals := TRadIADelphiSignatureParser.FindTopLevel(ATypeName, '=');
  if LEquals > 0 then
    Result := Trim(Copy(ATypeName, 1, LEquals - 1))
  else
    Result := Trim(ATypeName);
end;

function AddLocalDeclaration(
  const ADeclaration: string;
  const AVariables: TRadIADelphiVariableMap;
  out AError: string
): Boolean;
var
  LColon: Integer;
  LName: string;
  LNames: TArray<string>;
  LNormalizedName: string;
  LTypeName: string;
begin
  Result := False;
  LColon := TRadIADelphiSignatureParser.FindTopLevel(ADeclaration, ':');
  if LColon = 0 then
  begin
    AError := 'A local variable declaration has no explicit Delphi type.';
    Exit;
  end;
  LNames := TRadIADelphiSignatureParser.SplitTopLevelItems(
    Copy(ADeclaration, 1, LColon - 1),
    ','
  );
  LTypeName := StripLocalInitializer(Copy(ADeclaration, LColon + 1, MaxInt));
  if LTypeName.IsEmpty then
  begin
    AError := 'A local variable declaration has an empty Delphi type.';
    Exit;
  end;
  for LName in LNames do
  begin
    LNormalizedName := Trim(LName);
    if LNormalizedName.IsEmpty then
    begin
      AError := 'A local variable declaration has an empty name.';
      Exit;
    end;
    AVariables.AddOrSetValue(
      LowerCase(LNormalizedName),
      TRadIADelphiVariableUsage.Create(LNormalizedName, LTypeName, '')
    );
  end;
  Result := True;
end;

function AddLocalVariables(
  const AHeader: string;
  const AVariables: TRadIADelphiVariableMap;
  out AError: string
): Boolean;
var
  LDeclaration: string;
  LDeclarations: TArray<string>;
  LIndex: Integer;
  LStart: Integer;
  LTokens: TArray<TRadIASemanticToken>;
  LTrimmedDeclaration: string;
begin
  Result := True;
  LTokens := SignificantTokens(AHeader);
  LStart := -1;
  for LIndex := Low(LTokens) to High(LTokens) do
    if SameText(LTokens[LIndex].Text, 'var') then
    begin
      LStart := LTokens[LIndex].StartOffset + LTokens[LIndex].Length + 1;
      Break;
    end;
  if LStart < 0 then
    Exit;
  LDeclarations := TRadIADelphiSignatureParser.SplitTopLevelItems(
    Copy(AHeader, LStart, MaxInt),
    ';'
  );
  for LDeclaration in LDeclarations do
  begin
    LTrimmedDeclaration := Trim(LDeclaration);
    if LTrimmedDeclaration.IsEmpty then
      Continue;
    if not AddLocalDeclaration(LTrimmedDeclaration, AVariables, AError) then
      Exit(False);
  end;
end;

function IsAssignmentAt(
  const ATokens: TArray<TRadIASemanticToken>;
  const AIndex: Integer
): Boolean;
begin
  Result := (AIndex + 2 <= High(ATokens)) and
    (ATokens[AIndex + 1].Text = ':') and
    (ATokens[AIndex + 2].Text = '=');
end;

procedure MarkSelectionUsage(
  const ASelectedText: string;
  const AVariables: TRadIADelphiVariableMap
);
var
  LIndex: Integer;
  LKey: string;
  LTokens: TArray<TRadIASemanticToken>;
  LUsage: TRadIADelphiVariableUsage;
begin
  LTokens := SignificantTokens(ASelectedText);
  for LIndex := Low(LTokens) to High(LTokens) do
  begin
    if LTokens[LIndex].Kind <> stkIdentifier then
      Continue;
    LKey := LowerCase(LTokens[LIndex].Text);
    if not AVariables.TryGetValue(LKey, LUsage) then
      Continue;
    if LUsage.FirstUse = MaxInt then
      LUsage.FirstUse := LTokens[LIndex].StartOffset;
    if IsAssignmentAt(LTokens, LIndex) then
      LUsage.Assigned := True
    else
      LUsage.Read := True;
  end;
end;

function ExtractParameterKind(
  const AUsage: TRadIADelphiVariableUsage;
  out AInclude: Boolean
): TRadIADelphiExtractParameterKind;
begin
  AInclude := AUsage.Read or AUsage.Assigned;
  if SameText(AUsage.Modifier, 'var') then
    Result := epkVar
  else if SameText(AUsage.Modifier, 'out') and not AUsage.Read then
    Result := epkOut
  else if SameText(AUsage.Modifier, 'out') then
    Result := epkVar
  else if AUsage.Assigned then
  begin
    if AUsage.Read then
      Result := epkVar
    else
      Result := epkOut;
  end
  else if SameText(AUsage.Modifier, 'const') then
    Result := epkConst
  else
    Result := epkValue;
end;

function SelectionUsesFunctionResult(const ASelectedText: string): Boolean;
var
  LToken: TRadIASemanticToken;
begin
  for LToken in SignificantTokens(ASelectedText) do
    if (LToken.Kind = stkIdentifier) and SameText(LToken.Text, 'Result') then
      Exit(True);
  Result := False;
end;

function CompareExtractParameters(
  const ALeft: TRadIADelphiVariableUsage;
  const ARight: TRadIADelphiVariableUsage
): Integer;
begin
  Result := ALeft.FirstUse - ARight.FirstUse;
end;

function BuildExtractParameters(
  const AVariables: TRadIADelphiVariableMap
): TArray<TRadIADelphiExtractParameter>;
var
  LInclude: Boolean;
  LInputs: TList<TRadIADelphiExtractParameter>;
  LKind: TRadIADelphiExtractParameterKind;
  LOutputs: TList<TRadIADelphiExtractParameter>;
  LParameter: TRadIADelphiExtractParameter;
  LUsage: TRadIADelphiVariableUsage;
  LUsages: TList<TRadIADelphiVariableUsage>;
begin
  LInputs := TList<TRadIADelphiExtractParameter>.Create;
  LOutputs := TList<TRadIADelphiExtractParameter>.Create;
  LUsages := TList<TRadIADelphiVariableUsage>.Create;
  try
    for LUsage in AVariables.Values do
      if LUsage.FirstUse <> MaxInt then
        LUsages.Add(LUsage);
    LUsages.Sort(TComparer<TRadIADelphiVariableUsage>.Construct(
      CompareExtractParameters
    ));
    for LUsage in LUsages do
    begin
      LKind := ExtractParameterKind(LUsage, LInclude);
      if LInclude then
      begin
        LParameter := TRadIADelphiExtractParameter.Create(
          LUsage.Name,
          LUsage.TypeName,
          LKind
        );
        if LKind in [epkVar, epkOut] then
          LOutputs.Add(LParameter)
        else
          LInputs.Add(LParameter);
      end;
    end;
    Result := LInputs.ToArray + LOutputs.ToArray;
  finally
    LUsages.Free;
    LOutputs.Free;
    LInputs.Free;
  end;
end;

function CheckClosingToken(
  const AText: string;
  const ABlocks: TStack<string>;
  out AError: string
): Boolean;
begin
  Result := True;
  if not SameText(AText, 'end') and not SameText(AText, 'until') then
    Exit;
  if (ABlocks.Count = 0) or not SameText(ABlocks.Peek, AText) then
  begin
    AError := 'The selection cuts across a Delphi control-flow block.';
    Exit(False);
  end;
  ABlocks.Pop;
end;

function CheckSymbolBalance(
  const AText: string;
  const ASymbols: TStack<string>;
  out AError: string
): Boolean;
var
  LExpected: string;
begin
  Result := True;
  if (AText = '(') or (AText = '[') then
  begin
    if AText = '(' then
      ASymbols.Push(')')
    else
      ASymbols.Push(']');
    Exit;
  end;
  if (AText <> ')') and (AText <> ']') then
    Exit;
  if ASymbols.Count > 0 then
    LExpected := ASymbols.Peek
  else
    LExpected := '';
  if LExpected <> AText then
  begin
    AError := 'The selection cuts across a Delphi expression.';
    Exit(False);
  end;
  ASymbols.Pop;
end;

function ValidateExtractionToken(
  const AToken: TRadIASemanticToken;
  const ABlocks: TStack<string>;
  const ASymbols: TStack<string>;
  out AError: string
): Boolean;
var
  LOpening: string;
begin
  Result := False;
  if (AToken.Kind = stkIdentifier) and
    IsForbiddenControlFlow(AToken.Text) then
  begin
    AError := 'The selection contains control flow that cannot be extracted: ' +
      AToken.Text;
    Exit;
  end;
  if AToken.Kind = stkIdentifier then
  begin
    LOpening := OpeningKind(AToken.Text);
    if not LOpening.IsEmpty then
      ABlocks.Push(LOpening)
    else if not CheckClosingToken(AToken.Text, ABlocks, AError) then
      Exit;
  end
  else if (AToken.Kind = stkSymbol) and
    not CheckSymbolBalance(AToken.Text, ASymbols, AError) then
    Exit;
  Result := True;
end;

function ValidateTokens(const ASelectedText: string; out AError: string): Boolean;
var
  LBlocks: TStack<string>;
  LSymbols: TStack<string>;
  LToken: TRadIASemanticToken;
begin
  Result := False;
  AError := '';
  LBlocks := TStack<string>.Create;
  LSymbols := TStack<string>.Create;
  try
    for LToken in TRadIASemanticLexer.Tokenize(ASelectedText) do
      if not ValidateExtractionToken(LToken, LBlocks, LSymbols, AError) then
        Exit;
    if LBlocks.Count > 0 then
      AError := 'The selection does not close every Delphi control-flow block.'
    else if LSymbols.Count > 0 then
      AError := 'The selection does not close every Delphi expression.'
    else
      Result := True;
  finally
    LSymbols.Free;
    LBlocks.Free;
  end;
end;

function ValidateSelectionText(
  const ASelectedText: string;
  out AError: string
): Boolean;
var
  LLastCodeToken: string;
  LToken: TRadIASemanticToken;
  LTrimmed: string;
begin
  Result := False;
  AError := '';
  LTrimmed := Trim(ASelectedText);
  if LTrimmed.IsEmpty then
    AError := 'Select one or more complete Delphi statements first.'
  else if Length(ASelectedText) > CMaxSelectionCharacters then
    AError := 'The selected Delphi block exceeds the 65536-character limit.'
  else
  begin
    LLastCodeToken := '';
    for LToken in TRadIASemanticLexer.Tokenize(ASelectedText) do
      if not (LToken.Kind in [stkWhitespace, stkComment, stkDirective]) then
        LLastCodeToken := LToken.Text;
    if LLastCodeToken <> ';' then
      AError := 'The selected Delphi block must end at a statement boundary.'
    else
      Result := ValidateTokens(ASelectedText, AError);
  end;
end;

class function TRadIADelphiExtractionAnalyzer.TryAnalyze(
  const ASource: string;
  const ASelectedText: string;
  const ACursorLine: Integer;
  const ACursorColumn: Integer;
  out ASelection: TRadIADelphiExtractSelection;
  out AError: string
): Boolean;
var
  LCursorOffset: Integer;
  LSelectionOffset: Integer;
begin
  Result := False;
  ASelection := Default(TRadIADelphiExtractSelection);
  if not ValidateSelectionText(ASelectedText, AError) then
    Exit;
  LCursorOffset := OffsetForPosition(ASource, ACursorLine, ACursorColumn);
  if LCursorOffset < 0 then
  begin
    AError := 'The editor cursor is outside the active buffer.';
    Exit;
  end;
  if not FindSelectionOffset(
    ASource,
    ASelectedText,
    LCursorOffset,
    LSelectionOffset,
    AError
  ) then
    Exit;
  ASelection := TRadIADelphiExtractSelection.Create(
    ASelectedText,
    LSelectionOffset
  );
  Result := True;
end;

class function TRadIADelphiExtractionAnalyzer.TryInferParameters(
  const ASource: string;
  const ASelection: TRadIADelphiExtractSelection;
  const ARoutineSignature: string;
  const ARoutineStartOffset: Integer;
  out AParameters: TArray<TRadIADelphiExtractParameter>;
  out AError: string
): Boolean;
var
  LBodyEnd: Integer;
  LBodyStart: Integer;
  LHeaderEnd: Integer;
  LSignature: TRadIADelphiSignature;
  LVariables: TRadIADelphiVariableMap;
begin
  Result := False;
  AParameters := nil;
  AError := '';
  if not TRadIADelphiSignatureParser.TryParse(
    ARoutineSignature,
    LSignature,
    AError
  ) then
    Exit;
  if not TryFindRoutineBody(
    ASource,
    ARoutineSignature,
    ARoutineStartOffset,
    LBodyStart,
    LBodyEnd,
    AError
  ) then
    Exit;
  if (ASelection.StartOffset <= LBodyStart) or
    (ASelection.StartOffset + ASelection.Length > LBodyEnd) then
  begin
    AError := 'The selection is outside the enclosing routine body.';
    Exit;
  end;
  if SelectionUsesFunctionResult(ASelection.Content) then
  begin
    AError := 'Extract Method does not move assignments to the function Result.';
    Exit;
  end;
  LVariables := TRadIADelphiVariableMap.Create([doOwnsValues]);
  try
    AddSignatureParameters(LSignature, LVariables);
    LHeaderEnd := ARoutineStartOffset + Length(ARoutineSignature);
    if not AddLocalVariables(
      Copy(ASource, LHeaderEnd + 1, LBodyStart - LHeaderEnd),
      LVariables,
      AError
    ) then
      Exit;
    MarkSelectionUsage(ASelection.Content, LVariables);
    AParameters := BuildExtractParameters(LVariables);
    Result := True;
  finally
    LVariables.Free;
  end;
end;

end.
