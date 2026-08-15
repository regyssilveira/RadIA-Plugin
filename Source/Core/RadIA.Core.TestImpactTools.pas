unit RadIA.Core.TestImpactTools;

interface

uses
  RadIA.Core.DUnitX,
  RadIA.Core.TestImpact,
  RadIA.Core.Tools;

procedure RegisterRadIATestImpactTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIATestImpactService;
  const ARunner: IRadIADUnitXRunner
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIATestImpactToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FRunner: IRadIADUnitXRunner;
    FService: IRadIATestImpactService;
    function BuildPlanJson(
      const APlan: TRadIATestImpactPlan
    ): TJSONObject;
    function ParseArray(
      const AJson: TJSONObject;
      const AName: string
    ): TArray<string>;
    function PlanFromJson(
      const AJson: TJSONObject
    ): TRadIATestImpactResult;
    function StatusName(const AStatus: TRadIADUnitXRunStatus): string;
  public
    constructor Create(
      const AService: IRadIATestImpactService;
      const ARunner: IRadIADUnitXRunner
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor; virtual; abstract;
  end;

  TRadIAPlanImpactedDUnitXTestsTool = class(TRadIATestImpactToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIARunImpactedDUnitXTestsTool = class(TRadIATestImpactToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

const
  CPlanInputSchema =
    '{"type":"object","required":["changedFiles"],"properties":{' +
    '"changedFiles":{"type":"array","minItems":1,"maxItems":100,' +
    '"items":{"type":"string","minLength":1}},"changedSymbols":{' +
    '"type":"array","maxItems":100,"items":{"type":"string",' +
    '"minLength":1}},"coverageReport":{"type":"string"}},' +
    '"additionalProperties":false}';
  CRunInputSchema =
    '{"type":"object","required":["changedFiles","executablePath"],' +
    '"properties":{"changedFiles":{"type":"array","minItems":1,' +
    '"maxItems":100,"items":{"type":"string","minLength":1}},' +
    '"changedSymbols":{"type":"array","maxItems":100,"items":{' +
    '"type":"string","minLength":1}},"coverageReport":{' +
    '"type":"string"},"executablePath":{"type":"string",' +
    '"minLength":1},"timeoutMs":{"type":"integer","minimum":1000,' +
    '"maximum":600000}},"additionalProperties":false}';
  CPlanOutputSchema =
    '{"type":"object","required":["runMode","confidence",' +
    '"changedUnits","selectedFixtures","reasons"],"properties":{' +
    '"runMode":{"type":"string"},"confidence":{"type":"string"},' +
    '"changedUnits":{"type":"array"},"selectedFixtures":{' +
    '"type":"array"},"reasons":{"type":"array"}}}';

function ArrayJson(const AValues: TArray<string>): TJSONArray;
var
  LValue: string;
begin
  Result := TJSONArray.Create;
  for LValue in AValues do
    Result.Add(LValue);
end;

constructor TRadIATestImpactToolBase.Create(
  const AService: IRadIATestImpactService;
  const ARunner: IRadIADUnitXRunner
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  if not Assigned(ARunner) then
    raise EArgumentNilException.Create('ARunner');
  FService := AService;
  FRunner := ARunner;
end;

function TRadIATestImpactToolBase.BuildPlanJson(
  const APlan: TRadIATestImpactPlan
): TJSONObject;
begin
  Result := TJSONObject.Create;
  if APlan.FullSuite then
    Result.AddPair('runMode', 'full')
  else
    Result.AddPair('runMode', 'selected');
  Result.AddPair('confidence', APlan.Confidence);
  Result.AddPair('coverageAvailable', TJSONBool.Create(APlan.CoverageAvailable));
  Result.AddPair('changedUnits', ArrayJson(APlan.ChangedUnits));
  Result.AddPair('changedSymbols', ArrayJson(APlan.ChangedSymbols));
  Result.AddPair('selectedFixtures', ArrayJson(APlan.SelectedFixtures));
  Result.AddPair('selectedTestUnits', ArrayJson(APlan.SelectedTestUnits));
  Result.AddPair(
    'coverageMatchedUnits',
    ArrayJson(APlan.CoverageMatchedUnits)
  );
  Result.AddPair('reasons', ArrayJson(APlan.Reasons));
end;

function TRadIATestImpactToolBase.ParseArray(
  const AJson: TJSONObject;
  const AName: string
): TArray<string>;
var
  LArray: TJSONArray;
  LIndex: Integer;
begin
  Result := nil;
  if not AJson.TryGetValue<TJSONArray>(AName, LArray) then
    Exit;
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
    Result[LIndex] := Trim(LArray[LIndex].Value);
end;

function TRadIATestImpactToolBase.PlanFromJson(
  const AJson: TJSONObject
): TRadIATestImpactResult;
begin
  Result := FService.Plan(
    ParseArray(AJson, 'changedFiles'),
    ParseArray(AJson, 'changedSymbols'),
    Trim(AJson.GetValue<string>('coverageReport', ''))
  );
end;

function TRadIATestImpactToolBase.StatusName(
  const AStatus: TRadIADUnitXRunStatus
): string;
begin
  case AStatus of
    drsSucceeded: Result := 'succeeded';
    drsCancelled: Result := 'cancelled';
    drsTimedOut: Result := 'timedOut';
    drsRunning: Result := 'running';
    drsIdle: Result := 'idle';
  else
    Result := 'failed';
  end;
end;

function TRadIAPlanImpactedDUnitXTestsTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LPlanJson: TJSONObject;
  LResult: TRadIATestImpactResult;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Test impact arguments must be a JSON object.'
    ));
  try
    LResult := PlanFromJson(LArguments);
    if not LResult.Success then
      Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
    LPlanJson := BuildPlanJson(LResult.Plan);
    try
      Result := TRadIAToolResult.Succeeded(LPlanJson.ToJSON);
    finally
      LPlanJson.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAPlanImpactedDUnitXTestsTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PlanImpactedDUnitXTests',
    '1.0.0',
    'Explains the smallest safe DUnitX fixture set for workspace changes.',
    CPlanInputSchema,
    CPlanOutputSchema,
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

function TRadIARunImpactedDUnitXTestsTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LExecutablePath: string;
  LExecution: TRadIADUnitXRunResult;
  LOutput: TJSONObject;
  LPlanResult: TRadIATestImpactResult;
  LReport: TJSONValue;
  LTimeoutMs: Integer;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Test impact arguments must be a JSON object.'
    ));
  try
    LExecutablePath := Trim(
      LArguments.GetValue<string>('executablePath', '')
    );
    if LExecutablePath.IsEmpty then
      Exit(TRadIAToolResult.Failed(
        'invalid_executable',
        'Executable path is required.'
      ));
    LTimeoutMs := LArguments.GetValue<Integer>('timeoutMs', 120000);
    if (LTimeoutMs < 1000) or (LTimeoutMs > 600000) then
      Exit(TRadIAToolResult.Failed(
        'invalid_timeout',
        'Timeout must be between 1000 and 600000 milliseconds.'
      ));
    LPlanResult := PlanFromJson(LArguments);
    if not LPlanResult.Success then
      Exit(TRadIAToolResult.Failed(
        LPlanResult.ErrorCode,
        LPlanResult.ErrorMessage
      ));
    LExecution := FRunner.Execute(TRadIADUnitXRunRequest.Create(
      LExecutablePath,
      LTimeoutMs,
      LPlanResult.Plan.SelectedFixtures
    ));
    if not LExecution.ErrorCode.IsEmpty then
      Exit(TRadIAToolResult.Failed(
        LExecution.ErrorCode,
        LExecution.ErrorMessage
      ));
    LOutput := BuildPlanJson(LPlanResult.Plan);
    try
      LOutput.AddPair('status', StatusName(LExecution.Status));
      LOutput.AddPair('exitCode', TJSONNumber.Create(LExecution.ExitCode));
      LOutput.AddPair(
        'durationMs',
        TJSONNumber.Create(LExecution.DurationMs)
      );
      LReport := TJSONObject.ParseJSONValue(LExecution.Report.ToJson);
      LOutput.AddPair('report', LReport);
      Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
    finally
      LOutput.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIARunImpactedDUnitXTestsTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'RunImpactedDUnitXTests',
    '1.0.0',
    'Plans, explains, and runs impacted DUnitX fixtures or the full suite.',
    CRunInputSchema,
    CPlanOutputSchema,
    trExecution
  ).WithExecutionOptions(600000, False);
end;

procedure RegisterRadIATestImpactTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIATestImpactService;
  const ARunner: IRadIADUnitXRunner
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(
    TRadIAPlanImpactedDUnitXTestsTool.Create(AService, ARunner)
  );
  ARegistry.RegisterTool(
    TRadIARunImpactedDUnitXTestsTool.Create(AService, ARunner)
  );
end;

end.
