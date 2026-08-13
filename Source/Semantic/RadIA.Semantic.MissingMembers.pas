unit RadIA.Semantic.MissingMembers;

interface

uses
  RadIA.Semantic.Index;

type
  TRadIASemanticMissingMemberPreview = record
  private
    FChanged: Boolean;
    FErrorMessage: string;
    FMissingCount: Integer;
    FProposedSource: string;
  public
    constructor Create(
      const AChanged: Boolean;
      const AMissingCount: Integer;
      const AProposedSource: string;
      const AErrorMessage: string
    );
    property Changed: Boolean read FChanged;
    property ErrorMessage: string read FErrorMessage;
    property MissingCount: Integer read FMissingCount;
    property ProposedSource: string read FProposedSource;
  end;

  TRadIASemanticMissingMemberGenerator = class
  public
    class function Generate(
      const ASource: string;
      const AContainerName: string;
      const AMissingMembers: TArray<TRadIASemanticIndexedSymbol>;
      const ADefines: TArray<string>
    ): TRadIASemanticMissingMemberPreview; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  RadIA.Semantic.Lexer,
  RadIA.Semantic.Parser;

function InsertText(
  const ASource: string;
  const AOffset: Integer;
  const AText: string
): string;
begin
  Result := Copy(ASource, 1, AOffset) + AText +
    Copy(ASource, AOffset + 1, MaxInt);
end;

function IsStructuralKeyword(const AText: string): Boolean;
begin
  Result := SameText(AText, 'class') or SameText(AText, 'record') or
    SameText(AText, 'interface') or SameText(AText, 'object');
end;

function IsClassMethodModifier(
  const ATokens: TArray<TRadIASemanticToken>;
  const AIndex: Integer
): Boolean;
begin
  Result := (AIndex + 1 < Length(ATokens)) and
    (SameText(ATokens[AIndex + 1].Text, 'procedure') or
     SameText(ATokens[AIndex + 1].Text, 'function') or
     SameText(ATokens[AIndex + 1].Text, 'operator'));
end;

function FindTypeEndOffset(
  const ASource: string;
  const ATypeOffset: Integer
): Integer;
var
  LDepth: Integer;
  LIndex: Integer;
  LStarted: Boolean;
  LTokens: TArray<TRadIASemanticToken>;
begin
  Result := -1;
  LDepth := 0;
  LStarted := False;
  LTokens := TRadIASemanticLexer.Tokenize(ASource);
  for LIndex := 0 to High(LTokens) do
  begin
    if LTokens[LIndex].StartOffset < ATypeOffset then
      Continue;
    if IsStructuralKeyword(LTokens[LIndex].Text) and
      not IsClassMethodModifier(LTokens, LIndex) then
    begin
      Inc(LDepth);
      LStarted := True;
      Continue;
    end;
    if LStarted and SameText(LTokens[LIndex].Text, 'end') then
    begin
      Dec(LDepth);
      if LDepth = 0 then
        Exit(LTokens[LIndex].StartOffset);
    end;
  end;
end;

function FindModuleEndOffset(const ASource: string): Integer;
var
  LIndex: Integer;
  LTokens: TArray<TRadIASemanticToken>;
begin
  Result := -1;
  LTokens := TRadIASemanticLexer.Tokenize(ASource);
  for LIndex := High(LTokens) - 1 downto 0 do
    if SameText(LTokens[LIndex].Text, 'end') and
      (LTokens[LIndex + 1].Text = '.') then
      Exit(LTokens[LIndex].StartOffset);
end;

function FindTargetType(
  const AParsed: TRadIASemanticParseResult;
  const AContainerName: string;
  out ASymbol: TRadIASemanticSymbol
): Boolean;
var
  LSymbol: TRadIASemanticSymbol;
begin
  for LSymbol in AParsed.Symbols do
    if SameText(LSymbol.Name, AContainerName) and
      (LSymbol.Kind in [sskClass, sskRecord, sskHelper]) then
    begin
      ASymbol := LSymbol;
      Exit(True);
    end;
  ASymbol := Default(TRadIASemanticSymbol);
  Result := False;
end;

function MethodDeclaration(
  const ASymbol: TRadIASemanticIndexedSymbol;
  const AOverloaded: Boolean
): string;
begin
  Result := Trim(ASymbol.Signature);
  if not Result.EndsWith(';') then
    Result := Result + ';';
  if AOverloaded then
    Result := Result + ' overload;';
end;

function QualifiedDeclaration(
  const ADeclaration: string;
  const AMethodName: string;
  const AContainerName: string
): string;
var
  LNameOffset: Integer;
begin
  LNameOffset := Pos(AMethodName, ADeclaration);
  if LNameOffset = 0 then
    Exit(ADeclaration);
  Result := Copy(ADeclaration, 1, LNameOffset - 1) +
    AContainerName + '.' + AMethodName +
    Copy(ADeclaration, LNameOffset + Length(AMethodName), MaxInt);
end;

