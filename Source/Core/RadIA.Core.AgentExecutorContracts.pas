unit RadIA.Core.AgentExecutorContracts;

interface

uses
  RadIA.Core.CliManager;

type
  TRadIAExecutorCapability = (
    ecStructuredOutput,
    ecStableResume,
    ecSessionIdInOutput,
    ecModelSelection,
    ecMcp,
    ecFim
  );

  TRadIAExecutorCapabilities = set of TRadIAExecutorCapability;

  TRadIAResumeSyntax = (
    rsUnsupported,
    rsCodexExecResume,
    rsLongResumeOption
  );

  TRadIASessionIdSource = (
    sisUnavailable,
    sisStructuredEvent,
    sisExitHint
  );

  TRadIAExecutorContract = record
  private
    FKind: TRadIACliKind;
    FClientId: string;
    FCapabilities: TRadIAExecutorCapabilities;
    FResumeSyntax: TRadIAResumeSyntax;
    FSessionIdSource: TRadIASessionIdSource;
  public
    constructor Create(
      const AKind: TRadIACliKind;
      const AClientId: string;
      const ACapabilities: TRadIAExecutorCapabilities;
      const AResumeSyntax: TRadIAResumeSyntax;
      const ASessionIdSource: TRadIASessionIdSource
    );
    function Supports(
      const ACapability: TRadIAExecutorCapability
    ): Boolean;
    property Kind: TRadIACliKind read FKind;
    property ClientId: string read FClientId;
    property Capabilities: TRadIAExecutorCapabilities read FCapabilities;
    property ResumeSyntax: TRadIAResumeSyntax read FResumeSyntax;
    property SessionIdSource: TRadIASessionIdSource read FSessionIdSource;
  end;

  TRadIAAgentScopeIdentity = record
  private
    FJourneyId: string;
    FConversationId: string;
    FSessionId: string;
    FProjectId: string;
    FRequestId: string;
  public
    constructor Create(
      const AJourneyId: string;
      const AConversationId: string;
      const ASessionId: string;
      const AProjectId: string;
      const ARequestId: string
    );
    function BelongsToJourney(
      const AOther: TRadIAAgentScopeIdentity
    ): Boolean;
    function IsComplete: Boolean;
    property JourneyId: string read FJourneyId;
    property ConversationId: string read FConversationId;
    property SessionId: string read FSessionId;
    property ProjectId: string read FProjectId;
    property RequestId: string read FRequestId;
  end;

  IRadIAExecutorCapabilityProbe = interface
    ['{9A1D5849-1427-4206-A178-C24312564465}']
    function Probe(
      const ADefinition: TRadIACliDefinition;
      const ADeclared: TRadIAExecutorContract;
      out AEffective: TRadIAExecutorContract;
      out AReason: string
    ): Boolean;
  end;

  TRadIAExecutorContractCatalog = class
  public
    class function All: TArray<TRadIAExecutorContract>; static;
    class function FindByClientId(
      const AClientId: string;
      out AContract: TRadIAExecutorContract
    ): Boolean; static;
    class function FindByKind(
      const AKind: TRadIACliKind;
      out AContract: TRadIAExecutorContract
    ): Boolean; static;
  end;

implementation

uses
  System.SysUtils;

const
  CCommonCapabilities: TRadIAExecutorCapabilities = [
    ecStructuredOutput,
    ecStableResume,
    ecSessionIdInOutput,
    ecModelSelection,
    ecMcp
  ];

{ TRadIAExecutorContract }

constructor TRadIAExecutorContract.Create(
  const AKind: TRadIACliKind;
  const AClientId: string;
  const ACapabilities: TRadIAExecutorCapabilities;
  const AResumeSyntax: TRadIAResumeSyntax;
  const ASessionIdSource: TRadIASessionIdSource
);
begin
  if Trim(AClientId) = '' then
    raise EArgumentException.Create('The executor client id is required.');
  FKind := AKind;
  FClientId := LowerCase(Trim(AClientId));
  FCapabilities := ACapabilities;
  FResumeSyntax := AResumeSyntax;
  FSessionIdSource := ASessionIdSource;
end;

function TRadIAExecutorContract.Supports(
  const ACapability: TRadIAExecutorCapability
): Boolean;
begin
  Result := ACapability in FCapabilities;
end;

{ TRadIAAgentScopeIdentity }

constructor TRadIAAgentScopeIdentity.Create(
  const AJourneyId: string;
  const AConversationId: string;
  const ASessionId: string;
  const AProjectId: string;
  const ARequestId: string
);
begin
  FJourneyId := Trim(AJourneyId);
  FConversationId := Trim(AConversationId);
  FSessionId := Trim(ASessionId);
  FProjectId := Trim(AProjectId);
  FRequestId := Trim(ARequestId);
end;

function TRadIAAgentScopeIdentity.BelongsToJourney(
  const AOther: TRadIAAgentScopeIdentity
): Boolean;
begin
  Result :=
    (FJourneyId <> '') and
    SameText(FJourneyId, AOther.JourneyId) and
    SameText(FProjectId, AOther.ProjectId);
end;

function TRadIAAgentScopeIdentity.IsComplete: Boolean;
begin
  Result :=
    (FJourneyId <> '') and
    (FConversationId <> '') and
    (FSessionId <> '') and
    (FProjectId <> '') and
    (FRequestId <> '');
end;

{ TRadIAExecutorContractCatalog }

class function TRadIAExecutorContractCatalog.All:
  TArray<TRadIAExecutorContract>;
begin
  Result := [
    TRadIAExecutorContract.Create(
      ckCodex,
      'codex',
      CCommonCapabilities,
      rsCodexExecResume,
      sisStructuredEvent
    ),
    TRadIAExecutorContract.Create(
      ckClaude,
      'claude',
      CCommonCapabilities,
      rsLongResumeOption,
      sisStructuredEvent
    ),
    TRadIAExecutorContract.Create(
      ckGemini,
      'gemini',
      CCommonCapabilities,
      rsLongResumeOption,
      sisStructuredEvent
    ),
    TRadIAExecutorContract.Create(
      ckCopilot,
      'copilot',
      CCommonCapabilities,
      rsLongResumeOption,
      sisExitHint
    )
  ];
end;

class function TRadIAExecutorContractCatalog.FindByClientId(
  const AClientId: string;
  out AContract: TRadIAExecutorContract
): Boolean;
var
  LContract: TRadIAExecutorContract;
begin
  for LContract in All do
    if SameText(LContract.ClientId, Trim(AClientId)) then
    begin
      AContract := LContract;
      Exit(True);
    end;
  AContract := Default(TRadIAExecutorContract);
  Result := False;
end;

class function TRadIAExecutorContractCatalog.FindByKind(
  const AKind: TRadIACliKind;
  out AContract: TRadIAExecutorContract
): Boolean;
var
  LContract: TRadIAExecutorContract;
begin
  for LContract in All do
    if LContract.Kind = AKind then
    begin
      AContract := LContract;
      Exit(True);
    end;
  AContract := Default(TRadIAExecutorContract);
  Result := False;
end;

end.
