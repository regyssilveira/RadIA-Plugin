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
    '"items":{"type":"string","maxLength":128}}},"additionalProperties":false}';
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

function ContainsText(const AValues: TList<string>; const AValue: string): Boolean;
var
  LItem: string;
begin
  Result := False;
  for LItem in AValues do
    if SameText(LItem, AValue) then
      Exit(True);
end;

procedure AddDistinct(const AValues: TList<string>; const AValue: string);
begin
  if not AValue.Trim.IsEmpty and not ContainsText(AValues, AValue) then
    AValues.Add(AValue);
end;

function ContainsSqlParameter(
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

function BuildParameterValidationJson(
  const AMissing: TList<string>;
  const AExtra: TList<string>
): string;
var
  LArray: TJSONArray;
  LItem: string;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('valid', TJSONBool.Create((AMissing.Count = 0) and (AExtra.Count = 0)));
    LArray := TJSONArray.Create;
    for LItem in AMissing do
      LArray.Add(LItem);
    LRoot.AddPair('missingBindings', LArray);
    LArray := TJSONArray.Create;
    for LItem in AExtra do
      LArray.Add(LItem);
    LRoot.AddPair('extraBindings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACTool.ValidateParameters(const AInput: TJSONObject): TRadIAToolResult;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LBindings: TJSONArray;
  LBindingNames: TList<string>;
  LExtra: TList<string>;
  LIndex: Integer;
  LMissing: TList<string>;
  LParameter: TRadIAFireDACSqlParameter;
  LSql: string;
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
  LBindingNames := TList<string>.Create;
  LMissing := TList<string>.Create;
  LExtra := TList<string>.Create;
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  try
    for LIndex := 0 to LBindings.Count - 1 do
      AddDistinct(LBindingNames, LBindings.Items[LIndex].Value);
    LAnalysis := LAnalyzer.Analyze(LSql);
    try
      for LParameter in LAnalysis.Parameters do
        if not ContainsText(LBindingNames, LParameter.Name) then
          LMissing.Add(LParameter.Name);
      for LIndex := 0 to LBindingNames.Count - 1 do
        if not ContainsSqlParameter(LAnalysis.Parameters, LBindingNames[LIndex]) then
          LExtra.Add(LBindingNames[LIndex]);
      Result := TRadIAToolResult.Succeeded(BuildParameterValidationJson(LMissing, LExtra));
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
    LExtra.Free;
    LMissing.Free;
    LBindingNames.Free;
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
        'Compares SQL placeholders with supplied FireDAC binding names without executing SQL.',
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
