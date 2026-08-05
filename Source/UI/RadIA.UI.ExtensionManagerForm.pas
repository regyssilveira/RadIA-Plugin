unit RadIA.UI.ExtensionManagerForm;

interface

uses
  System.Classes,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.DeclarativeExtensions;

type
  TRadIAExtensionManagerForm = class(TForm)
  private
    FCloseButton: TButton;
    FEnableButton: TButton;
    FFooterPanel: TPanel;
    FInstallButton: TButton;
    FListView: TListView;
    FManager: TRadIADeclarativeExtensionManager;
    FOpenDialog: TOpenDialog;
    FReloadButton: TButton;
    FRemoveButton: TButton;
    FReservedCommands: TArray<string>;
    FStatusLabel: TLabel;
    procedure ApplyCurrentTheme;
    function BuildReservedCommands: TArray<string>;
    procedure CloseClick(Sender: TObject);
    procedure EnableClick(Sender: TObject);
    function GetSelectedDiagnostic(
      out ADiagnostic: TRadIADeclarativeExtensionDiagnostic
    ): Boolean;
    procedure InstallClick(Sender: TObject);
    procedure ListSelectItem(
      Sender: TObject;
      Item: TListItem;
      Selected: Boolean
    );
    procedure NotifyChat;
    procedure RefreshList;
    procedure ReloadClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure SetStatus(const AMessage: string);
    procedure UpdateActionStates;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure ShowRadIAExtensionManager;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  Vcl.Controls,
  RadIA.Core.Mediator,
  RadIA.Core.PromptTemplates;

procedure ShowRadIAExtensionManager;
var
  LForm: TRadIAExtensionManagerForm;
begin
  LForm := TRadIAExtensionManagerForm.Create(Application);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

constructor TRadIAExtensionManagerForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Rad IA - Declarative Extensions';
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 920;
  ClientHeight := 500;
  Constraints.MinWidth := 720;
  Constraints.MinHeight := 380;

  FManager := TRadIADeclarativeExtensionManager.Create(
    TPath.Combine(TPath.Combine(TPath.GetHomePath, 'RadIA'), 'extensions')
  );
  FReservedCommands := BuildReservedCommands;

  FListView := TListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ViewStyle := vsReport;
  FListView.ReadOnly := True;
  FListView.RowSelect := True;
  FListView.HideSelection := False;
  FListView.OnSelectItem := ListSelectItem;
  FListView.Columns.Add.Caption := 'Extension';
  FListView.Columns.Add.Caption := 'Status';
  FListView.Columns.Add.Caption := 'Manifest';
  FListView.Columns.Add.Caption := 'Diagnostic';
  FListView.Columns[0].Width := 150;
  FListView.Columns[1].Width := 90;
  FListView.Columns[2].Width := 230;
  FListView.Columns[3].Width := 410;

  FFooterPanel := TPanel.Create(Self);
  FFooterPanel.Parent := Self;
  FFooterPanel.Align := alBottom;
  FFooterPanel.Height := 76;
  FFooterPanel.BevelOuter := bvNone;
  FFooterPanel.ShowCaption := False;

  FInstallButton := TButton.Create(Self);
  FInstallButton.Parent := FFooterPanel;
  FInstallButton.SetBounds(8, 8, 120, 27);
  FInstallButton.Caption := 'Install / Update...';
  FInstallButton.OnClick := InstallClick;

  FEnableButton := TButton.Create(Self);
  FEnableButton.Parent := FFooterPanel;
  FEnableButton.SetBounds(136, 8, 110, 27);
  FEnableButton.Caption := 'Enable';
  FEnableButton.OnClick := EnableClick;

  FReloadButton := TButton.Create(Self);
  FReloadButton.Parent := FFooterPanel;
  FReloadButton.SetBounds(254, 8, 130, 27);
  FReloadButton.Caption := 'Reload / Diagnose';
  FReloadButton.OnClick := ReloadClick;

  FRemoveButton := TButton.Create(Self);
  FRemoveButton.Parent := FFooterPanel;
  FRemoveButton.SetBounds(392, 8, 90, 27);
  FRemoveButton.Caption := 'Remove';
  FRemoveButton.OnClick := RemoveClick;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := FFooterPanel;
  FCloseButton.SetBounds(822, 8, 90, 27);
  FCloseButton.Anchors := [akTop, akRight];
  FCloseButton.Caption := 'Close';
  FCloseButton.ModalResult := mrClose;
  FCloseButton.OnClick := CloseClick;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FFooterPanel;
  FStatusLabel.SetBounds(8, 44, 904, 22);
  FStatusLabel.Anchors := [akLeft, akTop, akRight];
  FStatusLabel.AutoSize := False;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := 'Rad IA extension (*.radia.json)|*.radia.json|' +
    'JSON manifest (*.json)|*.json';
  FOpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
  FOpenDialog.Title := 'Install or update a declarative extension';

  RefreshList;
end;

destructor TRadIAExtensionManagerForm.Destroy;
begin
  FManager.Free;
  inherited Destroy;
end;

procedure TRadIAExtensionManagerForm.ApplyCurrentTheme;
var
  LThemingServices: IOTAIDEThemingServices;
begin
  if Supports(
    BorlandIDEServices,
    IOTAIDEThemingServices,
    LThemingServices
  ) and LThemingServices.IDEThemingEnabled then
    LThemingServices.ApplyTheme(Self);
end;

function TRadIAExtensionManagerForm.BuildReservedCommands:
  TArray<string>;
const
  CNativeCommands: array[0..12] of string = (
    '/agent',
    '/agent run',
    '/agent plan',
    '/agent replay',
    '/agent pause',
    '/agent resume',
    '/agent cancel',
    '/agent history',
    '/terminal',
    '/tools',
    '/tool',
    '/revoke-tools',
    '/extensions reload'
  );
