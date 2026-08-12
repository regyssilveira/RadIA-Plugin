unit RadIA.Semantic.Preprocessor;

interface

uses
  RadIA.Semantic.Lexer;

type
  TRadIASemanticActivity = (
    saInactive,
    saActive,
    saUnknown
  );

  TRadIASemanticProcessedToken = record
  private
    FActivity: TRadIASemanticActivity;
    FToken: TRadIASemanticToken;
  public
    constructor Create(
      const AToken: TRadIASemanticToken;
      const AActivity: TRadIASemanticActivity
    );
    property Activity: TRadIASemanticActivity read FActivity;
    property Token: TRadIASemanticToken read FToken;
  end;

  TRadIASemanticIncludeReference = record
  private
    FActivity: TRadIASemanticActivity;
    FPath: string;
    FStartOffset: Integer;
  public
    constructor Create(
      const APath: string;
      const AStartOffset: Integer;
      const AActivity: TRadIASemanticActivity
    );
    property Activity: TRadIASemanticActivity read FActivity;
    property Path: string read FPath;
    property StartOffset: Integer read FStartOffset;
  end;

  TRadIASemanticPreprocessResult = record
  private
    FDiagnostics: TArray<string>;
    FIncludes: TArray<TRadIASemanticIncludeReference>;
    FTokens: TArray<TRadIASemanticProcessedToken>;
  public
    constructor Create(
      const ATokens: TArray<TRadIASemanticProcessedToken>;
      const ADiagnostics: TArray<string>;
      const AIncludes: TArray<TRadIASemanticIncludeReference>
    );
    property Diagnostics: TArray<string> read FDiagnostics;
    property Includes: TArray<TRadIASemanticIncludeReference> read FIncludes;
    property Tokens: TArray<TRadIASemanticProcessedToken> read FTokens;
  end;

  TRadIASemanticPreprocessor = class
  public
    class function Process(
      const ASource: string;
      const ADefines: TArray<string>
    ): TRadIASemanticPreprocessResult; static;
    class function ActivityName(
      const AActivity: TRadIASemanticActivity
    ): string; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils;

type
  TRadIASemanticConditionalFrame = record
    ParentActivity: TRadIASemanticActivity;
    CurrentActivity: TRadIASemanticActivity;
    KnownBranchTaken: Boolean;
    UnknownBranchSeen: Boolean;
  end;

function CombineActivity(
  const AParent: TRadIASemanticActivity;
  const AChild: TRadIASemanticActivity
): TRadIASemanticActivity;
begin
  if (AParent = saInactive) or (AChild = saInactive) then
    Exit(saInactive);
  if (AParent = saUnknown) or (AChild = saUnknown) then
    Exit(saUnknown);
  Result := saActive;
end;

function NegateActivity(
  const AValue: TRadIASemanticActivity
): TRadIASemanticActivity;
begin
  case AValue of
    saActive: Result := saInactive;
    saInactive: Result := saActive;
  else
    Result := saUnknown;
  end;
end;

function ExtractDirectiveBody(const AText: string): string;
begin
  Result := Trim(AText);
  if StartsText('{$', Result) then
    Result := Copy(Result, 3, Length(Result) - 3)
  else if StartsText('(*$', Result) then
    Result := Copy(Result, 4, Length(Result) - 5);
  Result := Trim(Result);
end;

procedure SplitDirective(
  const AText: string;
  out ACommand: string;
  out AArgument: string
);
var
  LPosition: Integer;
begin
  ACommand := ExtractDirectiveBody(AText);
  LPosition := Pos(' ', ACommand);
  if LPosition = 0 then
  begin
    AArgument := '';
    ACommand := UpperCase(ACommand);
    Exit;
  end;
  AArgument := Trim(Copy(ACommand, LPosition + 1, MaxInt));
  ACommand := UpperCase(Copy(ACommand, 1, LPosition - 1));
end;

procedure AddDiagnostic(
  const ADiagnostics: TList<string>;
  const AToken: TRadIASemanticToken;
  const AMessage: string
); forward;

