unit RadIA.Tests.ToolSecurity;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Tools,
  RadIA.Core.ToolSecurity,
  RadIA.Core.ToolRegistry;

type
  TTestRadIATool = class(TInterfacedObject, IRadIATool)
  private
    FDescriptor: TRadIAToolDescriptor;
    FExecutionCount: Integer;
  public
    constructor Create(
      const AName: string;
      const ARisk: TRadIAToolRisk
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    property ExecutionCount: Integer read FExecutionCount;
  end;

  TTestRadIAConsentProvider = class(
    TInterfacedObject,
    IRadIAConsentProvider
  )
  private
    FDecision: TRadIAConsentDecision;
    FRequestCount: Integer;
  public
    constructor Create(const ADecision: TRadIAConsentDecision);
    function RequestConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
    property RequestCount: Integer read FRequestCount;
  end;

  [TestFixture]
  TTestRadIAToolSecurity = class
  private
    function CreateRequest(
      const AToolName: string;
      const AArgumentsJson: string = '{}'
    ): TRadIAToolRequest;
  public
    [Test]
    procedure ReadOnlyToolExecutesWithoutConsent;
    [Test]
    procedure DeniedToolDoesNotExecute;
    [Test]
    procedure CancelledToolDoesNotExecuteAndIsAudited;
    [Test]
    procedure AllowOncePromptsAndAuditsEveryExecution;
    [Test]
    procedure DestructiveConsentIsNeverCached;
    [Test]
    procedure SessionConsentIsScopedAndRevocable;
    [Test]
    procedure SensitiveToolIsDeniedWithoutPrompt;
    [Test]
    procedure AuditRedactsSecrets;
    [Test]
    procedure JsonLinesAuditPersistsStructuredEvent;
    [Test]
    procedure ConsentProviderDeniesDuringShutdown;
    [Test]
    procedure ConsentProviderHonorsSessionRiskPreferences;
    [Test]
    procedure UnknownToolIsDeniedAndAudited;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.Config,
  RadIA.Core.Interfaces,
  RadIA.Core.SettingsStorage,
  RadIA.Core.Types,
  RadIA.OTA.Consent;

{ TTestRadIATool }

constructor TTestRadIATool.Create(
  const AName: string;
  const ARisk: TRadIAToolRisk
);
begin
  inherited Create;
  FDescriptor := TRadIAToolDescriptor.Create(
    AName,
    '1.0.0',
    'Test tool.',
    '{"type":"object"}',
    '{"type":"object"}',
    ARisk
  );
end;

function TTestRadIATool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Inc(FExecutionCount);
  Result := TRadIAToolResult.Succeeded('{"executed":true}');
end;

function TTestRadIATool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := FDescriptor;
end;

{ TTestRadIAConsentProvider }

constructor TTestRadIAConsentProvider.Create(
  const ADecision: TRadIAConsentDecision
);
begin
  inherited Create;
  FDecision := ADecision;
end;

function TTestRadIAConsentProvider.RequestConsent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
begin
  Inc(FRequestCount);
  Result := FDecision;
end;

{ TTestRadIAToolSecurity }

procedure TTestRadIAToolSecurity.AuditRedactsSecrets;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LExecutor: IRadIAToolPolicyExecutor;
  LEvents: TArray<TRadIAToolAuditEvent>;
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(
    TTestRadIATool.Create('ReadSecret', trReadOnly)
  );
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    nil,
    LAudit,
    TRadIASecretRedactor.Create
  );

  LExecutor.Execute(
    CreateRequest(
      'ReadSecret',
      '{"apiKey":"secret-value","authorization":"Bearer token"}'
    )
  );
  LEvents := LAudit.GetEvents;

  Assert.AreEqual<Integer>(1, Length(LEvents));
  Assert.Contains(LEvents[0].ArgumentsJson, '"apiKey":"[REDACTED]"');
  Assert.Contains(
    LEvents[0].ArgumentsJson,
    '"authorization":"[REDACTED]"'
  );
  Assert.IsFalse(LEvents[0].ArgumentsJson.Contains('secret-value'));
end;

function TTestRadIAToolSecurity.CreateRequest(
  const AToolName: string;
  const AArgumentsJson: string
): TRadIAToolRequest;
begin
  Result := TRadIAToolRequest.Create(
    AToolName,
    AArgumentsJson,
    TGUID.NewGuid.ToString,
    'test',
    'session-one',
    'project-one',
    'workspace'
  );
end;

procedure TTestRadIAToolSecurity.ConsentProviderDeniesDuringShutdown;
var
  LDescriptor: TRadIAToolDescriptor;
  LOriginalShutdown: Boolean;
  LProvider: IRadIAConsentProvider;
begin
  LOriginalShutdown := GIsShuttingDown;
  GIsShuttingDown := True;
  try
    LProvider := TRadIAOTAConsentProvider.Create(1000);
    LDescriptor := TRadIAToolDescriptor.Create(
      'ApplyPatch',
      '1.0.0',
      'Applies a reviewed patch.',
      '{"type":"object"}',
      '{"type":"object"}',
      trReversibleWrite
    );

    Assert.AreEqual(
      cdDeny,
      LProvider.RequestConsent(
        CreateRequest('ApplyPatch'),
        LDescriptor
      )
    );
  finally
    GIsShuttingDown := LOriginalShutdown;
  end;
