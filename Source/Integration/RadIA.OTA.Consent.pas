unit RadIA.OTA.Consent;

interface

uses
  RadIA.Core.Interfaces,
  RadIA.Core.Tools,
  RadIA.Core.ToolSecurity;

type
  TRadIAOTAConsentProvider = class(
    TInterfacedObject,
    IRadIAConsentProvider
  )
  private
    FConfig: IRadIAConfig;
    FTimeoutMs: Cardinal;
    function ShowConsentDialog(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
  public
    constructor Create(
      const ATimeoutMs: Cardinal = 0;
      const AConfig: IRadIAConfig = nil
    );
    function CanRememberForSession(
      const ARisk: TRadIAToolRisk
    ): Boolean;
    function RequestConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Winapi.Windows,
  RadIA.Core.Config,
  RadIA.Core.Types;

const
  CAllowOnceModalResult = 101;
  CAllowSessionModalResult = 102;
  CDenyModalResult = 103;
  CConsentContentMargin = 20;
  CConsentButtonGap = 8;
  CConsentButtonHeight = 30;
  CConsentButtonWidth = 104;
  CConsentDefaultHeight = 580;
  CConsentDefaultWidth = 760;
  CConsentMinimumHeight = 500;
  CConsentMinimumWidth = 640;

type
  TRadIAConsentForm = class(TForm)
  private
    FAllowOnceButton: TButton;
    FAllowSessionButton: TButton;
    FArgumentsMemo: TMemo;
    FCancelButton: TButton;
    FDenyButton: TButton;
    FDescriptionLabel: TLabel;
    FRemainingSeconds: Integer;
    FScopeLabel: TLabel;
    FStatusLabel: TLabel;
    FTimer: TTimer;
    FTitleLabel: TLabel;
    function AddButton(
      const ACaption: string;
      const AModalResult: Integer;
      const AEnabled: Boolean = True
    ): TButton;
    procedure ConfigureContent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor;
      const AShowArguments: Boolean
    );
    procedure FormResize(Sender: TObject);
    procedure LayoutControls;
    function RiskName(const ARisk: TRadIAToolRisk): string;
    procedure TimerTick(Sender: TObject);
  public
    constructor CreateConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor;
      const ATimeoutMs: Cardinal;
      const AShowArguments: Boolean;
      const AAllowSession: Boolean
    );
  end;

{ TRadIAConsentForm }

function TRadIAConsentForm.AddButton(
  const ACaption: string;
  const AModalResult: Integer;
  const AEnabled: Boolean
): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.Width := CConsentButtonWidth;
  Result.Height := CConsentButtonHeight;
  Result.ModalResult := AModalResult;
  Result.Enabled := AEnabled;
end;

procedure TRadIAConsentForm.ConfigureContent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor;
  const AShowArguments: Boolean
);
begin
  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := Self;
  FTitleLabel.AutoSize := False;
  FTitleLabel.WordWrap := True;
  FTitleLabel.Font.Style := [fsBold];
  FTitleLabel.Font.Size := 12;
  FTitleLabel.Caption := 'RadIA requests permission to run ' +
    ADescriptor.Name;

  FDescriptionLabel := TLabel.Create(Self);
  FDescriptionLabel.Parent := Self;
  FDescriptionLabel.AutoSize := False;
  FDescriptionLabel.WordWrap := True;
  FDescriptionLabel.Caption := ADescriptor.Description;

  FScopeLabel := TLabel.Create(Self);
  FScopeLabel.Parent := Self;
  FScopeLabel.AutoSize := False;
  FScopeLabel.WordWrap := True;
  FScopeLabel.Caption := Format(
    'Risk: %s | Origin: %s | Project: %s | Scope: %s',
    [
      RiskName(ADescriptor.Risk),
      ARequest.Origin,
      ARequest.ProjectId,
      ARequest.Scope
    ]
  );

  FArgumentsMemo := TMemo.Create(Self);
  FArgumentsMemo.Parent := Self;
  FArgumentsMemo.ReadOnly := True;
  FArgumentsMemo.ScrollBars := ssBoth;
  FArgumentsMemo.WordWrap := False;
  if AShowArguments then
    FArgumentsMemo.Text := ARequest.ArgumentsJson
  else
    FArgumentsMemo.Text :=
      'Arguments are hidden by your Security & Consent settings.';

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.AutoSize := False;
  FStatusLabel.WordWrap := True;
end;

procedure TRadIAConsentForm.FormResize(Sender: TObject);
begin
  LayoutControls;
end;

procedure TRadIAConsentForm.LayoutControls;
var
  LButtonTop: Integer;
  LContentWidth: Integer;
  LRightButtonLeft: Integer;
  LStatusTop: Integer;
