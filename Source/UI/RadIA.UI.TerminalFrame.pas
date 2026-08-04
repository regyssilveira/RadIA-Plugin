unit RadIA.UI.TerminalFrame;

interface

uses
  System.Classes,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.CliProcess,
  RadIA.Core.Terminal;

type
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
    FAnsiParser: TRadIATerminalAnsiParser;
    FHistory: TRadIATerminalHistory;
    FSession: IRadIACliProcessSession;
    FLifecycleGuard: IInterface;
    procedure AppendOutput(const AText: string);
    procedure AppendSegment(
      const ASegment: TRadIATerminalTextSegment
    );
    procedure BuildControls;
    procedure ClearClick(Sender: TObject);
    procedure FinishCommand(
      const ACommand: string;
      const AProfileId: string;
      const AResult: TRadIACliProcessResult
    );
    function GetWorkingDirectory: string;
    procedure HandleRunningInput;
    procedure HistoryChange(Sender: TObject);
    procedure LoadHistory;
    procedure RunClick(Sender: TObject);
    procedure SnippetChange(Sender: TObject);
    procedure StopClick(Sender: TObject);
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyCurrentTheme;
    procedure EnsureVisibleContent;
  end;

implementation

{$R *.dfm}

uses
  System.DateUtils,
  System.IOUtils,
  System.SyncObjs,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Graphics,
  RadIA.Core.AgentExecutors,
  RadIA.OTA.Helper;

type
  IRadIATerminalLifecycleGuard = interface
    ['{81E20293-FA87-486D-BD47-75E0589DDDBC}']
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

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
  FAnsiParser := TRadIATerminalAnsiParser.Create;

  LAppData := GetEnvironmentVariable('APPDATA');
  if LAppData = '' then
    LAppData := TPath.GetHomePath;
  FHistory := TRadIATerminalHistory.Create(
    TPath.Combine(LAppData, 'RadIA\terminal-history.json')
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
  FAnsiParser.Free;
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
  for LSegment in FAnsiParser.Feed(AText) do
    AppendSegment(LSegment);
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
  FOutputEditor.Invalidate;
end;

procedure TRadIATerminalFrame.ClearClick(Sender: TObject);
begin
  FOutputEditor.Clear;
  FAnsiParser.Reset;
end;

procedure TRadIATerminalFrame.EnsureVisibleContent;
begin
  FCommandEdit.SetFocus;
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
begin
  if Trim(FCommandEdit.Text) = '' then
    Exit;
  if FSession.WriteInput(FCommandEdit.Text + sLineBreak) then
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

procedure TRadIATerminalFrame.RunClick(Sender: TObject);
var
  LCommand: string;
  LGuard: IRadIATerminalLifecycleGuard;
  LInvocation: TRadIACliInvocation;
  LProfile: TRadIATerminalProfile;
  LProfiles: TArray<TRadIATerminalProfile>;
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
  FSession := TRadIACliProcessRunner.StartInteractive(
    LInvocation,
    30 * 60 * 1000,
    procedure(AChunk: string)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              Self.AppendOutput(AChunk);
          end
        )
      );
    end,
    procedure(AChunk: string)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              Self.AppendOutput(AChunk);
          end
        )
      );
    end,
    procedure(AResult: TRadIACliProcessResult)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              Self.FinishCommand(LCommand, LProfile.Id, AResult);
          end
        )
      );
    end
  );
  FRunButton.Enabled := True;
  FCommandEdit.Clear;
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

end.
