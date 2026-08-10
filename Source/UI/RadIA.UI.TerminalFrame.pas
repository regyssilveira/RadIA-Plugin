unit RadIA.UI.TerminalFrame;

interface

uses
  System.Classes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.CliProcess,
  RadIA.Core.Terminal,
  RadIA.Core.TerminalEmulator,
  RadIA.Core.ToolSecurity,
  RadIA.Core.JourneyContext;

type
  TRadIATerminalHyperlink = record
    StartIndex: Integer;
    TextLength: Integer;
    Uri: string;
  end;

  IRadIATerminalLifecycleGuard = interface
    ['{81E20293-FA87-486D-BD47-75E0589DDDBC}']
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

  TRadIATerminalFrame = class(TFrame)
  private
    FTopPanel: TPanel;
    FProfileLabel: TLabel;
    FProfileCombo: TComboBox;
    FSnippetLabel: TLabel;
    FSnippetCombo: TComboBox;
    FHistoryLabel: TLabel;
    FHistoryCombo: TComboBox;
    FCommandLabel: TLabel;
    FCommandEdit: TEdit;
    FPaletteLabel: TLabel;
    FPaletteEdit: TEdit;
    FPaletteCombo: TComboBox;
    FPaletteItems: TArray<TRadIATerminalPaletteItem>;
    FRunButton: TButton;
    FStopButton: TButton;
    FClearButton: TButton;
    FOutputEditor: TRichEdit;
    FOutputLabel: TLabel;
    FStatusLabel: TLabel;
    FJourneyLabel: TLabel;
    FScreen: IRadIATerminalEmulator;
    FHistory: TRadIATerminalHistory;
    FHistorySearchIndex: Integer;
    FHistorySearchQuery: string;
    FUpdatingHistorySearch: Boolean;
    FFocusQueued: Boolean;
    FSession: IRadIACliProcessSession;
    FAuthorizationPolicy: IRadIAToolAuthorizationPolicy;
    FJourneyContext: IRadIAJourneyContextCoordinator;
    FLifecycleGuard: IInterface;
    FHyperlinks: TArray<TRadIATerminalHyperlink>;
    procedure ApplyDeferredFocus(
      const AGuard: IRadIATerminalLifecycleGuard
    );
    procedure AppendOutput(const AText: string);
    procedure AppendSegment(
      const ASegment: TRadIATerminalTextSegment
    );
    procedure BuildControls;
    procedure BuildPaletteControls;
    procedure ConfigureControlHints;
    function CanRunCommand(
      const AProfile: TRadIATerminalProfile;
      const ACommand: string;
      const AWorkingDirectory: string
    ): Boolean;
    function CanOpenLink(const AUri: string): Boolean;
    procedure ClearClick(Sender: TObject);
    procedure CommandChange(Sender: TObject);
    procedure CommandKeyDown(
      Sender: TObject;
      var Key: Word;
      Shift: TShiftState
    );
    procedure FinishCommand(
      const ACommand: string;
      const AProfileId: string;
      const AResult: TRadIACliProcessResult
    );
    function GetWorkingDirectory: string;
    procedure GetTerminalSize(
      out AColumns: SmallInt;
      out ARows: SmallInt
    );
    procedure HandleRunningInput;
    procedure HistoryChange(Sender: TObject);
    procedure LoadHistory;
    procedure PaletteChange(Sender: TObject);
    procedure PaletteKeyDown(
      Sender: TObject;
      var Key: Word;
      Shift: TShiftState
    );
    procedure PaletteQueryChange(Sender: TObject);
    procedure OutputMouseDown(
      Sender: TObject;
      Button: TMouseButton;
      Shift: TShiftState;
      X: Integer;
      Y: Integer
    );
    procedure OutputDoubleClick(Sender: TObject);
    procedure OutputMouseUp(
      Sender: TObject;
      Button: TMouseButton;
      Shift: TShiftState;
      X: Integer;
      Y: Integer
    );
    procedure SendMouseInput(
      const AButton: TMouseButton;
      const AHorizontalPosition: Integer;
      const AVerticalPosition: Integer;
      const APressed: Boolean
    );
    procedure QueueCompletion(
      const AGuard: IRadIATerminalLifecycleGuard;
      const ACommand: string;
      const AProfileId: string;
      const AResult: TRadIACliProcessResult
    );
    procedure QueueOutput(
      const AGuard: IRadIATerminalLifecycleGuard;
      const AChunk: string
    );
    procedure RefreshPalette;
    procedure RefreshJourneyContext;
    procedure RunClick(Sender: TObject);
    procedure SnippetChange(Sender: TObject);
    procedure StopClick(Sender: TObject);
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyCurrentTheme;
    procedure EnsureVisibleContent;
    {$IFDEF TESTS}
    function TestJourneyCaption: string;
    {$ENDIF}
  end;

  TRadIATerminalTabsFrame = class(TCustomFrame)
  private
    FAddButton: TButton;
    FCloseButton: TButton;
    FNextSessionNumber: Integer;
    FPageControl: TPageControl;
    FToolbar: TPanel;
    procedure AddClick(Sender: TObject);
    function AddSession: TRadIATerminalFrame;
    procedure CloseClick(Sender: TObject);
    function GetActiveSession: TRadIATerminalFrame;
    function HasAccessibleLabels(
      const ASession: TRadIATerminalFrame
    ): Boolean;
    function HasCommandInput(
      const ASession: TRadIATerminalFrame
    ): Boolean;
    function HasOutput(
      const ASession: TRadIATerminalFrame
    ): Boolean;
    function HasRequiredControls(
      const ASession: TRadIATerminalFrame
    ): Boolean;
    function IsAvailableTabStop(const AControl: TWinControl): Boolean;
    function CountTabStops(
      const ASession: TRadIATerminalFrame
    ): Integer;
    procedure WriteSmokeEvidence(
      const ASession: TRadIATerminalFrame
    );
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyCurrentTheme;
    procedure EnsureVisibleContent;
    {$IFDEF TESTS}
    procedure TestAddSession;
    function TestActiveSession: TObject;
    procedure TestCloseSession;
    function TestSessionCount: Integer;
    function TestAccessibilityReady: Boolean;
    {$ENDIF}
  end;

implementation

{$R *.dfm}
{$R RadIA.UI.TerminalTabsFrame.dfm}

uses
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.Math,
  System.SyncObjs,
  System.SysUtils,
  Winapi.Messages,
  Winapi.RichEdit,
  Winapi.ShellAPI,
  Winapi.Windows,
  Vcl.Graphics,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliMcpSettings,
  RadIA.Core.Container,
  RadIA.Core.PseudoTerminal,
  RadIA.Core.Tools,
  RadIA.OTA.Helper;

