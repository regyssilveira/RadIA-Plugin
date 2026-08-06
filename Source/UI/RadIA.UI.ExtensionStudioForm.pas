unit RadIA.UI.ExtensionStudioForm;

interface

uses
  Vcl.Forms;

function CreateRadIAExtensionManifest(
  AOwner: TForm;
  out AManifest: string
): Boolean;

implementation

uses
  System.Classes,
  System.SysUtils,
  ToolsAPI,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  RadIA.Core.ExtensionStudio;

type
  TRadIAExtensionStudioForm = class(TForm)
  private
    FContentEdit: TMemo;
    FAuditButton: TButton;
    FDescriptionEdit: TEdit;
    FExtensionIdEdit: TEdit;
    FInstallButton: TButton;
    FKindCombo: TComboBox;
    FNameEdit: TEdit;
    FPreviewEdit: TMemo;
    FExportButton: TButton;
    FSaveDialog: TSaveDialog;
    FStatusLabel: TLabel;
    FTriggerEdit: TEdit;
    FTriggerLabel: TLabel;
    FVersionEdit: TEdit;
    function BuildDraft: TRadIAExtensionStudioDraft;
    procedure AuditClick(Sender: TObject);
    function CreateEdit(
      const ACaption: string;
      const ATop: Integer;
      out AEdit: TEdit
    ): TLabel;
    procedure InputChanged(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure KindChanged(Sender: TObject);
    procedure RefreshPreview;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    function Manifest: string;
  end;

function CreateRadIAExtensionManifest(
  AOwner: TForm;
  out AManifest: string
): Boolean;
var
  LForm: TRadIAExtensionStudioForm;
begin
  AManifest := '';
  LForm := TRadIAExtensionStudioForm.Create(AOwner);
  try
    Result := LForm.ShowModal = mrOk;
    if Result then
      AManifest := LForm.Manifest;
  finally
    LForm.Free;
  end;
end;

constructor TRadIAExtensionStudioForm.Create(AOwner: TComponent);
var
  LCancelButton: TButton;
  LLabel: TLabel;
  LLeftPanel: TPanel;
begin
  inherited CreateNew(AOwner);
  Caption := 'Rad IA - Addon Studio';
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 980;
  ClientHeight := 620;
  Constraints.MinWidth := 800;
  Constraints.MinHeight := 560;

  LLeftPanel := TPanel.Create(Self);
  LLeftPanel.Parent := Self;
  LLeftPanel.Align := alLeft;
  LLeftPanel.Width := 430;
  LLeftPanel.BevelOuter := bvNone;
  LLeftPanel.Padding.SetBounds(8, 8, 8, 8);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LLeftPanel;
  LLabel.SetBounds(8, 10, 120, 20);
  LLabel.Caption := 'Capability type';
  FKindCombo := TComboBox.Create(Self);
  FKindCombo.Parent := LLeftPanel;
  FKindCombo.SetBounds(140, 6, 274, 25);
  FKindCombo.Style := csDropDownList;
  FKindCombo.Items.Add('Chat command');
  FKindCombo.Items.Add('Skill');
  FKindCombo.Items.Add('Tool alias');
  FKindCombo.Items.Add('Journey');
  FKindCombo.Items.Add('Audited workflow');
  FKindCombo.ItemIndex := 0;
  FKindCombo.OnChange := KindChanged;

  CreateEdit('Extension ID', 42, FExtensionIdEdit);
  FExtensionIdEdit.Text := 'MyExtension';
  CreateEdit('Version', 76, FVersionEdit);
  FVersionEdit.Text := '1.0.0';
  CreateEdit('Name', 110, FNameEdit);
  FNameEdit.Text := 'My command';
  CreateEdit('Description', 144, FDescriptionEdit);
  FDescriptionEdit.Text := 'Describe what this capability does.';
  FTriggerLabel := CreateEdit('Slash command', 178, FTriggerEdit);
  FTriggerEdit.Text := '/my-command';

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LLeftPanel;
  LLabel.SetBounds(8, 216, 120, 20);
  LLabel.Caption := 'Content';
  FContentEdit := TMemo.Create(Self);
  FContentEdit.Parent := LLeftPanel;
  FContentEdit.SetBounds(8, 238, 406, 280);
  FContentEdit.Anchors := [akLeft, akTop, akRight, akBottom];
  FContentEdit.ScrollBars := ssBoth;
  FContentEdit.WordWrap := False;
  FContentEdit.Text := 'Explain or transform: {argument}';
  FContentEdit.OnChange := InputChanged;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := LLeftPanel;
  FStatusLabel.SetBounds(8, 526, 406, 34);
  FStatusLabel.Anchors := [akLeft, akRight, akBottom];
  FStatusLabel.AutoSize := False;
  FStatusLabel.WordWrap := True;

  FInstallButton := TButton.Create(Self);
  FInstallButton.Parent := LLeftPanel;
  FInstallButton.SetBounds(218, 574, 96, 28);
  FInstallButton.Anchors := [akRight, akBottom];
  FInstallButton.Caption := 'Install';
  FInstallButton.ModalResult := mrOk;

  FAuditButton := TButton.Create(Self);
  FAuditButton.Parent := LLeftPanel;
  FAuditButton.SetBounds(8, 574, 92, 28);
  FAuditButton.Anchors := [akLeft, akBottom];
  FAuditButton.Caption := 'Audit';
  FAuditButton.OnClick := AuditClick;

  FExportButton := TButton.Create(Self);
  FExportButton.Parent := LLeftPanel;
  FExportButton.SetBounds(108, 574, 102, 28);
  FExportButton.Anchors := [akLeft, akBottom];
  FExportButton.Caption := 'Export...';
  FExportButton.OnClick := ExportClick;

  LCancelButton := TButton.Create(Self);
  LCancelButton.Parent := LLeftPanel;
  LCancelButton.SetBounds(322, 574, 92, 28);
  LCancelButton.Anchors := [akRight, akBottom];
  LCancelButton.Caption := 'Cancel';
  LCancelButton.ModalResult := mrCancel;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(446, 10, 180, 20);
  LLabel.Caption := 'Validated manifest preview';
  FPreviewEdit := TMemo.Create(Self);
  FPreviewEdit.Parent := Self;
  FPreviewEdit.SetBounds(438, 34, 534, 568);
  FPreviewEdit.Anchors := [akLeft, akTop, akRight, akBottom];
  FPreviewEdit.ReadOnly := True;
  FPreviewEdit.ScrollBars := ssBoth;
  FPreviewEdit.WordWrap := False;

  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.DefaultExt := 'radiaext';
  FSaveDialog.Filter := 'Rad IA extension package (*.radiaext)|*.radiaext';
  FSaveDialog.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];
  FSaveDialog.Title := 'Export unsigned Rad IA extension package';

  RefreshPreview;
