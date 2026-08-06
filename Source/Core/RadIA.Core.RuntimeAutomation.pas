unit RadIA.Core.RuntimeAutomation;

interface

type
  TRadIARuntimeAutomationCapability = (
    racInvoke,
    racSetValue,
    racSelect,
    racClose
  );

  TRadIARuntimeAutomationCapabilities =
    set of TRadIARuntimeAutomationCapability;

  TRadIARuntimeActionKind = (
    rakInvoke,
    rakSetValue,
    rakSelect,
    rakClose,
    rakCancel,
    rakWait,
    rakAssert
  );

  TRadIARuntimeSelector = record
  private
    FAutomationId: string;
    FClassName: string;
    FControlName: string;
    FParentPath: string;
    FText: string;
  public
    constructor Create(
      const AAutomationId: string;
      const AClassName: string;
      const AControlName: string;
      const AText: string;
      const AParentPath: string
    );
    function HasStableIdentity: Boolean;
  end;

  TRadIARuntimeSessionIdentity = record
  private
    FBuildId: string;
    FCreatedAtUtc: TDateTime;
    FExecutablePath: string;
    FProcessId: LongWord;
    FProjectPath: string;
    FSessionId: string;
  public
    constructor Create(
      const ASessionId: string;
      const AProcessId: LongWord;
      const ACreatedAtUtc: TDateTime;
      const AExecutablePath: string;
      const AProjectPath: string;
      const ABuildId: string
    );
    function IsComplete: Boolean;
    property SessionId: string read FSessionId;
    property ProcessId: LongWord read FProcessId;
    property CreatedAtUtc: TDateTime read FCreatedAtUtc;
    property ExecutablePath: string read FExecutablePath;
    property ProjectPath: string read FProjectPath;
    property BuildId: string read FBuildId;
  end;

  TRadIARuntimeScenarioLimits = record
  private
    FMaxActions: Integer;
    FMaxDurationMs: Cardinal;
    FMaxRepetitions: Integer;
  public
    constructor Create(
      const AMaxActions: Integer;
      const AMaxDurationMs: Cardinal;
      const AMaxRepetitions: Integer
    );
    function IsValid: Boolean;
    property MaxActions: Integer read FMaxActions;
    property MaxDurationMs: Cardinal read FMaxDurationMs;
  end;

  TRadIARuntimeScenarioAction = record
  private
    FKind: TRadIARuntimeActionKind;
    FSelector: TRadIARuntimeSelector;
    FTimeoutMs: Cardinal;
    FValue: string;
  public
    constructor Create(
      const AKind: TRadIARuntimeActionKind;
      const ASelector: TRadIARuntimeSelector;
      const AValue: string;
      const ATimeoutMs: Cardinal
    );
    property Kind: TRadIARuntimeActionKind read FKind;
    property Selector: TRadIARuntimeSelector read FSelector;
    property TimeoutMs: Cardinal read FTimeoutMs;
  end;

  TRadIARuntimeScenario = record
  private
    FActions: TArray<TRadIARuntimeScenarioAction>;
    FLimits: TRadIARuntimeScenarioLimits;
    FName: string;
    FSession: TRadIARuntimeSessionIdentity;
  public
    constructor Create(
      const AName: string;
      const ASession: TRadIARuntimeSessionIdentity;
      const ALimits: TRadIARuntimeScenarioLimits;
      const AActions: TArray<TRadIARuntimeScenarioAction>
    );
    function IsExecutable: Boolean;
  end;

  TRadIARuntimeElementState = record
  private
    FCapabilities: TRadIARuntimeAutomationCapabilities;
    FEnabled: Boolean;
    FVisible: Boolean;
  public
    constructor Create(
      const AVisible: Boolean;
      const AEnabled: Boolean;
      const ACapabilities: TRadIARuntimeAutomationCapabilities
    );
    property Visible: Boolean read FVisible;
    property Enabled: Boolean read FEnabled;
    property Capabilities: TRadIARuntimeAutomationCapabilities
      read FCapabilities;
  end;

  TRadIARuntimeWindowSnapshot = record
  private
    FClassName: string;
    FOwnerId: string;
    FProcessId: LongWord;
    FState: TRadIARuntimeElementState;
    FText: string;
    FWindowId: string;
  public
    constructor Create(
      const AWindowId: string;
      const AProcessId: LongWord;
      const AClassName: string;
      const AText: string;
      const AOwnerId: string;
      const AState: TRadIARuntimeElementState
    );
    property WindowId: string read FWindowId;
    property ProcessId: LongWord read FProcessId;
    property ClassName: string read FClassName;
    property Text: string read FText;
    property OwnerId: string read FOwnerId;
    property State: TRadIARuntimeElementState read FState;
  end;

  TRadIARuntimeControlSnapshot = record
  private
    FClassName: string;
    FControlId: string;
    FParentId: string;
    FPath: string;
    FState: TRadIARuntimeElementState;
    FText: string;
  public
    constructor Create(
      const AControlId: string;
      const AParentId: string;
      const AClassName: string;
      const AText: string;
      const APath: string;
      const AState: TRadIARuntimeElementState
    );
    property ControlId: string read FControlId;
    property ParentId: string read FParentId;
    property ClassName: string read FClassName;
    property Text: string read FText;
    property Path: string read FPath;
    property State: TRadIARuntimeElementState read FState;
  end;

  IRadIARuntimeDiscoveryFacade = interface
    ['{0A8C3464-B8C8-4DF3-8417-D2310EC1A23F}']
    function GetWindows(
      const ASession: TRadIARuntimeSessionIdentity
    ): TArray<TRadIARuntimeWindowSnapshot>;
    function GetControlTree(
      const ASession: TRadIARuntimeSessionIdentity;
      const AWindowId: string
    ): TArray<TRadIARuntimeControlSnapshot>;
  end;