type
  TRadIATerminalLifecycleGuard = class(
    TInterfacedObject,
    IRadIATerminalLifecycleGuard
  )
  private
    FAlive: Integer;
  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

{ TRadIATerminalLifecycleGuard }

constructor TRadIATerminalLifecycleGuard.Create;
begin
  inherited Create;
  FAlive := 1;
end;

procedure TRadIATerminalLifecycleGuard.Invalidate;
begin
  TInterlocked.Exchange(FAlive, 0);
end;

function TRadIATerminalLifecycleGuard.IsAlive: Boolean;
begin
  Result := TInterlocked.CompareExchange(FAlive, 0, 0) <> 0;
end;

{ TRadIATerminalFrame }

constructor TRadIATerminalFrame.Create(AOwner: TComponent);
var
  LAppData: string;
begin
  inherited Create(AOwner);
  Align := alClient;
  FLifecycleGuard := TRadIATerminalLifecycleGuard.Create;
  FScreen := TRadIATerminalEmulatorFactory.CreateNative;

  LAppData := GetEnvironmentVariable('APPDATA');
  if LAppData = '' then
    LAppData := TPath.GetHomePath;
  FHistory := TRadIATerminalHistory.Create(
    TPath.Combine(LAppData, 'RadIA\terminal-history.json')
  );
  FHistorySearchIndex := -1;
  TRadIAContainer.TryResolve<IRadIAToolAuthorizationPolicy>(
    FAuthorizationPolicy
  );
  TRadIAContainer.TryResolve<IRadIAJourneyContextCoordinator>(
    FJourneyContext
  );
end;

destructor TRadIATerminalFrame.Destroy;
var
  LGuard: IRadIATerminalLifecycleGuard;
begin
  if Supports(
    FLifecycleGuard,
    IRadIATerminalLifecycleGuard,
    LGuard
  ) then
    LGuard.Invalidate;
  if Assigned(FSession) then
  begin
    FSession.Cancel;
    FSession := nil;
  end;
  FScreen := nil;
  FHistory.Free;
  inherited Destroy;
end;

procedure TRadIATerminalFrame.CreateWnd;
begin
  inherited;
  if Assigned(FTopPanel) then
    Exit;
  BuildControls;
end;

procedure TRadIATerminalFrame.BuildControls;
var
  LProfile: TRadIATerminalProfile;
  LSnippet: TRadIATerminalSnippet;
begin
  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 220;
  FTopPanel.BevelOuter := bvNone;
  FTopPanel.ShowCaption := False;

  FProfileLabel := TLabel.Create(Self);
  FProfileLabel.Parent := FTopPanel;
  FProfileLabel.SetBounds(8, 6, 180, 17);
  FProfileLabel.Caption := 'Shell profile';

  FProfileCombo := TComboBox.Create(Self);
  FProfileCombo.Parent := FTopPanel;
  FProfileCombo.SetBounds(8, 24, 180, 25);
  FProfileCombo.Style := csDropDownList;
  FProfileLabel.FocusControl := FProfileCombo;
  for LProfile in TRadIATerminalCatalog.Profiles do
    FProfileCombo.Items.Add(LProfile.DisplayName);
  FProfileCombo.ItemIndex := 0;

  FSnippetLabel := TLabel.Create(Self);
  FSnippetLabel.Parent := FTopPanel;
  FSnippetLabel.SetBounds(196, 6, 180, 17);
  FSnippetLabel.Caption := 'Command snippet';

  FSnippetCombo := TComboBox.Create(Self);
  FSnippetCombo.Parent := FTopPanel;
  FSnippetCombo.SetBounds(196, 24, 180, 25);
  FSnippetCombo.Style := csDropDownList;
  FSnippetLabel.FocusControl := FSnippetCombo;
  FSnippetCombo.Items.Add('Snippets...');
  for LSnippet in TRadIATerminalCatalog.Snippets do
    FSnippetCombo.Items.Add(LSnippet.Name);
  FSnippetCombo.ItemIndex := 0;
  FSnippetCombo.OnChange := SnippetChange;

  FHistoryLabel := TLabel.Create(Self);
  FHistoryLabel.Parent := FTopPanel;
  FHistoryLabel.SetBounds(384, 6, 220, 17);
  FHistoryLabel.Caption := 'Command history';

  FHistoryCombo := TComboBox.Create(Self);
  FHistoryCombo.Parent := FTopPanel;
  FHistoryCombo.SetBounds(384, 24, 220, 25);
  FHistoryCombo.Style := csDropDownList;
  FHistoryLabel.FocusControl := FHistoryCombo;
  FHistoryCombo.OnChange := HistoryChange;

  FCommandLabel := TLabel.Create(Self);
  FCommandLabel.Parent := FTopPanel;
  FCommandLabel.SetBounds(8, 55, 596, 17);
  FCommandLabel.Caption := 'Terminal command';

  FCommandEdit := TEdit.Create(Self);
  FCommandEdit.Parent := FTopPanel;
  FCommandEdit.SetBounds(8, 73, 596, 25);
  FCommandLabel.FocusControl := FCommandEdit;
  FCommandEdit.OnChange := CommandChange;
  FCommandEdit.OnKeyDown := CommandKeyDown;

  FRunButton := TButton.Create(Self);
  FRunButton.Parent := FTopPanel;
  FRunButton.SetBounds(612, 71, 72, 27);
  FRunButton.Caption := 'Run';
  FRunButton.Default := True;
  FRunButton.OnClick := RunClick;

  FStopButton := TButton.Create(Self);
  FStopButton.Parent := FTopPanel;
  FStopButton.SetBounds(692, 71, 72, 27);
  FStopButton.Caption := 'Stop';
  FStopButton.Enabled := False;
  FStopButton.OnClick := StopClick;

  FClearButton := TButton.Create(Self);
  FClearButton.Parent := FTopPanel;
  FClearButton.SetBounds(772, 71, 72, 27);
  FClearButton.Caption := 'Clear';
  FClearButton.OnClick := ClearClick;

  BuildPaletteControls;
  ConfigureControlHints;

  FJourneyLabel := TLabel.Create(Self);
  FJourneyLabel.Parent := FTopPanel;
  FJourneyLabel.SetBounds(8, 153, 820, 17);
  FJourneyLabel.Caption := 'Journey: Detached';
  FJourneyLabel.Hint :=
    'Shared context identity used by chat, terminal, and editor for the active project.';
  FJourneyLabel.ShowHint := True;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FTopPanel;
  FStatusLabel.SetBounds(8, 175, 820, 17);
  FStatusLabel.Caption := 'Ready';

  FOutputLabel := TLabel.Create(Self);
  FOutputLabel.Parent := FTopPanel;
  FOutputLabel.SetBounds(8, 197, 820, 17);
  FOutputLabel.Caption := 'Terminal output';

  FOutputEditor := TRichEdit.Create(Self);
  FOutputEditor.Parent := Self;
  FOutputEditor.Align := alClient;
  FOutputEditor.ReadOnly := True;
  FOutputEditor.ScrollBars := ssBoth;
  FOutputEditor.WordWrap := False;
  FOutputEditor.Font.Name := 'Consolas';
  FOutputEditor.Font.Size := 10;
  FOutputEditor.OnDblClick := OutputDoubleClick;
  FOutputEditor.OnMouseDown := OutputMouseDown;
  FOutputEditor.OnMouseUp := OutputMouseUp;
  FOutputLabel.FocusControl := FOutputEditor;
  LoadHistory;
  RefreshJourneyContext;
