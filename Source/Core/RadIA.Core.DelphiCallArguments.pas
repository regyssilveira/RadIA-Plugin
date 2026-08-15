unit RadIA.Core.DelphiCallArguments;

interface

uses
  RadIA.Core.DelphiSignatures;

type
  TRadIADelphiArgumentBinding = record
  private
    FExpression: string;
    FParameterName: string;
  public
    constructor Create(
      const AParameterName: string;
      const AExpression: string
    );
    property Expression: string read FExpression;
    property ParameterName: string read FParameterName;
  end;

  TRadIADelphiCallRewriteRequest = record
  private
    FArgumentText: string;
    FBindings: TArray<TRadIADelphiArgumentBinding>;
    FDelta: TRadIADelphiSignatureDelta;
    FNewSignature: TRadIADelphiSignature;
    FOldSignature: TRadIADelphiSignature;
  public
    constructor Create(
      const AArgumentText: string;
      const AOldSignature: TRadIADelphiSignature;
      const ANewSignature: TRadIADelphiSignature;
      const ADelta: TRadIADelphiSignatureDelta;
      const ABindings: TArray<TRadIADelphiArgumentBinding>
    );
    property ArgumentText: string read FArgumentText;
    property Bindings: TArray<TRadIADelphiArgumentBinding> read FBindings;
    property Delta: TRadIADelphiSignatureDelta read FDelta;
    property NewSignature: TRadIADelphiSignature read FNewSignature;
    property OldSignature: TRadIADelphiSignature read FOldSignature;
  end;

  TRadIADelphiCallRewrite = record
  private
    FArgumentText: string;
    FRemovedArgumentCount: Integer;
    FUsedNamedArguments: Boolean;
  public
    class function TryCreate(
      const ARequest: TRadIADelphiCallRewriteRequest;
      out ARewrite: TRadIADelphiCallRewrite;
      out AError: string
    ): Boolean; static;
    property ArgumentText: string read FArgumentText;
    property RemovedArgumentCount: Integer read FRemovedArgumentCount;
    property UsedNamedArguments: Boolean read FUsedNamedArguments;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils;

type
  TRadIAParsedArgument = record
  private
    FExpression: string;
    FName: string;
  public
    constructor Create(const AName: string; const AExpression: string);
    property Expression: string read FExpression;
    property Name: string read FName;
  end;

  TRadIADelphiCallBuildContext = record
    Bindings: TArray<TRadIADelphiArgumentBinding>;
    Delta: TRadIADelphiSignatureDelta;
    NewSignature: TRadIADelphiSignature;
    OldExpressions: TArray<string>;
    UseNames: Boolean;
  end;

constructor TRadIADelphiArgumentBinding.Create(
  const AParameterName: string;
  const AExpression: string
);
begin
  FParameterName := AParameterName;
  FExpression := AExpression;
end;

constructor TRadIADelphiCallRewriteRequest.Create(
  const AArgumentText: string;
  const AOldSignature: TRadIADelphiSignature;
  const ANewSignature: TRadIADelphiSignature;
  const ADelta: TRadIADelphiSignatureDelta;
  const ABindings: TArray<TRadIADelphiArgumentBinding>
);
begin
  FArgumentText := AArgumentText;
  FOldSignature := AOldSignature;
  FNewSignature := ANewSignature;
  FDelta := ADelta;
  FBindings := Copy(ABindings);
end;

constructor TRadIAParsedArgument.Create(
  const AName: string;
  const AExpression: string
);
begin
  FName := AName;
  FExpression := AExpression;
end;

function TryParseArgument(
  const AText: string;
  out AArgument: TRadIAParsedArgument;
  out AError: string
): Boolean;
var
  LColonOffset: Integer;