begin
  LContentWidth := ClientWidth - (2 * CConsentContentMargin);
  LButtonTop := ClientHeight - CConsentContentMargin -
    CConsentButtonHeight;
  LStatusTop := LButtonTop - 48;

  FTitleLabel.SetBounds(CConsentContentMargin, 18, LContentWidth, 48);
  FDescriptionLabel.SetBounds(
    CConsentContentMargin,
    72,
    LContentWidth,
    44
  );
  FScopeLabel.SetBounds(CConsentContentMargin, 126, LContentWidth, 48);
  FArgumentsMemo.SetBounds(
    CConsentContentMargin,
    184,
    LContentWidth,
    LStatusTop - 196
  );
  FStatusLabel.SetBounds(
    CConsentContentMargin,
    LStatusTop,
    LContentWidth,
    38
  );

  FAllowOnceButton.SetBounds(
    CConsentContentMargin,
    LButtonTop,
    CConsentButtonWidth,
    CConsentButtonHeight
  );
  FAllowSessionButton.SetBounds(
    CConsentContentMargin + CConsentButtonWidth + CConsentButtonGap,
    LButtonTop,
    CConsentButtonWidth,
    CConsentButtonHeight
  );
  LRightButtonLeft := ClientWidth - CConsentContentMargin -
    (2 * CConsentButtonWidth) - CConsentButtonGap;
  FDenyButton.SetBounds(
    LRightButtonLeft,
    LButtonTop,
    CConsentButtonWidth,
    CConsentButtonHeight
  );
  FCancelButton.SetBounds(
    LRightButtonLeft + CConsentButtonWidth + CConsentButtonGap,
    LButtonTop,
    CConsentButtonWidth,
    CConsentButtonHeight
  );
end;

constructor TRadIAConsentForm.CreateConsent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor;
  const ATimeoutMs: Cardinal;
  const AShowArguments: Boolean;
  const AAllowSession: Boolean
);
begin
  inherited CreateNew(nil);
  BorderStyle := bsDialog;
  Caption := 'RadIA Tool Consent';
  ClientWidth := CConsentDefaultWidth;
  ClientHeight := CConsentDefaultHeight;
  Constraints.MinWidth := CConsentMinimumWidth;
  Constraints.MinHeight := CConsentMinimumHeight;
  Position := poMainFormCenter;
  ConfigureContent(ARequest, ADescriptor, AShowArguments);

  FAllowOnceButton := AddButton('Allow once', CAllowOnceModalResult);
  FAllowSessionButton := AddButton(
    'Allow session',
    CAllowSessionModalResult,
    AAllowSession
  );
  FDenyButton := AddButton('Deny', CDenyModalResult);
  FCancelButton := AddButton('Cancel', mrCancel);
  OnResize := FormResize;
  LayoutControls;

  FRemainingSeconds := Integer((ATimeoutMs + 999) div 1000);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 1000;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
  TimerTick(nil);
end;

function TRadIAConsentForm.RiskName(
  const ARisk: TRadIAToolRisk
): string;
begin
  case ARisk of
    trReadOnly: Result := 'Read only';
    trReversibleWrite: Result := 'Reversible write';
    trStructuralWrite: Result := 'Structural write';
    trExecution: Result := 'Execution';
    trDestructive: Result := 'Destructive';
  else
    Result := 'Sensitive';
  end;
end;

procedure TRadIAConsentForm.TimerTick(Sender: TObject);
begin
  if GIsShuttingDown or Application.Terminated then
  begin
    ModalResult := mrCancel;
    Exit;
  end;

  if FRemainingSeconds <= 0 then
  begin
    ModalResult := CDenyModalResult;
    Exit;
  end;

  FStatusLabel.Caption := Format(
    'No action will be performed without approval. Timeout in %d seconds.',
    [FRemainingSeconds]
  );
  Dec(FRemainingSeconds);
end;

{ TRadIAOTAConsentProvider }

constructor TRadIAOTAConsentProvider.Create(
  const ATimeoutMs: Cardinal;
  const AConfig: IRadIAConfig
);
begin
  inherited Create;
  FConfig := AConfig;
  if not Assigned(FConfig) then
    FConfig := TRadIAConfig.GetInstance;
  FTimeoutMs := ATimeoutMs;
end;

function TRadIAOTAConsentProvider.CanRememberForSession(
  const ARisk: TRadIAToolRisk
): Boolean;
begin
  case ARisk of
    trReversibleWrite:
      Result := FConfig.ConsentRememberReversible;
    trStructuralWrite:
      Result := FConfig.ConsentRememberStructural;
    trExecution:
      Result := FConfig.ConsentRememberExecution;
  else
    Result := False;
  end;
end;

function TRadIAOTAConsentProvider.RequestConsent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
var
  LDecision: TRadIAConsentDecision;
begin
  Result := cdDeny;
  if GIsShuttingDown or Application.Terminated then
    Exit;

  if GetCurrentThreadId = MainThreadID then
    Exit(ShowConsentDialog(ARequest, ADescriptor));

  LDecision := cdDeny;
  TThread.Synchronize(
    nil,
    TThreadProcedure(
      procedure
      begin
        if not GIsShuttingDown and not Application.Terminated then
          LDecision := ShowConsentDialog(ARequest, ADescriptor);
      end
    )
  );
  Result := LDecision;
end;

function TRadIAOTAConsentProvider.ShowConsentDialog(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
var
  LForm: TRadIAConsentForm;
  LTimeoutMs: Cardinal;
begin
  LTimeoutMs := FTimeoutMs;
  if LTimeoutMs = 0 then
    LTimeoutMs := Cardinal(FConfig.ConsentTimeoutSeconds) * 1000;
  LForm := TRadIAConsentForm.CreateConsent(
    ARequest,
    ADescriptor,
    LTimeoutMs,
    FConfig.ConsentShowArguments,
    CanRememberForSession(ADescriptor.Risk)
  );
  try
    case LForm.ShowModal of
      CAllowOnceModalResult: Result := cdAllowOnce;
      CAllowSessionModalResult: Result := cdAllowSession;
      CDenyModalResult: Result := cdDeny;
    else
      Result := cdCancel;
    end;
  finally
    LForm.Free;
  end;
end;

end.
