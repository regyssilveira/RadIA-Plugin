unit RadIA.UI.ExtensionSigningForm;

interface

uses
  Vcl.Forms;

procedure ShowRadIAExtensionSigning(
  AOwner: TForm;
  const AManifest: string;
  const ASuggestedFileName: string
);

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  RadIA.Core.CliProcess,
  RadIA.Core.ExtensionSigning,
  RadIA.Core.Interfaces;

type
  TRadIAExtensionSigningForm = class(TForm)
  private
    FCertificates: TArray<TRadIAExtensionSigningCertificate>;
    FCertificateCombo: TComboBox;
    FCloseButton: TButton;
    FLifecycleGuard: IInterface;
    FManifest: string;
    FOutputDialog: TSaveDialog;
    FPackagerPath: string;
    FPublisherIdEdit: TEdit;
    FPublisherNameEdit: TEdit;
    FRefreshButton: TButton;
    FSession: IRadIACliProcessSession;
    FSignButton: TButton;
    FStatusLabel: TLabel;
    procedure ApplyCertificateResult(
      const AResult: TRadIACliProcessResult
    );
    procedure ApplySigningResult(
      const AOutputPath: string;
      const AResult: TRadIACliProcessResult
    );
    procedure CreateControls(const ASuggestedFileName: string);
    procedure RefreshCertificates(Sender: TObject);
    procedure SetBusy(const AValue: Boolean; const AStatus: string);
    procedure SignClick(Sender: TObject);
    procedure StartSigning(const AOutputPath: string);
  protected
    procedure CreateWnd; override;
  public
    constructor Create(
      AOwner: TComponent;
      const AManifest: string;
      const ASuggestedFileName: string
    ); reintroduce;
    destructor Destroy; override;
  end;

procedure ShowRadIAExtensionSigning(
  AOwner: TForm;
  const AManifest: string;
  const ASuggestedFileName: string
);
var
  LForm: TRadIAExtensionSigningForm;
begin
  LForm := TRadIAExtensionSigningForm.Create(
    AOwner,
    AManifest,
    ASuggestedFileName
  );
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

constructor TRadIAExtensionSigningForm.Create(
  AOwner: TComponent;
  const AManifest: string;
  const ASuggestedFileName: string
);
begin
  inherited CreateNew(AOwner);
  FManifest := AManifest;
  FPackagerPath := TRadIAExtensionSigningService.FindPackager;
  FLifecycleGuard := TLifecycleGuard.Create;
  Caption := 'Rad IA - Sign extension package';
  Position := poOwnerFormCenter;
  BorderStyle := bsDialog;
  ClientWidth := 650;
  ClientHeight := 285;
  CreateControls(ASuggestedFileName);
  RefreshCertificates(nil);
end;

procedure TRadIAExtensionSigningForm.ApplyCertificateResult(
  const AResult: TRadIACliProcessResult
);
var
  LCertificate: TRadIAExtensionSigningCertificate;
begin
  if not AResult.Succeeded then
  begin
    SetBusy(False, 'Unable to load certificates: ' + Trim(AResult.StdErr));
    Exit;
  end;
  try
    FCertificates := TRadIAExtensionSigningService.ParseCertificates(
      AResult.StdOut
    );
    FCertificateCombo.Items.Clear;
    for LCertificate in FCertificates do
      FCertificateCombo.Items.Add(
        LCertificate.DisplayName + ' | expires ' +
        LCertificate.ExpiresAt + ' | ' + LCertificate.Thumbprint
      );
    if Length(FCertificates) > 0 then
    begin
      FCertificateCombo.ItemIndex := 0;
      SetBusy(False, Format('%d signing certificate(s) available.', [
        Length(FCertificates)
      ]));
    end
    else
      SetBusy(False, 'No valid RSA certificate with a private key was found.');
  except
    on E: Exception do
      SetBusy(False, 'Unable to read certificates: ' + E.Message);
  end;
end;

procedure TRadIAExtensionSigningForm.ApplySigningResult(
  const AOutputPath: string;
  const AResult: TRadIACliProcessResult
);
var
  LFingerprint: string;
begin
  if not AResult.Succeeded then
  begin
    SetBusy(False, 'Signing failed: ' + Trim(AResult.StdErr));
    Exit;
  end;
  try
    LFingerprint := TRadIAExtensionSigningService.ValidateSignedPackage(
      AOutputPath
    );
    SetBusy(False, 'Signed package verified. Publisher fingerprint: ' +
      LFingerprint);
  except
    on E: Exception do
      SetBusy(False, 'Signed package validation failed: ' + E.Message);
  end;
end;

procedure TRadIAExtensionSigningForm.CreateControls(
  const ASuggestedFileName: string
);
var
  LLabel: TLabel;