end;

procedure TRadIATerminalFrame.BuildPaletteControls;
begin
  FPaletteLabel := TLabel.Create(Self);
  FPaletteLabel.Parent := FTopPanel;
  FPaletteLabel.SetBounds(8, 104, 280, 17);
  FPaletteLabel.Caption := 'Command palette (Ctrl+P)';

  FPaletteEdit := TEdit.Create(Self);
  FPaletteEdit.Parent := FTopPanel;
  FPaletteEdit.SetBounds(8, 122, 280, 25);
  FPaletteEdit.TextHint := 'Search snippets and history';
  FPaletteEdit.OnChange := PaletteQueryChange;
  FPaletteEdit.OnKeyDown := PaletteKeyDown;
  FPaletteLabel.FocusControl := FPaletteEdit;

  FPaletteCombo := TComboBox.Create(Self);
  FPaletteCombo.Parent := FTopPanel;
  FPaletteCombo.SetBounds(296, 122, 548, 25);
  FPaletteCombo.Style := csDropDownList;
  FPaletteCombo.OnChange := PaletteChange;
end;

procedure TRadIATerminalFrame.ConfigureControlHints;
begin
  FProfileCombo.Hint := 'Select the shell executable and argument profile for this terminal session';
  FSnippetCombo.Hint := 'Insert a safe predefined command into the command field without running it';
  FHistoryCombo.Hint := 'Restore a command from local terminal history without executing it';
  FCommandEdit.Hint := 'Enter runs or sends input. Ctrl+R searches history and Ctrl+P opens the palette';
  FRunButton.Hint := 'Run the command after execution policy and consent checks';
  FStopButton.Hint := 'Cancel the active process and its child process tree';
  FClearButton.Hint := 'Clear visible terminal output without deleting command history';
  FPaletteEdit.Hint := 'Filter command snippets and local history. Press Enter to select a result';
  FPaletteCombo.Hint := 'Choose a filtered command and place it in the command field';

  FProfileCombo.ShowHint := True;
  FSnippetCombo.ShowHint := True;
  FHistoryCombo.ShowHint := True;
  FCommandEdit.ShowHint := True;
  FRunButton.ShowHint := True;
  FStopButton.ShowHint := True;
  FClearButton.ShowHint := True;
  FPaletteEdit.ShowHint := True;
  FPaletteCombo.ShowHint := True;
end;

procedure TRadIATerminalFrame.AppendOutput(const AText: string);
var
  LSegment: TRadIATerminalTextSegment;
begin
  if AText = '' then
    Exit;
  FScreen.Feed(AText);
  FHyperlinks := nil;
  SendMessage(FOutputEditor.Handle, WM_SETREDRAW, 0, 0);
  try
    FOutputEditor.Clear;
    for LSegment in FScreen.RenderSegments do
      AppendSegment(LSegment);
  finally
    SendMessage(FOutputEditor.Handle, WM_SETREDRAW, 1, 0);
    FOutputEditor.Invalidate;
  end;
end;

procedure TRadIATerminalFrame.AppendSegment(
  const ASegment: TRadIATerminalTextSegment
);
const
  TERMINAL_COLORS: array[TRadIATerminalColor] of TColor = (
    clWindowText,
    clBlack,
    $000000CC,
    $0000A000,
    $0000A0A0,
    $00CC0000,
    $00A000A0,
    $00A0A000,
    $00C0C0C0,
    $00606060,
    $004040FF,
    $0040E040,
    $0040E0E0,
    $00FF8080,
    $00E040E0,
    $00E0E040,
    clWhite
  );
var
  LBackground: TColor;
  LCharacterFormat: TCharFormat2;
  LForeground: TColor;
  LSwapColor: TColor;
  LHyperlink: TRadIATerminalHyperlink;
  function RgbColor(const ARgb: Integer): TColor;
  begin
    Result := RGB(
      (ARgb shr 16) and $FF,
      (ARgb shr 8) and $FF,
      ARgb and $FF
    );
  end;
begin
  FOutputEditor.SelStart := Length(FOutputEditor.Text);
  FOutputEditor.SelLength := 0;
  if ASegment.Style.ForegroundRgb >= 0 then
    LForeground := RgbColor(ASegment.Style.ForegroundRgb)
  else if ASegment.Style.Foreground = tcDefault then
    LForeground := FOutputEditor.Font.Color
  else
    LForeground := TERMINAL_COLORS[ASegment.Style.Foreground];
  if ASegment.Style.BackgroundRgb >= 0 then
    LBackground := RgbColor(ASegment.Style.BackgroundRgb)
  else if ASegment.Style.Background = tcDefault then
    LBackground := FOutputEditor.Color
  else
    LBackground := TERMINAL_COLORS[ASegment.Style.Background];
  if ASegment.Style.Inverse then
  begin
    LSwapColor := LForeground;
    LForeground := LBackground;
    LBackground := LSwapColor;
  end;
  if (ASegment.Style.Hyperlink <> '') and
    (ASegment.Style.Foreground = tcDefault) and
    (ASegment.Style.ForegroundRgb < 0) then
    LForeground := clHotLight;
  FOutputEditor.SelAttributes.Color := LForeground;
  FOutputEditor.SelAttributes.Style := [];
  if ASegment.Style.Bold then
    FOutputEditor.SelAttributes.Style :=
      FOutputEditor.SelAttributes.Style + [fsBold];
  if ASegment.Style.Italic then
    FOutputEditor.SelAttributes.Style :=
      FOutputEditor.SelAttributes.Style + [fsItalic];
  if ASegment.Style.Underline or (ASegment.Style.Hyperlink <> '') then
    FOutputEditor.SelAttributes.Style :=
      FOutputEditor.SelAttributes.Style + [fsUnderline];
  FillChar(LCharacterFormat, SizeOf(LCharacterFormat), 0);
  LCharacterFormat.cbSize := SizeOf(LCharacterFormat);
  LCharacterFormat.dwMask := CFM_BACKCOLOR;
  LCharacterFormat.crBackColor := ColorToRGB(LBackground);
  SendMessage(
    FOutputEditor.Handle,
    EM_SETCHARFORMAT,
    SCF_SELECTION,
    LPARAM(@LCharacterFormat)
  );
  if ASegment.Style.Hyperlink <> '' then
  begin
    LHyperlink.StartIndex := FOutputEditor.SelStart;
    LHyperlink.TextLength := Length(ASegment.Text);
    LHyperlink.Uri := ASegment.Style.Hyperlink;
    FHyperlinks := FHyperlinks + [LHyperlink];
  end;
  FOutputEditor.SelText := ASegment.Text;
