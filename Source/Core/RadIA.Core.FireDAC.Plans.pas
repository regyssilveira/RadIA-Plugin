unit RadIA.Core.FireDAC.Plans;

interface

uses
  RadIA.Core.Tools;

procedure RegisterRadIAFireDACPlanTools(const ARegistry: IRadIAToolRegistry);

implementation

uses
  System.JSON,
  System.StrUtils,
  System.SysUtils;

type
  TRadIAFireDACPlanKind = (fpkQueryOptimization, fpkThreadSafety);

  TRadIAFireDACPlanTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIAFireDACPlanKind;
    function BuildQueryPlan(const AInput: TJSONObject): TRadIAToolResult;
    function BuildThreadPlan(const AInput: TJSONObject): TRadIAToolResult;
  public
    constructor Create(const AKind: TRadIAFireDACPlanKind);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CQueryInputSchema =
    '{"type":"object","additionalProperties":false,"required":["statementKind"],' +
    '"properties":{"statementKind":{"type":"string","enum":["select","insert","update","delete","other"]},' +
    '"usesSelectAll":{"type":"boolean"},"hasWhere":{"type":"boolean"},' +
    '"parameterCount":{"type":"integer","minimum":0,"maximum":512},' +
    '"schemaCompared":{"type":"boolean"},"planEvidenceAvailable":{"type":"boolean"}}}';
  CThreadInputSchema =
    '{"type":"object","additionalProperties":false,"required":["componentType"],' +
    '"properties":{"componentType":{"type":"string","minLength":1,"maxLength":64},' +
    '"sharedConnection":{"type":"boolean"},"sharedDataset":{"type":"boolean"},' +
    '"uiAccessFromWorker":{"type":"boolean"},"ownerScope":{"type":"string",' +
    '"enum":["worker-local","shared","unknown"]}}}';
  CPlanOutputSchema =
    '{"type":"object","required":["deterministicFacts","steps","hypotheses","limitations"]}';

constructor TRadIAFireDACPlanTool.Create(const AKind: TRadIAFireDACPlanKind);
begin
  inherited Create;
  FKind := AKind;
end;

procedure AddBooleanFact(
  const AFacts: TJSONArray;
  const AName: string;
  const AValue: Boolean
);
var
  LFact: TJSONObject;
begin
  LFact := TJSONObject.Create;
  LFact.AddPair('name', AName);
  LFact.AddPair('value', TJSONBool.Create(AValue));
  AFacts.AddElement(LFact);
end;

function TRadIAFireDACPlanTool.BuildQueryPlan(
  const AInput: TJSONObject
): TRadIAToolResult;
var
  LFacts: TJSONArray;
  LHasWhere: Boolean;
  LHypotheses: TJSONArray;
  LLimitations: TJSONArray;
  LPlanEvidence: Boolean;
  LRoot: TJSONObject;
  LStatementKind: string;
  LSteps: TJSONArray;
  LUsesSelectAll: Boolean;
begin
  LStatementKind := AInput.GetValue<string>('statementKind', '').ToLower;
  if not MatchText(LStatementKind, ['select', 'insert', 'update', 'delete', 'other']) then
    Exit(TRadIAToolResult.Failed('invalid_statement_kind', 'A supported statement kind is required.'));
  LUsesSelectAll := AInput.GetValue<Boolean>('usesSelectAll', False);
  LHasWhere := AInput.GetValue<Boolean>('hasWhere', False);
  LPlanEvidence := AInput.GetValue<Boolean>('planEvidenceAvailable', False);
  LRoot := TJSONObject.Create;
  try
    LFacts := TJSONArray.Create;
    LSteps := TJSONArray.Create;
    LHypotheses := TJSONArray.Create;
    LLimitations := TJSONArray.Create;
    LRoot.AddPair('deterministicFacts', LFacts);
    LRoot.AddPair('steps', LSteps);
    LRoot.AddPair('hypotheses', LHypotheses);
    LRoot.AddPair('limitations', LLimitations);
    LRoot.AddPair('mutationApplied', TJSONBool.Create(False));
    LRoot.AddPair('contentTrust', 'untrusted-data');
    LFacts.Add(LStatementKind);
    AddBooleanFact(LFacts, 'usesSelectAll', LUsesSelectAll);
    AddBooleanFact(LFacts, 'hasWhere', LHasWhere);
    if LUsesSelectAll then
      LSteps.Add('Review the required projection and remove unused columns.');
    if (LStatementKind = 'select') and not LHasWhere then
      LSteps.Add('Confirm that an unfiltered read is intentional and bounded.');
    LSteps.Add('Validate parameters and compare referenced fields with the authorized schema.');
    LSteps.Add('Measure the unchanged and proposed query under the same representative workload.');
    if not LPlanEvidence then
      LHypotheses.Add('Index and latency improvements remain hypotheses without execution-plan evidence.');
    LLimitations.Add('This plan does not execute SQL or inspect row data.');
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACPlanTool.BuildThreadPlan(
  const AInput: TJSONObject
): TRadIAToolResult;
var
  LFacts: TJSONArray;
  LHypotheses: TJSONArray;
  LLimitations: TJSONArray;
  LOwnerScope: string;
  LRoot: TJSONObject;
  LSteps: TJSONArray;