end;

procedure TTestRadIAToolSecurity.
  ConsentProviderHonorsSessionRiskPreferences;
var
  LConfig: IRadIAConfig;
  LProvider: TRadIAOTAConsentProvider;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  TRadIAConfig.SetStorage(LStorage);
  LConfig := TRadIAConfig.Create;
  LConfig.ConsentRememberReversible := True;
  LConfig.ConsentRememberStructural := False;
  LConfig.ConsentRememberExecution := False;
  LProvider := TRadIAOTAConsentProvider.Create(1000, LConfig);
  try
    Assert.IsTrue(
      LProvider.CanRememberForSession(trReversibleWrite)
    );
    Assert.IsFalse(
      LProvider.CanRememberForSession(trStructuralWrite)
    );
    Assert.IsFalse(
      LProvider.CanRememberForSession(trExecution)
    );
    LConfig.ConsentRememberStructural := True;
    LConfig.ConsentRememberExecution := True;
    Assert.IsTrue(
      LProvider.CanRememberForSession(trStructuralWrite)
    );
    Assert.IsTrue(
      LProvider.CanRememberForSession(trExecution)
    );
    Assert.IsFalse(
      LProvider.CanRememberForSession(trDestructive)
    );
    Assert.IsFalse(
      LProvider.CanRememberForSession(trSensitive)
    );
  finally
    LProvider.Free;
    LConfig := nil;
    LStorage := nil;
    TRadIAConfig.SetStorage(nil);
  end;
end;

procedure TTestRadIAToolSecurity.AllowOncePromptsAndAuditsEveryExecution;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LConsent: TTestRadIAConsentProvider;
  LEvents: TArray<TRadIAToolAuditEvent>;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LTool: TTestRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LTool := TTestRadIATool.Create('ApplyPatch', trReversibleWrite);
  LRegistry.RegisterTool(LTool);
  LConsent := TTestRadIAConsentProvider.Create(cdAllowOnce);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    LConsent,
    LAudit,
    TRadIASecretRedactor.Create
  );

  Assert.IsTrue(LExecutor.Execute(CreateRequest('ApplyPatch')).Success);
  Assert.IsTrue(LExecutor.Execute(CreateRequest('ApplyPatch')).Success);
  LEvents := LAudit.GetEvents;

  Assert.AreEqual(2, LConsent.RequestCount);
  Assert.AreEqual(2, LTool.ExecutionCount);
  Assert.AreEqual<Integer>(2, Length(LEvents));
  Assert.AreEqual(cdAllowOnce, LEvents[0].Decision);
  Assert.AreEqual(aoSucceeded, LEvents[0].Outcome);
  Assert.AreEqual(cdAllowOnce, LEvents[1].Decision);
  Assert.AreEqual(aoSucceeded, LEvents[1].Outcome);
end;

procedure TTestRadIAToolSecurity.CancelledToolDoesNotExecuteAndIsAudited;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LConsent: TTestRadIAConsentProvider;
  LEvents: TArray<TRadIAToolAuditEvent>;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: TTestRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LTool := TTestRadIATool.Create('ApplyPatch', trReversibleWrite);
  LRegistry.RegisterTool(LTool);
  LConsent := TTestRadIAConsentProvider.Create(cdCancel);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    LConsent,
    LAudit,
    TRadIASecretRedactor.Create
  );

  LResult := LExecutor.Execute(CreateRequest('ApplyPatch'));
  LEvents := LAudit.GetEvents;

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('consent_cancelled', LResult.ErrorCode);
  Assert.AreEqual(0, LTool.ExecutionCount);
  Assert.AreEqual(1, LConsent.RequestCount);
  Assert.AreEqual<Integer>(1, Length(LEvents));
  Assert.AreEqual(cdCancel, LEvents[0].Decision);
  Assert.AreEqual(aoCancelled, LEvents[0].Outcome);
end;

procedure TTestRadIAToolSecurity.DeniedToolDoesNotExecute;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LConsent: TTestRadIAConsentProvider;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: TTestRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LTool := TTestRadIATool.Create('ApplyPatch', trReversibleWrite);
  LRegistry.RegisterTool(LTool);
  LConsent := TTestRadIAConsentProvider.Create(cdDeny);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    LConsent,
    LAudit,
    TRadIASecretRedactor.Create
  );

  LResult := LExecutor.Execute(CreateRequest('ApplyPatch'));

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('consent_denied', LResult.ErrorCode);
  Assert.AreEqual(0, LTool.ExecutionCount);
  Assert.AreEqual(aoDenied, LAudit.GetEvents[0].Outcome);
end;

