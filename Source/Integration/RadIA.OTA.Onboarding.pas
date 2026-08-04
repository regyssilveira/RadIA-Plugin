unit RadIA.OTA.Onboarding;

interface

procedure ShowRadIAOnboarding(const AForce: Boolean = True);
procedure ReleaseRadIAOnboarding;

implementation

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.Forms,
  RadIA.Core.Container,
  RadIA.Core.Onboarding,
  RadIA.Core.ProjectTemplateService,
  RadIA.OTA.DockableForm,
  RadIA.UI.ConfigForm,
  RadIA.UI.OnboardingForm,
  RadIA.UI.ProjectWizard;

type
  TRadIAOnboardingController = class
  private
    FForm: TRadIAOnboardingForm;
    FStore: TRadIAOnboardingStore;
    procedure ExecuteAction(const AAction: TRadIAOnboardingAction);
    procedure FormClose(Sender: TObject; var AAction: TCloseAction);
    procedure OpenSettings(const ACategory: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Show(const AForce: Boolean);
  end;

var
  GController: TRadIAOnboardingController;

constructor TRadIAOnboardingController.Create;
begin
  inherited Create;
  FStore := TRadIAOnboardingStore.Create;
end;

destructor TRadIAOnboardingController.Destroy;
begin
  FForm.Free;
  FStore.Free;
  inherited Destroy;
end;

procedure TRadIAOnboardingController.ExecuteAction(
  const AAction: TRadIAOnboardingAction
);
var
  LProjectWizard: TRadIAProjectWizardForm;
begin
  case AAction of
    oaOpenChat:
      ShowRadIAChat;
    oaOpenProviderSettings:
      OpenSettings('Gemini');
    oaOpenSecuritySettings:
      OpenSettings('Security & Consent');
    oaOpenCliMcpSettings:
      OpenSettings('CLI & MCP');
    oaOpenTerminal:
      ShowRadIATerminal;
    oaCreateProject:
      begin
        LProjectWizard := TRadIAProjectWizardForm.Create(
          nil,
          TRadIAContainer.Resolve<IRadIAProjectTemplateService>,
          TRadIAContainer.Resolve<IRadIAAuthorizedProjectTemplateService>
        );
        try
          LProjectWizard.ShowModal;
        finally
          LProjectWizard.Free;
        end;
      end;
  end;
end;

procedure TRadIAOnboardingController.FormClose(
  Sender: TObject;
  var AAction: TCloseAction
);
begin
  if FForm.ModalResult = mrOk then
    FStore.MarkCompleted
  else
    FStore.MarkShown(FForm.StepIndex);
  AAction := caFree;
  FForm := nil;
end;

procedure TRadIAOnboardingController.OpenSettings(
  const ACategory: string
);
var
  LConfigForm: TRadIAFormAIConfig;
begin
  LConfigForm := TRadIAFormAIConfig.Create(nil);
  try
    LConfigForm.LoadConfig;
    LConfigForm.SelectCategory(ACategory);
    LConfigForm.ShowModal;
  finally
    LConfigForm.Free;
  end;
end;

procedure TRadIAOnboardingController.Show(const AForce: Boolean);
var
  LState: TRadIAOnboardingState;
begin
  if not AForce and not FStore.ShouldShowAutomatically then
    Exit;
  if Assigned(FForm) then
  begin
    FForm.BringToFront;
    Exit;
  end;
  FForm := TRadIAOnboardingForm.Create(nil);
  FForm.OnAction := ExecuteAction;
  FForm.OnClose := FormClose;
  LState := FStore.Load;
  if LState.FlowVersion = TRadIAOnboardingStore.CurrentFlowVersion then
    FForm.StartAtStep(LState.LastStep);
  FForm.Show;
end;

procedure ReleaseRadIAOnboarding;
begin
  FreeAndNil(GController);
end;

procedure ShowRadIAOnboarding(const AForce: Boolean);
begin
  if not Assigned(GController) then
    GController := TRadIAOnboardingController.Create;
  GController.Show(AForce);
end;

initialization
  GController := nil;

finalization
  ReleaseRadIAOnboarding;

end.
