unit RadIA.Core.RuntimePerformance;

interface

uses
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools;

type
  TRadIARuntimePerformanceSummary = record
  private
    FCpuTimeMs: UInt64;
    FDurationMs: UInt64;
    FPeakPrivateBytes: UInt64;
    FPeakWorkingSetBytes: UInt64;
    FSampleCount: Integer;
    FUnresponsiveSamples: Integer;
  public
    constructor Create(
      const ADurationMs: UInt64;
      const ACpuTimeMs: UInt64;
      const APeakWorkingSetBytes: UInt64;
      const APeakPrivateBytes: UInt64;
      const ASampleCount: Integer;
      const AUnresponsiveSamples: Integer
    );
    function IsUsable: Boolean;
    property DurationMs: UInt64 read FDurationMs;
    property CpuTimeMs: UInt64 read FCpuTimeMs;
    property PeakWorkingSetBytes: UInt64 read FPeakWorkingSetBytes;
    property PeakPrivateBytes: UInt64 read FPeakPrivateBytes;
    property SampleCount: Integer read FSampleCount;
    property UnresponsiveSamples: Integer read FUnresponsiveSamples;
  end;

  IRadIARuntimePerformanceSampler = interface
    ['{1057785F-C1E8-408A-B286-DA51BC1280A7}']
    function BeginMeasurement(
      const AProcessId: LongWord;
      const AMaximumDurationMs: Cardinal;
      out AErrorMessage: string
    ): Boolean;
    function CompleteMeasurement(
      out ASummary: TRadIARuntimePerformanceSummary;
      out AErrorMessage: string
    ): Boolean;
    procedure CancelMeasurement;
  end;

  IRadIARuntimePerformanceCoordinator = interface
    ['{08F5476F-F3FB-4100-A2B3-EC310BE29DD2}']
    function BeginMeasurement(
      const AScenarioKey: string;
      const AMaximumDurationMs: Cardinal
    ): TRadIAToolResult;
    function CompleteMeasurement: TRadIAToolResult;
    function Compare(
      const ABaselineEvidenceId: string;
      const AVerificationEvidenceId: string
    ): TRadIAToolResult;
    function Cancel: Boolean;
  end;

  TRadIARuntimePerformanceCoordinator = class(
    TInterfacedObject,
    IRadIARuntimePerformanceCoordinator
  )
  private type
    TRadIARuntimePerformanceEvidence = class
    private
      FBuildId: string;
      FContentJson: string;
      FEvidenceId: string;
      FProjectPath: string;
      FScenarioKey: string;
      FSessionId: string;
      FSummary: TRadIARuntimePerformanceSummary;
    public
      property BuildId: string read FBuildId write FBuildId;
      property ContentJson: string read FContentJson write FContentJson;
      property EvidenceId: string read FEvidenceId write FEvidenceId;
      property ProjectPath: string read FProjectPath write FProjectPath;
      property ScenarioKey: string read FScenarioKey write FScenarioKey;
      property SessionId: string read FSessionId write FSessionId;
      property Summary: TRadIARuntimePerformanceSummary read FSummary write FSummary;
    end;
  private
    FActiveBuildId: string;
    FActiveProjectPath: string;
    FActivePreviewId: string;
    FActiveScenarioKey: string;
    FActiveSessionId: string;
    FDebugSession: IRadIARuntimeDebugSessionCoordinator;
    FEvidence: TObject;
    FSampler: IRadIARuntimePerformanceSampler;
    FScenario: IRadIARuntimeScenarioCoordinator;
    function BuildComparison(
      const ABaseline: TRadIARuntimePerformanceEvidence;
      const AVerification: TRadIARuntimePerformanceEvidence
    ): string;
    function BuildEvidence(
      const AEvidence: TRadIARuntimePerformanceEvidence
    ): string;
    function FindEvidence(
      const AEvidenceId: string
    ): TRadIARuntimePerformanceEvidence;
    procedure ResetActive;
  public
    constructor Create(
      const ADebugSession: IRadIARuntimeDebugSessionCoordinator;
      const AScenario: IRadIARuntimeScenarioCoordinator;
      const ASampler: IRadIARuntimePerformanceSampler
    );
    destructor Destroy; override;
    function BeginMeasurement(
      const AScenarioKey: string;
      const AMaximumDurationMs: Cardinal
    ): TRadIAToolResult;
    function CompleteMeasurement: TRadIAToolResult;
    function Compare(
      const ABaselineEvidenceId: string;
      const AVerificationEvidenceId: string
    ): TRadIAToolResult;
    function Cancel: Boolean;
  end;

procedure RegisterRadIARuntimePerformanceTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimePerformanceCoordinator
);

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeAutomation;

const
  CMinimumMeasurementMs = 100;
  CMaximumMeasurementMs = 5 * 60 * 1000;

type
  TRadIARuntimePerformanceEvidenceDictionary =
    TObjectDictionary<string,
      TRadIARuntimePerformanceCoordinator.TRadIARuntimePerformanceEvidence>;

  TRadIARuntimePerformanceToolKind = (
    rptkBegin,
    rptkComplete,
    rptkCompare,
    rptkCancel
  );

  TRadIARuntimePerformanceTool = class(TInterfacedObject, IRadIATool)
  private
    FCoordinator: IRadIARuntimePerformanceCoordinator;
    FKind: TRadIARuntimePerformanceToolKind;
  public
    constructor Create(
      const AKind: TRadIARuntimePerformanceToolKind;
      const ACoordinator: IRadIARuntimePerformanceCoordinator
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

function NewEvidenceId: string;
begin
  Result := LowerCase(
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '')
  );
end;

function PercentageDelta(const ABaseline, AVerification: UInt64): Double;
begin
  if ABaseline = 0 then
  begin
    if AVerification = 0 then
      Exit(0);
    Exit(100);
  end;
  Result := ((AVerification - Double(ABaseline)) / ABaseline) * 100;
end;

constructor TRadIARuntimePerformanceSummary.Create(
  const ADurationMs: UInt64;
  const ACpuTimeMs: UInt64;
  const APeakWorkingSetBytes: UInt64;
  const APeakPrivateBytes: UInt64;
  const ASampleCount: Integer;
  const AUnresponsiveSamples: Integer
);
begin
  FDurationMs := ADurationMs;
  FCpuTimeMs := ACpuTimeMs;
  FPeakWorkingSetBytes := APeakWorkingSetBytes;
  FPeakPrivateBytes := APeakPrivateBytes;
  FSampleCount := ASampleCount;
  FUnresponsiveSamples := AUnresponsiveSamples;
end;

function TRadIARuntimePerformanceSummary.IsUsable: Boolean;
begin
  Result := (FDurationMs >= CMinimumMeasurementMs) and (FSampleCount > 0) and
    (FUnresponsiveSamples >= 0) and (FUnresponsiveSamples <= FSampleCount);
end;

constructor TRadIARuntimePerformanceCoordinator.Create(
  const ADebugSession: IRadIARuntimeDebugSessionCoordinator;
  const AScenario: IRadIARuntimeScenarioCoordinator;
  const ASampler: IRadIARuntimePerformanceSampler
);
begin
  inherited Create;
  if not Assigned(ADebugSession) or not Assigned(AScenario) or
    not Assigned(ASampler) then
    raise EArgumentNilException.Create('Runtime performance dependency');
  FDebugSession := ADebugSession;
  FScenario := AScenario;
  FSampler := ASampler;
  FEvidence := TRadIARuntimePerformanceEvidenceDictionary.Create([doOwnsValues]);
end;

destructor TRadIARuntimePerformanceCoordinator.Destroy;
begin
  FSampler.CancelMeasurement;
  FEvidence.Free;
  inherited Destroy;
end;

function TRadIARuntimePerformanceCoordinator.BeginMeasurement(
  const AScenarioKey: string;
  const AMaximumDurationMs: Cardinal
): TRadIAToolResult;
var
  LError: string;
  LRoot: TJSONObject;
  LSession: TRadIARuntimeSessionIdentity;
  LStatus: TRadIARuntimeScenarioStatus;
