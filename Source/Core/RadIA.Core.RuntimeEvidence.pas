unit RadIA.Core.RuntimeEvidence;

interface

uses
  RadIA.Core.Debugger,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.ToolSecurity;

type
  IRadIARuntimeEvidenceCoordinator = interface
    ['{7957B887-DCB9-491E-8C84-60D9EAB34183}']
    function Capture(
      const APhase: string;
      const AExpressions: TArray<string>
    ): string;
    function Compare(
      const AFailureEvidenceId: string;
      const AVerificationEvidenceId: string
    ): string;
  end;

  TRadIARuntimeEvidenceCoordinator = class(
    TInterfacedObject,
    IRadIARuntimeEvidenceCoordinator
  )
  private type
    TRadIARuntimeEvidenceEntry = class
    private
      FBuildId: string;
      FContentJson: string;
      FEvidenceId: string;
      FEventKind: TRadIARuntimeDebugEventKind;
      FEventAvailable: Boolean;
      FFingerprint: string;
      FPhase: string;
      FProjectPath: string;
      FScenarioState: TRadIARuntimeScenarioState;
      FSessionId: string;
    public
      property BuildId: string read FBuildId write FBuildId;
      property ContentJson: string read FContentJson write FContentJson;
      property EvidenceId: string read FEvidenceId write FEvidenceId;
      property EventKind: TRadIARuntimeDebugEventKind
        read FEventKind write FEventKind;
      property EventAvailable: Boolean
        read FEventAvailable write FEventAvailable;
      property Fingerprint: string read FFingerprint write FFingerprint;
      property Phase: string read FPhase write FPhase;
      property ProjectPath: string read FProjectPath write FProjectPath;
      property ScenarioState: TRadIARuntimeScenarioState
        read FScenarioState write FScenarioState;
      property SessionId: string read FSessionId write FSessionId;
    end;
  private
    FDebugger: IRadIADebuggerFacade;
    FDebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FEvaluation: IRadIADebuggerEvaluationFacade;
    FEvidence: TObject;
    FRedactor: IRadIASecretRedactor;
    FScenarioCoordinator: IRadIARuntimeScenarioCoordinator;
    function BuildCapture(
      const APhase: string;
      const AExpressions: TArray<string>;
      const AEntry: TRadIARuntimeEvidenceEntry
    ): string;
    function FindEvidence(
      const AEvidenceId: string
    ): TRadIARuntimeEvidenceEntry;
  public
    constructor Create(
      const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
      const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator;
      const ADebugger: IRadIADebuggerFacade;
      const AEvaluation: IRadIADebuggerEvaluationFacade;
      const ARedactor: IRadIASecretRedactor
    );
    destructor Destroy; override;
    function Capture(
      const APhase: string;
      const AExpressions: TArray<string>
    ): string;
    function Compare(
      const AFailureEvidenceId: string;
      const AVerificationEvidenceId: string
    ): string;
  end;

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.Hash,
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeAutomation;

type
  TRadIARuntimeEvidenceDictionary =
    TObjectDictionary<string,
      TRadIARuntimeEvidenceCoordinator.TRadIARuntimeEvidenceEntry>;

function NewOpaqueId: string;
begin
  Result := LowerCase(
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '')
  );
end;

procedure AddCallStack(
  const ADebugger: IRadIADebuggerFacade;
  const ARedactor: IRadIASecretRedactor;
  const ARoot: TJSONObject
);
var
  LArray: TJSONArray;
  LFrame: TRadIACallStackFrame;
  LItem: TJSONObject;
  LStack: TRadIACallStackSnapshot;
begin
  LStack := ADebugger.GetCallStack(100);
  ARoot.AddPair(
    'stackAccessible',
    TJSONBool.Create(LStack.Accessible)
  );
  ARoot.AddPair('stackStatus', ARedactor.Redact(LStack.Status));
  LArray := TJSONArray.Create;
  ARoot.AddPair('frames', LArray);
  for LFrame in LStack.Frames do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('index', TJSONNumber.Create(LFrame.Index));
    LItem.AddPair('header', ARedactor.Redact(LFrame.Header));
    LItem.AddPair('fileName', LFrame.FileName);
    LItem.AddPair(
      'lineNumber',
      TJSONNumber.Create(LFrame.LineNumber)
    );
    LArray.AddElement(LItem);
  end;
end;

procedure AddExpressions(
  const AEvaluation: IRadIADebuggerEvaluationFacade;
  const ARedactor: IRadIASecretRedactor;
  const AExpressions: TArray<string>;
  const ARoot: TJSONObject
);
var
  LArray: TJSONArray;
  LExpression: string;
  LItem: TJSONObject;
  LValue: TRadIADebugValueSnapshot;