end;

procedure TRadIAExtensionStudioForm.AuditClick(Sender: TObject);
begin
  try
    FPreviewEdit.Text := TRadIAExtensionStudioBuilder.BuildAudit(BuildDraft);
    FStatusLabel.Caption := 'Audit completed. No package or installation was changed.';
  except
    on E: Exception do
      FStatusLabel.Caption := E.Message;
  end;
end;

function TRadIAExtensionStudioForm.BuildDraft:
  TRadIAExtensionStudioDraft;
begin
  Result := TRadIAExtensionStudioDraft.Create(
    TRadIAExtensionStudioKind(FKindCombo.ItemIndex),
    FExtensionIdEdit.Text,
    FVersionEdit.Text,
    FNameEdit.Text,
    FDescriptionEdit.Text,
    FTriggerEdit.Text,
    FContentEdit.Text
  );
end;

procedure TRadIAExtensionStudioForm.CreateWnd;
var
  LThemingServices: IOTAIDEThemingServices;
begin
  inherited CreateWnd;
  if Supports(
    BorlandIDEServices,
    IOTAIDEThemingServices,
    LThemingServices
  ) and LThemingServices.IDEThemingEnabled then
    LThemingServices.ApplyTheme(Self);
end;

function TRadIAExtensionStudioForm.CreateEdit(
  const ACaption: string;
  const ATop: Integer;
  out AEdit: TEdit
): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := FKindCombo.Parent;
  Result.SetBounds(8, ATop + 4, 126, 20);
  Result.Caption := ACaption;
  AEdit := TEdit.Create(Self);
  AEdit.Parent := FKindCombo.Parent;
  AEdit.SetBounds(140, ATop, 274, 25);
  AEdit.Anchors := [akLeft, akTop, akRight];
  AEdit.OnChange := InputChanged;
end;

procedure TRadIAExtensionStudioForm.InputChanged(Sender: TObject);
begin
  RefreshPreview;
end;

procedure TRadIAExtensionStudioForm.ExportClick(Sender: TObject);
var
  LHash: string;
begin
  FSaveDialog.FileName := FExtensionIdEdit.Text + '-' +
    FVersionEdit.Text + '.radiaext';
  if not FSaveDialog.Execute then
    Exit;
  try
    LHash := TRadIAExtensionStudioPackager.ExportUnsigned(
      Manifest,
      FSaveDialog.FileName
    );
    FStatusLabel.Caption := 'Package exported and verified. SHA-256: ' + LHash;
  except
    on E: Exception do
      FStatusLabel.Caption := 'Package export failed: ' + E.Message;
  end;
end;

procedure TRadIAExtensionStudioForm.KindChanged(Sender: TObject);
begin
  FContentEdit.Enabled := True;
  case TRadIAExtensionStudioKind(FKindCombo.ItemIndex) of
    eskAlias:
      begin
        FTriggerLabel.Caption := 'Target tool';
        FTriggerEdit.Text := 'GetIDEState';
        FContentEdit.Clear;
        FContentEdit.Enabled := False;
      end;
    eskWorkflow:
      begin
        FTriggerLabel.Caption := 'Not used';
        FTriggerEdit.Clear;
        FContentEdit.Text :=
          '[{"tool":"GetIDEState","arguments":{}}]';
      end;
  else
    FTriggerLabel.Caption := 'Slash command';
    FTriggerEdit.Text := '/my-command';
    FContentEdit.Text := 'Explain or transform: {argument}';
  end;
  RefreshPreview;
end;

function TRadIAExtensionStudioForm.Manifest: string;
begin
  Result := TRadIAExtensionStudioBuilder.BuildManifest(BuildDraft);
end;

procedure TRadIAExtensionStudioForm.RefreshPreview;
begin
  try
    FPreviewEdit.Text := Manifest;
    FStatusLabel.Caption := 'Draft is structurally valid and ready for full installation checks.';
    FInstallButton.Enabled := True;
    FAuditButton.Enabled := True;
    FExportButton.Enabled := True;
  except
    on E: Exception do
    begin
      FPreviewEdit.Clear;
      FStatusLabel.Caption := E.Message;
      FInstallButton.Enabled := False;
      FAuditButton.Enabled := False;
      FExportButton.Enabled := False;
    end;
  end;
end;

end.
