unit RadIA.Core.FireDAC.Tools;

interface

uses
  RadIA.Core.Tools;

procedure RegisterRadIAFireDACTools(const ARegistry: IRadIAToolRegistry);

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  RadIA.Core.FireDAC.Model,
  RadIA.Core.FireDAC.Parameters,
  RadIA.Core.FireDAC.SqlAnalyzer;

const
  CAnalyzeInputSchema =
    '{"type":"object","required":["sql"],' +
    '"properties":{"sql":{"type":"string","maxLength":262144},' +
    '"file":{"type":"string","maxLength":1024},' +
    '"line":{"type":"integer","minimum":0}},"additionalProperties":false}';
  CValidateInputSchema =
    '{"type":"object","required":["sql","bindings"],' +
    '"properties":{"sql":{"type":"string","maxLength":262144},' +
    '"bindings":{"type":"array","maxItems":512,' +
    '"items":{"oneOf":[{"type":"string","maxLength":128},' +
    '{"type":"object","required":["name"],"properties":{' +
    '"name":{"type":"string","maxLength":128},' +
    '"dataType":{"type":"string","maxLength":64},' +
    '"direction":{"type":"string","enum":["unknown","input","output","inputOutput","result"]},' +
    '"size":{"type":"integer","minimum":0,"maximum":2147483647},' +
    '"nullable":{"type":"string","enum":["unknown","true","false"]},' +
    '"valueState":{"type":"string","enum":["unknown","value","null"]},' +
    '"assignmentKind":{"type":"string","maxLength":64}},' +
    '"additionalProperties":false}]}}},"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

type
  TRadIAFireDACToolKind = (ftkAnalyzeQuery, ftkValidateParameters);

  TRadIAFireDACTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIAFireDACToolKind;
    function AnalyzeQuery(const AInput: TJSONObject): TRadIAToolResult;
    function ValidateParameters(const AInput: TJSONObject): TRadIAToolResult;
  public
    constructor Create(const AKind: TRadIAFireDACToolKind);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIAFireDACTool.Create(const AKind: TRadIAFireDACToolKind);
begin
  inherited Create;
  FKind := AKind;
end;

function TRadIAFireDACTool.AnalyzeQuery(const AInput: TJSONObject): TRadIAToolResult;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LFileName: string;
  LLine: Integer;
  LSql: string;
begin
  LSql := AInput.GetValue<string>('sql', '');
  if LSql.Trim.IsEmpty then
    Exit(TRadIAToolResult.Failed('sql_required', 'A non-empty SQL value is required.'));
  LFileName := AInput.GetValue<string>('file', '');
  LLine := AInput.GetValue<Integer>('line', 0);
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  try
    LAnalysis := LAnalyzer.Analyze(LSql, LFileName, LLine);
    try
      Result := TRadIAToolResult.Succeeded(LAnalysis.ToJson, LAnalysis.Truncated);
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

function ContainsBinding(
  const AValues: TList<TRadIAFireDACParameterBinding>;
  const AName: string
): Boolean;
var
  LItem: TRadIAFireDACParameterBinding;
begin
  Result := False;
  for LItem in AValues do
    if SameText(LItem.Name, AName) then
      Exit(True);
end;

function TryParseBinding(
  const AValue: TJSONValue;
  out ABinding: TRadIAFireDACParameterBinding
): Boolean;
var
  LObject: TJSONObject;
  LName: string;
begin
  Result := False;
  if AValue is TJSONString then
  begin
    LName := AValue.Value.Trim;
    if LName.IsEmpty then
      Exit;
    ABinding := TRadIAFireDACParameterBinding.Create(
      LName, '', fpdUnknown, 0, 'unknown', 'unknown', ''
    );
    Exit(True);
  end;
  if not (AValue is TJSONObject) then
    Exit;
  LObject := TJSONObject(AValue);
  LName := LObject.GetValue<string>('name', '').Trim;
  if LName.IsEmpty then
    Exit;
  ABinding := TRadIAFireDACParameterBinding.Create(
    LName,
    LObject.GetValue<string>('dataType', ''),
    RadIAFireDACParameterDirection(LObject.GetValue<string>('direction', 'unknown')),
    LObject.GetValue<Integer>('size', 0),
    LObject.GetValue<string>('nullable', 'unknown'),
    LObject.GetValue<string>('valueState', 'unknown'),
    LObject.GetValue<string>('assignmentKind', '')
  );
  Result := True;
