unit RadIA.OTA.Consent;

interface

uses
  RadIA.Core.Interfaces,
  RadIA.Core.ConsentGate,
  RadIA.Core.Tools,
  RadIA.Core.ToolSecurity;

type
  TRadIAOTAConsentProvider = class(
    TInterfacedObject,
    IRadIAConsentProvider
  )
  private
    FConfig: IRadIAConfig;
    FConsentGate: IRadIAConsentGate;
    FRedactor: IRadIASecretRedactor;
    FTimeoutMs: Cardinal;
    function EffectiveTimeoutMs: Cardinal;
    procedure InitializeDependencies(
      const AConfig: IRadIAConfig;
      const ARedactor: IRadIASecretRedactor;
      const AConsentGate: IRadIAConsentGate
    );
    function ShowConsentDialog(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
  public
    constructor Create(
      const ATimeoutMs: Cardinal = 0;
      const AConfig: IRadIAConfig = nil
    ); overload;
    constructor Create(
      const ATimeoutMs: Cardinal;
      const AConfig: IRadIAConfig;
      const ARedactor: IRadIASecretRedactor;
      const AConsentGate: IRadIAConsentGate
    ); overload;
    destructor Destroy; override;
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
  RadIA.Core.ConsentPresentation,
  RadIA.Core.Config,
  RadIA.Core.Types,
  RadIA.Core.Version;

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
      const APresentation: TRadIAConsentPresentation
    );
    procedure FormResize(Sender: TObject);
    procedure LayoutControls;
    procedure TimerTick(Sender: TObject);
  public
    constructor CreateConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor;
      const ATimeoutMs: Cardinal;
      const AShowArguments: Boolean;
      const AAllowSession: Boolean;
      const ARedactor: IRadIASecretRedactor
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
  const APresentation: TRadIAConsentPresentation
);
begin
  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := Self;
  FTitleLabel.AutoSize := False;
  FTitleLabel.WordWrap := True;
  FTitleLabel.Font.Style := [fsBold];
  FTitleLabel.Font.Size := 12;
  FTitleLabel.Caption := APresentation.Title;

  FDescriptionLabel := TLabel.Create(Self);
  FDescriptionLabel.Parent := Self;
  FDescriptionLabel.AutoSize := False;
  FDescriptionLabel.WordWrap := True;
  FDescriptionLabel.Caption := APresentation.Description;

  FScopeLabel := TLabel.Create(Self);
  FScopeLabel.Parent := Self;
  FScopeLabel.AutoSize := False;
  FScopeLabel.WordWrap := True;
  FScopeLabel.Caption := Format(
    'Risk: %s | Source: %s | Project: %s | Scope: %s',
    [
      APresentation.Risk,
      APresentation.Source,
      APresentation.ProjectId,
      APresentation.Scope
    ]
  );

  FArgumentsMemo := TMemo.Create(Self);
  FArgumentsMemo.Parent := Self;
  FArgumentsMemo.ReadOnly := True;
  FArgumentsMemo.ScrollBars := ssBoth;
  FArgumentsMemo.WordWrap := False;
  FArgumentsMemo.ShowHint := True;
  FArgumentsMemo.Hint :=
    'Review the sanitized arguments that will be sent to the selected tool.';
  FArgumentsMemo.Text := APresentation.Arguments;

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
  const AAllowSession: Boolean;
  const ARedactor: IRadIASecretRedactor
);
var
  LPresentation: TRadIAConsentPresentation;
begin
  inherited CreateNew(nil);
  BorderStyle := bsDialog;
  Caption := RadIAVersionedCaption('RadIA Tool Consent');
  ClientWidth := CConsentDefaultWidth;
  ClientHeight := CConsentDefaultHeight;
  Constraints.MinWidth := CConsentMinimumWidth;
  Constraints.MinHeight := CConsentMinimumHeight;
  Position := poMainFormCenter;
  PopupMode := pmAuto;
  PopupParent := Application.MainForm;
  LPresentation := TRadIAConsentPresentation.Build(
    ARequest,
    ADescriptor,
    ARedactor,
    AShowArguments
  );
  ConfigureContent(LPresentation);

  FAllowOnceButton := AddButton('Allow once', CAllowOnceModalResult);
  FAllowOnceButton.Hint := 'Authorize only this request.';
  FAllowSessionButton := AddButton(
    'Allow session',
    CAllowSessionModalResult,
    AAllowSession
  );
  FAllowSessionButton.Hint :=
    'Authorize compatible tools with the same risk, source, project, and scope until revoked ' +
    'or the IDE closes.';
  FDenyButton := AddButton('Deny', CDenyModalResult);
  FDenyButton.Hint := 'Reject this request without performing the action.';
  FCancelButton := AddButton('Cancel', mrCancel);
  FCancelButton.Hint := 'Cancel the workflow that requested this action.';
  ShowHint := True;
  OnResize := FormResize;
  LayoutControls;

  FRemainingSeconds := Integer((ATimeoutMs + 999) div 1000);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 1000;
  FTimer.OnTimer := TimerTick;
  FTimer.Enabled := True;
  TimerTick(nil);
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
  InitializeDependencies(AConfig, nil, nil);
  FTimeoutMs := ATimeoutMs;
end;

constructor TRadIAOTAConsentProvider.Create(
  const ATimeoutMs: Cardinal;
  const AConfig: IRadIAConfig;
  const ARedactor: IRadIASecretRedactor;
  const AConsentGate: IRadIAConsentGate
);
begin
  inherited Create;
  InitializeDependencies(AConfig, ARedactor, AConsentGate);
  FTimeoutMs := ATimeoutMs;
end;

procedure TRadIAOTAConsentProvider.InitializeDependencies(
  const AConfig: IRadIAConfig;
  const ARedactor: IRadIASecretRedactor;
  const AConsentGate: IRadIAConsentGate
);
begin
  FConfig := AConfig;
  if not Assigned(FConfig) then
    FConfig := TRadIAConfig.GetInstance;
  FRedactor := ARedactor;
  if not Assigned(FRedactor) then
    FRedactor := TRadIASecretRedactor.Create;
  FConsentGate := AConsentGate;
  if not Assigned(FConsentGate) then
    FConsentGate := TRadIAConsentGate.Create;
end;

destructor TRadIAOTAConsentProvider.Destroy;
begin
  FRedactor := nil;
  FConsentGate := nil;
  inherited Destroy;
end;

function TRadIAOTAConsentProvider.EffectiveTimeoutMs: Cardinal;
begin
  Result := FTimeoutMs;
  if Result = 0 then
    Result := Cardinal(FConfig.ConsentTimeoutSeconds) * 1000;
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

  if not FConsentGate.Acquire(
    EffectiveTimeoutMs,
    GetCurrentThreadId <> MainThreadID
  ) then
    Exit(cdCancel);

  try
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
  finally
    FConsentGate.Release;
  end;
end;

function TRadIAOTAConsentProvider.ShowConsentDialog(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
var
  LForm: TRadIAConsentForm;
  LTimeoutMs: Cardinal;
begin
  LTimeoutMs := EffectiveTimeoutMs;
  LForm := TRadIAConsentForm.CreateConsent(
    ARequest,
    ADescriptor,
    LTimeoutMs,
    FConfig.ConsentShowArguments,
    CanRememberForSession(ADescriptor.Risk),
    FRedactor
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