begin
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(12, 16, 110, 20);
  LLabel.Caption := 'Certificate';
  FCertificateCombo := TComboBox.Create(Self);
  FCertificateCombo.Parent := Self;
  FCertificateCombo.SetBounds(122, 12, 438, 25);
  FCertificateCombo.Style := csDropDownList;
  FRefreshButton := TButton.Create(Self);
  FRefreshButton.Parent := Self;
  FRefreshButton.SetBounds(568, 11, 70, 27);
  FRefreshButton.Caption := 'Refresh';
  FRefreshButton.OnClick := RefreshCertificates;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(12, 58, 110, 20);
  LLabel.Caption := 'Publisher ID';
  FPublisherIdEdit := TEdit.Create(Self);
  FPublisherIdEdit.Parent := Self;
  FPublisherIdEdit.SetBounds(122, 54, 516, 25);
  FPublisherIdEdit.Text := 'my-company';

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(12, 100, 110, 20);
  LLabel.Caption := 'Publisher name';
  FPublisherNameEdit := TEdit.Create(Self);
  FPublisherNameEdit.Parent := Self;
  FPublisherNameEdit.SetBounds(122, 96, 516, 25);
  FPublisherNameEdit.Text := 'My Company';

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.SetBounds(12, 140, 626, 62);
  FStatusLabel.AutoSize := False;
  FStatusLabel.WordWrap := True;

  FSignButton := TButton.Create(Self);
  FSignButton.Parent := Self;
  FSignButton.SetBounds(466, 238, 82, 30);
  FSignButton.Caption := 'Sign...';
  FSignButton.OnClick := SignClick;
  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := Self;
  FCloseButton.SetBounds(556, 238, 82, 30);
  FCloseButton.Caption := 'Close';
  FCloseButton.ModalResult := mrCancel;

  FOutputDialog := TSaveDialog.Create(Self);
  FOutputDialog.DefaultExt := 'radiaext';
  FOutputDialog.FileName := ASuggestedFileName;
  FOutputDialog.Filter := 'Rad IA extension package (*.radiaext)|*.radiaext';
  FOutputDialog.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];
end;

procedure TRadIAExtensionSigningForm.CreateWnd;
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

destructor TRadIAExtensionSigningForm.Destroy;
begin
  (FLifecycleGuard as IRadIALifecycleGuard).Invalidate;
  if Assigned(FSession) then
    FSession.Cancel;
  inherited Destroy;
end;

procedure TRadIAExtensionSigningForm.RefreshCertificates(Sender: TObject);
var
  LGuard: IRadIALifecycleGuard;
begin
  if FPackagerPath = '' then
  begin
    FStatusLabel.Caption := 'The signed package builder was not found.';
    Exit;
  end;
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  SetBusy(True, 'Loading certificates from CurrentUser\My...');
  FSession := TRadIACliProcessRunner.Start(
    TRadIAExtensionSigningService.BuildCertificateQueryInvocation,
    15000,
    nil,
    nil,
    procedure(AResult: TRadIACliProcessResult)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              ApplyCertificateResult(AResult);
          end
        )
      );
    end
  );
end;

procedure TRadIAExtensionSigningForm.SetBusy(
  const AValue: Boolean;
  const AStatus: string
);
begin
  FCertificateCombo.Enabled := not AValue;
  FPublisherIdEdit.Enabled := not AValue;
  FPublisherNameEdit.Enabled := not AValue;
  FRefreshButton.Enabled := not AValue;
  FCloseButton.Enabled := not AValue;
  FSignButton.Enabled := not AValue and
    (FCertificateCombo.ItemIndex >= 0);
  FStatusLabel.Caption := AStatus;
end;

procedure TRadIAExtensionSigningForm.SignClick(Sender: TObject);
begin
  if FCertificateCombo.ItemIndex < 0 then
  begin
    FStatusLabel.Caption := 'Select a signing certificate.';
    Exit;
  end;
  if not FOutputDialog.Execute then
    Exit;
  StartSigning(FOutputDialog.FileName);
end;

procedure TRadIAExtensionSigningForm.StartSigning(
  const AOutputPath: string
);
var
  LGuard: IRadIALifecycleGuard;
  LManifestPath: string;
  LRequest: TRadIAExtensionSigningRequest;
begin
  LManifestPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-Signing-' + TGUID.NewGuid.ToString + '.json'
  );
  TFile.WriteAllText(LManifestPath, FManifest, TEncoding.UTF8);
  LRequest := TRadIAExtensionSigningRequest.Create(
    LManifestPath,
    AOutputPath,
    FPackagerPath,
    FPublisherIdEdit.Text,
    FPublisherNameEdit.Text,
    FCertificates[FCertificateCombo.ItemIndex].Thumbprint
  );
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  SetBusy(True, 'Signing and verifying extension package...');
  try
    FSession := TRadIACliProcessRunner.Start(
      TRadIAExtensionSigningService.BuildSigningInvocation(LRequest),
      60000,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        TThread.Queue(
          nil,
          TThreadProcedure(
            procedure
            begin
              if TFile.Exists(LManifestPath) then
                TFile.Delete(LManifestPath);
              if LGuard.IsAlive then
                ApplySigningResult(AOutputPath, AResult);
            end
          )
        );
      end
    );
  except
    if TFile.Exists(LManifestPath) then
      TFile.Delete(LManifestPath);
    raise;
  end;
end;

end.
