unit RadIA.UI.ExternalMcpFrame;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpRuntime,
  RadIA.Core.ExternalMcpSecurity;

type
  IRadIAExternalMcpFrameGuard = interface
    ['{B5E12D5D-35CF-4E51-A55F-5140795245FC}']
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

  TRadIAExternalMcpFrameGuard = class(
    TInterfacedObject,
    IRadIAExternalMcpFrameGuard
  )
  private
    FAlive: Integer;
  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

  TRadIAExternalMcpFrame = class(TFrame)
  private
    FBtnApply: TButton;
    FBtnGrantRemove: TButton;
    FBtnGrantUpdate: TButton;
    FBtnGrantNew: TButton;
    FBtnImport: TButton;
    FBtnRefresh: TButton;
    FBtnServerRemove: TButton;
    FBtnServerTest: TButton;
    FBtnServerUpdate: TButton;
    FBtnServerNew: TButton;
    FChkConsentEveryTime: TCheckBox;
    FChkEnabled: TCheckBox;
    FChkUnbounded: TCheckBox;
    FCmbGrantRisk: TComboBox;
    FCmbGrantTool: TComboBox;
    FEdtCommand: TEdit;
    FEdtDisplayName: TEdit;
    FEdtPathArguments: TEdit;
    FEdtServerId: TEdit;
    FEdtTimeout: TEdit;
    FEdtWorkingDirectory: TEdit;
    FGrants: TArray<TRadIAExternalMcpToolGrant>;
    FGuard: IRadIAExternalMcpFrameGuard;
    FLblStatus: TLabel;
    FLstGrants: TListBox;
    FLstServers: TListBox;
    FMemoArguments: TMemo;
    FMemoStatus: TMemo;
    FRuntime: IRadIAExternalMcpRuntime;
    FScrollBox: TScrollBox;
    FServers: TArray<TRadIAExternalMcpServerConfig>;
    procedure AddHint(const AControl: TControl; const AText: string);
    procedure ApplyClick(Sender: TObject);
    procedure CompleteApply(const ASuccess: Boolean; const AError: string);
    procedure CompleteRefresh(const ASuccess: Boolean; const AError: string);
    procedure CompleteTest(
      const ASuccess: Boolean;
      const AStatus: TRadIAExternalMcpRuntimeStatus;
      const AError: string
    );
    procedure ConfigureHints;
    procedure CreateControls;
    procedure CreateGrantControls;
    procedure CreateHeaderControls;
    procedure CreateServerControls;
    function CurrentGrant(out AGrant: TRadIAExternalMcpToolGrant): Boolean;
    function CurrentServer(out AServer: TRadIAExternalMcpServerConfig): Boolean;
    procedure GrantClick(Sender: TObject);
    procedure GrantNewClick(Sender: TObject);
    procedure GrantRemoveClick(Sender: TObject);
    procedure GrantUpdateClick(Sender: TObject);
    procedure ImportClick(Sender: TObject);
    procedure LoadFromRuntime;
    procedure MarkPending;
    procedure RefreshClick(Sender: TObject);
    procedure RefreshGrantList;
    procedure RefreshServerList;
    procedure RefreshStatus;
    procedure ServerClick(Sender: TObject);
    procedure ServerNewClick(Sender: TObject);
    procedure ServerRemoveClick(Sender: TObject);
    procedure ServerTestClick(Sender: TObject);
    procedure ServerUpdateClick(Sender: TObject);
    procedure SetBusy(const ABusy: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  System.SyncObjs,
  System.IOUtils,
  System.StrUtils,
  System.SysUtils,
  System.Threading,
  System.UITypes,
  Vcl.Dialogs,
  Vcl.Graphics,
  RadIA.Core.Container,
  RadIA.Core.ExternalMcpImport,
  RadIA.Core.Tools;

const
  CContentWidth = 610;

{ TRadIAExternalMcpFrameGuard }

constructor TRadIAExternalMcpFrameGuard.Create;
begin
  inherited Create;
  FAlive := 1;
end;

function TRadIAExternalMcpFrameGuard.IsAlive: Boolean;
begin
  Result := TInterlocked.CompareExchange(FAlive, 1, 1) = 1;
end;

procedure TRadIAExternalMcpFrameGuard.Invalidate;
begin
  TInterlocked.Exchange(FAlive, 0);
end;

function CreateLabel(
  const AOwner: TComponent;
  const AParent: TWinControl;
  const ACaption: string;
  const ALeft: Integer;
  const ATop: Integer
): TLabel;
begin
  Result := TLabel.Create(AOwner);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.Left := ALeft;
  Result.Top := ATop;
end;

function CreateEdit(
  const AOwner: TComponent;
  const AParent: TWinControl;
  const ALeft: Integer;
  const ATop: Integer;
  const AWidth: Integer
): TEdit;
begin
  Result := TEdit.Create(AOwner);
  Result.Parent := AParent;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Anchors := [akLeft, akTop, akRight];
end;

constructor TRadIAExternalMcpFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGuard := TRadIAExternalMcpFrameGuard.Create;
  Align := alClient;
  TRadIAContainer.TryResolve<IRadIAExternalMcpRuntime>(FRuntime);
  CreateControls;
  LoadFromRuntime;
end;

destructor TRadIAExternalMcpFrame.Destroy;
begin
  FGuard.Invalidate;
  FGuard := nil;
  FRuntime := nil;
  inherited Destroy;
end;

procedure TRadIAExternalMcpFrame.AddHint(
  const AControl: TControl;
  const AText: string
);
begin
  AControl.Hint := AText;
  AControl.ShowHint := True;
end;

procedure TRadIAExternalMcpFrame.CreateControls;
begin
  FScrollBox := TScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align := alClient;
  FScrollBox.BorderStyle := bsNone;
  FScrollBox.HorzScrollBar.Visible := False;
  FScrollBox.VertScrollBar.Tracking := True;

  CreateHeaderControls;
  CreateServerControls;
  CreateGrantControls;
  ConfigureHints;
end;

procedure TRadIAExternalMcpFrame.CreateHeaderControls;
var
  LTitle: TLabel;
begin

  LTitle := CreateLabel(Self, FScrollBox, 'External MCP Servers', 16, 12);
  LTitle.Font.Style := [fsBold];
  LTitle.Font.Size := 11;
  FLblStatus := CreateLabel(Self, FScrollBox, 'Runtime status: loading', 16, 38);
  FLblStatus.AutoSize := False;
  FLblStatus.Width := CContentWidth - 190;
  FLblStatus.Anchors := [akLeft, akTop, akRight];

  FBtnRefresh := TButton.Create(Self);
  FBtnRefresh.Parent := FScrollBox;
  FBtnRefresh.SetBounds(CContentWidth - 160, 10, 72, 27);
  FBtnRefresh.Anchors := [akTop, akRight];
  FBtnRefresh.Caption := 'Refresh';
  FBtnRefresh.OnClick := RefreshClick;
  FBtnImport := TButton.Create(Self);
  FBtnImport.Parent := FScrollBox;
  FBtnImport.SetBounds(CContentWidth - 248, 10, 80, 27);
  FBtnImport.Anchors := [akTop, akRight];
  FBtnImport.Caption := 'Import...';
  FBtnImport.OnClick := ImportClick;
  FBtnApply := TButton.Create(Self);
  FBtnApply.Parent := FScrollBox;
  FBtnApply.SetBounds(CContentWidth - 80, 10, 80, 27);
  FBtnApply.Anchors := [akTop, akRight];
  FBtnApply.Caption := 'Apply';
  FBtnApply.OnClick := ApplyClick;
end;

procedure TRadIAExternalMcpFrame.CreateServerControls;
var
  LServerGroup: TGroupBox;
begin
  LServerGroup := TGroupBox.Create(Self);
  LServerGroup.Parent := FScrollBox;
  LServerGroup.SetBounds(16, 66, CContentWidth, 350);
  LServerGroup.Anchors := [akLeft, akTop, akRight];
  LServerGroup.Caption := 'Servers';

  FLstServers := TListBox.Create(Self);
  FLstServers.Parent := LServerGroup;
  FLstServers.SetBounds(12, 24, 190, 240);
  FLstServers.OnClick := ServerClick;
  CreateLabel(Self, LServerGroup, 'Stable ID:', 218, 24);
  FEdtServerId := CreateEdit(Self, LServerGroup, 218, 42, 180);
  CreateLabel(Self, LServerGroup, 'Display name:', 412, 24);
  FEdtDisplayName := CreateEdit(Self, LServerGroup, 412, 42, 180);
  CreateLabel(Self, LServerGroup, 'Executable or command:', 218, 74);
  FEdtCommand := CreateEdit(Self, LServerGroup, 218, 92, 374);
  CreateLabel(Self, LServerGroup, 'Arguments (one per line):', 218, 124);
  FMemoArguments := TMemo.Create(Self);
  FMemoArguments.Parent := LServerGroup;
  FMemoArguments.SetBounds(218, 142, 200, 76);
  FMemoArguments.ScrollBars := ssVertical;
  FMemoArguments.WordWrap := False;
  CreateLabel(Self, LServerGroup, 'Working directory:', 432, 124);
  FEdtWorkingDirectory := CreateEdit(Self, LServerGroup, 432, 142, 160);
  CreateLabel(Self, LServerGroup, 'Timeout (ms):', 432, 174);
  FEdtTimeout := CreateEdit(Self, LServerGroup, 432, 192, 110);
  FEdtTimeout.NumbersOnly := True;
  FChkEnabled := TCheckBox.Create(Self);
  FChkEnabled.Parent := LServerGroup;
  FChkEnabled.SetBounds(432, 224, 180, 21);
  FChkEnabled.Caption := 'Enable this server';

  FBtnServerNew := TButton.Create(Self);
  FBtnServerNew.Parent := LServerGroup;
  FBtnServerNew.SetBounds(218, 272, 72, 27);
  FBtnServerNew.Caption := 'New';
  FBtnServerNew.OnClick := ServerNewClick;
  FBtnServerUpdate := TButton.Create(Self);
  FBtnServerUpdate.Parent := LServerGroup;
  FBtnServerUpdate.SetBounds(298, 272, 112, 27);
  FBtnServerUpdate.Caption := 'Add / Update';
  FBtnServerUpdate.OnClick := ServerUpdateClick;
  FBtnServerRemove := TButton.Create(Self);
  FBtnServerRemove.Parent := LServerGroup;
  FBtnServerRemove.SetBounds(418, 272, 88, 27);
  FBtnServerRemove.Caption := 'Remove';
  FBtnServerRemove.OnClick := ServerRemoveClick;
  FBtnServerTest := TButton.Create(Self);
  FBtnServerTest.Parent := LServerGroup;
  FBtnServerTest.SetBounds(514, 272, 78, 27);
  FBtnServerTest.Caption := 'Test';
  FBtnServerTest.OnClick := ServerTestClick;
end;

procedure TRadIAExternalMcpFrame.CreateGrantControls;
var
  LGrantGroup: TGroupBox;
begin
  LGrantGroup := TGroupBox.Create(Self);
  LGrantGroup.Parent := FScrollBox;
  LGrantGroup.SetBounds(16, 428, CContentWidth, 300);
  LGrantGroup.Anchors := [akLeft, akTop, akRight];
  LGrantGroup.Caption := 'Tool grants';
  FLstGrants := TListBox.Create(Self);
  FLstGrants.Parent := LGrantGroup;
  FLstGrants.SetBounds(12, 24, 190, 210);
  FLstGrants.OnClick := GrantClick;
  CreateLabel(Self, LGrantGroup, 'Federated tool:', 218, 24);
  FCmbGrantTool := TComboBox.Create(Self);
  FCmbGrantTool.Parent := LGrantGroup;
  FCmbGrantTool.SetBounds(218, 42, 374, 24);
  CreateLabel(Self, LGrantGroup, 'Risk:', 218, 76);
  FCmbGrantRisk := TComboBox.Create(Self);
  FCmbGrantRisk.Parent := LGrantGroup;
  FCmbGrantRisk.SetBounds(218, 94, 180, 24);
  FCmbGrantRisk.Style := csDropDownList;
  FCmbGrantRisk.Items.AddStrings([
    'Read only',
    'Reversible write',
    'Structural write',
    'Execution',
    'Destructive',
    'Sensitive'
  ]);
  FCmbGrantRisk.ItemIndex := 0;
  CreateLabel(Self, LGrantGroup, 'Path arguments (comma-separated):', 412, 76);
  FEdtPathArguments := CreateEdit(Self, LGrantGroup, 412, 94, 180);
  FChkConsentEveryTime := TCheckBox.Create(Self);
  FChkConsentEveryTime.Parent := LGrantGroup;
  FChkConsentEveryTime.SetBounds(218, 132, 180, 21);
  FChkConsentEveryTime.Caption := 'Ask on every call';
  FChkUnbounded := TCheckBox.Create(Self);
  FChkUnbounded.Parent := LGrantGroup;
  FChkUnbounded.SetBounds(412, 132, 220, 21);
  FChkUnbounded.Caption := 'Allow non-path-limited access';
  FBtnGrantNew := TButton.Create(Self);
  FBtnGrantNew.Parent := LGrantGroup;
  FBtnGrantNew.SetBounds(218, 170, 72, 27);
  FBtnGrantNew.Caption := 'New';
  FBtnGrantNew.OnClick := GrantNewClick;
  FBtnGrantUpdate := TButton.Create(Self);
  FBtnGrantUpdate.Parent := LGrantGroup;
  FBtnGrantUpdate.SetBounds(298, 170, 112, 27);
  FBtnGrantUpdate.Caption := 'Add / Update';
  FBtnGrantUpdate.OnClick := GrantUpdateClick;
  FBtnGrantRemove := TButton.Create(Self);
  FBtnGrantRemove.Parent := LGrantGroup;
  FBtnGrantRemove.SetBounds(418, 170, 88, 27);
  FBtnGrantRemove.Caption := 'Remove';
  FBtnGrantRemove.OnClick := GrantRemoveClick;

  FMemoStatus := TMemo.Create(Self);
  FMemoStatus.Parent := FScrollBox;
  FMemoStatus.SetBounds(16, 740, CContentWidth, 100);
  FMemoStatus.Anchors := [akLeft, akTop, akRight];
  FMemoStatus.ReadOnly := True;
  FMemoStatus.ScrollBars := ssVertical;
  FScrollBox.VertScrollBar.Range := 860;
end;

procedure TRadIAExternalMcpFrame.ConfigureHints;
begin
  AddHint(FLstServers, 'Select a server to edit its isolated local process configuration.');
  AddHint(FEdtServerId, 'Stable lowercase ID used in mcp.<server> namespaces.');
  AddHint(FEdtDisplayName, 'Friendly name shown only in the RadIA interface.');
  AddHint(FEdtCommand, 'Full executable path or command used to start the local MCP server.');
  AddHint(FMemoArguments, 'Pass one literal process argument per line. Shell expansion is not used.');
  AddHint(FEdtWorkingDirectory, 'Optional absolute directory used only by this server process.');
  AddHint(FEdtTimeout, 'Connection and request timeout between 1000 and 300000 milliseconds.');
  AddHint(FChkEnabled, 'Disabled servers remain saved but are not started or discovered.');
  AddHint(FBtnServerNew, 'Clear the editor to define another server without replacing a selection.');
  AddHint(FBtnServerUpdate, 'Validate and add a server, or replace the selected pending entry.');
  AddHint(FBtnServerRemove, 'Remove the selected server from the pending snapshot after confirmation.');
  AddHint(FBtnServerTest, 'Connect and discover this server without saving the edited snapshot.');
  AddHint(FLstGrants, 'Select an explicit local grant to inspect or edit its policy.');
  AddHint(FCmbGrantTool, 'Select a discovered federated tool or enter its complete namespaced name.');
  AddHint(FCmbGrantRisk, 'Local risk classification; server annotations cannot lower this value.');
  AddHint(FEdtPathArguments, 'JSON argument names whose path values must stay inside the project.');
  AddHint(FChkConsentEveryTime, 'Require explicit user consent every time this tool is called.');
  AddHint(FChkUnbounded, 'Use only when the tool has no path arguments that RadIA can confine.');
  AddHint(FBtnGrantNew, 'Clear the grant editor before defining another explicit authorization.');
  AddHint(FBtnGrantUpdate, 'Validate and add a grant, or replace the selected pending grant.');
  AddHint(FBtnGrantRemove, 'Remove the selected grant from the pending snapshot.');
  AddHint(FBtnApply, 'Preview the counts, confirm, save with DPAPI, and refresh without restarting.');
  AddHint(FBtnImport, 'Load mcpServers JSON into the pending preview without saving or starting it.');
  AddHint(
    FBtnRefresh,
    'Discard pending edits, reconnect saved servers, and refresh discovery without restarting Delphi.'
  );
  AddHint(FMemoStatus, 'Shows sanitized runtime counts and actionable results for apply, refresh, and test.');
end;

procedure TRadIAExternalMcpFrame.ImportClick(Sender: TObject);
var
  LDialog: TOpenDialog;
  LError: string;
  LImported: TArray<TRadIAExternalMcpServerConfig>;
  LImportedServer: TRadIAExternalMcpServerConfig;
  LIndex: Integer;
  LTargetIndex: Integer;
begin
  LDialog := TOpenDialog.Create(Self);
  try
    LDialog.Filter := 'MCP JSON configuration (*.json)|*.json|All files (*.*)|*.*';
    LDialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
    if not LDialog.Execute then
      Exit;
    if TFile.GetSize(LDialog.FileName) > (4 * 1024 * 1024) then
    begin
      MessageDlg('The MCP configuration exceeds 4 MiB.', mtError, [mbOK], 0);
      Exit;
    end;
    if not TRadIAExternalMcpConfigImporter.ImportJson(
      TFile.ReadAllText(LDialog.FileName, TEncoding.UTF8),
      LImported,
      LError
    ) then
    begin
      MessageDlg(LError, mtError, [mbOK], 0);
      Exit;
    end;
    for LImportedServer in LImported do
    begin
      LTargetIndex := -1;
      for LIndex := 0 to High(FServers) do
        if SameText(FServers[LIndex].Id, LImportedServer.Id) then
        begin
          LTargetIndex := LIndex;
          Break;
        end;
      if LTargetIndex < 0 then
      begin
        LTargetIndex := Length(FServers);
        SetLength(FServers, LTargetIndex + 1);
      end;
      FServers[LTargetIndex] := LImportedServer;
    end;
    RefreshServerList;
    FMemoStatus.Lines.Text := Format(
      '%d server(s) imported into the pending preview only.'#13#10 +
      'Review each server and its arguments, then click Apply to confirm.',
      [Length(LImported)]
    );
  finally
    LDialog.Free;
  end;
end;

procedure TRadIAExternalMcpFrame.LoadFromRuntime;
begin
  if not Assigned(FRuntime) then
  begin
    FLblStatus.Caption := 'Runtime status: unavailable';
    FMemoStatus.Lines.Text := 'Repair the RadIA package to restore the external MCP runtime.';
    SetBusy(True);
    Exit;
  end;
  FServers := FRuntime.GetServers;
  FGrants := FRuntime.GetGrants;
  RefreshServerList;
  RefreshGrantList;
  RefreshStatus;
end;

procedure TRadIAExternalMcpFrame.RefreshServerList;
var
  LIndex: Integer;
begin
  FLstServers.Items.BeginUpdate;
  try
    FLstServers.Clear;
    for LIndex := 0 to High(FServers) do
      FLstServers.Items.Add(FServers[LIndex].DisplayName + ' [' + FServers[LIndex].Id + ']');
  finally
    FLstServers.Items.EndUpdate;
  end;
end;

procedure TRadIAExternalMcpFrame.RefreshGrantList;
var
  LGrant: TRadIAExternalMcpToolGrant;
  LTool: TRadIAExternalMcpTool;
begin
  FLstGrants.Items.BeginUpdate;
  FCmbGrantTool.Items.BeginUpdate;
  try
    FLstGrants.Clear;
    FCmbGrantTool.Items.Clear;
    for LGrant in FGrants do
    begin
      FLstGrants.Items.Add(LGrant.NamespacedName);
      FCmbGrantTool.Items.Add(LGrant.NamespacedName);
    end;
    if Assigned(FRuntime) then
      for LTool in FRuntime.GetDiscoveredTools do
        if FCmbGrantTool.Items.IndexOf(LTool.NamespacedName) < 0 then
          FCmbGrantTool.Items.Add(LTool.NamespacedName);
  finally
    FCmbGrantTool.Items.EndUpdate;
    FLstGrants.Items.EndUpdate;
  end;
end;

procedure TRadIAExternalMcpFrame.RefreshStatus;
var
  LStatus: TRadIAExternalMcpRuntimeStatus;
begin
  if not Assigned(FRuntime) then
    Exit;
  LStatus := FRuntime.GetStatus;
  FLblStatus.Caption := Format(
    'Runtime status: %d/%d enabled servers connected; %d error(s)',
    [LStatus.ConnectedServers, LStatus.EnabledServers, LStatus.ErrorCount]
  );
  FMemoStatus.Lines.Text := Format(
    'Configured servers: %d'#13#10 +
    'Discovered tools: %d; granted tools: %d'#13#10 +
    'Resources: %d; prompts: %d',
    [
      LStatus.ConfiguredServers,
      LStatus.ToolCount,
      LStatus.GrantedTools,
      LStatus.ResourceCount,
      LStatus.PromptCount
    ]
  );
end;

procedure TRadIAExternalMcpFrame.MarkPending;
begin
  FLblStatus.Caption := 'Pending changes: review and click Apply';
  FMemoStatus.Lines.Text := Format(
    'Pending preview: %d server(s), %d explicit grant(s).'#13#10 +
    'No file or process has been changed yet.',
    [Length(FServers), Length(FGrants)]
  );
end;

function TRadIAExternalMcpFrame.CurrentServer(
  out AServer: TRadIAExternalMcpServerConfig
): Boolean;
var
  LError: string;
begin
  AServer := TRadIAExternalMcpServerConfig.Create(
    Trim(FEdtServerId.Text),
    Trim(FEdtDisplayName.Text),
    Trim(FEdtCommand.Text),
    FMemoArguments.Lines.ToStringArray,
    Trim(FEdtWorkingDirectory.Text),
    FChkEnabled.Checked,
    StrToIntDef(Trim(FEdtTimeout.Text), 30000)
  );
  Result := AServer.Validate(LError);
  if not Result then
    MessageDlg(LError, mtError, [mbOK], 0);
end;

procedure TRadIAExternalMcpFrame.ServerClick(Sender: TObject);
var
  LServer: TRadIAExternalMcpServerConfig;
begin
  if (FLstServers.ItemIndex < 0) or
    (FLstServers.ItemIndex > High(FServers)) then
    Exit;
  LServer := FServers[FLstServers.ItemIndex];
  FEdtServerId.Text := LServer.Id;
  FEdtDisplayName.Text := LServer.DisplayName;
  FEdtCommand.Text := LServer.Command;
  FMemoArguments.Clear;
  FMemoArguments.Lines.AddStrings(LServer.Arguments);
  FEdtWorkingDirectory.Text := LServer.WorkingDirectory;
  FEdtTimeout.Text := IntToStr(LServer.TimeoutMs);
  FChkEnabled.Checked := LServer.Enabled;
end;

procedure TRadIAExternalMcpFrame.ServerNewClick(Sender: TObject);
begin
  FLstServers.ItemIndex := -1;
  FEdtServerId.Clear;
  FEdtDisplayName.Clear;
  FEdtCommand.Clear;
  FMemoArguments.Clear;
  FEdtWorkingDirectory.Clear;
  FEdtTimeout.Text := '30000';
  FChkEnabled.Checked := True;
  FEdtServerId.SetFocus;
end;

procedure TRadIAExternalMcpFrame.ServerUpdateClick(Sender: TObject);
var
  LIndex: Integer;
  LServer: TRadIAExternalMcpServerConfig;
begin
  if not CurrentServer(LServer) then
    Exit;
  LIndex := FLstServers.ItemIndex;
  if (LIndex < 0) or (LIndex > High(FServers)) then
  begin
    LIndex := Length(FServers);
    SetLength(FServers, LIndex + 1);
  end;
  FServers[LIndex] := LServer;
  RefreshServerList;
  FLstServers.ItemIndex := LIndex;
  MarkPending;
end;

procedure TRadIAExternalMcpFrame.ServerRemoveClick(Sender: TObject);
var
  LGrantIndex: Integer;
  LIndex: Integer;
  LServerId: string;
begin
  LIndex := FLstServers.ItemIndex;
  if (LIndex < 0) or (LIndex > High(FServers)) then
    Exit;
  if MessageDlg(
    'Remove this server from the pending snapshot?',
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  LServerId := FServers[LIndex].Id;
  Delete(FServers, LIndex, 1);
  LGrantIndex := High(FGrants);
  while LGrantIndex >= 0 do
  begin
    if FGrants[LGrantIndex].NamespacedName.StartsWith(
      'mcp.' + LServerId + '.',
      True
    ) then
      Delete(FGrants, LGrantIndex, 1);
    Dec(LGrantIndex);
  end;
  RefreshServerList;
  RefreshGrantList;
  MarkPending;
end;

procedure TRadIAExternalMcpFrame.ServerTestClick(Sender: TObject);
var
  LGuard: IRadIAExternalMcpFrameGuard;
  LRuntime: IRadIAExternalMcpRuntime;
  LServer: TRadIAExternalMcpServerConfig;
begin
  if not Assigned(FRuntime) or not CurrentServer(LServer) then
    Exit;
  SetBusy(True);
  FMemoStatus.Lines.Text := 'Connecting and discovering the selected server...';
  LRuntime := FRuntime;
  LGuard := FGuard;
  TTask.Run(
    procedure
    var
      LError: string;
      LStatus: TRadIAExternalMcpRuntimeStatus;
      LSuccess: Boolean;
    begin
      LSuccess := LRuntime.TestServer(LServer, LStatus, LError);
      TThread.Queue(nil,
        procedure
        begin
          if LGuard.IsAlive then
            CompleteTest(LSuccess, LStatus, LError);
        end
      );
    end
  );
end;

procedure TRadIAExternalMcpFrame.CompleteTest(
  const ASuccess: Boolean;
  const AStatus: TRadIAExternalMcpRuntimeStatus;
  const AError: string
);
begin
  SetBusy(False);
  if ASuccess then
    FMemoStatus.Lines.Text := Format(
      'Test passed.'#13#10 +
      'Tools: %d; resources: %d; prompts: %d.',
      [AStatus.ToolCount, AStatus.ResourceCount, AStatus.PromptCount]
    )
  else
    FMemoStatus.Lines.Text := 'Test failed: ' + AError;
end;

function TRadIAExternalMcpFrame.CurrentGrant(
  out AGrant: TRadIAExternalMcpToolGrant
): Boolean;
var
  LError: string;
  LPaths: TArray<string>;
  LValue: string;
  LValues: TArray<string>;
begin
  LValues := SplitString(FEdtPathArguments.Text, ',');
  LPaths := nil;
  for LValue in LValues do
    if Trim(LValue) <> '' then
    begin
      SetLength(LPaths, Length(LPaths) + 1);
      LPaths[High(LPaths)] := Trim(LValue);
    end;
  AGrant := TRadIAExternalMcpToolGrant.Create(
    Trim(FCmbGrantTool.Text),
    TRadIAToolRisk(FCmbGrantRisk.ItemIndex),
    FChkConsentEveryTime.Checked,
    LPaths,
    FChkUnbounded.Checked
  );
  Result := AGrant.Validate(LError);
  if not Result then
    MessageDlg(LError, mtError, [mbOK], 0);
end;

procedure TRadIAExternalMcpFrame.GrantClick(Sender: TObject);
var
  LGrant: TRadIAExternalMcpToolGrant;
begin
  if (FLstGrants.ItemIndex < 0) or
    (FLstGrants.ItemIndex > High(FGrants)) then
    Exit;
  LGrant := FGrants[FLstGrants.ItemIndex];
  FCmbGrantTool.Text := LGrant.NamespacedName;
  FCmbGrantRisk.ItemIndex := Ord(LGrant.Risk);
  FChkConsentEveryTime.Checked := LGrant.ConsentEveryTime;
  FEdtPathArguments.Text := string.Join(', ', LGrant.PathArguments);
  FChkUnbounded.Checked := LGrant.AllowUnboundedAccess;
end;

procedure TRadIAExternalMcpFrame.GrantNewClick(Sender: TObject);
begin
  FLstGrants.ItemIndex := -1;
  FCmbGrantTool.ItemIndex := -1;
  FCmbGrantTool.Text := '';
  FCmbGrantRisk.ItemIndex := 0;
  FEdtPathArguments.Clear;
  FChkConsentEveryTime.Checked := False;
  FChkUnbounded.Checked := False;
  FCmbGrantTool.SetFocus;
end;

procedure TRadIAExternalMcpFrame.GrantUpdateClick(Sender: TObject);
var
  LGrant: TRadIAExternalMcpToolGrant;
  LIndex: Integer;
begin
  if not CurrentGrant(LGrant) then
    Exit;
  LIndex := FLstGrants.ItemIndex;
  if (LIndex < 0) or (LIndex > High(FGrants)) then
  begin
    LIndex := Length(FGrants);
    SetLength(FGrants, LIndex + 1);
  end;
  FGrants[LIndex] := LGrant;
  RefreshGrantList;
  FLstGrants.ItemIndex := LIndex;
  MarkPending;
end;

procedure TRadIAExternalMcpFrame.GrantRemoveClick(Sender: TObject);
var
  LIndex: Integer;
begin
  LIndex := FLstGrants.ItemIndex;
  if (LIndex < 0) or (LIndex > High(FGrants)) then
    Exit;
  Delete(FGrants, LIndex, 1);
  RefreshGrantList;
  MarkPending;
end;

procedure TRadIAExternalMcpFrame.ApplyClick(Sender: TObject);
var
  LGrants: TArray<TRadIAExternalMcpToolGrant>;
  LGuard: IRadIAExternalMcpFrameGuard;
  LRuntime: IRadIAExternalMcpRuntime;
  LServers: TArray<TRadIAExternalMcpServerConfig>;
begin
  if not Assigned(FRuntime) then
    Exit;
  if MessageDlg(
    Format(
      'Save and refresh %d server(s) and %d explicit tool grant(s)?',
      [Length(FServers), Length(FGrants)]
    ),
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  LServers := Copy(FServers);
  LGrants := Copy(FGrants);
  LRuntime := FRuntime;
  LGuard := FGuard;
  SetBusy(True);
  FMemoStatus.Lines.Text := 'Protecting settings and refreshing the external MCP runtime...';
  TTask.Run(
    procedure
    var
      LError: string;
      LSuccess: Boolean;
    begin
      LSuccess := LRuntime.SaveAndRefresh(LServers, LGrants, LError);
      TThread.Queue(nil,
        procedure
        begin
          if LGuard.IsAlive then
            CompleteApply(LSuccess, LError);
        end
      );
    end
  );
end;

procedure TRadIAExternalMcpFrame.CompleteApply(
  const ASuccess: Boolean;
  const AError: string
);
begin
  SetBusy(False);
  if ASuccess then
  begin
    LoadFromRuntime;
    FMemoStatus.Lines.Insert(0, 'Settings saved and runtime refreshed without restarting Delphi.');
  end
  else
    FMemoStatus.Lines.Text := 'Apply failed; the previous runtime remains active: ' + AError;
end;

procedure TRadIAExternalMcpFrame.RefreshClick(Sender: TObject);
var
  LGuard: IRadIAExternalMcpFrameGuard;
  LRuntime: IRadIAExternalMcpRuntime;
begin
  if not Assigned(FRuntime) then
    Exit;
  LRuntime := FRuntime;
  LGuard := FGuard;
  SetBusy(True);
  FMemoStatus.Lines.Text := 'Refreshing configured external MCP servers...';
  TTask.Run(
    procedure
    var
      LError: string;
      LSuccess: Boolean;
    begin
      LSuccess := LRuntime.Refresh(LError);
      TThread.Queue(nil,
        procedure
        begin
          if LGuard.IsAlive then
            CompleteRefresh(LSuccess, LError);
        end
      );
    end
  );
end;

procedure TRadIAExternalMcpFrame.CompleteRefresh(
  const ASuccess: Boolean;
  const AError: string
);
begin
  SetBusy(False);
  if ASuccess then
  begin
    LoadFromRuntime;
    FMemoStatus.Lines.Insert(0, 'Runtime refreshed without restarting Delphi.');
  end
  else
  begin
    RefreshStatus;
    FMemoStatus.Lines.Insert(0, 'Refresh failed; the previous runtime remains active: ' + AError);
  end;
end;

procedure TRadIAExternalMcpFrame.SetBusy(const ABusy: Boolean);
begin
  FBtnApply.Enabled := not ABusy and Assigned(FRuntime);
  FBtnImport.Enabled := not ABusy and Assigned(FRuntime);
  FBtnRefresh.Enabled := not ABusy and Assigned(FRuntime);
  FBtnServerTest.Enabled := not ABusy and Assigned(FRuntime);
  FBtnServerNew.Enabled := not ABusy;
  FBtnServerUpdate.Enabled := not ABusy;
  FBtnServerRemove.Enabled := not ABusy;
  FBtnGrantUpdate.Enabled := not ABusy;
  FBtnGrantNew.Enabled := not ABusy;
  FBtnGrantRemove.Enabled := not ABusy;
end;

end.