end;

procedure TRadIATerminalFrame.ApplyCurrentTheme;
begin
  Invalidate;
  if Assigned(FOutputEditor) then
    FOutputEditor.Invalidate;
end;

procedure TRadIATerminalFrame.ApplyDeferredFocus(
  const AGuard: IRadIATerminalLifecycleGuard
);
var
  LCommandHandle: HWND;
  LParentForm: TCustomForm;
begin
  if not AGuard.IsAlive then
    Exit;
  FFocusQueued := False;
  if not Assigned(FCommandEdit) or not Assigned(FCommandEdit.Parent) then
    Exit;
  LParentForm := GetParentForm(FCommandEdit);
  if not Assigned(LParentForm) or not LParentForm.Showing or
    not LParentForm.HandleAllocated or not FCommandEdit.HandleAllocated then
    Exit;
  LCommandHandle := FCommandEdit.Handle;
  if not IsWindow(LCommandHandle) or
    (GetParent(LCommandHandle) = 0) or
    not IsWindowVisible(LCommandHandle) or
    not FCommandEdit.Enabled then
    Exit;
  Winapi.Windows.SetFocus(LCommandHandle);
end;

procedure TRadIATerminalFrame.ClearClick(Sender: TObject);
begin
  FOutputEditor.Clear;
  FScreen.Clear;
  FHyperlinks := nil;
end;

function TRadIATerminalFrame.CanOpenLink(const AUri: string): Boolean;
var
  LDecision: TRadIAConsentDecision;
  LDescriptor: TRadIAToolDescriptor;
  LJson: TJSONObject;
  LRequest: TRadIAToolRequest;
begin
  Result := False;
  if not Assigned(FAuthorizationPolicy) then
  begin
    FStatusLabel.Caption := 'Link authorization policy is unavailable';
    Exit;
  end;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('uri', AUri);
    LRequest := TRadIAToolRequest.Create(
      'OpenTerminalLink',
      LJson.ToJSON,
      TGUID.NewGuid.ToString,
      'terminal',
      'terminal-link',
      GetWorkingDirectory,
      AUri
    );
    LDescriptor := TRadIAToolDescriptor.Create(
      'OpenTerminalLink',
      '1.0.0',
      'Opens a terminal hyperlink in the operating system.',
      '{"type":"object"}',
      '{"type":"object"}',
      trExecution
    ).WithConsentEveryTime;
    LDecision := FAuthorizationPolicy.Authorize(LRequest, LDescriptor);
    Result := LDecision in [cdAllowOnce, cdAllowSession];
    if not Result then
      FStatusLabel.Caption := 'Terminal link was not authorized';
  finally
    LJson.Free;
  end;
end;

function TRadIATerminalFrame.CanRunCommand(
  const AProfile: TRadIATerminalProfile;
  const ACommand: string;
  const AWorkingDirectory: string
): Boolean;
var
  LClientId: string;
  LDecision: TRadIAConsentDecision;
  LDescriptor: TRadIAToolDescriptor;
  LJson: TJSONObject;
  LMcpSettings: TRadIACliMcpClientSettings;
  LMcpStore: TRadIACliMcpSettings;
  LJourney: TRadIAJourneyContextSnapshot;
  LProjectId: string;
  LRequest: TRadIAToolRequest;
  LSessionId: string;
begin
  Result := False;
  if not Assigned(FAuthorizationPolicy) then
  begin
    FStatusLabel.Caption := 'Execution policy is unavailable';
    Exit;
  end;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('command', ACommand);
    LJson.AddPair('profileId', AProfile.Id);
    LJson.AddPair('workingDirectory', AWorkingDirectory);
    if AProfile.Id.StartsWith('ai-') then
    begin
      LClientId := AProfile.Id.Substring(3);
      LMcpStore := TRadIACliMcpSettings.Create;
      try
        LMcpSettings := LMcpStore.Load(LClientId, '', '');
        LJson.AddPair('mcpConfigPath', LMcpSettings.McpConfigPath);
        LJson.AddPair('mcpBridgePath', LMcpSettings.McpBridgePath);
      finally
        LMcpStore.Free;
      end;
    end;
    LSessionId := 'terminal';
    LProjectId := AWorkingDirectory;
    if Assigned(FJourneyContext) and FJourneyContext.TryGetActive(LJourney) and
      SameFileName(ExtractFileDir(LJourney.ProjectId), AWorkingDirectory) then
    begin
      LSessionId := LJourney.JourneyId;
      LProjectId := LJourney.ProjectId;
    end;
    LRequest := TRadIAToolRequest.Create(
      'RunTerminalCommand',
      LJson.ToJSON,
      TGUID.NewGuid.ToString,
      'terminal',
      LSessionId,
      LProjectId,
      AWorkingDirectory
    );
    LDescriptor := TRadIAToolDescriptor.Create(
      'RunTerminalCommand',
      '1.0.0',
      'Authorizes an interactive terminal command.',
      '{"type":"object"}',
      '{"type":"object"}',
      trExecution
    );
    LDecision := FAuthorizationPolicy.Authorize(
      LRequest,
      LDescriptor
    );
    Result := LDecision in [cdAllowOnce, cdAllowSession];
    if not Result then
      FStatusLabel.Caption := 'Terminal command was not authorized';
  finally
    LJson.Free;
  end;
end;