begin
  if FActiveSessionId <> '' then
    Exit(TRadIAToolResult.Failed(
      'performance_measurement_active',
      'A runtime performance measurement is already active.'
    ));
  if (Trim(AScenarioKey) = '') or
    (AMaximumDurationMs < CMinimumMeasurementMs) or
    (AMaximumDurationMs > CMaximumMeasurementMs) then
    Exit(TRadIAToolResult.Failed(
      'invalid_performance_measurement',
      'scenarioKey and a duration from 100 to 300000 ms are required.'
    ));
  LSession := FDebugSession.GetCurrentSession;
  if not LSession.IsComplete then
    Exit(TRadIAToolResult.Failed(
      'runtime_session_required',
      'A complete runtime debug session is required.'
    ));
  LStatus := FScenario.GetStatus;
  if (LStatus.State <> rssPrepared) or (LStatus.PreviewId = '') then
    Exit(TRadIAToolResult.Failed(
      'performance_scenario_not_prepared',
      'Prepare the bounded runtime scenario before starting measurement.'
    ));
  if not FSampler.BeginMeasurement(
    LSession.ProcessId,
    AMaximumDurationMs,
    LError
  ) then
    Exit(TRadIAToolResult.Failed('performance_sampler_unavailable', LError));
  FActiveSessionId := LSession.SessionId;
  FActiveBuildId := LSession.BuildId;
  FActiveProjectPath := LSession.ProjectPath;
  FActivePreviewId := LStatus.PreviewId;
  FActiveScenarioKey := Trim(AScenarioKey);
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('state', 'measuring');
    LRoot.AddPair('scenarioKey', FActiveScenarioKey);
    LRoot.AddPair('sessionId', FActiveSessionId);
    LRoot.AddPair('maximumDurationMs', TJSONNumber.Create(AMaximumDurationMs));
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimePerformanceCoordinator.BuildEvidence(
  const AEvidence: TRadIARuntimePerformanceEvidence
): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('evidenceId', AEvidence.EvidenceId);
    LRoot.AddPair('scenarioKey', AEvidence.ScenarioKey);
    LRoot.AddPair('projectPath', AEvidence.ProjectPath);
    LRoot.AddPair('sessionId', AEvidence.SessionId);
    LRoot.AddPair('buildId', AEvidence.BuildId);
    LRoot.AddPair('durationMs', TJSONNumber.Create(AEvidence.Summary.DurationMs));
    LRoot.AddPair('cpuTimeMs', TJSONNumber.Create(AEvidence.Summary.CpuTimeMs));
    LRoot.AddPair(
      'peakWorkingSetBytes',
      TJSONNumber.Create(AEvidence.Summary.PeakWorkingSetBytes)
    );
    LRoot.AddPair(
      'peakPrivateBytes',
      TJSONNumber.Create(AEvidence.Summary.PeakPrivateBytes)
    );
    LRoot.AddPair('sampleCount', TJSONNumber.Create(AEvidence.Summary.SampleCount));
    LRoot.AddPair(
      'unresponsiveSamples',
      TJSONNumber.Create(AEvidence.Summary.UnresponsiveSamples)
    );
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimePerformanceCoordinator.CompleteMeasurement:
  TRadIAToolResult;
var
  LEvidence: TRadIARuntimePerformanceEvidence;
  LError: string;
  LStatus: TRadIARuntimeScenarioStatus;
  LSession: TRadIARuntimeSessionIdentity;
  LSummary: TRadIARuntimePerformanceSummary;
begin
  if FActiveSessionId = '' then
    Exit(TRadIAToolResult.Failed(
      'performance_measurement_not_active',
      'No runtime performance measurement is active.'
    ));
  LSession := FDebugSession.GetCurrentSession;
  if not SameText(LSession.SessionId, FActiveSessionId) or
    not SameText(LSession.BuildId, FActiveBuildId) then
  begin
    FSampler.CancelMeasurement;
    ResetActive;
    Exit(TRadIAToolResult.Failed(
      'performance_session_changed',
      'The runtime session changed during performance measurement.'
    ));
  end;
  if not FSampler.CompleteMeasurement(LSummary, LError) then
  begin
    ResetActive;
    Exit(TRadIAToolResult.Failed('performance_measurement_failed', LError));
  end;
  LStatus := FScenario.GetStatus;
  if (LStatus.State <> rssSucceeded) or
    not SameText(LStatus.PreviewId, FActivePreviewId) then
  begin
    ResetActive;
    Exit(TRadIAToolResult.Failed(
      'performance_scenario_incomplete',
      'The measured runtime scenario must finish successfully.'
    ));
  end;
  if not LSummary.IsUsable then
  begin
    ResetActive;
    Exit(TRadIAToolResult.Failed(
      'performance_evidence_insufficient',
      'The measurement did not produce enough bounded samples.'
    ));
  end;
  LEvidence := TRadIARuntimePerformanceEvidence.Create;
  LEvidence.EvidenceId := NewEvidenceId;
  LEvidence.ScenarioKey := FActiveScenarioKey;
  LEvidence.ProjectPath := FActiveProjectPath;
  LEvidence.SessionId := FActiveSessionId;
  LEvidence.BuildId := FActiveBuildId;
  LEvidence.Summary := LSummary;
  LEvidence.ContentJson := BuildEvidence(LEvidence);
  TRadIARuntimePerformanceEvidenceDictionary(FEvidence).Add(
    LEvidence.EvidenceId,
    LEvidence
  );
  Result := TRadIAToolResult.Succeeded(LEvidence.ContentJson);
  ResetActive;
