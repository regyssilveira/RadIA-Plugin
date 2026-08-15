unit RadIA.Core.DelphiSignatures;

interface

type
  TRadIADelphiRoutineKind = (
    drkUnknown,
    drkProcedure,
    drkFunction,
    drkConstructor,
    drkDestructor,
    drkOperator
  );

  TRadIADelphiParameter = record
  private
    FDefaultValue: string;
    FModifier: string;
    FName: string;
    FTypeName: string;
  public
    constructor Create(
      const AName: string;
      const AModifier: string;
      const ATypeName: string;
      const ADefaultValue: string
    );
    property DefaultValue: string read FDefaultValue;
    property Modifier: string read FModifier;
    property Name: string read FName;
    property TypeName: string read FTypeName;
  end;

  TRadIADelphiSignature = record
  private
    FDirectives: string;
    FIsClassRoutine: Boolean;
    FKind: TRadIADelphiRoutineKind;
    FName: string;
    FParameters: TArray<TRadIADelphiParameter>;
    FReturnType: string;
  public
    function FindParameter(const AName: string): Integer;
    property Directives: string read FDirectives;
    property IsClassRoutine: Boolean read FIsClassRoutine;
    property Kind: TRadIADelphiRoutineKind read FKind;
    property Name: string read FName;
    property Parameters: TArray<TRadIADelphiParameter> read FParameters;
    property ReturnType: string read FReturnType;
  end;

  TRadIADelphiSignatureParser = class
  strict private
    class function ExtractHeader(
      const AText: string;
      out ASignature: TRadIADelphiSignature;
      out AParameterText: string;
      out ASuffix: string;
      out AError: string
    ): Boolean; static;
    class function ParseParameters(
      const AText: string;
      out AParameters: TArray<TRadIADelphiParameter>;
      out AError: string
    ): Boolean; static;
  public
    class function TryParse(
      const AText: string;
      out ASignature: TRadIADelphiSignature;
      out AError: string
    ): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils;

function IsIdentifier(const AValue: string): Boolean;
var
  LIndex: Integer;