procedure TRadIATerminalFrame.CommandChange(Sender: TObject);
begin
  if FUpdatingHistorySearch then
    Exit;
  FHistorySearchIndex := -1;
  FHistorySearchQuery := '';
end;

procedure TRadIATerminalFrame.CommandKeyDown(
  Sender: TObject;
  var Key: Word;
  Shift: TShiftState
);
var
  LCommand: string;
  LNextIndex: Integer;
begin
  if (Key = Ord('P')) and (ssCtrl in Shift) then
  begin
    Key := 0;
    FPaletteEdit.SetFocus;
    Exit;
  end;
  if (Key <> Ord('R')) or not (ssCtrl in Shift) then
    Exit;
  Key := 0;
  if FHistorySearchQuery = '' then
    FHistorySearchQuery := FCommandEdit.Text;
  if FHistory.FindPrevious(
    FHistorySearchQuery,
    FHistorySearchIndex,
    LCommand,
    LNextIndex
  ) then
  begin
    FUpdatingHistorySearch := True;
    try
      FCommandEdit.Text := LCommand;
      FCommandEdit.SelStart := Length(LCommand);
    finally
      FUpdatingHistorySearch := False;
    end;
    FHistorySearchIndex := LNextIndex;
    FStatusLabel.Caption := 'Reverse search: ' + FHistorySearchQuery;
  end
  else
    FStatusLabel.Caption := 'No earlier history match';
end;

procedure TRadIATerminalFrame.EnsureVisibleContent;
var
  LGuard: IRadIATerminalLifecycleGuard;
begin
  RefreshJourneyContext;
  if FFocusQueued or not Supports(
    FLifecycleGuard,
    IRadIATerminalLifecycleGuard,
    LGuard
  ) then
    Exit;
  FFocusQueued := True;
  TThread.Queue(
    nil,
    procedure
    begin
      if LGuard.IsAlive then
        ApplyDeferredFocus(LGuard);
    end
  );
end;

procedure TRadIATerminalFrame.RefreshJourneyContext;
var
  LContext: TRadIAJourneyContextSnapshot;
begin
  if not Assigned(FJourneyLabel) then
    Exit;
  if Assigned(FJourneyContext) and FJourneyContext.TryGetActive(LContext) then
  begin
    FJourneyLabel.Caption := 'Journey: ' + Copy(LContext.JourneyId, 1, 8) +
      ' | Project: ' + ExtractFileName(LContext.ProjectId);
    case LContext.State of
      jasRunning:
        FJourneyLabel.Caption := FJourneyLabel.Caption + ' | Running';
      jasCancellationRequested:
        FJourneyLabel.Caption := FJourneyLabel.Caption + ' | Cancelling';
    end;
    FJourneyLabel.Hint := 'Journey ' + LContext.JourneyId + sLineBreak +
      'Conversation ' + LContext.ConversationId + sLineBreak +
      'Executor ' + LContext.ExecutorId;
  end
  else
  begin
    FJourneyLabel.Caption := 'Journey: Detached';
    FJourneyLabel.Hint :=
      'Use the Journey button or /context in chat to link shared context.';
  end;
end;

procedure TRadIATerminalFrame.FinishCommand(
  const ACommand: string;
  const AProfileId: string;
  const AResult: TRadIACliProcessResult
);
begin
  FSession := nil;
  if Assigned(FJourneyContext) then
    FJourneyContext.CompleteActivity;
  RefreshJourneyContext;
  FRunButton.Enabled := True;
  FRunButton.Caption := 'Run';
  FStopButton.Enabled := False;
  if AResult.Cancelled then
    FStatusLabel.Caption := 'Cancelled'
  else if AResult.TimedOut then
    FStatusLabel.Caption := 'Timed out'
  else
    FStatusLabel.Caption := Format('Finished with exit code %d', [AResult.ExitCode]);
  FHistory.Add(
    TRadIATerminalHistoryEntry.Create(
      TTimeZone.Local.ToUniversalTime(Now),
      AProfileId,
      ACommand,
      AResult.ExitCode
    )
  );
  FHistory.Save;
  LoadHistory;
end;

function TRadIATerminalFrame.GetWorkingDirectory: string;
begin
  Result := TRadIAOTAHelper.GetActiveProjectFolder;
  if Result = '' then
    Result := GetCurrentDir;
end;

procedure TRadIATerminalFrame.GetTerminalSize(
  out AColumns: SmallInt;
  out ARows: SmallInt
);
const
  CMinimumColumns = 20;
  CMinimumRows = 5;
var
  LCanvas: TControlCanvas;
  LCharacterHeight: Integer;
  LCharacterWidth: Integer;
begin
  LCanvas := TControlCanvas.Create;
  try
    LCanvas.Control := FOutputEditor;
    LCanvas.Font.Assign(FOutputEditor.Font);
    LCharacterWidth := Max(1, LCanvas.TextWidth('W'));
    LCharacterHeight := Max(1, LCanvas.TextHeight('W'));
  finally
    LCanvas.Free;
  end;
  AColumns := SmallInt(
    Min(
      High(SmallInt),
      Max(CMinimumColumns, FOutputEditor.ClientWidth div LCharacterWidth)
    )
  );
  ARows := SmallInt(
    Min(
      High(SmallInt),
      Max(CMinimumRows, FOutputEditor.ClientHeight div LCharacterHeight)
    )
  );
end;

procedure TRadIATerminalFrame.HistoryChange(Sender: TObject);
var
  LEntries: TArray<TRadIATerminalHistoryEntry>;
  LIndex: Integer;
begin
  LEntries := FHistory.Entries;
  LIndex := FHistoryCombo.ItemIndex;
  if (LIndex >= Low(LEntries)) and (LIndex <= High(LEntries)) then
    FCommandEdit.Text := LEntries[High(LEntries) - LIndex].Command;
end;

procedure TRadIATerminalFrame.HandleRunningInput;
var
  LLineEnding: string;
begin
  if Trim(FCommandEdit.Text) = '' then
    Exit;
  if FSession.IsPseudoTerminal then
    LLineEnding := #13
  else
    LLineEnding := sLineBreak;
  if FSession.WriteInput(
    FScreen.PreparePaste(FCommandEdit.Text) + LLineEnding
  ) then
  begin
    AppendOutput('> ' + FCommandEdit.Text + sLineBreak);
    FCommandEdit.Clear;
    FStatusLabel.Caption := 'Input sent';
  end
  else
    FStatusLabel.Caption := 'Input channel is not ready';
end;