end;

function TRadIARuntimePerformanceCoordinator.FindEvidence(
  const AEvidenceId: string
): TRadIARuntimePerformanceEvidence;
begin
  if not TRadIARuntimePerformanceEvidenceDictionary(FEvidence).TryGetValue(
    Trim(AEvidenceId),
    Result
  ) then
    Result := nil;
end;

function TRadIARuntimePerformanceCoordinator.BuildComparison(
  const ABaseline: TRadIARuntimePerformanceEvidence;
  const AVerification: TRadIARuntimePerformanceEvidence
): string;
var
  LCpuDelta: Double;
  LDurationDelta: Double;
  LPrivateDelta: Double;
  LRegression: Boolean;
  LRoot: TJSONObject;
  LWorkingSetDelta: Double;
begin
  LDurationDelta := PercentageDelta(
    ABaseline.Summary.DurationMs,
    AVerification.Summary.DurationMs
  );
  LCpuDelta := PercentageDelta(
    ABaseline.Summary.CpuTimeMs,
    AVerification.Summary.CpuTimeMs
  );
  LWorkingSetDelta := PercentageDelta(
    ABaseline.Summary.PeakWorkingSetBytes,
    AVerification.Summary.PeakWorkingSetBytes
  );
  LPrivateDelta := PercentageDelta(
    ABaseline.Summary.PeakPrivateBytes,
    AVerification.Summary.PeakPrivateBytes
  );
  LRegression := (LDurationDelta > 10) or (LCpuDelta > 10) or
    (LWorkingSetDelta > 10) or (LPrivateDelta > 10) or
    (AVerification.Summary.UnresponsiveSamples >
      ABaseline.Summary.UnresponsiveSamples);
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('comparable', TJSONBool.Create(True));
    LRoot.AddPair('scenarioKey', ABaseline.ScenarioKey);
    LRoot.AddPair('durationDeltaPercent', TJSONNumber.Create(LDurationDelta));
    LRoot.AddPair('cpuTimeDeltaPercent', TJSONNumber.Create(LCpuDelta));
    LRoot.AddPair(
      'peakWorkingSetDeltaPercent',
      TJSONNumber.Create(LWorkingSetDelta)
    );
    LRoot.AddPair(
      'peakPrivateBytesDeltaPercent',
      TJSONNumber.Create(LPrivateDelta)
    );
    LRoot.AddPair(
      'unresponsiveSampleDelta',
      TJSONNumber.Create(
        AVerification.Summary.UnresponsiveSamples -
        ABaseline.Summary.UnresponsiveSamples
      )
    );
    LRoot.AddPair('regressionDetected', TJSONBool.Create(LRegression));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimePerformanceCoordinator.Compare(
  const ABaselineEvidenceId: string;
  const AVerificationEvidenceId: string
): TRadIAToolResult;
var
  LBaseline: TRadIARuntimePerformanceEvidence;
  LVerification: TRadIARuntimePerformanceEvidence;
begin
  LBaseline := FindEvidence(ABaselineEvidenceId);
  LVerification := FindEvidence(AVerificationEvidenceId);
  if not Assigned(LBaseline) or not Assigned(LVerification) then
    Exit(TRadIAToolResult.Failed(
      'performance_evidence_not_found',
      'Both performance evidence identifiers are required.'
    ));
  if not SameText(LBaseline.ProjectPath, LVerification.ProjectPath) or
    not SameText(LBaseline.ScenarioKey, LVerification.ScenarioKey) or
    SameText(LBaseline.SessionId, LVerification.SessionId) or
    SameText(LBaseline.BuildId, LVerification.BuildId) then
    Exit(TRadIAToolResult.Failed(
      'performance_evidence_not_comparable',
      'Evidence must use the same project and scenario in distinct sessions and builds.'
    ));
  Result := TRadIAToolResult.Succeeded(
    BuildComparison(LBaseline, LVerification)
  );
