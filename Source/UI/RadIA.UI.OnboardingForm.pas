unit RadIA.UI.OnboardingForm;

interface

uses
  System.Classes,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.Onboarding;

type
  TRadIAOnboardingActionEvent = procedure(
    const AAction: TRadIAOnboardingAction
  ) of object;

  TRadIAOnboardingForm = class(TForm)
  private
    FActionButton: TButton;
    FBackButton: TButton;
    FCloseButton: TButton;
    FDescriptionLabel: TLabel;
    FFooterPanel: TPanel;
    FHeaderLabel: TLabel;
    FNextButton: TButton;
    FOnAction: TRadIAOnboardingActionEvent;
    FProgressLabel: TLabel;
    FStepIndex: Integer;
    FSteps: TArray<TRadIAOnboardingStep>;
    procedure ActionClick(Sender: TObject);
    procedure BackClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure ApplyCurrentTheme;
    procedure RefreshStep;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure StartAtStep(const AStepIndex: Integer);
    property OnAction: TRadIAOnboardingActionEvent read FOnAction write FOnAction;
    property StepIndex: Integer read FStepIndex;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  ToolsAPI,
  Vcl.Controls,
  Vcl.Graphics,
  RadIA.UI.Resources;

constructor TRadIAOnboardingForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Rad IA - Getting Started';
  BorderStyle := bsSizeable;
  Position := poScreenCenter;
  ClientWidth := 620;
  ClientHeight := 360;
  Constraints.MinWidth := 560;
  Constraints.MinHeight := 320;

  FSteps := TRadIAOnboardingCatalog.Steps;
  FStepIndex := 0;

  FHeaderLabel := TLabel.Create(Self);
  FHeaderLabel.Parent := Self;
  FHeaderLabel.Left := 32;
  FHeaderLabel.Top := 32;
  FHeaderLabel.Width := 540;
  FHeaderLabel.AutoSize := False;
  FHeaderLabel.Height := 38;
  FHeaderLabel.Font.Size := 16;
  FHeaderLabel.Font.Style := [fsBold];

  FProgressLabel := TLabel.Create(Self);
  FProgressLabel.Parent := Self;
  FProgressLabel.Left := 32;
  FProgressLabel.Top := 78;
  FProgressLabel.Width := 540;
  FProgressLabel.AutoSize := False;

  FDescriptionLabel := TLabel.Create(Self);
  FDescriptionLabel.Parent := Self;
  FDescriptionLabel.Left := 32;
  FDescriptionLabel.Top := 116;
  FDescriptionLabel.Width := 540;
  FDescriptionLabel.Height := 88;
  FDescriptionLabel.AutoSize := False;
  FDescriptionLabel.WordWrap := True;

  FActionButton := TButton.Create(Self);
  FActionButton.Parent := Self;
  FActionButton.Left := 32;
  FActionButton.Top := 220;
  FActionButton.Width := 210;
  FActionButton.Height := 34;
  FActionButton.OnClick := ActionClick;

  FFooterPanel := TPanel.Create(Self);
  FFooterPanel.Parent := Self;
  FFooterPanel.Align := alBottom;
  FFooterPanel.Height := 58;
  FFooterPanel.BevelOuter := bvNone;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := FFooterPanel;
  FCloseButton.Left := 16;
  FCloseButton.Top := 12;
  FCloseButton.Width := 90;
  FCloseButton.Caption := 'Close';
  FCloseButton.OnClick := CloseClick;

  FNextButton := TButton.Create(Self);
  FNextButton.Parent := FFooterPanel;
  FNextButton.Anchors := [akTop, akRight];
  FNextButton.Left := ClientWidth - 106;
  FNextButton.Top := 12;
  FNextButton.Width := 90;
  FNextButton.OnClick := NextClick;

  FBackButton := TButton.Create(Self);
  FBackButton.Parent := FFooterPanel;
  FBackButton.Anchors := [akTop, akRight];
  FBackButton.Left := ClientWidth - 202;
  FBackButton.Top := 12;
  FBackButton.Width := 90;
  FBackButton.Caption := 'Back';
  FBackButton.OnClick := BackClick;

  RefreshStep;
  ApplyCurrentTheme;
end;

procedure TRadIAOnboardingForm.ActionClick(Sender: TObject);
begin
  if Assigned(FOnAction) then
    FOnAction(FSteps[FStepIndex].Action);
end;

procedure TRadIAOnboardingForm.BackClick(Sender: TObject);
begin
  FStepIndex := Max(0, FStepIndex - 1);
  RefreshStep;
end;

procedure TRadIAOnboardingForm.CloseClick(Sender: TObject);
begin
  Close;
end;

procedure TRadIAOnboardingForm.CreateWnd;
begin
  inherited CreateWnd;
  ApplyCurrentTheme;
end;

procedure TRadIAOnboardingForm.ApplyCurrentTheme;
var
  LActiveTheme: string;
  LColors: TRadIAThemeColors;
  LThemingServices: IOTAIDEThemingServices;
begin
  LActiveTheme := 'light';
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) and
    LThemingServices.IDEThemingEnabled then
  begin
    LThemingServices.ApplyTheme(Self);
    LActiveTheme := LThemingServices.ActiveTheme;
  end;
  LColors := TRadIAThemeColors.GetColorsForTheme(LActiveTheme);
  Color := LColors.BgBase;
  if Assigned(FFooterPanel) then
    FFooterPanel.Color := LColors.BgBase;
  if Assigned(FHeaderLabel) then
    FHeaderLabel.Font.Color := LColors.TextColor;
  if Assigned(FProgressLabel) then
    FProgressLabel.Font.Color := LColors.TextColor;
  if Assigned(FDescriptionLabel) then
    FDescriptionLabel.Font.Color := LColors.TextColor;
  if SameText(LActiveTheme, 'dark') then
    TRadIAUIHelper.ApplyDarkTitleBar(Self, True);
end;

procedure TRadIAOnboardingForm.NextClick(Sender: TObject);
begin
  if FStepIndex = High(FSteps) then
  begin
    ModalResult := mrOk;
    Close;
    Exit;
  end;
  Inc(FStepIndex);
  RefreshStep;
end;

procedure TRadIAOnboardingForm.RefreshStep;
begin
  FHeaderLabel.Caption := FSteps[FStepIndex].Title;
  FProgressLabel.Caption := Format(
    'Step %d of %d',
    [FStepIndex + 1, Length(FSteps)]
  );
  FDescriptionLabel.Caption := FSteps[FStepIndex].Description;
  FActionButton.Caption := FSteps[FStepIndex].ActionLabel;
  FBackButton.Enabled := FStepIndex > 0;
  if FStepIndex = High(FSteps) then
    FNextButton.Caption := 'Finish'
  else
    FNextButton.Caption := 'Next';
end;

procedure TRadIAOnboardingForm.StartAtStep(const AStepIndex: Integer);
begin
  FStepIndex := EnsureRange(AStepIndex, 0, High(FSteps));
  RefreshStep;
end;

end.