procedure TRadIATerminalFrame.LoadHistory;
var
  LEntries: TArray<TRadIATerminalHistoryEntry>;
  LIndex: Integer;
begin
  FHistory.Load;
  LEntries := FHistory.Entries;
  FHistoryCombo.Items.BeginUpdate;
  try
    FHistoryCombo.Items.Clear;
    for LIndex := High(LEntries) downto Low(LEntries) do
      FHistoryCombo.Items.Add(LEntries[LIndex].Command);
    if FHistoryCombo.Items.Count > 0 then
      FHistoryCombo.ItemIndex := 0;
  finally
    FHistoryCombo.Items.EndUpdate;
  end;
  RefreshPalette;
end;

procedure TRadIATerminalFrame.PaletteChange(Sender: TObject);
var
  LIndex: Integer;
begin
  LIndex := FPaletteCombo.ItemIndex;
  if (LIndex < Low(FPaletteItems)) or (LIndex > High(FPaletteItems)) then
    Exit;
  FCommandEdit.Text := FPaletteItems[LIndex].Command;
  FCommandEdit.SetFocus;
  FCommandEdit.SelStart := Length(FCommandEdit.Text);
end;

procedure TRadIATerminalFrame.PaletteKeyDown(
  Sender: TObject;
  var Key: Word;
  Shift: TShiftState
);
begin
  if (Key = VK_DOWN) and (FPaletteCombo.Items.Count > 0) then
  begin
    Key := 0;
    FPaletteCombo.SetFocus;
    Exit;
  end;
  if (Key = VK_RETURN) and (Length(FPaletteItems) > 0) then
  begin
    Key := 0;
    FPaletteCombo.ItemIndex := 0;
    PaletteChange(FPaletteCombo);
  end;
end;

procedure TRadIATerminalFrame.PaletteQueryChange(Sender: TObject);
begin
  RefreshPalette;
end;

procedure TRadIATerminalFrame.QueueCompletion(
  const AGuard: IRadIATerminalLifecycleGuard;
  const ACommand: string;
  const AProfileId: string;
  const AResult: TRadIACliProcessResult
);
begin
  TThread.Queue(
    nil,
    TThreadProcedure(
      procedure
      begin
        if AGuard.IsAlive then
          Self.FinishCommand(ACommand, AProfileId, AResult);
      end
    )
  );
end;

procedure TRadIATerminalFrame.QueueOutput(
  const AGuard: IRadIATerminalLifecycleGuard;
  const AChunk: string
);
begin
  TThread.Queue(
    nil,
    TThreadProcedure(
      procedure
      begin
        if AGuard.IsAlive then
          Self.AppendOutput(AChunk);
      end
    )
  );
end;

procedure TRadIATerminalFrame.RefreshPalette;
var
  LItem: TRadIATerminalPaletteItem;
begin
  FPaletteItems := TRadIATerminalCatalog.SearchPalette(
    FPaletteEdit.Text,
    FHistory.Entries
  );
  FPaletteCombo.Items.BeginUpdate;
  try
    FPaletteCombo.Items.Clear;
    for LItem in FPaletteItems do
      FPaletteCombo.Items.Add(
        '[' + LItem.Source + '] ' + LItem.Name
      );
    if FPaletteCombo.Items.Count > 0 then
      FPaletteCombo.ItemIndex := 0;
  finally
    FPaletteCombo.Items.EndUpdate;
  end;
end;

procedure TRadIATerminalFrame.RunClick(Sender: TObject);
var
  LColumns: SmallInt;
  LCommand: string;
  LGuard: IRadIATerminalLifecycleGuard;
  LInvocation: TRadIACliInvocation;
  LProfile: TRadIATerminalProfile;
  LProfiles: TArray<TRadIATerminalProfile>;
  LRows: SmallInt;
  LWorkingDirectory: string;
begin
  if Assigned(FSession) and FSession.IsRunning then
  begin
    HandleRunningInput;
    Exit;
  end;
  LCommand := Trim(FCommandEdit.Text);
  if LCommand = '' then
    Exit;
  LProfiles := TRadIATerminalCatalog.Profiles;
  if (FProfileCombo.ItemIndex < Low(LProfiles)) or
    (FProfileCombo.ItemIndex > High(LProfiles)) then
    Exit;
  LProfile := LProfiles[FProfileCombo.ItemIndex];
  LWorkingDirectory := GetWorkingDirectory;
  if not CanRunCommand(LProfile, LCommand, LWorkingDirectory) then
    Exit;
  LInvocation := LProfile.BuildInvocation(LCommand, LWorkingDirectory);
  AppendOutput(sLineBreak + '> ' + LCommand + sLineBreak);
  FRunButton.Enabled := False;
  FRunButton.Caption := 'Send';
  FStopButton.Enabled := True;
  FStatusLabel.Caption := 'Running in ' + LInvocation.WorkingDirectory;
  LGuard := FLifecycleGuard as IRadIATerminalLifecycleGuard;
  GetTerminalSize(LColumns, LRows);
  FScreen.Resize(LColumns);
  if TRadIAPseudoTerminalRunner.IsSupported then
    FSession := TRadIAPseudoTerminalRunner.Start(
      LInvocation,
      LColumns,
      LRows,
      30 * 60 * 1000,
      procedure(AChunk: string)
      begin
        Self.QueueOutput(LGuard, AChunk);
      end,
      procedure(AResult: TRadIACliProcessResult)
      begin
        Self.QueueCompletion(
          LGuard,
          LCommand,
          LProfile.Id,
          AResult
        );
      end
    )
  else
    FSession := TRadIACliProcessRunner.StartInteractive(
      LInvocation,
      30 * 60 * 1000,
      procedure(AChunk: string)
      begin
        Self.QueueOutput(LGuard, AChunk);
      end,
      procedure(AChunk: string)
      begin
        Self.QueueOutput(LGuard, AChunk);
      end,
      procedure(AResult: TRadIACliProcessResult)
      begin
        Self.QueueCompletion(
          LGuard,
          LCommand,
          LProfile.Id,
          AResult
        );
      end
    );
  if Assigned(FJourneyContext) then
  begin
    FJourneyContext.BeginActivity;
    RefreshJourneyContext;
  end;
  FRunButton.Enabled := True;
  FCommandEdit.Clear;
end;

procedure TRadIATerminalFrame.Resize;
var
  LColumns: SmallInt;
  LRows: SmallInt;
begin
  inherited;
  if not Assigned(FOutputEditor) or not Assigned(FSession) or
    not FSession.IsPseudoTerminal then
    Exit;
  GetTerminalSize(LColumns, LRows);
  FScreen.Resize(LColumns);
  FSession.Resize(LColumns, LRows);
