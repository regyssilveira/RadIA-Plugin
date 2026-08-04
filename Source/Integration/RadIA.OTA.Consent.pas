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

type
  TRadIAConsentForm = class(TForm)
  private
    FRemainingSeconds: Integer;
    FStatusLabel: TLabel;
    FTimer: TTimer;
    procedure AddButton(
      const ACaption: string;
      const ALeft: Integer;
      const AModalResult: Integer;
      const AEnabled: Boolean = True
    );
    procedure ConfigureContent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor;
      const AShowArguments: Boolean
    );
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

procedure TRadIAConsentForm.AddButton(
  const ACaption: string;
  const ALeft: Integer;
  const AModalResult: Integer;
  const AEnabled: Boolean
);
var
  LButton: TButton;
begin
  LButton := TButton.Create(Self);
  LButton.Parent := Self;
  LButton.Caption := ACaption;
  LButton.Left := ALeft;
  LButton.Top := 352;
  LButton.Width := 104;
  LButton.Height := 30;
  LButton.ModalResult := AModalResult;
  LButton.Enabled := AEnabled;
end;

procedure TRadIAConsentForm.ConfigureContent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor;
  const AShowArguments: Boolean
);
var
  LArgumentsMemo: TMemo;
  LDescriptionLabel: TLabel;
  LScopeLabel: TLabel;
  LTitleLabel: TLabel;
begin
  LTitleLabel := TLabel.Create(Self);
  LTitleLabel.Parent := Self;
  LTitleLabel.Left := 20;
  LTitleLabel.Top := 18;
  LTitleLabel.Font.Style := [fsBold];
  LTitleLabel.Font.Size := 12;
  LTitleLabel.Caption := 'RadIA requests permission to run ' +
    ADescriptor.Name;

  LDescriptionLabel := TLabel.Create(Self);
  LDescriptionLabel.Parent := Self;
  LDescriptionLabel.Left := 20;
  LDescriptionLabel.Top := 55;
  LDescriptionLabel.Width := 520;
  LDescriptionLabel.AutoSize := False;
  LDescriptionLabel.WordWrap := True;
  LDescriptionLabel.Caption := ADescriptor.Description;

  LScopeLabel := TLabel.Create(Self);
  LScopeLabel.Parent := Self;
  LScopeLabel.Left := 20;
  LScopeLabel.Top := 104;
  LScopeLabel.Width := 520;
  LScopeLabel.AutoSize := False;
  LScopeLabel.Caption := Format(
    'Risk: %s | Origin: %s | Project: %s | Scope: %s',
    [
      RiskName(ADescriptor.Risk),
      ARequest.Origin,
      ARequest.ProjectId,
      ARequest.Scope
    ]
  );

  LArgumentsMemo := TMemo.Create(Self);
  LArgumentsMemo.Parent := Self;
  LArgumentsMemo.Left := 20;
  LArgumentsMemo.Top := 136;
  LArgumentsMemo.Width := 520;
  LArgumentsMemo.Height := 170;
  LArgumentsMemo.ReadOnly := True;
  LArgumentsMemo.ScrollBars := ssBoth;
  LArgumentsMemo.WordWrap := False;
  if AShowArguments then
    LArgumentsMemo.Text := ARequest.ArgumentsJson
  else
    LArgumentsMemo.Text :=
      'Arguments are hidden by your Security & Consent settings.';

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.Left := 20;
  FStatusLabel.Top := 320;
  FStatusLabel.Width := 520;
  FStatusLabel.AutoSize := False;
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
  ClientWidth := 560;
  ClientHeight := 400;
  Position := poMainFormCenter;
  ConfigureContent(ARequest, ADescriptor, AShowArguments);

  AddButton('Allow once', 20, CAllowOnceModalResult);
  AddButton(
    'Allow session',
    132,
    CAllowSessionModalResult,
    AAllowSession
  );
  AddButton('Deny', 356, CDenyModalResult);
  AddButton('Cancel', 468, mrCancel);

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