function BuildDeclarationBlock(
  const AMissingMembers: TArray<TRadIASemanticIndexedSymbol>;
  const AExistingNames: TDictionary<string, Integer>
): string;
var
  LCount: Integer;
  LMember: TRadIASemanticIndexedSymbol;
begin
  Result := sLineBreak + '  public' + sLineBreak;
  for LMember in AMissingMembers do
  begin
    AExistingNames.TryGetValue(LowerCase(LMember.Name), LCount);
    Result := Result + '    ' + MethodDeclaration(LMember, LCount > 1) +
      sLineBreak;
  end;
end;

function BuildImplementationBlock(
  const AContainerName: string;
  const AMissingMembers: TArray<TRadIASemanticIndexedSymbol>
): string;
var
  LDeclaration: string;
  LMember: TRadIASemanticIndexedSymbol;
begin
  Result := '';
  for LMember in AMissingMembers do
  begin
    LDeclaration := MethodDeclaration(LMember, False);
    LDeclaration := QualifiedDeclaration(
      LDeclaration,
      LMember.Name,
      AContainerName
    );
    Result := Result + LDeclaration + sLineBreak + 'begin' + sLineBreak +
      'end;' + sLineBreak + sLineBreak;
  end;
end;

function BuildMethodNameCounts(
  const AParsed: TRadIASemanticParseResult;
  const AContainerName: string;
  const AMissingMembers: TArray<TRadIASemanticIndexedSymbol>
): TDictionary<string, Integer>;
var
  LCount: Integer;
  LIndexedSymbol: TRadIASemanticIndexedSymbol;
  LSymbol: TRadIASemanticSymbol;
begin
  Result := TDictionary<string, Integer>.Create;
  for LSymbol in AParsed.Symbols do
    if (LSymbol.Kind = sskMethod) and
      SameText(LSymbol.ContainerName, AContainerName) then
    begin
      Result.TryGetValue(LowerCase(LSymbol.Name), LCount);
      Result.AddOrSetValue(LowerCase(LSymbol.Name), LCount + 1);
    end;
  for LIndexedSymbol in AMissingMembers do
  begin
    Result.TryGetValue(LowerCase(LIndexedSymbol.Name), LCount);
    Result.AddOrSetValue(LowerCase(LIndexedSymbol.Name), LCount + 1);
  end;
end;

{ TRadIASemanticMissingMemberPreview }

constructor TRadIASemanticMissingMemberPreview.Create(
  const AChanged: Boolean;
  const AMissingCount: Integer;
  const AProposedSource: string;
  const AErrorMessage: string
);
begin
  FChanged := AChanged;
  FMissingCount := AMissingCount;
  FProposedSource := AProposedSource;
  FErrorMessage := AErrorMessage;
end;

{ TRadIASemanticMissingMemberGenerator }

class function TRadIASemanticMissingMemberGenerator.Generate(
  const ASource: string;
  const AContainerName: string;
  const AMissingMembers: TArray<TRadIASemanticIndexedSymbol>;
  const ADefines: TArray<string>
): TRadIASemanticMissingMemberPreview;
var
  LDeclarationBlock: string;
  LImplementationBlock: string;
  LMethodNames: TDictionary<string, Integer>;
  LModuleEnd: Integer;
  LParsed: TRadIASemanticParseResult;
  LProposed: string;
  LTargetType: TRadIASemanticSymbol;
  LTypeEnd: Integer;
begin
  if Length(AMissingMembers) = 0 then
    Exit(TRadIASemanticMissingMemberPreview.Create(False, 0, ASource, ''));
  LParsed := TRadIASemanticParser.Parse(ASource, ADefines);
  if not FindTargetType(LParsed, AContainerName, LTargetType) then
    Exit(TRadIASemanticMissingMemberPreview.Create(
      False,
      0,
      ASource,
      'The target class was not found in the current source.'
    ));
  LTypeEnd := FindTypeEndOffset(ASource, LTargetType.StartOffset);
  LModuleEnd := FindModuleEndOffset(ASource);
  if (LTypeEnd < 0) or (LModuleEnd < 0) then
    Exit(TRadIASemanticMissingMemberPreview.Create(
      False,
      0,
      ASource,
      'The target class or unit boundary is incomplete.'
    ));
  LMethodNames := BuildMethodNameCounts(
    LParsed,
    AContainerName,
    AMissingMembers
  );
  try
    LDeclarationBlock := BuildDeclarationBlock(
      AMissingMembers,
      LMethodNames
    );
    LImplementationBlock := BuildImplementationBlock(
      AContainerName,
      AMissingMembers
    );
  finally
    LMethodNames.Free;
  end;
  LProposed := InsertText(ASource, LModuleEnd, LImplementationBlock);
  LProposed := InsertText(LProposed, LTypeEnd, LDeclarationBlock);
  Result := TRadIASemanticMissingMemberPreview.Create(
    True,
    Length(AMissingMembers),
    LProposed,
    ''
  );
end;

end.
