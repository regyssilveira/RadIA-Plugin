unit RadIA.UI.TerminalFrame;

interface

uses
  System.Classes,
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
    FOutputMemo: TMemo;
    FStatusLabel: TLabel;
    FHistory: TRadIATerminalHistory;
    FSession: IRadIACliProcessSession;
    FLifecycleGuard: IInterface;
    procedure AppendOutput(const AText: string);
    procedure ClearClick(Sender: TObject);
    procedure FinishCommand(
      const ACommand: string;
      const AProfileId: string;
      const AResult: TRadIACliProcessResult
    );
    function GetWorkingDirectory: string;
    procedure HistoryChange(Sender: TObject);
    procedure LoadHistory;
    procedure RunClick(Sender: TObject);
    procedure SnippetChange(Sender: TObject);
    procedure StopClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyCurrentTheme;
    procedure EnsureVisibleContent;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.SyncObjs,
  System.SysUtils,
  Vcl.Controls,
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
  LProfile: TRadIATerminalProfile;
  LSnippet: TRadIATerminalSnippet;
begin
  inherited Create(AOwner);
  Align := alClient;
  FLifecycleGuard := TRadIATerminalLifecycleGuard.Create;

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

  FOutputMemo := TMemo.Create(Self);
  FOutputMemo.Parent := Self;
  FOutputMemo.Align := alClient;
  FOutputMemo.ReadOnly := True;
  FOutputMemo.ScrollBars := ssBoth;
  FOutputMemo.WordWrap := False;
  FOutputMemo.Font.Name := 'Consolas';
  FOutputMemo.Font.Size := 10;

  LAppData := GetEnvironmentVariable('APPDATA');
  if LAppData = '' then
    LAppData := TPath.GetHomePath;
  FHistory := TRadIATerminalHistory.Create(
    TPath.Combine(LAppData, 'RadIA\terminal-history.json')
  );
  LoadHistory;
end;

destructor TRadIATerminalFrame.Destroy;
begin
  (FLifecycleGuard as IRadIATerminalLifecycleGuard).Invalidate;
  if Assigned(FSession) then
  begin
    FSession.Cancel;
    FSession := nil;
  end;
  FHistory.Free;
  inherited Destroy;
end;

procedure TRadIATerminalFrame.AppendOutput(const AText: string);
begin
  if AText = '' then
    Exit;
  FOutputMemo.SelStart := Length(FOutputMemo.Text);
  FOutputMemo.SelText := AText;
end;

procedure TRadIATerminalFrame.ApplyCurrentTheme;
begin
  Invalidate;
  FOutputMemo.Invalidate;
end;

procedure TRadIATerminalFrame.ClearClick(Sender: TObject);
begin
  FOutputMemo.Clear;
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
    Exit;
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
  FStopButton.Enabled := True;
  FStatusLabel.Caption := 'Running in ' + LInvocation.WorkingDirectory;
  LGuard := FLifecycleGuard as IRadIATerminalLifecycleGuard;
  FSession := TRadIACliProcessRunner.Start(
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
