unit RadIA.Core.ToolSecurity;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Tools;

type
  TRadIAConsentDecision = (
    cdAllowOnce,
    cdAllowSession,
    cdDeny,
    cdCancel
  );

  TRadIAAuditOutcome = (
    aoSucceeded,
    aoDenied,
    aoCancelled,
    aoFailed,
    aoPreconditionFailed,
    aoUnsupported
  );

  TRadIAToolAuditEvent = record
  private
    FEventId: string;
    FStartedAtUtc: string;
    FCorrelationId: string;
    FToolName: string;
    FToolVersion: string;
    FOrigin: string;
    FSessionId: string;
    FProjectId: string;
    FScope: string;
    FArgumentsJson: string;
    FRisk: TRadIAToolRisk;
    FDecision: TRadIAConsentDecision;
    FOutcome: TRadIAAuditOutcome;
    FDurationMs: Int64;
    FErrorMessage: string;
  public
    class function CreateStarted(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor;
      const AArgumentsJson: string
    ): TRadIAToolAuditEvent; static;
    class function CreateUnknown(
      const ARequest: TRadIAToolRequest;
      const AArgumentsJson: string
    ): TRadIAToolAuditEvent; static;
    function Complete(
      const ADecision: TRadIAConsentDecision;
      const AOutcome: TRadIAAuditOutcome;
      const ADurationMs: Int64;
      const AErrorMessage: string
    ): TRadIAToolAuditEvent;
    property EventId: string read FEventId;
    property StartedAtUtc: string read FStartedAtUtc;
    property CorrelationId: string read FCorrelationId;
    property ToolName: string read FToolName;
    property ToolVersion: string read FToolVersion;
    property Origin: string read FOrigin;
    property SessionId: string read FSessionId;
    property ProjectId: string read FProjectId;
    property Scope: string read FScope;
    property ArgumentsJson: string read FArgumentsJson;
    property Risk: TRadIAToolRisk read FRisk;
    property Decision: TRadIAConsentDecision read FDecision;
    property Outcome: TRadIAAuditOutcome read FOutcome;
    property DurationMs: Int64 read FDurationMs;
    property ErrorMessage: string read FErrorMessage;
  end;

  IRadIAConsentProvider = interface
    ['{92F2B47E-BA2B-4B57-86D6-7F05137633FA}']
    function RequestConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
  end;

  IRadIAToolAuditSink = interface
    ['{6AB2342C-D4B3-43BA-9CB8-D879A52FC15E}']
    procedure Write(const AEvent: TRadIAToolAuditEvent);
  end;

  IRadIASecretRedactor = interface
    ['{68C5AB98-62E9-4913-802B-CE253D346873}']
    function Redact(const AText: string): string;
  end;

  IRadIAToolPolicyExecutor = interface(IRadIAToolExecutor)
    ['{11435A32-3FF5-4752-80F4-D8EBFEFF3846}']
    procedure RevokeSessionPermissions;
  end;

  TRadIADenyConsentProvider = class(
    TInterfacedObject,
    IRadIAConsentProvider
  )
  public
    function RequestConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
  end;

  TRadIASecretRedactor = class(
    TInterfacedObject,
    IRadIASecretRedactor
  )
  private
    function RedactJsonValue(const AText: string): string;
  public
    function Redact(const AText: string): string;
  end;

  TRadIAInMemoryToolAuditSink = class(
    TInterfacedObject,
    IRadIAToolAuditSink
  )
  private
    FEvents: TList<TRadIAToolAuditEvent>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const AEvent: TRadIAToolAuditEvent);
    function GetEvents: TArray<TRadIAToolAuditEvent>;
  end;

  TRadIAJsonLinesToolAuditSink = class(
    TInterfacedObject,
    IRadIAToolAuditSink
  )
  private
    FFileName: string;
    function ConsentDecisionName(
      const ADecision: TRadIAConsentDecision
    ): string;
    function OutcomeName(
      const AOutcome: TRadIAAuditOutcome
    ): string;
    function RiskName(const ARisk: TRadIAToolRisk): string;
  public
    constructor Create(const AFileName: string);
    procedure Write(const AEvent: TRadIAToolAuditEvent);
  end;

  TRadIAToolPolicyExecutor = class(
    TInterfacedObject,
    IRadIAToolPolicyExecutor,
    IRadIAToolExecutor
  )
  private
    FRegistry: IRadIAToolRegistry;
    FInnerExecutor: IRadIAToolExecutor;
    FConsentProvider: IRadIAConsentProvider;
    FAuditSink: IRadIAToolAuditSink;
    FRedactor: IRadIASecretRedactor;
    FSessionPermissions: TDictionary<string, Boolean>;
    function BuildPermissionKey(
      const ARequest: TRadIAToolRequest
    ): string;
    function Decide(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
    function OutcomeFromResult(
      const AResult: TRadIAToolResult
    ): TRadIAAuditOutcome;
  public
    constructor Create(
      const ARegistry: IRadIAToolRegistry;
      const AInnerExecutor: IRadIAToolExecutor;
      const AConsentProvider: IRadIAConsentProvider;
      const AAuditSink: IRadIAToolAuditSink;
      const ARedactor: IRadIASecretRedactor
    );
    destructor Destroy; override;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    procedure RevokeSessionPermissions;
  end;

implementation

uses
  System.DateUtils,
  System.Diagnostics,
  System.IOUtils,
  System.JSON,
  System.RegularExpressions,
  System.SysUtils;

const
  CConsentRequired = 'consent_required';
  CConsentDenied = 'consent_denied';
  CConsentCancelled = 'consent_cancelled';
  CSensitiveDenied = 'sensitive_tool_denied';
  CToolNotFound = 'tool_not_found';

{ TRadIAToolAuditEvent }

function TRadIAToolAuditEvent.Complete(
  const ADecision: TRadIAConsentDecision;
  const AOutcome: TRadIAAuditOutcome;
  const ADurationMs: Int64;
  const AErrorMessage: string
): TRadIAToolAuditEvent;
begin
  Result := Self;
  Result.FDecision := ADecision;
  Result.FOutcome := AOutcome;
  Result.FDurationMs := ADurationMs;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIAToolAuditEvent.CreateStarted(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor;
  const AArgumentsJson: string
): TRadIAToolAuditEvent;
begin
  Result.FEventId := TGUID.NewGuid.ToString;
  Result.FStartedAtUtc := FormatDateTime(
    'yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz"Z"',
    TTimeZone.Local.ToUniversalTime(Now)
  );
  Result.FCorrelationId := ARequest.CorrelationId;
  Result.FToolName := ADescriptor.Name;
  Result.FToolVersion := ADescriptor.Version;
  Result.FOrigin := ARequest.Origin;
  Result.FSessionId := ARequest.SessionId;
  Result.FProjectId := ARequest.ProjectId;
  Result.FScope := ARequest.Scope;
  Result.FArgumentsJson := AArgumentsJson;
  Result.FRisk := ADescriptor.Risk;
  Result.FDecision := cdDeny;
  Result.FOutcome := aoFailed;
  Result.FDurationMs := 0;
  Result.FErrorMessage := '';
end;

class function TRadIAToolAuditEvent.CreateUnknown(
  const ARequest: TRadIAToolRequest;
  const AArgumentsJson: string
): TRadIAToolAuditEvent;
begin
  Result.FEventId := TGUID.NewGuid.ToString;
  Result.FStartedAtUtc := FormatDateTime(
    'yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz"Z"',
    TTimeZone.Local.ToUniversalTime(Now)
  );
  Result.FCorrelationId := ARequest.CorrelationId;
  Result.FToolName := ARequest.ToolName;
  Result.FToolVersion := '';
  Result.FOrigin := ARequest.Origin;
  Result.FSessionId := ARequest.SessionId;
  Result.FProjectId := ARequest.ProjectId;
  Result.FScope := ARequest.Scope;
  Result.FArgumentsJson := AArgumentsJson;
  Result.FRisk := trSensitive;
  Result.FDecision := cdDeny;
  Result.FOutcome := aoUnsupported;
  Result.FDurationMs := 0;
  Result.FErrorMessage := 'Tool is not registered.';
end;

{ TRadIADenyConsentProvider }

function TRadIADenyConsentProvider.RequestConsent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
begin
  Result := cdDeny;
end;

{ TRadIASecretRedactor }

function TRadIASecretRedactor.Redact(const AText: string): string;
begin
  Result := RedactJsonValue(AText);
  Result := TRegEx.Replace(
    Result,
    '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+',
    'Bearer [REDACTED]'
  );
  Result := TRegEx.Replace(
    Result,
    '(?i)\bAKIA[0-9A-Z]{16}\b',
    '[REDACTED_AWS_ACCESS_KEY]'
  );
end;

function TRadIASecretRedactor.RedactJsonValue(
  const AText: string
): string;
const
  CSecretPattern =
    '(?i)("(?:api[_-]?key|access[_-]?token|refresh[_-]?token|' +
    'authorization|cookie|client[_-]?secret|password)"\s*:\s*)' +
    '"[^"]*"';
begin
  Result := TRegEx.Replace(AText, CSecretPattern, '$1"[REDACTED]"');
end;

{ TRadIAInMemoryToolAuditSink }

constructor TRadIAInMemoryToolAuditSink.Create;
begin
  inherited Create;
  FEvents := TList<TRadIAToolAuditEvent>.Create;
end;

destructor TRadIAInMemoryToolAuditSink.Destroy;
begin
  FEvents.Free;
  inherited;
end;

function TRadIAInMemoryToolAuditSink.GetEvents:
  TArray<TRadIAToolAuditEvent>;
begin
  TMonitor.Enter(FEvents);
  try
    Result := FEvents.ToArray;
  finally
    TMonitor.Exit(FEvents);
  end;
end;

procedure TRadIAInMemoryToolAuditSink.Write(
  const AEvent: TRadIAToolAuditEvent
);
begin
  TMonitor.Enter(FEvents);
  try
    FEvents.Add(AEvent);
  finally
    TMonitor.Exit(FEvents);
  end;
end;

{ TRadIAJsonLinesToolAuditSink }

function TRadIAJsonLinesToolAuditSink.ConsentDecisionName(
  const ADecision: TRadIAConsentDecision
): string;
begin
  case ADecision of
    cdAllowOnce: Result := 'AllowOnce';
    cdAllowSession: Result := 'AllowSession';
    cdCancel: Result := 'Cancel';
  else
    Result := 'Deny';
  end;
end;

constructor TRadIAJsonLinesToolAuditSink.Create(
  const AFileName: string
);
var
  LDirectory: string;
begin
  inherited Create;
  if Trim(AFileName) = '' then
    raise EArgumentException.Create('AFileName must not be empty.');

  FFileName := TPath.GetFullPath(AFileName);
  LDirectory := TPath.GetDirectoryName(FFileName);
  if not TDirectory.Exists(LDirectory) then
    TDirectory.CreateDirectory(LDirectory);
end;

function TRadIAJsonLinesToolAuditSink.OutcomeName(
  const AOutcome: TRadIAAuditOutcome
): string;
begin
  case AOutcome of
    aoSucceeded: Result := 'Succeeded';
    aoDenied: Result := 'Denied';
    aoCancelled: Result := 'Cancelled';
    aoPreconditionFailed: Result := 'PreconditionFailed';
    aoUnsupported: Result := 'Unsupported';
  else
    Result := 'Failed';
  end;
end;

function TRadIAJsonLinesToolAuditSink.RiskName(
  const ARisk: TRadIAToolRisk
): string;
begin
  case ARisk of
    trReadOnly: Result := 'ReadOnly';
    trReversibleWrite: Result := 'ReversibleWrite';
    trStructuralWrite: Result := 'StructuralWrite';
    trExecution: Result := 'Execution';
    trDestructive: Result := 'Destructive';
  else
    Result := 'Sensitive';
  end;
end;

procedure TRadIAJsonLinesToolAuditSink.Write(
  const AEvent: TRadIAToolAuditEvent
);
var
  LJson: TJSONObject;
  LLine: string;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('eventId', AEvent.EventId);
    LJson.AddPair('startedAtUtc', AEvent.StartedAtUtc);
    LJson.AddPair('correlationId', AEvent.CorrelationId);
    LJson.AddPair('tool', AEvent.ToolName);
    LJson.AddPair('version', AEvent.ToolVersion);
    LJson.AddPair('origin', AEvent.Origin);
    LJson.AddPair('sessionId', AEvent.SessionId);
    LJson.AddPair('projectId', AEvent.ProjectId);
    LJson.AddPair('scope', AEvent.Scope);
    LJson.AddPair('risk', RiskName(AEvent.Risk));
    LJson.AddPair(
      'consentDecision',
      ConsentDecisionName(AEvent.Decision)
    );
    LJson.AddPair('outcome', OutcomeName(AEvent.Outcome));
    LJson.AddPair(
      'durationMs',
      TJSONNumber.Create(AEvent.DurationMs)
    );
    LJson.AddPair('arguments', AEvent.ArgumentsJson);
    LJson.AddPair('errorMessage', AEvent.ErrorMessage);
    LLine := LJson.ToJSON + sLineBreak;
  finally
    LJson.Free;
  end;

  TMonitor.Enter(Self);
  try
    TFile.AppendAllText(FFileName, LLine, TEncoding.UTF8);
  finally
    TMonitor.Exit(Self);
  end;
end;

{ TRadIAToolPolicyExecutor }

function TRadIAToolPolicyExecutor.BuildPermissionKey(
  const ARequest: TRadIAToolRequest
): string;
begin
  Result := LowerCase(
    ARequest.SessionId + #31 +
    ARequest.ProjectId + #31 +
    ARequest.ToolName + #31 +
    ARequest.Scope
  );
end;

constructor TRadIAToolPolicyExecutor.Create(
  const ARegistry: IRadIAToolRegistry;
  const AInnerExecutor: IRadIAToolExecutor;
  const AConsentProvider: IRadIAConsentProvider;
  const AAuditSink: IRadIAToolAuditSink;
  const ARedactor: IRadIASecretRedactor
);
begin
  inherited Create;
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AInnerExecutor) then
    raise EArgumentNilException.Create('AInnerExecutor');
  if not Assigned(AAuditSink) then
    raise EArgumentNilException.Create('AAuditSink');
  if not Assigned(ARedactor) then
    raise EArgumentNilException.Create('ARedactor');

  FRegistry := ARegistry;
  FInnerExecutor := AInnerExecutor;
  FConsentProvider := AConsentProvider;
  FAuditSink := AAuditSink;
  FRedactor := ARedactor;
  FSessionPermissions := TDictionary<string, Boolean>.Create;
