unit RadIA.UI.ProjectWizard;

interface

uses
  System.Classes,
  Vcl.CheckLst,
  Vcl.Forms,
  Vcl.StdCtrls,
  RadIA.Core.ProjectTemplateService,
  RadIA.Core.ProjectTemplates,
  RadIA.Core.Version;

type
  TRadIAProjectWizardForm = class(TForm)
  private
    FService: IRadIAProjectTemplateService;
    FAuthorizedService: IRadIAAuthorizedProjectTemplateService;
    FAuthorizedRoot: string;
    FPreviewId: string;
    FProjectNameEdit: TEdit;
    FTemplateCombo: TComboBox;
    FVersionCombo: TComboBox;
    FPlatformList: TCheckListBox;
    FRootEdit: TEdit;
    FPreviewMemo: TMemo;
    FPreviewButton: TButton;
    FCreateButton: TButton;
    FStatusLabel: TLabel;
    procedure BrowseClick(Sender: TObject);
    procedure CreateClick(Sender: TObject);
    procedure FieldChanged(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure BuildControls;
    procedure InvalidatePreview;
    function BuildRequest: TRadIAProjectTemplateRequest;
    function DestinationPath: string;
    function SelectedPlatforms: TArray<string>;
    function SelectedTemplate: TRadIAProjectTemplateKind;
    procedure SetStatus(const AText: string; const AIsError: Boolean);
  public
    constructor Create(
      AOwner: TComponent;
      const AService: IRadIAProjectTemplateService;
      const AAuthorizedService: IRadIAAuthorizedProjectTemplateService
    ); reintroduce;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Graphics;

function DefaultDelphiVersion: string;
begin
{$IF CompilerVersion >= 37.0}
  Result := '37.0';
{$ELSE}
  Result := '23.0';
{$ENDIF}
end;

procedure TRadIAProjectWizardForm.BrowseClick(Sender: TObject);
var
  LDialog: TFileOpenDialog;
begin
  LDialog := TFileOpenDialog.Create(Self);
  try
    LDialog.Options := LDialog.Options + [fdoPickFolders, fdoPathMustExist];
    LDialog.Title := 'Select the authorized project root';
    if FAuthorizedRoot <> '' then
      LDialog.DefaultFolder := FAuthorizedRoot;
    if not LDialog.Execute then
      Exit;
    FAuthorizedRoot := ExcludeTrailingPathDelimiter(LDialog.FileName);
    FRootEdit.Text := FAuthorizedRoot;
    InvalidatePreview;
  finally
    LDialog.Free;
  end;
end;

function TRadIAProjectWizardForm.BuildRequest:
  TRadIAProjectTemplateRequest;
begin
  Result := TRadIAProjectTemplateRequest.Create(
    Trim(FProjectNameEdit.Text),
    SelectedTemplate,
    FVersionCombo.Text,
    SelectedPlatforms
  );
end;

procedure TRadIAProjectWizardForm.BuildControls;
var
  LBrowseButton: TButton;
  LCancelButton: TButton;
  LLabel: TLabel;
begin
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(16, 18, 110, 17);
  LLabel.Caption := 'Project name';
  FProjectNameEdit := TEdit.Create(Self);
  FProjectNameEdit.Parent := Self;
  FProjectNameEdit.SetBounds(136, 14, 300, 25);
  FProjectNameEdit.OnChange := FieldChanged;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(16, 54, 110, 17);
  LLabel.Caption := 'Template';
  FTemplateCombo := TComboBox.Create(Self);
  FTemplateCombo.Parent := Self;
  FTemplateCombo.Style := csDropDownList;
  FTemplateCombo.SetBounds(136, 50, 180, 25);
  FTemplateCombo.Items.AddStrings([
    'Console',
    'VCL',
    'FMX',
    'Library',
    'Package',
    'DUnitX',
    'Windows Service'
  ]);
  FTemplateCombo.ItemIndex := 1;
  FTemplateCombo.OnChange := FieldChanged;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(332, 54, 56, 17);
  LLabel.Caption := 'Delphi';
  FVersionCombo := TComboBox.Create(Self);
  FVersionCombo.Parent := Self;
  FVersionCombo.Style := csDropDownList;
  FVersionCombo.SetBounds(388, 50, 96, 25);
  FVersionCombo.Items.AddStrings(['23.0', '37.0']);
  FVersionCombo.ItemIndex := FVersionCombo.Items.IndexOf(
    DefaultDelphiVersion
  );
  FVersionCombo.OnChange := FieldChanged;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(16, 90, 110, 17);
  LLabel.Caption := 'Platforms';
  FPlatformList := TCheckListBox.Create(Self);
  FPlatformList.Parent := Self;
  FPlatformList.SetBounds(136, 86, 180, 54);
  FPlatformList.Items.Add('Win32');
  FPlatformList.Items.Add('Win64');
  FPlatformList.Checked[0] := True;
  FPlatformList.OnClickCheck := FieldChanged;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(16, 158, 110, 17);
  LLabel.Caption := 'Authorized root';
  FRootEdit := TEdit.Create(Self);
  FRootEdit.Parent := Self;
  FRootEdit.ReadOnly := True;
  FRootEdit.SetBounds(136, 154, 450, 25);
  LBrowseButton := TButton.Create(Self);
  LBrowseButton.Parent := Self;
  LBrowseButton.SetBounds(594, 153, 90, 27);
  LBrowseButton.Caption := 'Browse...';
  LBrowseButton.OnClick := BrowseClick;

  FPreviewMemo := TMemo.Create(Self);
  FPreviewMemo.Parent := Self;
  FPreviewMemo.ReadOnly := True;
  FPreviewMemo.ScrollBars := ssBoth;
  FPreviewMemo.WordWrap := False;
  FPreviewMemo.SetBounds(16, 196, 668, 270);
  FPreviewMemo.Anchors := [akLeft, akTop, akRight, akBottom];

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.SetBounds(16, 478, 440, 34);
  FStatusLabel.AutoSize := False;
  FStatusLabel.Anchors := [akLeft, akBottom, akRight];

  FPreviewButton := TButton.Create(Self);
  FPreviewButton.Parent := Self;
  FPreviewButton.SetBounds(472, 482, 100, 30);
  FPreviewButton.Caption := 'Preview';
  FPreviewButton.Anchors := [akRight, akBottom];
  FPreviewButton.OnClick := PreviewClick;

  FCreateButton := TButton.Create(Self);
  FCreateButton.Parent := Self;
  FCreateButton.SetBounds(580, 482, 104, 30);
  FCreateButton.Caption := 'Create && Open';
  FCreateButton.Enabled := False;
  FCreateButton.Anchors := [akRight, akBottom];
  FCreateButton.OnClick := CreateClick;

  LCancelButton := TButton.Create(Self);
  LCancelButton.Parent := Self;
  LCancelButton.SetBounds(364, 482, 100, 30);
  LCancelButton.Caption := 'Close';
  LCancelButton.ModalResult := mrCancel;
  LCancelButton.Anchors := [akRight, akBottom];
end;

constructor TRadIAProjectWizardForm.Create(
  AOwner: TComponent;
  const AService: IRadIAProjectTemplateService;
  const AAuthorizedService: IRadIAAuthorizedProjectTemplateService
);
begin
  inherited CreateNew(AOwner);
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  if not Assigned(AAuthorizedService) then
    raise EArgumentNilException.Create('AAuthorizedService');
  FService := AService;
  FAuthorizedService := AAuthorizedService;
  Caption := RadIAVersionedCaption('RadIA New Project');
  BorderStyle := bsSizeable;
  Position := poScreenCenter;
  ClientWidth := 700;
  ClientHeight := 528;
  Constraints.MinWidth := 716;
  Constraints.MinHeight := 567;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  BuildControls;
end;

procedure TRadIAProjectWizardForm.CreateClick(Sender: TObject);
var
  LResult: TRadIAProjectTemplateOperationResult;
begin
  if FPreviewId = '' then
    Exit;
  Enabled := False;
  try
    LResult := FService.Commit(FPreviewId);
    if not LResult.Success then
    begin
      SetStatus(LResult.ErrorMessage, True);
      Exit;
    end;
    LResult := FService.Open(FPreviewId);
    if not LResult.Success then
    begin
      FService.Rollback(FPreviewId);
      SetStatus(LResult.ErrorMessage, True);
      Exit;
    end;
    ModalResult := mrOk;
  finally
    Enabled := True;
  end;
end;

function TRadIAProjectWizardForm.DestinationPath: string;
begin
  Result := TPath.Combine(
    FAuthorizedRoot,
    Trim(FProjectNameEdit.Text)
  );
end;

procedure TRadIAProjectWizardForm.FieldChanged(Sender: TObject);
begin
  InvalidatePreview;
end;

procedure TRadIAProjectWizardForm.InvalidatePreview;
begin
  FPreviewId := '';
  FCreateButton.Enabled := False;
  FPreviewMemo.Clear;
  SetStatus('Review the fields and generate a preview.', False);
end;

procedure TRadIAProjectWizardForm.PreviewClick(Sender: TObject);
var
  LResult: TRadIAProjectTemplateOperationResult;
begin
  if FAuthorizedRoot = '' then
  begin
    SetStatus('Select an authorized root folder first.', True);
    Exit;
  end;
  try
    LResult := FAuthorizedService.PreviewAtAuthorizedRoot(
      BuildRequest,
      FAuthorizedRoot,
      DestinationPath
    );
    if not LResult.Success then
    begin
      SetStatus(LResult.ErrorMessage, True);
      Exit;
    end;
    FPreviewId := LResult.PreviewId;
    FPreviewMemo.Text := LResult.PreviewJson;
    FCreateButton.Enabled := True;
    SetStatus(
      'Preview ready. No files have been created yet.',
      False
    );
  except
    on E: Exception do
      SetStatus(E.Message, True);
  end;
end;

function TRadIAProjectWizardForm.SelectedPlatforms: TArray<string>;
var
  LCount: Integer;
  LIndex: Integer;
begin
  SetLength(Result, 0);
  LCount := 0;
  for LIndex := 0 to FPlatformList.Items.Count - 1 do
  begin
    if not FPlatformList.Checked[LIndex] then
      Continue;
    SetLength(Result, LCount + 1);
    Result[LCount] := FPlatformList.Items[LIndex];
    Inc(LCount);
  end;
end;

function TRadIAProjectWizardForm.SelectedTemplate:
  TRadIAProjectTemplateKind;
begin
  case FTemplateCombo.ItemIndex of
    0: Result := ptkConsole;
    1: Result := ptkVcl;
    2: Result := ptkFmx;
    3: Result := ptkLibrary;
    4: Result := ptkPackage;
    5: Result := ptkDUnitX;
  else
    Result := ptkService;
  end;
end;

procedure TRadIAProjectWizardForm.SetStatus(
  const AText: string;
  const AIsError: Boolean
);
begin
  FStatusLabel.Caption := AText;
  if AIsError then
    FStatusLabel.Font.Color := clRed
  else
    FStatusLabel.Font.Color := clWindowText;
end;

end.