function NormalizeIncludePath(const AArgument: string): string;
begin
  Result := Trim(AArgument);
  if (Length(Result) >= 2) and
    (((Result[1] = '''') and (Result[Length(Result)] = '''')) or
    ((Result[1] = '"') and (Result[Length(Result)] = '"'))) then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

procedure CollectInclude(
  const AToken: TRadIASemanticToken;
  const AActivity: TRadIASemanticActivity;
  const AIncludes: TList<TRadIASemanticIncludeReference>;
  const ADiagnostics: TList<string>
);
var
  LArgument: string;
  LCommand: string;
  LPath: string;
begin
  SplitDirective(AToken.Text, LCommand, LArgument);
  if not SameText(LCommand, 'I') and not SameText(LCommand, 'INCLUDE') then
    Exit;
  LPath := NormalizeIncludePath(LArgument);
  if LPath = '' then
  begin
    AddDiagnostic(ADiagnostics, AToken, 'Include directive has no path.');
    Exit;
  end;
  AIncludes.Add(
    TRadIASemanticIncludeReference.Create(
      LPath,
      AToken.StartOffset,
      AActivity
    )
  );
end;

function EvaluateDefinedExpression(
  const AExpression: string;
  const ADefines: TDictionary<string, Boolean>
): TRadIASemanticActivity;
var
  LExpression: string;
  LMatch: TMatch;
  LNegated: Boolean;
begin
  LExpression := Trim(AExpression);
  LNegated := StartsText('not ', LExpression);
  if LNegated then
    LExpression := Trim(Copy(LExpression, 5, MaxInt));
  LMatch := TRegEx.Match(
    LExpression,
    '^Defined\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)$',
    [roIgnoreCase]
  );
  if not LMatch.Success then
    Exit(saUnknown);
  if ADefines.ContainsKey(UpperCase(LMatch.Groups[1].Value)) then
    Result := saActive
  else
    Result := saInactive;
  if LNegated then
    Result := NegateActivity(Result);
end;

function EvaluateCondition(
  const ACommand: string;
  const AArgument: string;
  const ADefines: TDictionary<string, Boolean>
): TRadIASemanticActivity;
begin
  if SameText(ACommand, 'IFDEF') then
  begin
    if ADefines.ContainsKey(UpperCase(AArgument)) then
      Exit(saActive);
    Exit(saInactive);
  end;
  if SameText(ACommand, 'IFNDEF') then
    Exit(NegateActivity(EvaluateCondition('IFDEF', AArgument, ADefines)));
  Result := EvaluateDefinedExpression(AArgument, ADefines);
end;

procedure AddDiagnostic(
  const ADiagnostics: TList<string>;
  const AToken: TRadIASemanticToken;
  const AMessage: string
);
begin
  ADiagnostics.Add(
    Format('Offset %d: %s', [AToken.StartOffset, AMessage])
  );
end;

function CurrentActivity(
  const AStack: TList<TRadIASemanticConditionalFrame>
): TRadIASemanticActivity;
begin
  if AStack.Count = 0 then
    Exit(saActive);
  Result := AStack.Last.CurrentActivity;
end;

procedure OpenConditional(
  const AStack: TList<TRadIASemanticConditionalFrame>;
  const ACondition: TRadIASemanticActivity
);
var
  LFrame: TRadIASemanticConditionalFrame;
begin
  LFrame.ParentActivity := CurrentActivity(AStack);
  LFrame.CurrentActivity := CombineActivity(
    LFrame.ParentActivity,
    ACondition
  );
  LFrame.KnownBranchTaken := ACondition = saActive;
  LFrame.UnknownBranchSeen := ACondition = saUnknown;
  AStack.Add(LFrame);
end;

procedure SwitchConditionalBranch(
  const AStack: TList<TRadIASemanticConditionalFrame>;
  const ACondition: TRadIASemanticActivity;
  const AToken: TRadIASemanticToken;
  const ADiagnostics: TList<string>
);
var
  LFrame: TRadIASemanticConditionalFrame;
  LIndex: Integer;
  LSelected: TRadIASemanticActivity;
begin
  if AStack.Count = 0 then
  begin
    AddDiagnostic(ADiagnostics, AToken, 'Conditional branch has no matching IF.');
    Exit;
  end;
  LIndex := AStack.Count - 1;
  LFrame := AStack[LIndex];
  if LFrame.KnownBranchTaken then
    LSelected := saInactive
  else if LFrame.UnknownBranchSeen then
    LSelected := saUnknown
  else
    LSelected := ACondition;
  LFrame.CurrentActivity := CombineActivity(
    LFrame.ParentActivity,
    LSelected
  );
  LFrame.KnownBranchTaken := LFrame.KnownBranchTaken or
    (ACondition = saActive);
  LFrame.UnknownBranchSeen := LFrame.UnknownBranchSeen or
    (ACondition = saUnknown);
  AStack[LIndex] := LFrame;
end;

procedure ApplyDefine(
  const ACommand: string;
  const AArgument: string;
  const AActivity: TRadIASemanticActivity;
  const ADefines: TDictionary<string, Boolean>
);
begin
  if (AActivity <> saActive) or (Trim(AArgument) = '') then
    Exit;
  if SameText(ACommand, 'DEFINE') then
    ADefines.AddOrSetValue(UpperCase(AArgument), True)
  else
    ADefines.Remove(UpperCase(AArgument));
end;

procedure ProcessDirective(
  const AToken: TRadIASemanticToken;
  const AStack: TList<TRadIASemanticConditionalFrame>;
  const ADefines: TDictionary<string, Boolean>;
  const ADiagnostics: TList<string>
);
var
  LArgument: string;
  LCommand: string;
  LCondition: TRadIASemanticActivity;
begin
  SplitDirective(AToken.Text, LCommand, LArgument);
  if SameText(LCommand, 'IFDEF') or
    SameText(LCommand, 'IFNDEF') or
    SameText(LCommand, 'IF') then
  begin
    LCondition := EvaluateCondition(LCommand, LArgument, ADefines);
    if LCondition = saUnknown then
      AddDiagnostic(ADiagnostics, AToken, 'Conditional expression is unresolved.');
    OpenConditional(AStack, LCondition);
    Exit;
  end;
  if SameText(LCommand, 'ELSEIF') then
  begin
    LCondition := EvaluateCondition('IF', LArgument, ADefines);
    if LCondition = saUnknown then
      AddDiagnostic(ADiagnostics, AToken, 'ELSEIF expression is unresolved.');
    SwitchConditionalBranch(AStack, LCondition, AToken, ADiagnostics);
    Exit;
  end;
  if SameText(LCommand, 'ELSE') then
  begin
    SwitchConditionalBranch(AStack, saActive, AToken, ADiagnostics);
    Exit;
  end;
  if SameText(LCommand, 'ENDIF') or SameText(LCommand, 'IFEND') then
  begin
    if AStack.Count = 0 then
      AddDiagnostic(ADiagnostics, AToken, 'ENDIF has no matching IF.')
    else
      AStack.Delete(AStack.Count - 1);
    Exit;
  end;
  if SameText(LCommand, 'DEFINE') or SameText(LCommand, 'UNDEF') then
    ApplyDefine(LCommand, LArgument, CurrentActivity(AStack), ADefines);
end;

{ TRadIASemanticProcessedToken }

constructor TRadIASemanticProcessedToken.Create(
  const AToken: TRadIASemanticToken;
  const AActivity: TRadIASemanticActivity
);
begin
  FToken := AToken;
  FActivity := AActivity;
end;

{ TRadIASemanticIncludeReference }

constructor TRadIASemanticIncludeReference.Create(
  const APath: string;
  const AStartOffset: Integer;
  const AActivity: TRadIASemanticActivity
);
begin
  FPath := APath;
  FStartOffset := AStartOffset;
  FActivity := AActivity;
end;

{ TRadIASemanticPreprocessResult }

constructor TRadIASemanticPreprocessResult.Create(
  const ATokens: TArray<TRadIASemanticProcessedToken>;
  const ADiagnostics: TArray<string>;
  const AIncludes: TArray<TRadIASemanticIncludeReference>
);
begin
  FTokens := Copy(ATokens);
  FDiagnostics := Copy(ADiagnostics);
  FIncludes := Copy(AIncludes);
end;

{ TRadIASemanticPreprocessor }

class function TRadIASemanticPreprocessor.ActivityName(
  const AActivity: TRadIASemanticActivity
): string;
begin
  case AActivity of
    saInactive: Result := 'inactive';
    saActive: Result := 'active';
  else
    Result := 'unknown';
  end;
end;

class function TRadIASemanticPreprocessor.Process(
  const ASource: string;
  const ADefines: TArray<string>
): TRadIASemanticPreprocessResult;
var
  LActivity: TRadIASemanticActivity;
  LDefine: string;
  LDefines: TDictionary<string, Boolean>;
  LDiagnostics: TList<string>;
  LIncludes: TList<TRadIASemanticIncludeReference>;
  LProcessed: TList<TRadIASemanticProcessedToken>;
  LStack: TList<TRadIASemanticConditionalFrame>;
  LToken: TRadIASemanticToken;
begin
  LDefines := TDictionary<string, Boolean>.Create;
  LDiagnostics := TList<string>.Create;
  LIncludes := TList<TRadIASemanticIncludeReference>.Create;
  LProcessed := TList<TRadIASemanticProcessedToken>.Create;
  LStack := TList<TRadIASemanticConditionalFrame>.Create;
  try
    for LDefine in ADefines do
      if Trim(LDefine) <> '' then
        LDefines.AddOrSetValue(UpperCase(Trim(LDefine)), True);
    for LToken in TRadIASemanticLexer.Tokenize(ASource) do
    begin
      LActivity := CurrentActivity(LStack);
      LProcessed.Add(TRadIASemanticProcessedToken.Create(LToken, LActivity));
      if LToken.Kind = stkDirective then
      begin
        CollectInclude(LToken, LActivity, LIncludes, LDiagnostics);
        ProcessDirective(LToken, LStack, LDefines, LDiagnostics);
      end;
    end;
    if LStack.Count > 0 then
      LDiagnostics.Add(
        Format('%d conditional block(s) were not closed.', [LStack.Count])
      );
    Result := TRadIASemanticPreprocessResult.Create(
      LProcessed.ToArray,
      LDiagnostics.ToArray,
      LIncludes.ToArray
    );
  finally
    LIncludes.Free;
    LStack.Free;
    LProcessed.Free;
    LDiagnostics.Free;
    LDefines.Free;
  end;
end;

end.
