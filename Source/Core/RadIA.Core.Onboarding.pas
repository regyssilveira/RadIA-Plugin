unit RadIA.Core.Onboarding;

interface

uses
  RadIA.Core.SettingsStorage;

type
  TRadIAOnboardingAction = (
    oaNone,
    oaOpenChat,
    oaOpenProviderSettings,
    oaOpenSecuritySettings,
    oaOpenCliMcpSettings,
    oaOpenTerminal,
    oaCreateProject,
    oaRunDoctor,
    oaRunProjectHealth,
    oaShowCapabilities
  );

  TRadIAOnboardingStep = record
  private
    FTitle: string;
    FDescription: string;
    FActionLabel: string;
    FAction: TRadIAOnboardingAction;
  public
    constructor Create(
      const ATitle: string;
      const ADescription: string;
      const AActionLabel: string;
      const AAction: TRadIAOnboardingAction
    );
    property Title: string read FTitle;
    property Description: string read FDescription;
    property ActionLabel: string read FActionLabel;
    property Action: TRadIAOnboardingAction read FAction;
  end;

  TRadIAOnboardingCatalog = class
  public
    class function Steps: TArray<TRadIAOnboardingStep>; static;
  end;

  TRadIAOnboardingState = record
  private
    FFlowVersion: Integer;
    FLastStep: Integer;
    FCompleted: Boolean;
  public
    constructor Create(
      const AFlowVersion: Integer;
      const ALastStep: Integer;
      const ACompleted: Boolean
    );
    property FlowVersion: Integer read FFlowVersion;
    property LastStep: Integer read FLastStep;
    property Completed: Boolean read FCompleted;
  end;

  TRadIAOnboardingStore = class
  private
    FStorage: IRadIASettingsStorage;
    FSettingsPath: string;
    procedure WriteState(const AState: TRadIAOnboardingState);
  public
    const CurrentFlowVersion = 3;
    constructor Create(
      const AStorage: IRadIASettingsStorage = nil;
      const ASettingsPath: string = ''
    );
    function Load: TRadIAOnboardingState;
    function ShouldShowAutomatically: Boolean;
    procedure MarkCompleted;
    procedure MarkShown(const ALastStep: Integer);
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  RadIA.Core.Config;

const
  CFlowVersionValue = 'FlowVersion';
  CLastStepValue = 'LastStep';
  CCompletedValue = 'Completed';

{ TRadIAOnboardingStep }

constructor TRadIAOnboardingStep.Create(
  const ATitle: string;
  const ADescription: string;
  const AActionLabel: string;
  const AAction: TRadIAOnboardingAction
);
begin
  FTitle := ATitle;
  FDescription := ADescription;
  FActionLabel := AActionLabel;
  FAction := AAction;
end;

{ TRadIAOnboardingCatalog }

class function TRadIAOnboardingCatalog.Steps:
  TArray<TRadIAOnboardingStep>;
begin
  Result := [
    TRadIAOnboardingStep.Create(
      'Start with your goal',
      'Open Rad IA and describe what you want to understand, change, validate, debug, or create. ' +
      'The recommended route is already selected, while every execution detail remains visible.',
      'Start in Rad IA',
      oaOpenChat
    ),
    TRadIAOnboardingStep.Create(
      'Experience a useful first result',
      'Inspect the active project health without changing files. Rad IA combines IDE, compiler, build, ' +
      'tests, and local knowledge to recommend the next safe action.',
      'Understand this project',
      oaRunProjectHealth
    ),
    TRadIAOnboardingStep.Create(
      'See the complete platform',
      'Rad IA can edit and review code, build, test, debug, control the Form Designer, use a terminal, ' +
      'connect through MCP, and run guided journeys. Discover capabilities when they become useful.',
      'Explore capabilities',
      oaShowCapabilities
    ),
    TRadIAOnboardingStep.Create(
      'Keep full control',
      'The composer always shows the effective mode, provider, model, and route. Use More for executor, ' +
      'journey, and scope controls, or Settings for the complete platform configuration.',
      'Open full settings',
      oaOpenProviderSettings
    )
  ];
end;

{ TRadIAOnboardingState }

constructor TRadIAOnboardingState.Create(
  const AFlowVersion: Integer;
  const ALastStep: Integer;
  const ACompleted: Boolean
);
begin
  FFlowVersion := AFlowVersion;
  FLastStep := ALastStep;
  FCompleted := ACompleted;
end;

{ TRadIAOnboardingStore }

constructor TRadIAOnboardingStore.Create(
  const AStorage: IRadIASettingsStorage;
  const ASettingsPath: string
);
begin
  inherited Create;
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := TRadIARegistrySettingsStorage.Create;
  FSettingsPath := Trim(ASettingsPath);
  if FSettingsPath = '' then
    FSettingsPath := TRadIAConfig.GetRegistryPath + '\Onboarding';
end;

function TRadIAOnboardingStore.Load: TRadIAOnboardingState;
var
  LCompleted: Boolean;
  LFlowVersion: Integer;
  LLastStep: Integer;
begin
  if not FStorage.OpenKey(FSettingsPath, False) then
    Exit(TRadIAOnboardingState.Create(0, 0, False));
  try
    LFlowVersion := Max(0, FStorage.ReadInteger(CFlowVersionValue, 0));
    LLastStep := Max(0, FStorage.ReadInteger(CLastStepValue, 0));
    LCompleted := FStorage.ReadInteger(CCompletedValue, 0) = 1;
    Result := TRadIAOnboardingState.Create(
      LFlowVersion,
      LLastStep,
      LCompleted
    );
  finally
    FStorage.CloseKey;
  end;
end;

procedure TRadIAOnboardingStore.MarkCompleted;
var
  LSteps: TArray<TRadIAOnboardingStep>;
begin
  LSteps := TRadIAOnboardingCatalog.Steps;
  WriteState(
    TRadIAOnboardingState.Create(
      CurrentFlowVersion,
      High(LSteps),
      True
    )
  );
end;

procedure TRadIAOnboardingStore.MarkShown(const ALastStep: Integer);
var
  LLastStep: Integer;
  LSteps: TArray<TRadIAOnboardingStep>;
begin
  LSteps := TRadIAOnboardingCatalog.Steps;
  LLastStep := EnsureRange(ALastStep, 0, High(LSteps));
  WriteState(
    TRadIAOnboardingState.Create(
      CurrentFlowVersion,
      LLastStep,
      False
    )
  );
end;

function TRadIAOnboardingStore.ShouldShowAutomatically: Boolean;
begin
  Result := Load.FlowVersion < CurrentFlowVersion;
end;

procedure TRadIAOnboardingStore.WriteState(
  const AState: TRadIAOnboardingState
);
begin
  if not FStorage.OpenKey(FSettingsPath, True) then
    raise EInOutError.Create('Unable to open the onboarding settings.');
  try
    FStorage.WriteInteger(CFlowVersionValue, AState.FlowVersion);
    FStorage.WriteInteger(CLastStepValue, AState.LastStep);
    FStorage.WriteInteger(CCompletedValue, Ord(AState.Completed));
  finally
    FStorage.CloseKey;
  end;
end;

end.