end;

procedure TRadIATerminalFrame.SnippetChange(Sender: TObject);
var
  LIndex: Integer;
  LSnippets: TArray<TRadIATerminalSnippet>;
begin
  LIndex := FSnippetCombo.ItemIndex - 1;
  LSnippets := TRadIATerminalCatalog.Snippets;
  if (LIndex >= Low(LSnippets)) and (LIndex <= High(LSnippets)) then
    FCommandEdit.Text := LSnippets[LIndex].Command;
end;

procedure TRadIATerminalFrame.StopClick(Sender: TObject);
begin
  if Assigned(FJourneyContext) then
  begin
    FJourneyContext.RequestCancellation;
    RefreshJourneyContext;
  end;
  if Assigned(FSession) then
    FSession.Cancel;
end;

procedure TRadIATerminalFrame.OutputMouseDown(
  Sender: TObject;
  Button: TMouseButton;
  Shift: TShiftState;
  X: Integer;
  Y: Integer
);
begin
  SendMouseInput(Button, X, Y, True);
end;

procedure TRadIATerminalFrame.OutputDoubleClick(Sender: TObject);
var
  LHyperlink: TRadIATerminalHyperlink;
  LOpenResult: HINST;
  LPosition: Integer;
begin
  if FScreen.MouseMode <> 0 then
    Exit;
  LPosition := FOutputEditor.SelStart;
  for LHyperlink in FHyperlinks do
  begin
    if (LPosition < LHyperlink.StartIndex) or
      (LPosition >= LHyperlink.StartIndex + LHyperlink.TextLength) then
      Continue;
    if not LHyperlink.Uri.StartsWith('https://', True) and
      not LHyperlink.Uri.StartsWith('http://', True) and
      not LHyperlink.Uri.StartsWith('mailto:', True) then
    begin
      FStatusLabel.Caption := 'Unsupported terminal link scheme';
      Exit;
    end;
    if not CanOpenLink(LHyperlink.Uri) then
      Exit;
    LOpenResult := ShellExecute(
      0,
      'open',
      PChar(LHyperlink.Uri),
      nil,
      nil,
      SW_SHOWNORMAL
    );
    if NativeInt(LOpenResult) <= 32 then
      FStatusLabel.Caption := 'Unable to open terminal link';
    Exit;
  end;
end;

procedure TRadIATerminalFrame.OutputMouseUp(
  Sender: TObject;
  Button: TMouseButton;
  Shift: TShiftState;
  X: Integer;
  Y: Integer
);
begin
  SendMouseInput(Button, X, Y, False);
end;

procedure TRadIATerminalFrame.SendMouseInput(
  const AButton: TMouseButton;
  const AHorizontalPosition: Integer;
  const AVerticalPosition: Integer;
  const APressed: Boolean
);
var
  LButtonCode: Integer;
  LDeviceContext: HDC;
  LInput: string;
  LMetrics: TTextMetric;
  LOldFont: HGDIOBJ;
begin
  if not Assigned(FSession) or not FSession.IsRunning or
    (FScreen.MouseMode = 0) then
    Exit;
  case AButton of
    mbLeft:
      LButtonCode := 0;
    mbMiddle:
      LButtonCode := 1;
    mbRight:
      LButtonCode := 2;
  else
    Exit;
  end;
  LDeviceContext := GetDC(FOutputEditor.Handle);
  if LDeviceContext = 0 then
    Exit;
  LOldFont := SelectObject(LDeviceContext, FOutputEditor.Font.Handle);
  try
    if not GetTextMetrics(LDeviceContext, LMetrics) then
      Exit;
    LInput := FScreen.EncodeMouse(
      LButtonCode,
      (AHorizontalPosition div Max(1, LMetrics.tmAveCharWidth)) + 1,
      (AVerticalPosition div Max(1, LMetrics.tmHeight)) + 1,
      APressed
    );
  finally
    SelectObject(LDeviceContext, LOldFont);
    ReleaseDC(FOutputEditor.Handle, LDeviceContext);
  end;
  if LInput <> '' then
    FSession.WriteInput(LInput);
end;

{$IFDEF TESTS}
function TRadIATerminalFrame.TestJourneyCaption: string;
begin
  RefreshJourneyContext;
  Result := FJourneyLabel.Caption;
end;
{$ENDIF}

{ TRadIATerminalTabsFrame }

procedure TRadIATerminalTabsFrame.AddClick(Sender: TObject);
begin
  AddSession;
end;

procedure TRadIATerminalTabsFrame.CreateWnd;
begin
  inherited;
  if Assigned(FPageControl) and (FPageControl.PageCount = 0) then
    AddSession;
end;

function TRadIATerminalTabsFrame.AddSession: TRadIATerminalFrame;
var
  LTab: TTabSheet;
begin
  Inc(FNextSessionNumber);
  LTab := TTabSheet.Create(FPageControl);
  LTab.PageControl := FPageControl;
  LTab.Caption := 'Terminal ' + FNextSessionNumber.ToString;
  Result := TRadIATerminalFrame.Create(LTab);
  Result.Parent := LTab;
  Result.Align := alClient;
  Result.ApplyCurrentTheme;
  FPageControl.ActivePage := LTab;
  if Showing then
    Result.EnsureVisibleContent;
end;

procedure TRadIATerminalTabsFrame.ApplyCurrentTheme;
var
  LIndex: Integer;
  LSession: TRadIATerminalFrame;
begin
  for LIndex := 0 to FPageControl.PageCount - 1 do
  begin
    LSession := TRadIATerminalFrame(
      FPageControl.Pages[LIndex].Controls[0]
    );
    LSession.ApplyCurrentTheme;
  end;
end;

procedure TRadIATerminalTabsFrame.CloseClick(Sender: TObject);
var
  LPage: TTabSheet;
begin
  if FPageControl.PageCount <= 1 then
    Exit;
  LPage := FPageControl.ActivePage;
  LPage.Free;
  EnsureVisibleContent;
end;

constructor TRadIATerminalTabsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Align := alClient;

  FToolbar := TPanel.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.Align := alTop;
  FToolbar.Height := 36;
  FToolbar.BevelOuter := bvNone;
  FToolbar.ShowCaption := False;

  FAddButton := TButton.Create(Self);
  FAddButton.Parent := FToolbar;
  FAddButton.SetBounds(8, 4, 110, 27);
  FAddButton.Caption := 'New terminal';
  FAddButton.Hint := 'Create an independent terminal session';
  FAddButton.ShowHint := True;
  FAddButton.OnClick := AddClick;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := FToolbar;
  FCloseButton.SetBounds(126, 4, 110, 27);
  FCloseButton.Caption := 'Close terminal';
  FCloseButton.Hint := 'Cancel and close the active terminal session';
  FCloseButton.ShowHint := True;
  FCloseButton.OnClick := CloseClick;

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;
end;

