unit RadIA.UI.ExtensionStudioForm;

interface

uses
  Vcl.Forms;

function CreateRadIAExtensionManifest(
  AOwner: TForm;
  const AReservedCommands: TArray<string>;
  out AManifest: string;
  out AResourcesPath: string
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
  RadIA.Core.ExtensionStudio,
  RadIA.UI.ExtensionSigningForm;

type
  TRadIAExtensionStudioForm = class(TForm)
  private
    FContentEdit: TMemo;
    FContentFileEdit: TEdit;
    FAuditButton: TButton;
    FDescriptionEdit: TEdit;
    FExtensionIdEdit: TEdit;
    FInstallButton: TButton;
    FKindCombo: TComboBox;
    FNameEdit: TEdit;
    FPreviewEdit: TMemo;
    FResourcesButton: TButton;
    FResourcesDialog: TFileOpenDialog;
    FResourcesEdit: TEdit;
    FExportButton: TButton;
    FReservedCommands: TArray<string>;
    FSaveDialog: TSaveDialog;
    FSignButton: TButton;
    FStatusLabel: TLabel;
    FTestButton: TButton;
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
    procedure CreateActionControls(const AParent: TWinControl);
    procedure InputChanged(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure KindChanged(Sender: TObject);
    procedure RefreshPreview;
    procedure ResourcesClick(Sender: TObject);
    procedure SignClick(Sender: TObject);
    procedure TestClick(Sender: TObject);
  protected
    procedure CreateWnd; override;
  public
    constructor Create(
      AOwner: TComponent;
      const AReservedCommands: TArray<string>
    ); reintroduce;
    function Manifest: string;
    function ResourcesPath: string;
  end;

function CreateRadIAExtensionManifest(
  AOwner: TForm;
  const AReservedCommands: TArray<string>;
  out AManifest: string;
  out AResourcesPath: string
): Boolean;
var
  LForm: TRadIAExtensionStudioForm;
begin
  AManifest := '';
  AResourcesPath := '';
  LForm := TRadIAExtensionStudioForm.Create(AOwner, AReservedCommands);
  try
    Result := LForm.ShowModal = mrOk;
    if Result then
    begin
      AManifest := LForm.Manifest;
      AResourcesPath := LForm.ResourcesPath;
    end;
  finally
    LForm.Free;
  end;
end;

constructor TRadIAExtensionStudioForm.Create(
  AOwner: TComponent;
  const AReservedCommands: TArray<string>
);
var
  LLabel: TLabel;
  LLeftPanel: TPanel;
begin
  inherited CreateNew(AOwner);
  FReservedCommands := Copy(AReservedCommands);
  Caption := 'Rad IA - Addon Studio';
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 980;
  ClientHeight := 700;
  Constraints.MinWidth := 800;
  Constraints.MinHeight := 640;

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
  CreateEdit('Content file', 212, FContentFileEdit);
  FContentFileEdit.Hint :=
    'Optional UTF-8 file under references, templates, or knowledge';
  FContentFileEdit.ShowHint := True;
  CreateEdit('Resources folder', 246, FResourcesEdit);
  FResourcesEdit.Width := 204;
  FResourcesEdit.Hint :=
    'Root containing references, templates, knowledge, or assets subfolders';
  FResourcesEdit.ShowHint := True;
  FResourcesButton := TButton.Create(Self);
  FResourcesButton.Parent := LLeftPanel;
  FResourcesButton.SetBounds(350, 246, 64, 25);
  FResourcesButton.Anchors := [akTop, akRight];
  FResourcesButton.Caption := 'Browse...';
  FResourcesButton.Hint :=
    'Select the root folder whose allowed resources will be packaged';
  FResourcesButton.ShowHint := True;
  FResourcesButton.OnClick := ResourcesClick;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LLeftPanel;
  LLabel.SetBounds(8, 284, 360, 20);
  LLabel.Caption := 'Inline content (empty when using a content file)';
  FContentEdit := TMemo.Create(Self);
  FContentEdit.Parent := LLeftPanel;
  FContentEdit.SetBounds(8, 306, 406, 280);
  FContentEdit.Anchors := [akLeft, akTop, akRight, akBottom];
  FContentEdit.ScrollBars := ssBoth;
  FContentEdit.WordWrap := False;
  FContentEdit.Text := 'Explain or transform: {argument}';
  FContentEdit.OnChange := InputChanged;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := LLeftPanel;
  FStatusLabel.SetBounds(8, 594, 406, 42);
  FStatusLabel.Anchors := [akLeft, akRight, akBottom];
  FStatusLabel.AutoSize := False;
  FStatusLabel.WordWrap := True;

  CreateActionControls(LLeftPanel);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(446, 10, 180, 20);
  LLabel.Caption := 'Validated manifest preview';
  FPreviewEdit := TMemo.Create(Self);
  FPreviewEdit.Parent := Self;
  FPreviewEdit.SetBounds(438, 34, 534, 648);
  FPreviewEdit.Anchors := [akLeft, akTop, akRight, akBottom];
  FPreviewEdit.ReadOnly := True;
  FPreviewEdit.ScrollBars := ssBoth;
  FPreviewEdit.WordWrap := False;

  FResourcesDialog := TFileOpenDialog.Create(Self);
  FResourcesDialog.Options := [fdoPickFolders, fdoPathMustExist];
  FResourcesDialog.Title := 'Select extension resources root';

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
  ).WithContentFile(FContentFileEdit.Text);
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

procedure TRadIAExtensionStudioForm.CreateActionControls(
  const AParent: TWinControl
);
var
  LCancelButton: TButton;
begin
  FInstallButton := TButton.Create(Self);
  FInstallButton.Parent := AParent;
  FInstallButton.SetBounds(272, 654, 60, 28);
  FInstallButton.Anchors := [akRight, akBottom];
  FInstallButton.Caption := 'Install';
  FInstallButton.ModalResult := mrOk;

  FAuditButton := TButton.Create(Self);
  FAuditButton.Parent := AParent;
  FAuditButton.SetBounds(8, 654, 58, 28);
  FAuditButton.Anchors := [akLeft, akBottom];
  FAuditButton.Caption := 'Audit';
  FAuditButton.OnClick := AuditClick;

  FTestButton := TButton.Create(Self);
  FTestButton.Parent := AParent;
  FTestButton.SetBounds(74, 654, 58, 28);
  FTestButton.Anchors := [akLeft, akBottom];
  FTestButton.Caption := 'Test';
  FTestButton.OnClick := TestClick;

  FExportButton := TButton.Create(Self);
  FExportButton.Parent := AParent;
  FExportButton.SetBounds(140, 654, 58, 28);
  FExportButton.Anchors := [akLeft, akBottom];
  FExportButton.Caption := 'Export...';
  FExportButton.OnClick := ExportClick;

  FSignButton := TButton.Create(Self);
  FSignButton.Parent := AParent;
  FSignButton.SetBounds(206, 654, 58, 28);
  FSignButton.Anchors := [akLeft, akBottom];
  FSignButton.Caption := 'Sign...';
  FSignButton.OnClick := SignClick;

  LCancelButton := TButton.Create(Self);
  LCancelButton.Parent := AParent;
  LCancelButton.SetBounds(340, 654, 74, 28);
  LCancelButton.Anchors := [akRight, akBottom];
  LCancelButton.Caption := 'Cancel';
  LCancelButton.ModalResult := mrCancel;

  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.DefaultExt := 'radiaext';
  FSaveDialog.Filter := 'Rad IA extension package (*.radiaext)|*.radiaext';
  FSaveDialog.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];
  FSaveDialog.Title := 'Export unsigned Rad IA extension package';
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
      FSaveDialog.FileName,
      FResourcesEdit.Text
    );
    FStatusLabel.Caption := 'Package exported and verified. SHA-256: ' + LHash;
  except
    on E: Exception do
      FStatusLabel.Caption := 'Package export failed: ' + E.Message;
  end;