var
  LCommand: string;
  LCommands: TList<string>;
  LDataDirectory: string;
  LTemplate: TPromptTemplate;
  LTemplateManager: TPromptTemplateManager;
begin
  LCommands := TList<string>.Create;
  try
    for LCommand in CNativeCommands do
      LCommands.Add(LCommand);
    LDataDirectory := TPath.Combine(TPath.GetHomePath, 'RadIA');
    LTemplateManager := TPromptTemplateManager.Create(LDataDirectory);
    try
      LTemplateManager.Load;
      for LTemplate in LTemplateManager.GetTemplates do
        if not LTemplate.SlashCommand.IsEmpty then
          LCommands.Add(LTemplate.SlashCommand);
    finally
      LTemplateManager.Free;
    end;
    Result := LCommands.ToArray;
  finally
    LCommands.Free;
  end;
end;

procedure TRadIAExtensionManagerForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TRadIAExtensionManagerForm.CreateWnd;
begin
  inherited CreateWnd;
  ApplyCurrentTheme;
end;

procedure TRadIAExtensionManagerForm.EnableClick(Sender: TObject);
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LEnable: Boolean;
  LMessage: string;
begin
  if not GetSelectedDiagnostic(LDiagnostic) then
    Exit;
  LEnable := SameText(LDiagnostic.Status, 'disabled');
  FManager.SetEnabled(
    LDiagnostic.ExtensionId,
    LEnable,
    FReservedCommands,
    LMessage
  );
  SetStatus(LMessage);
  RefreshList;
  NotifyChat;
end;

function TRadIAExtensionManagerForm.GetSelectedDiagnostic(
  out ADiagnostic: TRadIADeclarativeExtensionDiagnostic
): Boolean;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
begin
  ADiagnostic := Default(TRadIADeclarativeExtensionDiagnostic);
  Result := Assigned(FListView.Selected);
  if not Result then
    Exit;
  for LDiagnostic in FManager.GetDiagnostics do
    if SameFileName(
      LDiagnostic.FileName,
      FListView.Selected.SubItems[1]
    ) then
    begin
      ADiagnostic := LDiagnostic;
      Exit(True);
    end;
  Result := False;
end;

procedure TRadIAExtensionManagerForm.InstallClick(Sender: TObject);
var
  LExtensionId: string;
  LMessage: string;
begin
  if not FOpenDialog.Execute then
    Exit;
  FManager.InstallOrUpdate(
    FOpenDialog.FileName,
    FReservedCommands,
    LExtensionId,
    LMessage
  );
  SetStatus(LMessage);
  RefreshList;
  NotifyChat;
end;

procedure TRadIAExtensionManagerForm.ListSelectItem(
  Sender: TObject;
  Item: TListItem;
  Selected: Boolean
);
begin
  UpdateActionStates;
end;

procedure TRadIAExtensionManagerForm.NotifyChat;
begin
  TRadIAMediator.Instance.RequestPrompt('/extensions reload', False);
end;

procedure TRadIAExtensionManagerForm.RefreshList;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LItem: TListItem;
begin
  FReservedCommands := BuildReservedCommands;
  FManager.Reload(FReservedCommands);
  FListView.Items.BeginUpdate;
  try
    FListView.Items.Clear;
    for LDiagnostic in FManager.GetDiagnostics do
    begin
      LItem := FListView.Items.Add;
      if LDiagnostic.ExtensionId.IsEmpty then
        LItem.Caption := '(rejected)'
      else
        LItem.Caption := LDiagnostic.ExtensionId;
      LItem.SubItems.Add(LDiagnostic.Status);
      LItem.SubItems.Add(LDiagnostic.FileName);
      LItem.SubItems.Add(LDiagnostic.Message);
    end;
  finally
    FListView.Items.EndUpdate;
  end;
  if FListView.Items.Count = 0 then
    SetStatus('No declarative extension manifests were found.');
  UpdateActionStates;
end;

procedure TRadIAExtensionManagerForm.ReloadClick(Sender: TObject);
begin
  RefreshList;
  SetStatus('Extensions reloaded and diagnostics refreshed.');
  NotifyChat;
end;

procedure TRadIAExtensionManagerForm.RemoveClick(Sender: TObject);
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LDisplayName: string;
  LMessage: string;
begin
  if not GetSelectedDiagnostic(LDiagnostic) then
    Exit;
  if LDiagnostic.ExtensionId.IsEmpty then
    LDisplayName := ExtractFileName(LDiagnostic.FileName)
  else
    LDisplayName := LDiagnostic.ExtensionId;
  if MessageDlg(
    'Remove extension "' + LDisplayName + '" and its manifest?',
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  FManager.RemoveManifest(
    LDiagnostic.FileName,
    FReservedCommands,
    LMessage
  );
  SetStatus(LMessage);
  RefreshList;
  NotifyChat;
end;

procedure TRadIAExtensionManagerForm.SetStatus(const AMessage: string);
begin
  FStatusLabel.Caption := AMessage;
end;

procedure TRadIAExtensionManagerForm.UpdateActionStates;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LHasSelection: Boolean;
begin
  LHasSelection := GetSelectedDiagnostic(LDiagnostic) and
    not LDiagnostic.FileName.IsEmpty;
  FEnableButton.Enabled := LHasSelection and
    not LDiagnostic.ExtensionId.IsEmpty and
    not SameText(LDiagnostic.Status, 'rejected');
  FRemoveButton.Enabled := LHasSelection;
  if FEnableButton.Enabled and
    SameText(LDiagnostic.Status, 'disabled') then
    FEnableButton.Caption := 'Enable'
  else
    FEnableButton.Caption := 'Disable';
end;

end.
