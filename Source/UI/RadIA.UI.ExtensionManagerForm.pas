unit RadIA.UI.ExtensionManagerForm;

interface

uses
  System.Classes,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.ExtensionPublisherTrust;

type
  TRadIAExtensionManagerForm = class(TForm)
  private
    FCatalogButton: TButton;
    FCloseButton: TButton;
    FEnableButton: TButton;
    FFooterPanel: TPanel;
    FInstallButton: TButton;
    FListView: TListView;
    FManager: TRadIADeclarativeExtensionManager;
    FOpenDialog: TOpenDialog;
    FPublishersButton: TButton;
    FReloadButton: TButton;
    FRemoveButton: TButton;
    FReservedCommands: TArray<string>;
    FStatusLabel: TLabel;
    FStudioButton: TButton;
    FTrustStore: TRadIAExtensionPublisherTrustStore;
    FTrustStoreAvailable: Boolean;
    procedure ApplyCurrentTheme;
    function BuildReservedCommands: TArray<string>;
    procedure CatalogClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    function ConfirmPackageTrust(
      const APackageFileName: string;
      out ADecision: TRadIAExtensionPackageTrustDecision
    ): Boolean;
    procedure EnableClick(Sender: TObject);
    function GetSelectedDiagnostic(
      out ADiagnostic: TRadIADeclarativeExtensionDiagnostic
    ): Boolean;
    procedure InstallClick(Sender: TObject);
    procedure InstallPackageFile(const AFileName: string);
    procedure ListSelectItem(
      Sender: TObject;
      Item: TListItem;
      Selected: Boolean
    );
    procedure NotifyChat;
    procedure PublishersClick(Sender: TObject);
    procedure RefreshList;
    procedure ReloadClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure SetStatus(const AMessage: string);
    procedure StudioClick(Sender: TObject);
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
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  Vcl.Controls,
  RadIA.Core.DeclarativeExtensionPackages,
  RadIA.Core.ExtensionStudio,
  RadIA.Core.Mediator,
  RadIA.Core.PromptTemplates,
  RadIA.UI.ExtensionCatalogForm,
  RadIA.UI.ExtensionStudioForm;

type
  TRadIATrustedPublishersForm = class(TForm)
  private
    FCloseButton: TButton;
    FFooterPanel: TPanel;
    FListView: TListView;
    FRevokeButton: TButton;
    FTrustStore: TRadIAExtensionPublisherTrustStore;
    procedure RefreshList;
    procedure RevokeClick(Sender: TObject);
    procedure SelectItem(
      Sender: TObject;
      Item: TListItem;
      Selected: Boolean
    );
  public
    constructor Create(
      AOwner: TComponent;
      const ATrustStore: TRadIAExtensionPublisherTrustStore
    ); reintroduce;
  end;

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

{ TRadIATrustedPublishersForm }

constructor TRadIATrustedPublishersForm.Create(
  AOwner: TComponent;
  const ATrustStore: TRadIAExtensionPublisherTrustStore
);
begin
  inherited CreateNew(AOwner);
  FTrustStore := ATrustStore;
  Caption := 'Rad IA - Trusted Extension Publishers';
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 760;
  ClientHeight := 360;
  Constraints.MinWidth := 600;
  Constraints.MinHeight := 280;

  FListView := TListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ViewStyle := vsReport;
  FListView.ReadOnly := True;
  FListView.RowSelect := True;
  FListView.HideSelection := False;
  FListView.OnSelectItem := SelectItem;
  FListView.Columns.Add.Caption := 'Publisher';
  FListView.Columns.Add.Caption := 'ID';
  FListView.Columns.Add.Caption := 'SHA-256 fingerprint';
  FListView.Columns[0].Width := 190;
  FListView.Columns[1].Width := 170;
  FListView.Columns[2].Width := 380;

  FFooterPanel := TPanel.Create(Self);
  FFooterPanel.Parent := Self;
  FFooterPanel.Align := alBottom;
  FFooterPanel.Height := 48;
  FFooterPanel.BevelOuter := bvNone;
  FFooterPanel.ShowCaption := False;

  FRevokeButton := TButton.Create(Self);
  FRevokeButton.Parent := FFooterPanel;
  FRevokeButton.SetBounds(8, 10, 120, 27);
  FRevokeButton.Caption := 'Revoke trust';
  FRevokeButton.Enabled := False;
  FRevokeButton.OnClick := RevokeClick;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := FFooterPanel;
  FCloseButton.SetBounds(662, 10, 90, 27);
  FCloseButton.Anchors := [akTop, akRight];
  FCloseButton.Caption := 'Close';
  FCloseButton.ModalResult := mrClose;

  RefreshList;
