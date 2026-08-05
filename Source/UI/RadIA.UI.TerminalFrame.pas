unit RadIA.UI.TerminalFrame;

interface

uses
  System.Classes,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.CliProcess,
  RadIA.Core.Terminal,
  RadIA.Core.TerminalScreen;

type
  IRadIATerminalLifecycleGuard = interface
    ['{81E20293-FA87-486D-BD47-75E0589DDDBC}']
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

  TRadIATerminalFrame = class(TFrame)
  private
    FTopPanel: TPanel;
    FProfileCombo: TComboBox;
    FSnippetCombo: TComboBox;
    FHistoryCombo: TComboBox;
    FCommandEdit: TEdit;
    FRunButton: TButton;
    FStopButton: TButton;
    FClearButton: TButton;
    FOutputEditor: TRichEdit;
    FStatusLabel: TLabel;
    FScreen: TRadIATerminalScreen;
    FHistory: TRadIATerminalHistory;
    FHistorySearchIndex: Integer;
    FHistorySearchQuery: string;
    FUpdatingHistorySearch: Boolean;
    FFocusQueued: Boolean;
    FSession: IRadIACliProcessSession;
    FLifecycleGuard: IInterface;
    procedure ApplyDeferredFocus(
      const AGuard: IRadIATerminalLifecycleGuard
    );
    procedure AppendOutput(const AText: string);
    procedure AppendSegment(
      const ASegment: TRadIATerminalTextSegment
    );
    procedure BuildControls;
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
    {$ENDIF}
  end;

implementation

{$R *.dfm}
{$R RadIA.UI.TerminalTabsFrame.dfm}

uses
  System.DateUtils,
  System.IOUtils,
  System.Math,
  System.SyncObjs,
  System.SysUtils,
  Winapi.Messages,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Graphics,
  RadIA.Core.AgentExecutors,
  RadIA.Core.PseudoTerminal,
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
  FScreen := TRadIATerminalScreen.Create;

  LAppData := GetEnvironmentVariable('APPDATA');
  if LAppData = '' then
    LAppData := TPath.GetHomePath;
  FHistory := TRadIATerminalHistory.Create(
    TPath.Combine(LAppData, 'RadIA\terminal-history.json')
  );
  FHistorySearchIndex := -1;
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
  FScreen.Free;
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
  FTopPanel.Height := 112;
  FTopPanel.BevelOuter := bvNone;
  FTopPanel.ShowCaption := False;

  FProfileCombo := TComboBox.Create(Self);
  FProfileCombo.Parent := FTopPanel;
  FProfileCombo.SetBounds(8, 8, 180, 25);
  FProfileCombo.Style := csDropDownList;
  for LProfile in TRadIATerminalCatalog.Profiles do
    FProfileCombo.Items.Add(LProfile.DisplayName);
  FProfileCombo.ItemIndex := 0;

  FSnippetCombo := TComboBox.Create(Self);
  FSnippetCombo.Parent := FTopPanel;
  FSnippetCombo.SetBounds(196, 8, 180, 25);
  FSnippetCombo.Style := csDropDownList;
  FSnippetCombo.Items.Add('Snippets...');
  for LSnippet in TRadIATerminalCatalog.Snippets do
    FSnippetCombo.Items.Add(LSnippet.Name);
  FSnippetCombo.ItemIndex := 0;
  FSnippetCombo.OnChange := SnippetChange;

  FHistoryCombo := TComboBox.Create(Self);
  FHistoryCombo.Parent := FTopPanel;
  FHistoryCombo.SetBounds(384, 8, 220, 25);
  FHistoryCombo.Style := csDropDownList;
  FHistoryCombo.OnChange := HistoryChange;

  FCommandEdit := TEdit.Create(Self);
  FCommandEdit.Parent := FTopPanel;
  FCommandEdit.SetBounds(8, 42, 596, 25);
  FCommandEdit.OnChange := CommandChange;
  FCommandEdit.OnKeyDown := CommandKeyDown;

  FRunButton := TButton.Create(Self);
  FRunButton.Parent := FTopPanel;
  FRunButton.SetBounds(612, 40, 72, 27);
  FRunButton.Caption := 'Run';
  FRunButton.Default := True;
  FRunButton.OnClick := RunClick;

  FStopButton := TButton.Create(Self);
  FStopButton.Parent := FTopPanel;
  FStopButton.SetBounds(692, 40, 72, 27);
  FStopButton.Caption := 'Stop';
  FStopButton.Enabled := False;
  FStopButton.OnClick := StopClick;

  FClearButton := TButton.Create(Self);
  FClearButton.Parent := FTopPanel;
  FClearButton.SetBounds(772, 40, 72, 27);
  FClearButton.Caption := 'Clear';
  FClearButton.OnClick := ClearClick;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FTopPanel;
  FStatusLabel.SetBounds(8, 78, 820, 20);
  FStatusLabel.Caption := 'Ready';

  FOutputEditor := TRichEdit.Create(Self);
  FOutputEditor.Parent := Self;
  FOutputEditor.Align := alClient;
  FOutputEditor.ReadOnly := True;
  FOutputEditor.ScrollBars := ssBoth;
  FOutputEditor.WordWrap := False;
  FOutputEditor.Font.Name := 'Consolas';
  FOutputEditor.Font.Size := 10;
  LoadHistory;
end;

procedure TRadIATerminalFrame.AppendOutput(const AText: string);
var
  LSegment: TRadIATerminalTextSegment;
begin
  if AText = '' then
    Exit;
  FScreen.Feed(AText);
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
begin
  FOutputEditor.SelStart := Length(FOutputEditor.Text);
  FOutputEditor.SelLength := 0;
  if ASegment.Style.Foreground = tcDefault then
    FOutputEditor.SelAttributes.Color := FOutputEditor.Font.Color
  else
    FOutputEditor.SelAttributes.Color :=
      TERMINAL_COLORS[ASegment.Style.Foreground];
  FOutputEditor.SelAttributes.Style := [];
  if ASegment.Style.Bold then
    FOutputEditor.SelAttributes.Style := [fsBold];
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

procedure TRadIATerminalFrame.FinishCommand(
  const ACommand: string;
  const AProfileId: string;
  const AResult: TRadIACliProcessResult
);
begin
  FSession := nil;
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
  if FSession.WriteInput(FCommandEdit.Text + LLineEnding) then
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

procedure TRadIATerminalFrame.RunClick(Sender: TObject);
var
  LColumns: SmallInt;
  LCommand: string;
  LGuard: IRadIATerminalLifecycleGuard;
  LInvocation: TRadIACliInvocation;
  LProfile: TRadIATerminalProfile;
  LProfiles: TArray<TRadIATerminalProfile>;
  LRows: SmallInt;
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
  LInvocation := LProfile.BuildInvocation(LCommand, GetWorkingDirectory);
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
  if Assigned(FSession) then
    FSession.Cancel;
end;

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
    LSession.EnsureVisibleContent;
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
{$ENDIF}

end.