begin
  Result := False;
  AArgument := Default(TRadIAParsedArgument);
  AError := '';
  LColonOffset := TRadIADelphiSignatureParser.FindTopLevel(AText, ':');
  if (LColonOffset > 0) and (LColonOffset < Length(AText)) and
    (AText[LColonOffset + 1] = '=') then
  begin
    AArgument := TRadIAParsedArgument.Create(
      Trim(Copy(AText, 1, LColonOffset - 1)),
      Trim(Copy(AText, LColonOffset + 2, MaxInt))
    );
    if AArgument.Name.IsEmpty or AArgument.Expression.IsEmpty then
    begin
      AError := 'A named Delphi argument is incomplete.';
      Exit;
    end;
  end
  else
    AArgument := TRadIAParsedArgument.Create('', Trim(AText));
  if AArgument.Expression.IsEmpty then
  begin
    AError := 'A Delphi call contains an empty argument.';
    Exit;
  end;
  Result := True;
end;

function ParseArguments(
  const AText: string;
  out AArguments: TArray<TRadIAParsedArgument>;
  out AUsesNamed: Boolean;
  out AError: string
): Boolean;
var
  LArgument: TRadIAParsedArgument;
  LItem: string;
  LItems: TArray<string>;
  LList: TList<TRadIAParsedArgument>;
begin
  Result := False;
  AArguments := nil;
  AUsesNamed := False;
  AError := '';
  if Trim(AText).IsEmpty then
    Exit(True);
  LItems := TRadIADelphiSignatureParser.SplitTopLevelItems(AText, ',');
  LList := TList<TRadIAParsedArgument>.Create;
  try
    for LItem in LItems do
    begin
      if not TryParseArgument(LItem, LArgument, AError) then
        Exit;
      AUsesNamed := AUsesNamed or not LArgument.Name.IsEmpty;
      LList.Add(LArgument);
    end;
    AArguments := LList.ToArray;
    Result := True;
  finally
    LList.Free;
  end;
end;

function BindOldArguments(
  const AArguments: TArray<TRadIAParsedArgument>;
  const ASignature: TRadIADelphiSignature;
  out AExpressions: TArray<string>;
  out AError: string
): Boolean;
var
  LArgument: TRadIAParsedArgument;
  LIndex: Integer;
  LParameterIndex: Integer;
begin
  Result := False;
  AError := '';
  SetLength(AExpressions, Length(ASignature.Parameters));
  LParameterIndex := 0;
  for LIndex := 0 to Length(AArguments) - 1 do
  begin
    LArgument := AArguments[LIndex];
    if LArgument.Name.IsEmpty then
    begin
      while (LParameterIndex < Length(AExpressions)) and
        not AExpressions[LParameterIndex].IsEmpty do
        Inc(LParameterIndex);
    end
    else
      LParameterIndex := ASignature.FindParameter(LArgument.Name);
    if (LParameterIndex < 0) or (LParameterIndex >= Length(AExpressions)) then
    begin
      AError := 'A call argument does not match the old Delphi signature.';
      Exit;
    end;
    if not AExpressions[LParameterIndex].IsEmpty then
    begin
      AError := 'A Delphi call supplies the same parameter more than once.';
      Exit;
    end;
    AExpressions[LParameterIndex] := LArgument.Expression;
    Inc(LParameterIndex);
  end;
  Result := True;
end;

function BindingFor(
  const AParameterName: string;
  const ABindings: TArray<TRadIADelphiArgumentBinding>
): string;
var
  LBinding: TRadIADelphiArgumentBinding;
begin
  for LBinding in ABindings do
    if SameText(LBinding.ParameterName, AParameterName) then
      Exit(LBinding.Expression);
  Result := '';
end;

function IsConservativePureExpression(const AExpression: string): Boolean;
var
  LCharacter: Char;