end;

function TRadIAFireDACTool.ValidateParameters(const AInput: TJSONObject): TRadIAToolResult;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LBinding: TRadIAFireDACParameterBinding;
  LBindings: TJSONArray;
  LBindingValues: TList<TRadIAFireDACParameterBinding>;
  LIndex: Integer;
  LSql: string;
  LValidation: TRadIAFireDACParameterValidation;
  LValidator: TRadIAFireDACParameterValidator;
begin
  LSql := AInput.GetValue<string>('sql', '');
  LBindings := AInput.GetValue<TJSONArray>('bindings');
  if LSql.Trim.IsEmpty or not Assigned(LBindings) then
    Exit(TRadIAToolResult.Failed(
      'sql_and_bindings_required',
      'A non-empty SQL value and a bindings array are required.'
    ));
  if LBindings.Count > CRadIAFireDACMaximumParameters then
    Exit(TRadIAToolResult.Failed('too_many_bindings', 'The binding limit was exceeded.'));
  LBindingValues := TList<TRadIAFireDACParameterBinding>.Create;
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  LValidator := TRadIAFireDACParameterValidator.Create;
  try
    for LIndex := 0 to LBindings.Count - 1 do
    begin
      if not TryParseBinding(LBindings.Items[LIndex], LBinding) then
        Exit(TRadIAToolResult.Failed('invalid_binding', 'Each binding requires a non-empty name.'));
      if not ContainsBinding(LBindingValues, LBinding.Name) then
        LBindingValues.Add(LBinding);
    end;
    LAnalysis := LAnalyzer.Analyze(LSql);
    try
      LValidation := LValidator.Validate(
        LAnalysis.Parameters,
        LBindingValues.ToArray,
        TRadIAFireDACLocation.Create('', 0)
      );
      try
        Result := TRadIAToolResult.Succeeded(LValidation.ToJson);
      finally
        LValidation.Free;
      end;
    finally
      LAnalysis.Free;
    end;
  finally
    LValidator.Free;
    LAnalyzer.Free;
    LBindingValues.Free;
  end;
end;

function TRadIAFireDACTool.Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
var
  LInput: TJSONObject;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LInput) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Invalid JSON object.'));
  try
    case FKind of
      ftkAnalyzeQuery:
        Result := AnalyzeQuery(LInput);
      ftkValidateParameters:
        Result := ValidateParameters(LInput);
    else
      Result := TRadIAToolResult.Failed('unsupported_tool', 'Unsupported FireDAC tool.');
    end;
  finally
    LInput.Free;
  end;
end;

function TRadIAFireDACTool.GetDescriptor: TRadIAToolDescriptor;
begin
  case FKind of
    ftkAnalyzeQuery:
      Result := TRadIAToolDescriptor.Create(
        'AnalyzeFireDACQuery',
        '1.0.0',
        'Analyzes bounded SQL text without connecting to or querying a database.',
        CAnalyzeInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    ftkValidateParameters:
      Result := TRadIAToolDescriptor.Create(
        'ValidateFireDACParameters',
        '1.0.0',
        'Validates FireDAC binding names, types, directions, sizes, and null state without executing SQL.',
        CValidateInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  else
    raise EInvalidOpException.Create('Unsupported FireDAC tool kind.');
  end;
end;

procedure RegisterRadIAFireDACTools(const ARegistry: IRadIAToolRegistry);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAFireDACTool.Create(ftkAnalyzeQuery));
  ARegistry.RegisterTool(TRadIAFireDACTool.Create(ftkValidateParameters));
end;

end.