begin
  LArray := TJSONArray.Create;
  ARoot.AddPair('expressions', LArray);
  for LExpression in AExpressions do
  begin
    LValue := AEvaluation.EvaluateExpression(LExpression);
    LItem := TJSONObject.Create;
    LItem.AddPair(
      'expression',
      ARedactor.Redact(LValue.Expression)
    );
    LItem.AddPair(
      'result',
      ARedactor.Redact(LValue.ResultText)
    );
    LItem.AddPair('status', ARedactor.Redact(LValue.Status));
    LArray.AddElement(LItem);
  end;
end;

{ TRadIARuntimeEvidenceCoordinator }

function TRadIARuntimeEvidenceCoordinator.BuildCapture(
  const APhase: string;
  const AExpressions: TArray<string>;
  const AEntry: TRadIARuntimeEvidenceEntry
): string;
var
  LDebuggerState: TRadIADebuggerSnapshot;
  LEvent: TRadIARuntimeDebugEvent;
  LRecordedEventAvailable: Boolean;
  LRoot: TJSONObject;
  LScenarioStatus: TRadIARuntimeScenarioStatus;
  LSession: TRadIARuntimeSessionIdentity;
begin
  LSession := FDebugCoordinator.GetCurrentSession;
  if not LSession.IsComplete then
    raise EInvalidOp.Create(
      'A complete runtime debug session is required.'
    );
  LScenarioStatus := FScenarioCoordinator.GetStatus;
  AEntry.EvidenceId := NewOpaqueId;
  AEntry.Phase := APhase;
  AEntry.SessionId := LSession.SessionId;
  AEntry.ProjectPath := LSession.ProjectPath;
  AEntry.BuildId := LSession.BuildId;
  AEntry.ScenarioState := LScenarioStatus.State;
  LRecordedEventAvailable := FDebugCoordinator.TryGetLastEvent(LEvent);
  AEntry.EventAvailable := LRecordedEventAvailable;
  if LRecordedEventAvailable then
    AEntry.EventKind := LEvent.Kind;
  LDebuggerState := FDebugger.GetDebuggerState;
  if SameText(LDebuggerState.State, 'exception') then
  begin
    AEntry.EventAvailable := True;
    AEntry.EventKind := rdekException;
  end;

  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('evidenceId', AEntry.EvidenceId);
    LRoot.AddPair('phase', AEntry.Phase);
    LRoot.AddPair(
      'capturedAtUtc',
      DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True)
    );
    LRoot.AddPair('sessionId', AEntry.SessionId);
    LRoot.AddPair('projectPath', AEntry.ProjectPath);
    LRoot.AddPair('executablePath', LSession.ExecutablePath);
    LRoot.AddPair('buildId', AEntry.BuildId);
    LRoot.AddPair(
      'scenarioState',
      RadIARuntimeScenarioStateName(AEntry.ScenarioState)
    );
    LRoot.AddPair(
      'completedActions',
      TJSONNumber.Create(LScenarioStatus.CompletedActions)
    );
    LRoot.AddPair(
      'eventAvailable',
      TJSONBool.Create(AEntry.EventAvailable)
    );
    if AEntry.EventAvailable then
    begin
      if LRecordedEventAvailable then
        LRoot.AddPair(
          'eventSequence',
          TJSONNumber.Create(LEvent.Sequence)
        );
      LRoot.AddPair(
        'eventKind',
        RadIARuntimeDebugEventKindName(AEntry.EventKind)
      );
      LRoot.AddPair('debuggerState', LDebuggerState.State);
      if LRecordedEventAvailable then
        LRoot.AddPair('details', FRedactor.Redact(LEvent.Details))
      else
        LRoot.AddPair('details', FRedactor.Redact(LDebuggerState.Status));
    end;
    AddCallStack(FDebugger, FRedactor, LRoot);
    AddExpressions(FEvaluation, FRedactor, AExpressions, LRoot);
    AEntry.Fingerprint := LowerCase(
      THashSHA2.GetHashString(
        LRoot.ToJSON,
        THashSHA2.TSHA2Version.SHA256
      )
    );
    LRoot.AddPair('fingerprint', AEntry.Fingerprint);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimeEvidenceCoordinator.Capture(
  const APhase: string;
  const AExpressions: TArray<string>
): string;
var
  LEntry: TRadIARuntimeEvidenceEntry;