implementation

uses
  System.SysUtils;

{ TRadIARuntimeElementState }

constructor TRadIARuntimeElementState.Create(
  const AVisible: Boolean;
  const AEnabled: Boolean;
  const ACapabilities: TRadIARuntimeAutomationCapabilities
);
begin
  FVisible := AVisible;
  FEnabled := AEnabled;
  FCapabilities := ACapabilities;
end;

{ TRadIARuntimeWindowSnapshot }

constructor TRadIARuntimeWindowSnapshot.Create(
  const AWindowId: string;
  const AProcessId: LongWord;
  const AClassName: string;
  const AText: string;
  const AOwnerId: string;
  const AState: TRadIARuntimeElementState
);
begin
  FWindowId := AWindowId;
  FProcessId := AProcessId;
  FClassName := AClassName;
  FText := AText;
  FOwnerId := AOwnerId;
  FState := AState;
end;

{ TRadIARuntimeControlSnapshot }

constructor TRadIARuntimeControlSnapshot.Create(
  const AControlId: string;
  const AParentId: string;
  const AClassName: string;
  const AText: string;
  const APath: string;
  const AState: TRadIARuntimeElementState
);
begin
  FControlId := AControlId;
  FParentId := AParentId;
  FClassName := AClassName;
  FText := AText;
  FPath := APath;
  FState := AState;
end;

{ TRadIARuntimeSelector }

constructor TRadIARuntimeSelector.Create(
  const AAutomationId: string;
  const AClassName: string;
  const AControlName: string;
  const AText: string;
  const AParentPath: string
);
begin
  FAutomationId := Trim(AAutomationId);
  FClassName := Trim(AClassName);
  FControlName := Trim(AControlName);
  FText := Trim(AText);
  FParentPath := Trim(AParentPath);
end;

function TRadIARuntimeSelector.HasStableIdentity: Boolean;
begin
  Result :=
    (FAutomationId <> '') or
    (FControlName <> '') or
    ((FClassName <> '') and (FText <> '') and (FParentPath <> ''));
end;

{ TRadIARuntimeSessionIdentity }

constructor TRadIARuntimeSessionIdentity.Create(
  const ASessionId: string;
  const AProcessId: LongWord;
  const ACreatedAtUtc: TDateTime;
  const AExecutablePath: string;
  const AProjectPath: string;
  const ABuildId: string
);
begin
  FSessionId := Trim(ASessionId);
  FProcessId := AProcessId;
  FCreatedAtUtc := ACreatedAtUtc;
  FExecutablePath := Trim(AExecutablePath);
  FProjectPath := Trim(AProjectPath);
  FBuildId := Trim(ABuildId);
end;

function TRadIARuntimeSessionIdentity.IsComplete: Boolean;
begin
  Result :=
    (FSessionId <> '') and
    (FProcessId > 0) and
    (FCreatedAtUtc > 0) and
    (FExecutablePath <> '') and
    (FProjectPath <> '') and
    (FBuildId <> '');
end;

{ TRadIARuntimeScenarioLimits }

constructor TRadIARuntimeScenarioLimits.Create(
  const AMaxActions: Integer;
  const AMaxDurationMs: Cardinal;
  const AMaxRepetitions: Integer
);
begin
  FMaxActions := AMaxActions;
  FMaxDurationMs := AMaxDurationMs;
  FMaxRepetitions := AMaxRepetitions;
end;

function TRadIARuntimeScenarioLimits.IsValid: Boolean;
begin
  Result :=
    (FMaxActions > 0) and
    (FMaxActions <= 100) and
    (FMaxDurationMs >= 100) and
    (FMaxDurationMs <= 300000) and
    (FMaxRepetitions > 0) and
    (FMaxRepetitions <= 10);
end;

{ TRadIARuntimeScenarioAction }

constructor TRadIARuntimeScenarioAction.Create(
  const AKind: TRadIARuntimeActionKind;
  const ASelector: TRadIARuntimeSelector;
  const AValue: string;
  const ATimeoutMs: Cardinal
);
begin
  FKind := AKind;
  FSelector := ASelector;
  FValue := AValue;
  FTimeoutMs := ATimeoutMs;
end;

{ TRadIARuntimeScenario }

constructor TRadIARuntimeScenario.Create(
  const AName: string;
  const ASession: TRadIARuntimeSessionIdentity;
  const ALimits: TRadIARuntimeScenarioLimits;
  const AActions: TArray<TRadIARuntimeScenarioAction>
);
begin
  FName := Trim(AName);
  FSession := ASession;
  FLimits := ALimits;
  FActions := AActions;
end;

function TRadIARuntimeScenario.IsExecutable: Boolean;
var
  LAction: TRadIARuntimeScenarioAction;
begin
  Result :=
    (FName <> '') and
    FSession.IsComplete and
    FLimits.IsValid and
    (Length(FActions) > 0) and
    (Length(FActions) <= FLimits.MaxActions);
  if not Result then
    Exit;

  for LAction in FActions do
  begin
    if (LAction.Kind <> rakWait) and
      (not LAction.Selector.HasStableIdentity) then
      Exit(False);
    if (LAction.Kind in [rakSetValue, rakSelect, rakAssert]) and
      (Trim(LAction.FValue) = '') then
      Exit(False);
    if LAction.TimeoutMs > FLimits.MaxDurationMs then
      Exit(False);
  end;
end;

end.
