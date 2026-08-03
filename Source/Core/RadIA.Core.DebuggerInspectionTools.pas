unit RadIA.Core.DebuggerInspectionTools;

interface

uses
  RadIA.Core.Debugger,
  RadIA.Core.DebuggerWatches,
  RadIA.Core.Tools;

procedure RegisterRadIADebuggerInspectionTools(
  const ARegistry: IRadIAToolRegistry;
  const AEvaluator: IRadIADebuggerEvaluationFacade;
  const AWatches: IRadIADebuggerWatchService;
  const ASession: IRadIADebuggerSessionFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIADebuggerInspectionToolKind = (
    ditkEvaluateExpression,
    ditkAddWatch,
    ditkRemoveWatch,
    ditkListWatches,
    ditkEvaluateWatches,
    ditkStartDebugging
  );

  TRadIADebuggerInspectionTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FEvaluator: IRadIADebuggerEvaluationFacade;
    FKind: TRadIADebuggerInspectionToolKind;
    FSession: IRadIADebuggerSessionFacade;
    FWatches: IRadIADebuggerWatchService;
    function ExecuteExpression(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteWatchAction(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteWatchList(
      const AEvaluate: Boolean
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetExpression(const AArgumentsJson: string): string;
    function ValueToJson(
      const AValue: TRadIADebugValueSnapshot
    ): TJSONObject;
  public
    constructor Create(
      const AKind: TRadIADebuggerInspectionToolKind;
      const AEvaluator: IRadIADebuggerEvaluationFacade;
      const AWatches: IRadIADebuggerWatchService;
      const ASession: IRadIADebuggerSessionFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInput =
    '{"type":"object","additionalProperties":false}';
  CExpressionInput =
    '{"type":"object","required":["expression"],"properties":{' +
    '"expression":{"type":"string","minLength":1,"maxLength":256}},' +
    '"additionalProperties":false}';
  CObjectOutput = '{"type":"object"}';

procedure RegisterRadIADebuggerInspectionTools(
  const ARegistry: IRadIAToolRegistry;
  const AEvaluator: IRadIADebuggerEvaluationFacade;
  const AWatches: IRadIADebuggerWatchService;
  const ASession: IRadIADebuggerSessionFacade
);
var
  LKind: TRadIADebuggerInspectionToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AEvaluator) then
    raise EArgumentNilException.Create('AEvaluator');
  if not Assigned(AWatches) then
    raise EArgumentNilException.Create('AWatches');
  if not Assigned(ASession) then
    raise EArgumentNilException.Create('ASession');
  for LKind := Low(TRadIADebuggerInspectionToolKind) to
    High(TRadIADebuggerInspectionToolKind) do
    ARegistry.RegisterTool(
      TRadIADebuggerInspectionTool.Create(
        LKind,
        AEvaluator,
        AWatches,
        ASession
      )
    );
end;

constructor TRadIADebuggerInspectionTool.Create(
  const AKind: TRadIADebuggerInspectionToolKind;
  const AEvaluator: IRadIADebuggerEvaluationFacade;
  const AWatches: IRadIADebuggerWatchService;
  const ASession: IRadIADebuggerSessionFacade
);
begin
  inherited Create;
  FKind := AKind;
  FEvaluator := AEvaluator;
  FWatches := AWatches;
  FSession := ASession;
end;

function TRadIADebuggerInspectionTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAction: TRadIADebuggerActionResult;
begin
  case FKind of
    ditkEvaluateExpression:
      Result := ExecuteExpression(ARequest);
    ditkAddWatch,
    ditkRemoveWatch:
      Result := ExecuteWatchAction(ARequest);
    ditkListWatches:
      Result := ExecuteWatchList(False);
    ditkEvaluateWatches:
      Result := ExecuteWatchList(True);
    ditkStartDebugging:
      begin
        LAction := FSession.StartDebugging;
        if not LAction.Accepted then
          Result := TRadIAToolResult.Failed(
            LAction.ErrorCode,
            LAction.Message
          )
        else
          Result := TRadIAToolResult.Succeeded(
            '{"accepted":true,"stateBefore":"' +
            LAction.StateBefore + '","stateAfter":"' +
            LAction.StateAfter + '"}'
          );
      end;
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Debugger inspection tool kind is not supported.'
    );
  end;
end;

function TRadIADebuggerInspectionTool.ExecuteExpression(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LValue: TRadIADebugValueSnapshot;
begin
  LValue := FEvaluator.EvaluateExpression(
    GetExpression(ARequest.ArgumentsJson)
  );
  LJson := ValueToJson(LValue);
  try
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIADebuggerInspectionTool.ExecuteWatchAction(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LExpression: string;
  LJson: TJSONObject;
  LSuccess: Boolean;
begin
  LExpression := GetExpression(ARequest.ArgumentsJson);
  if FKind = ditkAddWatch then
    LSuccess := FWatches.Add(LExpression)
  else
    LSuccess := FWatches.Remove(LExpression);
  if not LSuccess then
    Exit(TRadIAToolResult.Failed(
      'watch_precondition_failed',
      'The watch already exists, is absent or the watch limit was reached.'
    ));
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('success', TJSONBool.Create(True));
    LJson.AddPair('expression', LExpression);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIADebuggerInspectionTool.ExecuteWatchList(
  const AEvaluate: Boolean
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LExpression: string;
  LExpressions: TArray<string>;
  LJson: TJSONObject;
  LValue: TRadIADebugValueSnapshot;
  LValues: TArray<TRadIADebugValueSnapshot>;
begin
  LJson := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LJson.AddPair('watches', LArray);
    if AEvaluate then
    begin
      LValues := FWatches.Evaluate(32);
      for LValue in LValues do
        LArray.AddElement(ValueToJson(LValue));
    end
    else
    begin
      LExpressions := FWatches.List;
      for LExpression in LExpressions do
        LArray.Add(LExpression);
    end;
    LJson.AddPair('count', TJSONNumber.Create(LArray.Count));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIADebuggerInspectionTool.GetDescriptor:
  TRadIAToolDescriptor;
var
  LDescription: string;
  LInput: string;
  LName: string;
  LRisk: TRadIAToolRisk;
begin
  LInput := CEmptyInput;
  LRisk := trReadOnly;
  case FKind of
    ditkEvaluateExpression:
      begin
        LName := 'EvaluateDebuggerExpression';
        LDescription := 'Evaluates an expression without debugger side effects.';
        LInput := CExpressionInput;
      end;
    ditkAddWatch:
      begin
        LName := 'AddDebuggerWatch';
        LDescription := 'Adds an expression to the bounded RadIA watch list.';
        LInput := CExpressionInput;
        LRisk := trStructuralWrite;
      end;
    ditkRemoveWatch:
      begin
        LName := 'RemoveDebuggerWatch';
        LDescription := 'Removes an expression from the RadIA watch list.';
        LInput := CExpressionInput;
        LRisk := trStructuralWrite;
      end;
    ditkListWatches:
      begin
        LName := 'ListDebuggerWatches';
        LDescription := 'Lists the bounded RadIA debugger watch expressions.';
      end;
    ditkEvaluateWatches:
      begin
        LName := 'EvaluateDebuggerWatches';
        LDescription := 'Evaluates all RadIA watches without side effects.';
      end;
    ditkStartDebugging:
      begin
        LName := 'StartDebugging';
        LDescription := 'Builds and starts the active project under the IDE debugger.';
        LRisk := trExecution;
      end;
  else
    Exit(Default(TRadIAToolDescriptor));
  end;
  Result := TRadIAToolDescriptor.Create(
    LName,
    '1.0',
    LDescription,
    LInput,
    CObjectOutput,
    LRisk
  );
end;

function TRadIADebuggerInspectionTool.GetExpression(
  const AArgumentsJson: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    AArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create(
      'Arguments must be a JSON object.'
    );
  try
    Result := Trim(
      LJson.GetValue<string>('expression', '')
    );
    if Result = '' then
      raise EArgumentException.Create(
        'expression must not be empty.'
      );
    if Length(Result) > 256 then
      raise EArgumentOutOfRangeException.Create(
        'expression exceeds 256 characters.'
      );
    if Result.Contains(#10) or Result.Contains(#13) or
      Result.Contains(#0) then
      raise EArgumentException.Create(
        'expression must use a single text line.'
      );
  finally
    LJson.Free;
  end;
end;

function TRadIADebuggerInspectionTool.ValueToJson(
  const AValue: TRadIADebugValueSnapshot
): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('expression', AValue.Expression);
  Result.AddPair('result', AValue.ResultText);
  Result.AddPair('status', AValue.Status);
  Result.AddPair('canModify', TJSONBool.Create(AValue.CanModify));
  Result.AddPair(
    'address',
    TJSONNumber.Create(AValue.Address)
  );
  Result.AddPair('size', TJSONNumber.Create(AValue.Size));
end;

end.