begin
  Result := not AExpression.IsEmpty;
  for LCharacter in AExpression do
    if not CharInSet(
      LCharacter,
      ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '''', ' ', '#', '$']
    ) then
      Exit(False);
end;

function CountRemovedArguments(
  const AOldExpressions: TArray<string>;
  const ADelta: TRadIADelphiSignatureDelta;
  out AError: string
): Integer;
var
  LIndex: Integer;
  LNewToOld: Integer;
  LUsed: TArray<Boolean>;
begin
  Result := 0;
  AError := '';
  SetLength(LUsed, Length(AOldExpressions));
  for LNewToOld in ADelta.NewToOld do
    if LNewToOld >= 0 then
      LUsed[LNewToOld] := True;
  for LIndex := 0 to Length(AOldExpressions) - 1 do
    if not LUsed[LIndex] and not AOldExpressions[LIndex].IsEmpty then
    begin
      if not IsConservativePureExpression(AOldExpressions[LIndex]) then
      begin
        AError := 'A removed argument may have side effects: ' +
          AOldExpressions[LIndex];
        Exit(-1);
      end;
      Inc(Result);
    end;
end;

function ResolveNewExpression(
  const ANewIndex: Integer;
  const AOldExpressions: TArray<string>;
  const ANewSignature: TRadIADelphiSignature;
  const ADelta: TRadIADelphiSignatureDelta;
  const ABindings: TArray<TRadIADelphiArgumentBinding>
): string;
var
  LOldIndex: Integer;
begin
  LOldIndex := ADelta.NewToOld[ANewIndex];
  if (LOldIndex >= 0) and (LOldIndex < Length(AOldExpressions)) then
    Result := AOldExpressions[LOldIndex]
  else
    Result := BindingFor(
      ANewSignature.Parameters[ANewIndex].Name,
      ABindings
    );
  if Result.IsEmpty then
    Result := ANewSignature.Parameters[ANewIndex].DefaultValue;
end;

function BuildNewArguments(
  const AContext: TRadIADelphiCallBuildContext;
  out AText: string;
  out AError: string
): Boolean;
var
  LExpression: string;
  LIndex: Integer;
begin
  Result := False;
  AText := '';
  AError := '';
  for LIndex := 0 to Length(AContext.NewSignature.Parameters) - 1 do
  begin
    LExpression := ResolveNewExpression(
      LIndex,
      AContext.OldExpressions,
      AContext.NewSignature,
      AContext.Delta,
      AContext.Bindings
    );
    if LExpression.IsEmpty then
    begin
      AError := 'A new required parameter has no argument binding: ' +
        AContext.NewSignature.Parameters[LIndex].Name;
      Exit;
    end;
    if not AText.IsEmpty then
      AText := AText + ', ';
    if AContext.UseNames then
      AText := AText +
        AContext.NewSignature.Parameters[LIndex].Name + ' := ';
    AText := AText + LExpression;
  end;
  Result := True;
end;

class function TRadIADelphiCallRewrite.TryCreate(
  const ARequest: TRadIADelphiCallRewriteRequest;
  out ARewrite: TRadIADelphiCallRewrite;
  out AError: string
): Boolean;
var
  LArguments: TArray<TRadIAParsedArgument>;
  LContext: TRadIADelphiCallBuildContext;
  LOldExpressions: TArray<string>;
  LRemovedArgumentCount: Integer;
begin
  ARewrite := Default(TRadIADelphiCallRewrite);
  Result := ParseArguments(
    ARequest.ArgumentText,
    LArguments,
    ARewrite.FUsedNamedArguments,
    AError
  );
  if not Result then
    Exit;
  if not BindOldArguments(
    LArguments,
    ARequest.OldSignature,
    LOldExpressions,
    AError
  ) then
    Exit(False);
  LRemovedArgumentCount := CountRemovedArguments(
    LOldExpressions,
    ARequest.Delta,
    AError
  );
  if LRemovedArgumentCount < 0 then
    Exit(False);
  ARewrite.FRemovedArgumentCount := LRemovedArgumentCount;
  LContext.Bindings := ARequest.Bindings;
  LContext.Delta := ARequest.Delta;
  LContext.NewSignature := ARequest.NewSignature;
  LContext.OldExpressions := LOldExpressions;
  LContext.UseNames := ARewrite.FUsedNamedArguments;
  Result := BuildNewArguments(
    LContext,
    ARewrite.FArgumentText,
    AError
  );
end;

end.