begin
  if not SameText(APhase, 'failure') and
    not SameText(APhase, 'verification') then
    raise EArgumentException.Create(
      'Runtime evidence phase must be failure or verification.'
    );
  if Length(AExpressions) > 10 then
    raise EArgumentOutOfRangeException.Create(
      'Runtime evidence accepts at most ten expressions.'
    );
  LEntry := TRadIARuntimeEvidenceEntry.Create;
  try
    Result := BuildCapture(APhase, AExpressions, LEntry);
    LEntry.ContentJson := Result;
    TMonitor.Enter(FEvidence);
    try
      TRadIARuntimeEvidenceDictionary(FEvidence).Add(
        LEntry.EvidenceId,
        LEntry
      );
      LEntry := nil;
    finally
      TMonitor.Exit(FEvidence);
    end;
  finally
    LEntry.Free;
  end;
end;

function TRadIARuntimeEvidenceCoordinator.Compare(
  const AFailureEvidenceId: string;
  const AVerificationEvidenceId: string
): string;
var
  LComparable: Boolean;
  LFailure: TRadIARuntimeEvidenceEntry;
  LFailureRemoved: Boolean;
  LRoot: TJSONObject;
  LVerification: TRadIARuntimeEvidenceEntry;
begin
  TMonitor.Enter(FEvidence);
  try
    LFailure := FindEvidence(AFailureEvidenceId);
    LVerification := FindEvidence(AVerificationEvidenceId);
    LComparable :=
      SameText(LFailure.Phase, 'failure') and
      SameText(LVerification.Phase, 'verification') and
      SameText(LFailure.ProjectPath, LVerification.ProjectPath) and
      not SameText(LFailure.SessionId, LVerification.SessionId) and
      not SameText(LFailure.BuildId, LVerification.BuildId);
    LFailureRemoved :=
      LComparable and
      LFailure.EventAvailable and
      (LFailure.EventKind = rdekException) and
      (LVerification.ScenarioState = rssSucceeded) and
      (
        not LVerification.EventAvailable or
        (LVerification.EventKind <> rdekException)
      );
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair(
        'failureEvidenceId',
        LFailure.EvidenceId
      );
      LRoot.AddPair(
        'verificationEvidenceId',
        LVerification.EvidenceId
      );
      LRoot.AddPair('comparable', TJSONBool.Create(LComparable));
      LRoot.AddPair(
        'failureReproduced',
        TJSONBool.Create(
          LFailure.EventAvailable and
          (LFailure.EventKind = rdekException)
        )
      );
      LRoot.AddPair(
        'verificationSucceeded',
        TJSONBool.Create(
          LVerification.ScenarioState = rssSucceeded
        )
      );
      LRoot.AddPair(
        'failureRemoved',
        TJSONBool.Create(LFailureRemoved)
      );
      if LFailureRemoved then
        LRoot.AddPair('outcome', 'fixed')
      else if not LComparable then
        LRoot.AddPair('outcome', 'notComparable')
      else
        LRoot.AddPair('outcome', 'stillFailing');
      Result := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  finally
    TMonitor.Exit(FEvidence);
  end;
end;

constructor TRadIARuntimeEvidenceCoordinator.Create(
  const ADebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AScenarioCoordinator: IRadIARuntimeScenarioCoordinator;
  const ADebugger: IRadIADebuggerFacade;
  const AEvaluation: IRadIADebuggerEvaluationFacade;
  const ARedactor: IRadIASecretRedactor
);
begin
  inherited Create;
  if not Assigned(ADebugCoordinator) then
    raise EArgumentNilException.Create('ADebugCoordinator');
  if not Assigned(AScenarioCoordinator) then
    raise EArgumentNilException.Create('AScenarioCoordinator');
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');
  if not Assigned(AEvaluation) then
    raise EArgumentNilException.Create('AEvaluation');
  if not Assigned(ARedactor) then
    raise EArgumentNilException.Create('ARedactor');
  FDebugCoordinator := ADebugCoordinator;
  FScenarioCoordinator := AScenarioCoordinator;
  FDebugger := ADebugger;
  FEvaluation := AEvaluation;
  FRedactor := ARedactor;
  FEvidence := TRadIARuntimeEvidenceDictionary.Create([doOwnsValues]);
end;

destructor TRadIARuntimeEvidenceCoordinator.Destroy;
begin
  FEvidence.Free;
  inherited;
end;

function TRadIARuntimeEvidenceCoordinator.FindEvidence(
  const AEvidenceId: string
): TRadIARuntimeEvidenceEntry;
begin
  if not TRadIARuntimeEvidenceDictionary(FEvidence).TryGetValue(
    AEvidenceId,
    Result
  ) then
    raise EArgumentException.Create(
      'Runtime evidence id is unknown or expired.'
    );
end;

end.
