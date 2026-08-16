unit RadIA.Core.FireDAC.Parameters;

interface

uses
  System.Generics.Collections,
  RadIA.Core.FireDAC.Model,
  RadIA.Core.FireDAC.SqlAnalyzer;

type
  TRadIAFireDACParameterDirection = (
    fpdUnknown,
    fpdInput,
    fpdOutput,
    fpdInputOutput,
    fpdResult
  );

  TRadIAFireDACParameterBinding = record
  private
    FAssignmentKind: string;
    FDataType: string;
    FDirection: TRadIAFireDACParameterDirection;
    FName: string;
    FNullable: string;
    FSize: Integer;
    FValueState: string;
  public
    constructor Create(
      const AName: string;
      const ADataType: string;
      const ADirection: TRadIAFireDACParameterDirection;
      const ASize: Integer;
      const ANullable: string;
      const AValueState: string;
      const AAssignmentKind: string
    );
    property AssignmentKind: string read FAssignmentKind;
    property DataType: string read FDataType;
    property Direction: TRadIAFireDACParameterDirection read FDirection;
    property Name: string read FName;
    property Nullable: string read FNullable;
    property Size: Integer read FSize;
    property ValueState: string read FValueState;
  end;

  TRadIAFireDACParameterValidation = class
  private
    FBindings: TList<TRadIAFireDACParameterBinding>;
    FFindings: TList<TRadIAFireDACFinding>;
    FMissing: TList<string>;
    FExtra: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddBinding(const ABinding: TRadIAFireDACParameterBinding);
    procedure AddExtra(const AName: string);
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    procedure AddMissing(const AName: string);
    function ToJson: string;
  end;

  TRadIAFireDACParameterValidator = class
  private
    procedure AnalyzeBinding(
      const ABinding: TRadIAFireDACParameterBinding;
      const ALocation: TRadIAFireDACLocation;
      const AResult: TRadIAFireDACParameterValidation
    );
    function ContainsBinding(
      const ABindings: TArray<TRadIAFireDACParameterBinding>;
      const AName: string
    ): Boolean;
    function ContainsParameter(
      const AParameters: TArray<TRadIAFireDACSqlParameter>;
      const AName: string
    ): Boolean;
  public
    function Validate(
      const AParameters: TArray<TRadIAFireDACSqlParameter>;
      const ABindings: TArray<TRadIAFireDACParameterBinding>;
      const ALocation: TRadIAFireDACLocation
    ): TRadIAFireDACParameterValidation;
  end;

function RadIAFireDACParameterDirection(
  const AValue: string
): TRadIAFireDACParameterDirection;
function RadIAFireDACParameterDirectionName(
  const AValue: TRadIAFireDACParameterDirection
): string;

implementation

uses
  System.JSON,
  System.StrUtils,
  System.SysUtils;

function RadIAFireDACParameterDirection(
  const AValue: string
): TRadIAFireDACParameterDirection;
begin
  if MatchText(AValue, ['input', 'ptInput']) then
    Exit(fpdInput);
  if MatchText(AValue, ['output', 'ptOutput']) then
    Exit(fpdOutput);
  if MatchText(AValue, ['inputOutput', 'ptInputOutput']) then
    Exit(fpdInputOutput);
  if MatchText(AValue, ['result', 'ptResult']) then
    Exit(fpdResult);
  Result := fpdUnknown;
end;

function RadIAFireDACParameterDirectionName(
  const AValue: TRadIAFireDACParameterDirection
): string;
const
  CNames: array[TRadIAFireDACParameterDirection] of string = (
    'unknown', 'input', 'output', 'inputOutput', 'result'
  );
begin
  Result := CNames[AValue];
end;

constructor TRadIAFireDACParameterBinding.Create(
  const AName: string;
  const ADataType: string;
  const ADirection: TRadIAFireDACParameterDirection;
  const ASize: Integer;
  const ANullable: string;
  const AValueState: string;
  const AAssignmentKind: string
);
begin
  FName := AName.Trim;
  FDataType := ADataType.Trim;
  FDirection := ADirection;
  FSize := ASize;
  FNullable := LowerCase(ANullable.Trim);
  FValueState := LowerCase(AValueState.Trim);
  FAssignmentKind := AAssignmentKind.Trim;