end;

procedure TRadIARuntimePerformanceCoordinator.ResetActive;
begin
  FActiveBuildId := '';
  FActiveProjectPath := '';
  FActivePreviewId := '';
  FActiveScenarioKey := '';
  FActiveSessionId := '';
end;

function TRadIARuntimePerformanceCoordinator.Cancel: Boolean;
begin
  Result := FActiveSessionId <> '';
  if Result then
  begin
    FSampler.CancelMeasurement;
    ResetActive;
  end;
end;

constructor TRadIARuntimePerformanceTool.Create(
  const AKind: TRadIARuntimePerformanceToolKind;
  const ACoordinator: IRadIARuntimePerformanceCoordinator
);
begin
  inherited Create;
  FKind := AKind;
  FCoordinator := ACoordinator;
end;

function TRadIARuntimePerformanceTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCancelRoot: TJSONObject;
  LRoot: TJSONObject;
begin
  if FKind = rptkComplete then
    Exit(FCoordinator.CompleteMeasurement);
  if FKind = rptkCancel then
  begin
    LCancelRoot := TJSONObject.Create;
    try
      LCancelRoot.AddPair(
        'cancelled',
        TJSONBool.Create(FCoordinator.Cancel)
      );
      Exit(TRadIAToolResult.Succeeded(LCancelRoot.ToJSON));
    finally
      LCancelRoot.Free;
    end;
  end;
  LRoot := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
  try
    if FKind = rptkBegin then
      Result := FCoordinator.BeginMeasurement(
        LRoot.GetValue<string>('scenarioKey', ''),
        LRoot.GetValue<Cardinal>('maximumDurationMs', 60000)
      )
    else
      Result := FCoordinator.Compare(
        LRoot.GetValue<string>('baselineEvidenceId', ''),
        LRoot.GetValue<string>('verificationEvidenceId', '')
      );
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimePerformanceTool.GetDescriptor: TRadIAToolDescriptor;
const
  CEmptySchema = '{"type":"object","additionalProperties":false}';
begin
  case FKind of
    rptkBegin:
      Result := TRadIAToolDescriptor.Create(
        'BeginRuntimePerformanceMeasurement',
        '1.0.0',
        'Starts bounded sampling for the active runtime session before a reviewed scenario.',
        '{"type":"object","required":["scenarioKey"],"properties":{' +
        '"scenarioKey":{"type":"string","minLength":1},' +
        '"maximumDurationMs":{"type":"integer","minimum":100,' +
        '"maximum":300000}},"additionalProperties":false}',
        '{}',
        trReadOnly
      );
    rptkComplete:
      Result := TRadIAToolDescriptor.Create(
        'CompleteRuntimePerformanceMeasurement',
        '1.0.0',
        'Stops sampling after a successful scenario and returns bounded evidence.',
        CEmptySchema,
        '{}',
        trReadOnly
      );
    rptkCompare:
      Result := TRadIAToolDescriptor.Create(
        'CompareRuntimePerformanceEvidence',
        '1.0.0',
        'Compares the same scenario across distinct runtime sessions and builds.',
        '{"type":"object","required":["baselineEvidenceId",' +
        '"verificationEvidenceId"],"properties":{' +
        '"baselineEvidenceId":{"type":"string","minLength":1},' +
        '"verificationEvidenceId":{"type":"string","minLength":1}},' +
        '"additionalProperties":false}',
        '{}',
        trReadOnly
      );
  else
    Result := TRadIAToolDescriptor.Create(
      'CancelRuntimePerformanceMeasurement',
      '1.0.0',
      'Cancels active performance sampling without producing evidence.',
      CEmptySchema,
      '{}',
      trReadOnly
    );
  end;
end;

procedure RegisterRadIARuntimePerformanceTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimePerformanceCoordinator
);
var
  LKind: TRadIARuntimePerformanceToolKind;
begin
  for LKind := Low(TRadIARuntimePerformanceToolKind) to
    High(TRadIARuntimePerformanceToolKind) do
    ARegistry.RegisterTool(TRadIARuntimePerformanceTool.Create(
      LKind,
      ACoordinator
    ));
end;

end.
