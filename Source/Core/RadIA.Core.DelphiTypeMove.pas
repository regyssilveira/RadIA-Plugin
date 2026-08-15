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

implementation

uses
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils,
  RadIA.Semantic.Lexer;

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
