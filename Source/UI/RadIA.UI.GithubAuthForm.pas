unit RadIA.UI.GithubAuthForm;

interface

uses  System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TRadIAFormGithubAuth = class(TForm)
    pnlClient: TPanel;
    lblTitle: TLabel;
    lblInstructions: TLabel;
    lblPIN: TLabel;
    lblStatus: TLabel;
    btnOpenBrowser: TButton;
    btnCancel: TButton;
    procedure btnOpenBrowserClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
  private
    FCancelled: Boolean;
    FAccessToken: string;
    FDeviceCode: string;
    FUserCode: string;
    FVerificationUri: string;
    FInterval: Integer;
    FExpiresIn: Integer;

    procedure StartPolling;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    class function Execute(AOwner: TComponent; out AAccessToken: string): Boolean;
  end;

implementation


uses
  Winapi.Windows, System.SysUtils, Vcl.Graphics, Vcl.Dialogs, System.Threading, RadIA.Provider.GithubCopilot,
      Winapi.ShellAPI, ToolsAPI, RadIA.Core.Version, RadIA.UI.Resources;

{$R *.dfm}



class function TRadIAFormGithubAuth.Execute(AOwner: TComponent; out AAccessToken: string): Boolean;
var
  LForm: TRadIAFormGithubAuth;
  LDeviceCode, LUserCode, LVerificationUri: string;
  LInterval, LExpiresIn: Integer;
  LErrorMsg: string;
begin
  AAccessToken := '';

  { Request authorization code from GitHub }
  if not TRadIAGithubCopilotProvider.RequestDeviceCode(LDeviceCode, LUserCode,
    LVerificationUri, LInterval, LExpiresIn, LErrorMsg) then
  begin
    MessageDlg('Failed to connect to GitHub Device Flow API: ' + LErrorMsg,
      mtError, [mbOK], 0);
    Exit(False);
  end;

  LForm := TRadIAFormGithubAuth.Create(AOwner);
  try
    LForm.FDeviceCode := LDeviceCode;
    LForm.FUserCode := LUserCode;
    LForm.FVerificationUri := LVerificationUri;
    LForm.FInterval := LInterval;
    LForm.FExpiresIn := LExpiresIn;

    LForm.lblPIN.Caption := LUserCode;

    if LForm.ShowModal = mrOk then
    begin
      AAccessToken := LForm.FAccessToken;
      Result := not AAccessToken.IsEmpty;
    end
    else
    begin
      Result := False;
    end;
  finally
    LForm.Free;
  end;
end;

constructor TRadIAFormGithubAuth.Create(AOwner: TComponent);
var
  LThemingServices: IOTAIDEThemingServices;
  LActiveTheme: string;
  LColors: TRadIAThemeColors;
begin
  inherited Create(AOwner);
  Caption := RadIAVersionedCaption('GitHub Copilot Authentication');
  FCancelled := False;
  FAccessToken := '';

  { Apply IDE Theming if available }
  LActiveTheme := 'light';
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      LThemingServices.ApplyTheme(Self);
      LActiveTheme := LThemingServices.ActiveTheme;
    end;
  end;

  { Custom styling fallback for colors }
  LColors := TRadIAThemeColors.GetColorsForTheme(LActiveTheme);
  Self.StyleElements := Self.StyleElements - [seClient, seBorder];
  Self.Color := LColors.BgBase;

  pnlClient.StyleElements := pnlClient.StyleElements - [seClient, seBorder];
  pnlClient.Color := LColors.BgBase;
  pnlClient.ParentBackground := False;

  lblTitle.StyleElements := lblTitle.StyleElements - [seClient, seBorder];
  lblTitle.Font.Color := LColors.TextColor;
  lblInstructions.StyleElements := lblInstructions.StyleElements - [seClient, seBorder];
  lblInstructions.Font.Color := LColors.TextColor;

  lblPIN.StyleElements := lblPIN.StyleElements - [seClient, seBorder];
  lblPIN.Font.Color := clHighlight; { Stand out PIN code }

  lblStatus.StyleElements := lblStatus.StyleElements - [seClient, seBorder];
  lblStatus.Font.Color := LColors.TextColor;
end;

procedure TRadIAFormGithubAuth.CreateWnd;
var
  LThemingServices: IOTAIDEThemingServices;
  LActiveTheme: string;
begin
  inherited CreateWnd;
  LActiveTheme := 'light';
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
      LActiveTheme := LThemingServices.ActiveTheme;
  end;

  if SameText(LActiveTheme, 'dark') then
    TRadIAUIHelper.ApplyDarkTitleBar(Self, True);
end;

procedure TRadIAFormGithubAuth.FormShow(Sender: TObject);
begin
  StartPolling;
end;

procedure TRadIAFormGithubAuth.StartPolling;
var
  LForm: TRadIAFormGithubAuth;
  LDeviceCode: string;
  LInterval: Integer;
  LExpiresIn: Integer;
  LCancelledPtr: PBoolean;
begin
  LForm := Self;
  LDeviceCode := FDeviceCode;
  LInterval := FInterval;
  LExpiresIn := FExpiresIn;
  LCancelledPtr := @FCancelled;

  lblStatus.Caption := 'Waiting for authorization in your browser...';
  TTask.Run(
    procedure
    var
      LAccessToken, LErrorMsg: string;
      LSuccess: Boolean;
    begin
      LSuccess := TRadIAGithubCopilotProvider.PollForAccessToken(
        LDeviceCode, LInterval, LExpiresIn, LCancelledPtr, LAccessToken, LErrorMsg
      );

      TThread.Queue(nil,
        TThreadProcedure(
          procedure
          begin
            if LSuccess then
            begin
              LForm.FAccessToken := LAccessToken;
              LForm.ModalResult := mrOk;
            end
            else
            begin
              if not LForm.FCancelled then
              begin
                MessageDlg('Authentication failed: ' + LErrorMsg, mtError, [mbOK], 0);
                LForm.ModalResult := mrCancel;
              end;
            end;
          end
        )
      );
    end);
end;

procedure TRadIAFormGithubAuth.btnOpenBrowserClick(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar(FVerificationUri), nil, nil, SW_SHOWNORMAL);
end;

procedure TRadIAFormGithubAuth.btnCancelClick(Sender: TObject);
begin
  FCancelled := True;
  ModalResult := mrCancel;
end;

procedure TRadIAFormGithubAuth.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FCancelled := True;
end;

end.