begin
  Result := not AValue.IsEmpty and
    CharInSet(AValue[1], ['A'..'Z', 'a'..'z', '_']);
  if not Result then
    Exit;
  for LIndex := 2 to Length(AValue) do
    if not CharInSet(AValue[LIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
end;

procedure UpdateNesting(
  const ACharacter: Char;
  var AAngleDepth: Integer;
  var ABracketDepth: Integer;
  var AParenthesisDepth: Integer
);
begin
  case ACharacter of
    '<': Inc(AAngleDepth);
    '>': if AAngleDepth > 0 then Dec(AAngleDepth);
    '[': Inc(ABracketDepth);
    ']': if ABracketDepth > 0 then Dec(ABracketDepth);
    '(': Inc(AParenthesisDepth);
    ')': if AParenthesisDepth > 0 then Dec(AParenthesisDepth);
  end;
end;

function IsTopLevel(
  const AAngleDepth: Integer;
  const ABracketDepth: Integer;
  const AParenthesisDepth: Integer
): Boolean;
begin
  Result := (AAngleDepth = 0) and (ABracketDepth = 0) and
    (AParenthesisDepth = 0);
end;

function FindTopLevelCharacter(
  const AText: string;
  const ACharacter: Char
): Integer;
var
  LAngleDepth: Integer;
  LBracketDepth: Integer;
  LCharacter: Char;
  LIndex: Integer;
  LParenthesisDepth: Integer;
  LQuote: Char;
begin
  Result := 0;
  LAngleDepth := 0;
  LBracketDepth := 0;
  LParenthesisDepth := 0;
  LQuote := #0;
  for LIndex := Low(AText) to High(AText) do
  begin
    LCharacter := AText[LIndex];
    if LQuote <> #0 then
    begin
      if LCharacter = LQuote then
        LQuote := #0;
      Continue;
    end;
    if CharInSet(LCharacter, ['''', '"']) then
    begin
      LQuote := LCharacter;
      Continue;
    end;
    UpdateNesting(
      LCharacter,
      LAngleDepth,
      LBracketDepth,
      LParenthesisDepth
    );
    if (LCharacter = ACharacter) and IsTopLevel(
      LAngleDepth,
      LBracketDepth,
      LParenthesisDepth
    ) then
      Exit(LIndex);
  end;
end;

function SplitTopLevel(
  const AText: string;
  const ASeparator: Char
): TArray<string>;
var
  LItem: string;
  LItems: TList<string>;
  LOffset: Integer;
  LRemaining: string;
begin
  LItems := TList<string>.Create;
  try
    LRemaining := AText;
    repeat
      LOffset := FindTopLevelCharacter(LRemaining, ASeparator);
      if LOffset = 0 then
      begin
        LItem := Trim(LRemaining);
        LRemaining := '';
      end
      else
      begin
        LItem := Trim(Copy(LRemaining, 1, LOffset - 1));
        Delete(LRemaining, 1, LOffset);
      end;
      if not LItem.IsEmpty then
        LItems.Add(LItem);
    until LRemaining.IsEmpty;
    Result := LItems.ToArray;
  finally
    LItems.Free;
  end;
end;

function RemovePrefix(var AText: string; const APrefix: string): Boolean;
begin
  Result := StartsText(APrefix + ' ', AText);
  if Result then
    AText := Trim(Copy(AText, Length(APrefix) + 1, MaxInt));
end;

function ParseRoutinePrefix(
  var AHeader: string;
  out AKind: TRadIADelphiRoutineKind;
  out AIsClassRoutine: Boolean
): Boolean;
begin
  AIsClassRoutine := RemovePrefix(AHeader, 'class');
  if RemovePrefix(AHeader, 'procedure') then
    AKind := drkProcedure
  else if RemovePrefix(AHeader, 'function') then
    AKind := drkFunction
  else if RemovePrefix(AHeader, 'constructor') then
    AKind := drkConstructor
  else if RemovePrefix(AHeader, 'destructor') then
    AKind := drkDestructor
  else if RemovePrefix(AHeader, 'operator') then
    AKind := drkOperator
  else
    AKind := drkUnknown;
  Result := AKind <> drkUnknown;
end;

function ExtractRoutineParts(
  const AHeader: string;
  out AName: string;
  out AParameterText: string;
  out ASuffix: string;
  out AError: string
): Boolean;
var
  LCloseOffset: Integer;
  LOpenOffset: Integer;
  LSeparatorOffset: Integer;
begin
  Result := False;
  AName := '';
  AParameterText := '';
  ASuffix := '';
  AError := '';
  LOpenOffset := Pos('(', AHeader);
  if LOpenOffset > 0 then
  begin
    LCloseOffset := LastDelimiter(')', AHeader);
    if LCloseOffset < LOpenOffset then
    begin
      AError := 'The Delphi parameter list is not balanced.';
      Exit;
    end;
    AName := Trim(Copy(AHeader, 1, LOpenOffset - 1));
    AParameterText := Copy(
      AHeader,
      LOpenOffset + 1,
      LCloseOffset - LOpenOffset - 1
    );
    ASuffix := Trim(Copy(AHeader, LCloseOffset + 1, MaxInt));
    Exit(True);
  end;
  LSeparatorOffset := FindTopLevelCharacter(AHeader, ';');
  if LSeparatorOffset = 0 then
    LSeparatorOffset := Pos(' ', AHeader);
  if LSeparatorOffset = 0 then
    AName := AHeader
  else
  begin
    AName := Trim(Copy(AHeader, 1, LSeparatorOffset - 1));
    ASuffix := Trim(Copy(AHeader, LSeparatorOffset + 1, MaxInt));
  end;
  Result := True;
end;

function ParseParameterGroup(
  const AGroup: string;
  out AParameters: TArray<TRadIADelphiParameter>;
  out AError: string
): Boolean;
var
  LColonOffset: Integer;
  LDefaultOffset: Integer;
  LDefaultValue: string;
  LModifier: string;
  LName: string;
  LNames: TArray<string>;
  LParameters: TList<TRadIADelphiParameter>;
  LRemainingGroup: string;
  LTypeName: string;
begin
  Result := False;
  AParameters := nil;
  AError := '';
  LRemainingGroup := AGroup;
  LModifier := '';
  if RemovePrefix(LRemainingGroup, 'const [Ref]') then
    LModifier := 'const [Ref]'
  else if RemovePrefix(LRemainingGroup, 'const') then
    LModifier := 'const'
  else if RemovePrefix(LRemainingGroup, 'var') then
    LModifier := 'var'
  else if RemovePrefix(LRemainingGroup, 'out') then
    LModifier := 'out';
  LColonOffset := FindTopLevelCharacter(LRemainingGroup, ':');
  if LColonOffset = 0 then
  begin
    AError := 'Each Delphi parameter group must declare a type.';
    Exit;
  end;
  LNames := SplitTopLevel(Copy(LRemainingGroup, 1, LColonOffset - 1), ',');
  LTypeName := Trim(Copy(LRemainingGroup, LColonOffset + 1, MaxInt));
  LDefaultOffset := FindTopLevelCharacter(LTypeName, '=');
  if LDefaultOffset > 0 then
  begin
    LDefaultValue := Trim(Copy(LTypeName, LDefaultOffset + 1, MaxInt));
    LTypeName := Trim(Copy(LTypeName, 1, LDefaultOffset - 1));
  end
  else
    LDefaultValue := '';
  if (Length(LNames) = 0) or LTypeName.IsEmpty then
  begin
    AError := 'A Delphi parameter name or type is empty.';
    Exit;
  end;
  LParameters := TList<TRadIADelphiParameter>.Create;
  try
    for LName in LNames do
    begin
      if not IsIdentifier(LName) then
      begin
        AError := 'A Delphi parameter name is invalid: ' + LName;
        Exit;
      end;
      LParameters.Add(TRadIADelphiParameter.Create(
        LName,
        LModifier,
        LTypeName,
        LDefaultValue
      ));
    end;
    AParameters := LParameters.ToArray;
    Result := True;
  finally
    LParameters.Free;
  end;
end;

constructor TRadIADelphiParameter.Create(
  const AName: string;
  const AModifier: string;
  const ATypeName: string;
  const ADefaultValue: string
);
begin
  FName := AName;
  FModifier := AModifier;
  FTypeName := ATypeName;
  FDefaultValue := ADefaultValue;
end;

function TRadIADelphiSignature.FindParameter(const AName: string): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to Length(FParameters) - 1 do
    if SameText(FParameters[LIndex].Name, AName) then
      Exit(LIndex);
  Result := -1;
end;

class function TRadIADelphiSignatureParser.ExtractHeader(
  const AText: string;
  out ASignature: TRadIADelphiSignature;
  out AParameterText: string;
  out ASuffix: string;
  out AError: string
): Boolean;
var
  LHeader: string;
begin
  Result := False;
  ASignature := Default(TRadIADelphiSignature);
  AParameterText := '';
  ASuffix := '';
  AError := '';
  LHeader := Trim(AText);
  if LHeader.EndsWith(';') then
    Delete(LHeader, Length(LHeader), 1);
  if not ParseRoutinePrefix(
    LHeader,
    ASignature.FKind,
    ASignature.FIsClassRoutine
  ) then
  begin
    AError := 'The text does not start with a supported Delphi routine kind.';
    Exit;
  end;
  if not ExtractRoutineParts(
    LHeader,
    ASignature.FName,
    AParameterText,
    ASuffix,
    AError
  ) then
    Exit;
  if ASignature.FName.IsEmpty then
  begin
    AError := 'The Delphi routine name is empty.';
    Exit;
  end;
  Result := True;
end;

class function TRadIADelphiSignatureParser.ParseParameters(
  const AText: string;
  out AParameters: TArray<TRadIADelphiParameter>;
  out AError: string
): Boolean;
var
  LGroup: string;
  LGroupParameters: TArray<TRadIADelphiParameter>;
  LGroups: TArray<string>;
  LParameters: TList<TRadIADelphiParameter>;
begin
  Result := False;
  AParameters := nil;
  AError := '';
  if Trim(AText).IsEmpty then
    Exit(True);
  LParameters := TList<TRadIADelphiParameter>.Create;
  try
    LGroups := SplitTopLevel(AText, ';');
    for LGroup in LGroups do
    begin
      if not ParseParameterGroup(LGroup, LGroupParameters, AError) then
        Exit;
      LParameters.AddRange(LGroupParameters);
    end;
    AParameters := LParameters.ToArray;
    Result := True;
  finally
    LParameters.Free;
  end;
end;

class function TRadIADelphiSignatureParser.TryParse(
  const AText: string;
  out ASignature: TRadIADelphiSignature;
  out AError: string
): Boolean;
var
  LParameterText: string;
  LReturnOffset: Integer;
  LSemicolonOffset: Integer;
  LSuffix: string;
begin
  Result := ExtractHeader(
    AText,
    ASignature,
    LParameterText,
    LSuffix,
    AError
  );
  if not Result then
    Exit;
  Result := ParseParameters(LParameterText, ASignature.FParameters, AError);
  if not Result then
    Exit;
  LReturnOffset := FindTopLevelCharacter(LSuffix, ':');
  if LReturnOffset > 0 then
  begin
    Delete(LSuffix, 1, LReturnOffset);
    LSemicolonOffset := FindTopLevelCharacter(LSuffix, ';');
    if LSemicolonOffset > 0 then
    begin
      ASignature.FReturnType := Trim(Copy(LSuffix, 1, LSemicolonOffset - 1));
      ASignature.FDirectives := Trim(Copy(LSuffix, LSemicolonOffset + 1, MaxInt));
    end
    else
    begin
      ASignature.FReturnType := Trim(LSuffix);
      ASignature.FDirectives := '';
    end;
  end
  else
  begin
    if LSuffix.StartsWith(';') then
      Delete(LSuffix, 1, 1);
    ASignature.FDirectives := Trim(LSuffix);
  end;
  if (ASignature.Kind = drkFunction) and ASignature.ReturnType.IsEmpty then
  begin
    AError := 'A Delphi function must declare a return type.';
    Exit(False);
  end;
  Result := True;
end;

end.