end;

procedure TRadIAExtensionStudioForm.ResourcesClick(Sender: TObject);
begin
  if Trim(FResourcesEdit.Text) <> '' then
    FResourcesDialog.DefaultFolder := FResourcesEdit.Text;
  if FResourcesDialog.Execute then
    FResourcesEdit.Text := FResourcesDialog.FileName;
end;

procedure TRadIAExtensionStudioForm.KindChanged(Sender: TObject);
begin
  FContentEdit.Enabled := True;
  FContentFileEdit.Enabled := True;
  case TRadIAExtensionStudioKind(FKindCombo.ItemIndex) of
    eskAlias:
      begin
        FTriggerLabel.Caption := 'Target tool';
        FTriggerEdit.Text := 'GetIDEState';
        FContentEdit.Clear;
        FContentEdit.Enabled := False;
        FContentFileEdit.Clear;
        FContentFileEdit.Enabled := False;
      end;
    eskWorkflow:
      begin
        FTriggerLabel.Caption := 'Not used';
        FTriggerEdit.Clear;
        FContentEdit.Text :=
          '[{"tool":"GetIDEState","arguments":{}}]';
        FContentFileEdit.Clear;
        FContentFileEdit.Enabled := False;
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

function TRadIAExtensionStudioForm.ResourcesPath: string;
begin
  Result := Trim(FResourcesEdit.Text);
end;

procedure TRadIAExtensionStudioForm.RefreshPreview;
begin
  try
    FPreviewEdit.Text := Manifest;
    FStatusLabel.Caption := 'Draft is structurally valid and ready for full installation checks.';
    FInstallButton.Enabled := True;
    FAuditButton.Enabled := True;
    FExportButton.Enabled := True;
    FSignButton.Enabled := True;
    FTestButton.Enabled := True;
  except
    on E: Exception do
    begin
      FPreviewEdit.Clear;
      FStatusLabel.Caption := E.Message;
      FInstallButton.Enabled := False;
      FAuditButton.Enabled := False;
      FExportButton.Enabled := False;
      FSignButton.Enabled := False;
      FTestButton.Enabled := False;
    end;
  end;
end;

procedure TRadIAExtensionStudioForm.SignClick(Sender: TObject);
begin
  try
    ShowRadIAExtensionSigning(
      Self,
      Manifest,
      FExtensionIdEdit.Text + '-' + FVersionEdit.Text + '-signed.radiaext',
      FResourcesEdit.Text
    );
  except
    on E: Exception do
      FStatusLabel.Caption := 'Unable to open signing: ' + E.Message;
  end;
end;

procedure TRadIAExtensionStudioForm.TestClick(Sender: TObject);
begin
  try
    FPreviewEdit.Text := TRadIAExtensionStudioSandbox.TestManifest(
      Manifest,
      FReservedCommands,
      FResourcesEdit.Text
    );
    FStatusLabel.Caption :=
      'Sandbox completed. Installed extensions were not changed.';
  except
    on E: Exception do
      FStatusLabel.Caption := 'Sandbox failed: ' + E.Message;
  end;
end;

end.