end;

function TRadIAToolPolicyExecutor.Decide(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
var
  LPermissionKey: string;
begin
  if ADescriptor.Risk = trReadOnly then
    Exit(cdAllowOnce);
  if ADescriptor.Risk = trSensitive then
    Exit(cdDeny);

  LPermissionKey := BuildPermissionKey(ARequest);
  TMonitor.Enter(FSessionPermissions);
  try
    if (ADescriptor.Risk <> trDestructive) and
      FSessionPermissions.ContainsKey(LPermissionKey) then
      Exit(cdAllowSession);
  finally
    TMonitor.Exit(FSessionPermissions);
  end;

  if not Assigned(FConsentProvider) then
    Exit(cdDeny);

  Result := FConsentProvider.RequestConsent(ARequest, ADescriptor);
  if (Result = cdAllowSession) and
    (ADescriptor.Risk <> trDestructive) then
  begin
    TMonitor.Enter(FSessionPermissions);
    try
      FSessionPermissions.AddOrSetValue(LPermissionKey, True);
    finally
      TMonitor.Exit(FSessionPermissions);
    end;
  end;
end;

destructor TRadIAToolPolicyExecutor.Destroy;
begin
  FSessionPermissions.Free;
  inherited;
end;

function TRadIAToolPolicyExecutor.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAuditEvent: TRadIAToolAuditEvent;
  LDecision: TRadIAConsentDecision;
  LDescriptor: TRadIAToolDescriptor;
  LStopwatch: TStopwatch;
  LTool: IRadIATool;
begin
  LStopwatch := TStopwatch.StartNew;
  if not FRegistry.TryResolve(ARequest.ToolName, LTool) then
  begin
    Result := TRadIAToolResult.Failed(
      CToolNotFound,
      Format('Tool "%s" is not registered.', [ARequest.ToolName])
    );
    LStopwatch.Stop;
    FAuditSink.Write(
      TRadIAToolAuditEvent.CreateUnknown(
        ARequest,
        FRedactor.Redact(ARequest.ArgumentsJson)
      ).Complete(
        cdDeny,
        aoUnsupported,
        LStopwatch.ElapsedMilliseconds,
        Result.ErrorMessage
      )
    );
    Exit;
  end;

  LDescriptor := LTool.Descriptor;
  LAuditEvent := TRadIAToolAuditEvent.CreateStarted(
    ARequest,
    LDescriptor,
    FRedactor.Redact(ARequest.ArgumentsJson)
  );
  LDecision := Decide(ARequest, LDescriptor);

  case LDecision of
    cdDeny:
      if LDescriptor.Risk = trSensitive then
        Result := TRadIAToolResult.Failed(
          CSensitiveDenied,
          'Sensitive tools are denied by default.'
        )
      else if not Assigned(FConsentProvider) then
        Result := TRadIAToolResult.Failed(
          CConsentRequired,
          'A consent provider is required for this tool.'
        )
      else
        Result := TRadIAToolResult.Failed(
          CConsentDenied,
          'Tool execution was denied.'
        );
    cdCancel:
      Result := TRadIAToolResult.Failed(
        CConsentCancelled,
        'Tool execution was cancelled.'
      );
  else
    Result := FInnerExecutor.Execute(ARequest);
  end;

  LStopwatch.Stop;
  FAuditSink.Write(
    LAuditEvent.Complete(
      LDecision,
      OutcomeFromResult(Result),
      LStopwatch.ElapsedMilliseconds,
      FRedactor.Redact(Result.ErrorMessage)
    )
  );
end;

function TRadIAToolPolicyExecutor.OutcomeFromResult(
  const AResult: TRadIAToolResult
): TRadIAAuditOutcome;
begin
  if AResult.Success then
    Exit(aoSucceeded);
  if AResult.ErrorCode = CConsentDenied then
    Exit(aoDenied);
  if AResult.ErrorCode = CSensitiveDenied then
    Exit(aoDenied);
  if AResult.ErrorCode = CConsentRequired then
    Exit(aoDenied);
  if AResult.ErrorCode = CConsentCancelled then
    Exit(aoCancelled);
  if AResult.ErrorCode = 'tool_cancelled' then
    Exit(aoCancelled);
  if AResult.ErrorCode = 'precondition_failed' then
    Exit(aoPreconditionFailed);
  if AResult.ErrorCode = 'unsupported' then
    Exit(aoUnsupported);
  Result := aoFailed;
end;

procedure TRadIAToolPolicyExecutor.RevokeSessionPermissions;
begin
  TMonitor.Enter(FSessionPermissions);
  try
    FSessionPermissions.Clear;
  finally
    TMonitor.Exit(FSessionPermissions);
  end;
end;

end.