end;

constructor TRadIAFireDACParameterValidation.Create;
begin
  inherited Create;
  FBindings := TList<TRadIAFireDACParameterBinding>.Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
  FMissing := TList<string>.Create;
  FExtra := TList<string>.Create;
end;

destructor TRadIAFireDACParameterValidation.Destroy;
begin
  FExtra.Free;
  FMissing.Free;
  FFindings.Free;
  FBindings.Free;
  inherited;
end;

procedure TRadIAFireDACParameterValidation.AddBinding(
  const ABinding: TRadIAFireDACParameterBinding
);
begin
  if FBindings.Count < CRadIAFireDACMaximumParameters then
    FBindings.Add(ABinding);
end;

procedure TRadIAFireDACParameterValidation.AddExtra(const AName: string);
begin
  if FExtra.Count < CRadIAFireDACMaximumParameters then
    FExtra.Add(AName);
end;

procedure TRadIAFireDACParameterValidation.AddFinding(
  const AFinding: TRadIAFireDACFinding
);
begin
  if FFindings.Count < CRadIAFireDACMaximumFindings then
    FFindings.Add(AFinding);
end;

procedure TRadIAFireDACParameterValidation.AddMissing(const AName: string);
begin
  if FMissing.Count < CRadIAFireDACMaximumParameters then
    FMissing.Add(AName);
end;

function FindingJson(const AFinding: TRadIAFireDACFinding): TJSONObject;
var
  LEvidence: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AFinding.Id);
  Result.AddPair('ruleId', AFinding.RuleId);
  Result.AddPair('severity', RadIAFireDACSeverityName(AFinding.Severity));
  Result.AddPair('confidence', RadIAFireDACConfidenceName(AFinding.Confidence));
  Result.AddPair('title', AFinding.Title);
  Result.AddPair('message', AFinding.Message);
  Result.AddPair('file', AFinding.Location.FileName);
  Result.AddPair('line', TJSONNumber.Create(AFinding.Location.Line));
  Result.AddPair('symbol', AFinding.Symbol);
  LEvidence := TJSONArray.Create;
  if not AFinding.Evidence.IsEmpty then
    LEvidence.Add(AFinding.Evidence);
  Result.AddPair('evidence', LEvidence);
  Result.AddPair('suggestedAction', AFinding.SuggestedAction);
  Result.AddPair('automaticFixAvailable', TJSONBool.Create(AFinding.AutomaticFixAvailable));
end;

function BindingJson(const ABinding: TRadIAFireDACParameterBinding): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', ABinding.Name);
  Result.AddPair('dataType', ABinding.DataType);
  Result.AddPair('direction', RadIAFireDACParameterDirectionName(ABinding.Direction));
  Result.AddPair('size', TJSONNumber.Create(ABinding.Size));
  Result.AddPair('nullable', ABinding.Nullable);
  Result.AddPair('valueState', ABinding.ValueState);
  Result.AddPair('assignmentKind', ABinding.AssignmentKind);
end;