procedure TRadIATerminalTabsFrame.EnsureVisibleContent;
var
  LSession: TRadIATerminalFrame;
begin
  LSession := GetActiveSession;
  if Assigned(LSession) then
  begin
    LSession.EnsureVisibleContent;
    WriteSmokeEvidence(LSession);
  end;
end;

function TRadIATerminalTabsFrame.GetActiveSession:
  TRadIATerminalFrame;
var
  LPage: TTabSheet;
begin
  Result := nil;
  LPage := FPageControl.ActivePage;
  if Assigned(LPage) and (LPage.ControlCount > 0) and
    (LPage.Controls[0] is TRadIATerminalFrame) then
    Result := TRadIATerminalFrame(LPage.Controls[0]);
end;

function TRadIATerminalTabsFrame.HasAccessibleLabels(
  const ASession: TRadIATerminalFrame
): Boolean;
begin
  Result :=
    Assigned(ASession) and
    (ASession.FProfileLabel.Caption <> '') and
    (ASession.FProfileLabel.FocusControl = ASession.FProfileCombo) and
    (ASession.FSnippetLabel.Caption <> '') and
    (ASession.FSnippetLabel.FocusControl = ASession.FSnippetCombo) and
    (ASession.FHistoryLabel.Caption <> '') and
    (ASession.FHistoryLabel.FocusControl = ASession.FHistoryCombo) and
    (ASession.FPaletteLabel.Caption <> '') and
    (ASession.FPaletteLabel.FocusControl = ASession.FPaletteEdit) and
    (ASession.FCommandLabel.Caption <> '') and
    (ASession.FCommandLabel.FocusControl = ASession.FCommandEdit) and
    (ASession.FOutputLabel.Caption <> '') and
    (ASession.FOutputLabel.FocusControl = ASession.FOutputEditor);
end;

function TRadIATerminalTabsFrame.HasCommandInput(
  const ASession: TRadIATerminalFrame
): Boolean;
begin
  Result := ASession.FCommandEdit.Visible and
    ASession.FCommandEdit.Enabled;
end;

function TRadIATerminalTabsFrame.HasOutput(
  const ASession: TRadIATerminalFrame
): Boolean;
begin
  Result := ASession.FOutputEditor.Visible and
    ASession.FOutputEditor.Enabled;
end;

function TRadIATerminalTabsFrame.HasRequiredControls(
  const ASession: TRadIATerminalFrame
): Boolean;
begin
  Result := FAddButton.Visible and
    FCloseButton.Visible and
    ASession.FRunButton.Visible and
    ASession.FStopButton.Visible and
    ASession.FClearButton.Visible;
end;

function TRadIATerminalTabsFrame.IsAvailableTabStop(
  const AControl: TWinControl
): Boolean;
begin
  Result := AControl.Visible and AControl.Enabled and AControl.TabStop;
end;

function TRadIATerminalTabsFrame.CountTabStops(
  const ASession: TRadIATerminalFrame
): Integer;
begin
  Result := 0;
  if IsAvailableTabStop(FAddButton) then
    Inc(Result);
  if IsAvailableTabStop(FCloseButton) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FProfileCombo) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FSnippetCombo) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FHistoryCombo) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FPaletteEdit) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FPaletteCombo) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FCommandEdit) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FRunButton) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FClearButton) then
    Inc(Result);
  if IsAvailableTabStop(ASession.FOutputEditor) then
    Inc(Result);
end;

procedure TRadIATerminalTabsFrame.WriteSmokeEvidence(
  const ASession: TRadIATerminalFrame
);
var
  LEvidencePath: string;
  LJson: TJSONObject;
  LTabStopCount: Integer;
begin
  LEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_TERMINAL')
  );
  if (LEvidencePath = '') or SameText(LEvidencePath, '1') then
    Exit;

  LTabStopCount := CountTabStops(ASession);

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('opened', TJSONBool.Create(Showing));
    LJson.AddPair('width', TJSONNumber.Create(Width));
    LJson.AddPair('height', TJSONNumber.Create(Height));
    LJson.AddPair(
      'requiredControlsVisible',
      TJSONBool.Create(HasRequiredControls(ASession))
    );
    LJson.AddPair(
      'commandInputAvailable',
      TJSONBool.Create(HasCommandInput(ASession))
    );
    LJson.AddPair(
      'outputAvailable',
      TJSONBool.Create(HasOutput(ASession))
    );
    LJson.AddPair(
      'paletteAvailable',
      TJSONBool.Create(
        ASession.FPaletteEdit.Visible and
        ASession.FPaletteEdit.Enabled and
        ASession.FPaletteCombo.Visible and
        ASession.FPaletteCombo.Enabled
      )
    );
    LJson.AddPair(
      'paletteItemCount',
      TJSONNumber.Create(ASession.FPaletteCombo.Items.Count)
    );
    LJson.AddPair(
      'profileCount',
      TJSONNumber.Create(ASession.FProfileCombo.Items.Count)
    );
    LJson.AddPair(
      'tabStopCount',
      TJSONNumber.Create(LTabStopCount)
    );
    LJson.AddPair(
      'accessibleLabelsAvailable',
      TJSONBool.Create(HasAccessibleLabels(ASession))
    );
    TDirectory.CreateDirectory(
      TPath.GetDirectoryName(LEvidencePath)
    );
    TFile.WriteAllText(LEvidencePath, LJson.ToJSON, TEncoding.UTF8);
  finally
    LJson.Free;
  end;
end;

{$IFDEF TESTS}
procedure TRadIATerminalTabsFrame.TestAddSession;
begin
  AddClick(Self);
end;

function TRadIATerminalTabsFrame.TestActiveSession: TObject;
begin
  Result := GetActiveSession;
end;

procedure TRadIATerminalTabsFrame.TestCloseSession;
begin
  CloseClick(Self);
end;

function TRadIATerminalTabsFrame.TestSessionCount: Integer;
begin
  Result := FPageControl.PageCount;
end;

function TRadIATerminalTabsFrame.TestAccessibilityReady: Boolean;
begin
  Result := HasAccessibleLabels(GetActiveSession);
end;
{$ENDIF}

end.