procedure TTestRadIAToolSecurity.DestructiveConsentIsNeverCached;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LConsent: TTestRadIAConsentProvider;
  LEvents: TArray<TRadIAToolAuditEvent>;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LTool: TTestRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LTool := TTestRadIATool.Create('DeleteArtifact', trDestructive);
  LRegistry.RegisterTool(LTool);
  LConsent := TTestRadIAConsentProvider.Create(cdAllowSession);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    LConsent,
    LAudit,
    TRadIASecretRedactor.Create
  );

  Assert.IsTrue(LExecutor.Execute(CreateRequest('DeleteArtifact')).Success);
  Assert.IsTrue(LExecutor.Execute(CreateRequest('DeleteArtifact')).Success);
  LEvents := LAudit.GetEvents;

  Assert.AreEqual(2, LConsent.RequestCount);
  Assert.AreEqual(2, LTool.ExecutionCount);
  Assert.AreEqual<Integer>(2, Length(LEvents));
  Assert.AreEqual(cdAllowSession, LEvents[0].Decision);
  Assert.AreEqual(cdAllowSession, LEvents[1].Decision);
end;

procedure TTestRadIAToolSecurity.JsonLinesAuditPersistsStructuredEvent;
var
  LAuditFile: string;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LText: string;
begin
  LAuditFile := TPath.Combine(
    TPath.GetTempPath,
    'radia-audit-' + TGUID.NewGuid.ToString + '.jsonl'
  );
  try
    LRegistry := TRadIAToolRegistry.Create;
    LRegistry.RegisterTool(
      TTestRadIATool.Create('GetState', trReadOnly)
    );
    LExecutor := TRadIAToolPolicyExecutor.Create(
      LRegistry,
      TRadIAToolExecutor.Create(LRegistry),
      nil,
      TRadIAJsonLinesToolAuditSink.Create(LAuditFile),
      TRadIASecretRedactor.Create
    );

    LExecutor.Execute(CreateRequest('GetState'));
    LText := TFile.ReadAllText(LAuditFile, TEncoding.UTF8);

    Assert.Contains(LText, '"tool":"GetState"');
    Assert.Contains(LText, '"origin":"test"');
    Assert.Contains(LText, '"outcome":"Succeeded"');
    Assert.Contains(LText, '"startedAtUtc":');
  finally
    if TFile.Exists(LAuditFile) then
      TFile.Delete(LAuditFile);
  end;
end;

procedure TTestRadIAToolSecurity.ReadOnlyToolExecutesWithoutConsent;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LConsent: TTestRadIAConsentProvider;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: TTestRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LTool := TTestRadIATool.Create('GetState', trReadOnly);
  LRegistry.RegisterTool(LTool);
  LConsent := TTestRadIAConsentProvider.Create(cdDeny);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    LConsent,
    LAudit,
    TRadIASecretRedactor.Create
  );

  LResult := LExecutor.Execute(CreateRequest('GetState'));

  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(1, LTool.ExecutionCount);
  Assert.AreEqual(0, LConsent.RequestCount);
  Assert.AreEqual(aoSucceeded, LAudit.GetEvents[0].Outcome);
end;

procedure TTestRadIAToolSecurity.SensitiveToolIsDeniedWithoutPrompt;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LConsent: TTestRadIAConsentProvider;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: TTestRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LTool := TTestRadIATool.Create('ReadCredentials', trSensitive);
  LRegistry.RegisterTool(LTool);
  LConsent := TTestRadIAConsentProvider.Create(cdAllowOnce);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    LConsent,
    LAudit,
    TRadIASecretRedactor.Create
  );

  LResult := LExecutor.Execute(CreateRequest('ReadCredentials'));

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('sensitive_tool_denied', LResult.ErrorCode);
  Assert.AreEqual(0, LTool.ExecutionCount);
  Assert.AreEqual(0, LConsent.RequestCount);
end;

procedure TTestRadIAToolSecurity.SessionConsentIsScopedAndRevocable;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LConsent: TTestRadIAConsentProvider;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(
    TTestRadIATool.Create('ApplyPatch', trReversibleWrite)
  );
  LConsent := TTestRadIAConsentProvider.Create(cdAllowSession);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    LConsent,
    LAudit,
    TRadIASecretRedactor.Create
  );

  Assert.IsTrue(LExecutor.Execute(CreateRequest('ApplyPatch')).Success);
  Assert.IsTrue(LExecutor.Execute(CreateRequest('ApplyPatch')).Success);
  Assert.AreEqual(1, LConsent.RequestCount);

  LExecutor.RevokeSessionPermissions;
  Assert.IsTrue(LExecutor.Execute(CreateRequest('ApplyPatch')).Success);
  Assert.AreEqual(2, LConsent.RequestCount);
end;

procedure TTestRadIAToolSecurity.UnknownToolIsDeniedAndAudited;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LEvents: TArray<TRadIAToolAuditEvent>;
  LExecutor: IRadIAToolPolicyExecutor;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    nil,
    LAudit,
    TRadIASecretRedactor.Create
  );

  LResult := LExecutor.Execute(CreateRequest('MissingTool'));
  LEvents := LAudit.GetEvents;

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('tool_not_found', LResult.ErrorCode);
  Assert.AreEqual<Integer>(1, Length(LEvents));
  Assert.AreEqual('MissingTool', LEvents[0].ToolName);
  Assert.AreEqual(aoUnsupported, LEvents[0].Outcome);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAToolSecurity);

end.