end;

procedure TRadIATrustedPublishersForm.RefreshList;
var
  LItem: TListItem;
  LPublisher: TRadIATrustedExtensionPublisher;
begin
  FListView.Items.BeginUpdate;
  try
    FListView.Items.Clear;
    for LPublisher in FTrustStore.GetPublishers do
    begin
      LItem := FListView.Items.Add;
      LItem.Caption := LPublisher.Name;
      LItem.SubItems.Add(LPublisher.Id);
      LItem.SubItems.Add(LPublisher.Fingerprint);
    end;
  finally
    FListView.Items.EndUpdate;
  end;
  FRevokeButton.Enabled := False;
end;

procedure TRadIATrustedPublishersForm.RevokeClick(Sender: TObject);
var
  LPublisherId: string;
begin
  if not Assigned(FListView.Selected) then
    Exit;
  LPublisherId := FListView.Selected.SubItems[0];
  if MessageDlg(
    'Revoke trust for publisher "' + LPublisherId + '"?',
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  FTrustStore.Revoke(LPublisherId);
  RefreshList;
end;

procedure TRadIATrustedPublishersForm.SelectItem(
  Sender: TObject;
  Item: TListItem;
  Selected: Boolean
);
begin
  FRevokeButton.Enabled := Selected;
end;

constructor TRadIAExtensionManagerForm.Create(AOwner: TComponent);
var
  LTrustStoreMessage: string;
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
  FTrustStore := TRadIAExtensionPublisherTrustStore.Create(
    TPath.Combine(
      TPath.Combine(TPath.GetHomePath, 'RadIA'),
      'trusted-extension-publishers.json'
    )
  );
  try
    FTrustStore.Load;
    FTrustStoreAvailable := True;
  except
    on E: Exception do
      LTrustStoreMessage := 'Trust store unavailable: ' + E.Message;
  end;
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
  FFooterPanel.Height := 108;
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

  FPublishersButton := TButton.Create(Self);
  FPublishersButton.Parent := FFooterPanel;
  FPublishersButton.SetBounds(490, 8, 150, 27);
  FPublishersButton.Caption := 'Trusted publishers...';
  FPublishersButton.Enabled := FTrustStoreAvailable;
  FPublishersButton.OnClick := PublishersClick;

  FCatalogButton := TButton.Create(Self);
  FCatalogButton.Parent := FFooterPanel;
  FCatalogButton.SetBounds(648, 42, 132, 27);
  FCatalogButton.Caption := 'Browse catalog...';
  FCatalogButton.OnClick := CatalogClick;

  FStudioButton := TButton.Create(Self);
  FStudioButton.Parent := FFooterPanel;
  FStudioButton.SetBounds(648, 8, 132, 27);
  FStudioButton.Caption := 'Addon Studio...';
  FStudioButton.OnClick := StudioClick;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := FFooterPanel;
  FCloseButton.SetBounds(822, 8, 90, 27);
  FCloseButton.Anchors := [akTop, akRight];
  FCloseButton.Caption := 'Close';
  FCloseButton.ModalResult := mrClose;
  FCloseButton.OnClick := CloseClick;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FFooterPanel;
  FStatusLabel.SetBounds(8, 78, 904, 22);
  FStatusLabel.Anchors := [akLeft, akTop, akRight];
  FStatusLabel.AutoSize := False;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := 'Rad IA extension package (*.radiaext)|*.radiaext|' +
    'Rad IA manifest (*.radia.json)|*.radia.json|' +
    'JSON manifest (*.json)|*.json';
  FOpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];
  FOpenDialog.Title := 'Install or update a declarative extension';

  RefreshList;
  if LTrustStoreMessage <> '' then
    SetStatus(LTrustStoreMessage);
end;

destructor TRadIAExtensionManagerForm.Destroy;
begin
  FTrustStore.Free;
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

procedure TRadIAExtensionManagerForm.CatalogClick(Sender: TObject);
var
  LPackageFileName: string;
begin
  if not BrowseRadIAExtensionCatalog(
    Self,
    TPath.Combine(TPath.GetHomePath, 'RadIA'),
    LPackageFileName
  ) then
    Exit;
  try
    InstallPackageFile(LPackageFileName);
  finally
    if TFile.Exists(LPackageFileName) then
      TFile.Delete(LPackageFileName);
  end;
end;

function TRadIAExtensionManagerForm.ConfirmPackageTrust(
  const APackageFileName: string;
  out ADecision: TRadIAExtensionPackageTrustDecision
): Boolean;
var
  LExisting: TRadIATrustedExtensionPublisher;
  LKeyChanged: Boolean;
  LMessage: string;
  LPackage: TRadIADeclarativeExtensionPackage;
  LPackageHash: string;