begin
  if AInput.GetValue<string>('componentType', '').Trim.IsEmpty then
    Exit(TRadIAToolResult.Failed('component_required', 'A component type is required.'));
  LOwnerScope := AInput.GetValue<string>('ownerScope', 'unknown').ToLower;
  if not MatchText(LOwnerScope, ['worker-local', 'shared', 'unknown']) then
    Exit(TRadIAToolResult.Failed('invalid_owner_scope', 'A supported owner scope is required.'));
  LRoot := TJSONObject.Create;
  try
    LFacts := TJSONArray.Create;
    LSteps := TJSONArray.Create;
    LHypotheses := TJSONArray.Create;
    LLimitations := TJSONArray.Create;
    LRoot.AddPair('deterministicFacts', LFacts);
    LRoot.AddPair('steps', LSteps);
    LRoot.AddPair('hypotheses', LHypotheses);
    LRoot.AddPair('limitations', LLimitations);
    LRoot.AddPair('mutationApplied', TJSONBool.Create(False));
    LRoot.AddPair('contentTrust', 'untrusted-data');
    AddBooleanFact(LFacts, 'sharedConnection', AInput.GetValue<Boolean>('sharedConnection', False));
    AddBooleanFact(LFacts, 'sharedDataset', AInput.GetValue<Boolean>('sharedDataset', False));
    AddBooleanFact(LFacts, 'uiAccessFromWorker', AInput.GetValue<Boolean>('uiAccessFromWorker', False));
    LSteps.Add('Create and configure the FireDAC connection inside the worker thread.');
    LSteps.Add('Keep queries, datasets, and transactions owned by the same worker.');
    LSteps.Add('Queue or synchronize every VCL update on the main thread.');
    LSteps.Add('Close datasets and free worker-owned FireDAC objects before the worker exits.');
    if LOwnerScope = 'unknown' then
      LHypotheses.Add('Ownership must be confirmed before preparing a source patch.');
    LLimitations.Add('This plan does not change source files or prove runtime scheduling.');
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACPlanTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LInput: TJSONObject;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LInput) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
  try
    if FKind = fpkQueryOptimization then
      Result := BuildQueryPlan(LInput)
    else
      Result := BuildThreadPlan(LInput);
  finally
    LInput.Free;
  end;
end;

function TRadIAFireDACPlanTool.GetDescriptor: TRadIAToolDescriptor;
begin
  if FKind = fpkQueryOptimization then
    Result := TRadIAToolDescriptor.Create(
      'PrepareFireDACQueryOptimization',
      '1.0.0',
      'Prepares an evidence-aware FireDAC query optimization plan without executing SQL.',
      CQueryInputSchema,
      CPlanOutputSchema,
      trReadOnly
    )
  else
    Result := TRadIAToolDescriptor.Create(
      'PrepareFireDACThreadSafetyPlan',
      '1.0.0',
      'Prepares a deterministic FireDAC worker-isolation plan without changing source files.',
      CThreadInputSchema,
      CPlanOutputSchema,
      trReadOnly
    );
end;

procedure RegisterRadIAFireDACPlanTools(const ARegistry: IRadIAToolRegistry);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAFireDACPlanTool.Create(fpkQueryOptimization));
  ARegistry.RegisterTool(TRadIAFireDACPlanTool.Create(fpkThreadSafety));
end;

end.