function TRadIAFireDACParameterValidation.ToJson: string;
var
  LArray: TJSONArray;
  LBinding: TRadIAFireDACParameterBinding;
  LFinding: TRadIAFireDACFinding;
  LItem: string;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('valid', TJSONBool.Create(
      (FMissing.Count = 0) and (FExtra.Count = 0) and (FFindings.Count = 0)
    ));
    LArray := TJSONArray.Create;
    for LBinding in FBindings do
      LArray.AddElement(BindingJson(LBinding));
    LRoot.AddPair('bindings', LArray);
    LArray := TJSONArray.Create;
    for LItem in FMissing do
      LArray.Add(LItem);
    LRoot.AddPair('missingBindings', LArray);
    LArray := TJSONArray.Create;
    for LItem in FExtra do
      LArray.Add(LItem);
    LRoot.AddPair('extraBindings', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(FindingJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACParameterValidator.ContainsBinding(
  const ABindings: TArray<TRadIAFireDACParameterBinding>;
  const AName: string
): Boolean;
var
  LBinding: TRadIAFireDACParameterBinding;
begin
  Result := False;
  for LBinding in ABindings do
    if SameText(LBinding.Name, AName) then
      Exit(True);
end;

function TRadIAFireDACParameterValidator.ContainsParameter(
  const AParameters: TArray<TRadIAFireDACSqlParameter>;
  const AName: string
): Boolean;
var
  LParameter: TRadIAFireDACSqlParameter;
begin
  Result := False;
  for LParameter in AParameters do
    if SameText(LParameter.Name, AName) then
      Exit(True);
end;

function IsStringType(const ADataType: string): Boolean;
begin
  Result := MatchText(ADataType, ['ftString', 'ftWideString', 'string', 'wideString']);
end;

function AssignmentMatchesType(const ABinding: TRadIAFireDACParameterBinding): Boolean;
begin
  Result := True;
  if ABinding.AssignmentKind.IsEmpty or ABinding.DataType.IsEmpty then
    Exit;
  if SameText(ABinding.AssignmentKind, 'AsInteger') then
    Result := MatchText(ABinding.DataType, ['ftSmallint', 'ftInteger', 'ftWord', 'ftLongWord', 'ftLargeint'])
  else if SameText(ABinding.AssignmentKind, 'AsString') then
    Result := IsStringType(ABinding.DataType)
  else if SameText(ABinding.AssignmentKind, 'AsBoolean') then
    Result := MatchText(ABinding.DataType, ['ftBoolean', 'boolean'])
  else if SameText(ABinding.AssignmentKind, 'AsDateTime') then
    Result := MatchText(ABinding.DataType, ['ftDate', 'ftTime', 'ftDateTime', 'ftTimeStamp']);
end;

procedure TRadIAFireDACParameterValidator.AnalyzeBinding(
  const ABinding: TRadIAFireDACParameterBinding;
  const ALocation: TRadIAFireDACLocation;
  const AResult: TRadIAFireDACParameterValidation
);
begin
  if IsStringType(ABinding.DataType) and (ABinding.Size <= 0) then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.parameter.string-size-missing',
      ffsMedium,
      ffcStrong,
      'String parameter has no explicit size',
      'A string parameter binding has no positive size.',
      TRadIAFireDACFindingDetails.Create(
        ALocation,
        ABinding.Name,
        'The declared string binding size is zero or absent.',
        'Declare the expected parameter size from the verified schema.',
        False
      )
    ));
  if SameText(ABinding.Nullable, 'false') and SameText(ABinding.ValueState, 'null') then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.parameter.null-not-allowed',
      ffsHigh,
      ffcProven,
      'Null assigned to non-null binding',
      'A binding declared as non-null has an explicit null value.',
      TRadIAFireDACFindingDetails.Create(
        ALocation,
        ABinding.Name,
        'The binding metadata declares nullable=false and valueState=null.',
        'Assign a non-null value or verify and update the nullability contract.',
        False
      )
    ));
  if not AssignmentMatchesType(ABinding) then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.parameter.assignment-type-mismatch',
      ffsHigh,
      ffcStrong,
      'Parameter assignment conflicts with declared type',
      'The assignment accessor does not match the declared parameter type.',
      TRadIAFireDACFindingDetails.Create(
        ALocation,
        ABinding.Name,
        ABinding.AssignmentKind + ' conflicts with ' + ABinding.DataType + '.',
        'Use an accessor compatible with the verified parameter type.',
        False
      )
    ));
end;

function TRadIAFireDACParameterValidator.Validate(
  const AParameters: TArray<TRadIAFireDACSqlParameter>;
  const ABindings: TArray<TRadIAFireDACParameterBinding>;
  const ALocation: TRadIAFireDACLocation
): TRadIAFireDACParameterValidation;
var
  LBinding: TRadIAFireDACParameterBinding;
  LParameter: TRadIAFireDACSqlParameter;
begin
  Result := TRadIAFireDACParameterValidation.Create;
  try
    for LParameter in AParameters do
      if not ContainsBinding(ABindings, LParameter.Name) then
        Result.AddMissing(LParameter.Name);
    for LBinding in ABindings do
    begin
      Result.AddBinding(LBinding);
      if not ContainsParameter(AParameters, LBinding.Name) then
        Result.AddExtra(LBinding.Name);
      AnalyzeBinding(LBinding, ALocation, Result);
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