begin
  Result := False;
  ADecision := Default(TRadIAExtensionPackageTrustDecision);
  LPackage := TRadIADeclarativeExtensionPackageReader.Read(
    APackageFileName
  );
  if not LPackage.IsSigned then
  begin
    LPackageHash := LowerCase(
      THashSHA2.GetHashStringFromFile(APackageFileName)
    );
    LMessage := 'This package has SHA-256 integrity but no publisher ' +
      'signature.' + sLineBreak + 'Extension: ' +
      LPackage.ExtensionId + ' ' + LPackage.Version + sLineBreak +
      'Package SHA-256: ' + LPackageHash + sLineBreak + sLineBreak +
      'Install it once without trusting a publisher?';
    Result := MessageDlg(
      LMessage,
      mtWarning,
      [mbYes, mbNo],
      0
    ) = mrYes;
    if Result then
      ADecision := TRadIAExtensionPackageTrustDecision.Create(
        True,
        LPackageHash
      );
    Exit;
  end;
  if not FTrustStoreAvailable then
    raise EInvalidOpException.Create(
      'Signed packages require an available publisher trust store.'
    );
  if FTrustStore.IsTrusted(LPackage.Publisher) then
    Exit(True);
  LKeyChanged := False;
  for LExisting in FTrustStore.GetPublishers do
    if SameText(LExisting.Id, LPackage.Publisher.Id) then
    begin
      LKeyChanged := True;
      Break;
    end;
  LMessage := 'Publisher: ' + LPackage.Publisher.Name + sLineBreak +
    'ID: ' + LPackage.Publisher.Id + sLineBreak +
    'Fingerprint: ' + LPackage.Publisher.Fingerprint + sLineBreak +
    sLineBreak;
  if LKeyChanged then
    LMessage := LMessage +
      'WARNING: this publisher ID was previously trusted with a ' +
      'different key.' + sLineBreak + sLineBreak;
  LMessage := LMessage +
    'The RSA-SHA256 signature is valid. Trust this publisher and install?';
  if MessageDlg(
    LMessage,
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  FTrustStore.Trust(LPackage.Publisher);
  Result := True;
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
  if SameText(ExtractFileExt(FOpenDialog.FileName), '.radiaext') then
  begin
    InstallPackageFile(FOpenDialog.FileName);
    Exit;
  end;
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

procedure TRadIAExtensionManagerForm.InstallPackageFile(
  const AFileName: string
);
var
  LDecision: TRadIAExtensionPackageTrustDecision;
  LExtensionId: string;
  LMessage: string;
begin
  try
    if not ConfirmPackageTrust(AFileName, LDecision) then
    begin
      SetStatus('Package installation cancelled.');
      Exit;
    end;
    TRadIATrustedExtensionPackageInstaller.Install(
      AFileName,
      FManager,
      FReservedCommands,
      FTrustStore,
      LDecision,
      LExtensionId,
      LMessage
    );
  except
    on E: Exception do
      LMessage := 'Package rejected: ' + E.Message;
  end;
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

procedure TRadIAExtensionManagerForm.PublishersClick(Sender: TObject);
var
  LForm: TRadIATrustedPublishersForm;
begin
  LForm := TRadIATrustedPublishersForm.Create(Self, FTrustStore);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
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
  if LDiagnostic.ExtensionId.IsEmpty then
    FManager.RemoveManifest(
      LDiagnostic.FileName,
      FReservedCommands,
      LMessage
    )
  else
    FManager.Remove(
      LDiagnostic.ExtensionId,
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

procedure TRadIAExtensionManagerForm.StudioClick(Sender: TObject);
var
  LExtensionId: string;
  LManifest: string;
  LMessage: string;
  LResourcesPath: string;
  LTempFileName: string;
begin
  if not CreateRadIAExtensionManifest(
    Self,
    FReservedCommands,
    LManifest,
    LResourcesPath
  ) then
    Exit;
  LTempFileName := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-StudioInstall-' + TGUID.NewGuid.ToString + '.radiaext'
  );
  try
    TRadIAExtensionStudioPackager.ExportUnsigned(
      LManifest,
      LTempFileName,
      LResourcesPath
    );
    TRadIADeclarativeExtensionPackageInstaller.Install(
      LTempFileName,
      FManager,
      FReservedCommands,
      LExtensionId,
      LMessage
    );
  finally
    if TFile.Exists(LTempFileName) then
      TFile.Delete(LTempFileName);
  end;
  SetStatus(LMessage);
  RefreshList;
  NotifyChat;
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
