unit RadIA.UI.ExtensionCatalogForm;

interface

uses
  Vcl.Forms;

function BrowseRadIAExtensionCatalog(
  AOwner: TForm;
  const ADataDirectory: string;
  out APackageFileName: string
): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  System.Threading,
  System.SyncObjs,
  ToolsAPI,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  RadIA.Core.ExtensionCatalog,
  RadIA.Core.Interfaces,
  RadIA.Core.Types;

type
  TRadIAExtensionCatalogBrowserForm = class(TForm)
  private
    FBusy: Boolean;
    FCloseButton: TButton;
    FDownloadedPackageFileName: string;
    FEntries: TArray<TRadIAExtensionCatalogEntry>;
    FInstallButton: TButton;
    FLifecycleGuard: IInterface;
    FListView: TListView;
    FLoadButton: TButton;
    FPreferences: TRadIAExtensionCatalogPreferences;
    FSearchEdit: TEdit;
    FStatusLabel: TLabel;
    FTopPanel: TPanel;
    FUrlEdit: TEdit;
    procedure ApplyCatalogResult(
      const AUrl: string;
      const ACatalog: TRadIAExtensionCatalog;
      const AError: string
    );
    procedure ApplyDownloadResult(
      const APackageFileName: string;
      const AError: string
    );
    procedure ApplyCurrentTheme;
    procedure CloseClick(Sender: TObject);
    class function DownloadPackage(
      const AEntry: TRadIAExtensionCatalogEntry;
      const AOutputFileName: string
    ): string; static;
    class procedure RunDownload(
      const AEntry: TRadIAExtensionCatalogEntry;
      const AOutputFileName: string;
      const AGuard: IRadIALifecycleGuard;
      const AForm: TRadIAExtensionCatalogBrowserForm
    ); static;
    procedure FormCloseQuery(
      Sender: TObject;
      var CanClose: Boolean
    );
    function GetSelectedEntry(
      out AEntry: TRadIAExtensionCatalogEntry
    ): Boolean;
    procedure InstallClick(Sender: TObject);
    procedure ListSelectItem(
      Sender: TObject;
      Item: TListItem;
      Selected: Boolean
    );
    procedure LoadClick(Sender: TObject);
    procedure LoadCatalogAsync(const AUrl: string);
    procedure RefreshEntries;
    procedure SearchChange(Sender: TObject);
    procedure SetBusy(
      const AValue: Boolean;
      const AStatus: string
    );
    procedure StartDownload(
      const AEntry: TRadIAExtensionCatalogEntry
    );
  protected
    procedure CreateWnd; override;
  public
    constructor Create(
      AOwner: TComponent;
      const ADataDirectory: string
    ); reintroduce;
    destructor Destroy; override;
    property DownloadedPackageFileName: string
      read FDownloadedPackageFileName;
  end;

function BrowseRadIAExtensionCatalog(
  AOwner: TForm;
  const ADataDirectory: string;
  out APackageFileName: string
): Boolean;
var
  LForm: TRadIAExtensionCatalogBrowserForm;
begin
  APackageFileName := '';
  LForm := TRadIAExtensionCatalogBrowserForm.Create(
    AOwner,
    ADataDirectory
  );
  try
    Result := LForm.ShowModal = mrOk;
    if Result then
      APackageFileName := LForm.DownloadedPackageFileName;
  finally
    LForm.Free;
  end;
end;

constructor TRadIAExtensionCatalogBrowserForm.Create(
  AOwner: TComponent;
  const ADataDirectory: string
);
var
  LFooterPanel: TPanel;
  LPreferencesError: string;
begin
  inherited CreateNew(AOwner);
  Caption := 'Rad IA - Extension Catalog';
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 900;
  ClientHeight := 500;
  Constraints.MinWidth := 700;
  Constraints.MinHeight := 380;
  OnCloseQuery := FormCloseQuery;
  FLifecycleGuard := TLifecycleGuard.Create;
  FPreferences := TRadIAExtensionCatalogPreferences.Create(
    TPath.Combine(ADataDirectory, 'extension-catalog.json')
  );

  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 76;
  FTopPanel.BevelOuter := bvNone;
  FTopPanel.ShowCaption := False;

  with TLabel.Create(Self) do
  begin
    Parent := FTopPanel;
    SetBounds(8, 12, 80, 20);
    Caption := 'Catalog URL';
  end;
  FUrlEdit := TEdit.Create(Self);
  FUrlEdit.Parent := FTopPanel;
  FUrlEdit.SetBounds(94, 8, 680, 25);
  FUrlEdit.Anchors := [akLeft, akTop, akRight];

  FLoadButton := TButton.Create(Self);
  FLoadButton.Parent := FTopPanel;
  FLoadButton.SetBounds(786, 7, 106, 27);
  FLoadButton.Anchors := [akTop, akRight];
  FLoadButton.Caption := 'Load catalog';
  FLoadButton.OnClick := LoadClick;

  with TLabel.Create(Self) do
  begin
    Parent := FTopPanel;
    SetBounds(8, 45, 80, 20);
    Caption := 'Search';
  end;
  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := FTopPanel;
  FSearchEdit.SetBounds(94, 41, 798, 25);
  FSearchEdit.Anchors := [akLeft, akTop, akRight];
  FSearchEdit.TextHint := 'Filter by extension, description, or publisher';
  FSearchEdit.OnChange := SearchChange;

  FListView := TListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ViewStyle := vsReport;
  FListView.ReadOnly := True;
  FListView.RowSelect := True;
  FListView.HideSelection := False;
  FListView.OnSelectItem := ListSelectItem;
  FListView.Columns.Add.Caption := 'Extension';
  FListView.Columns.Add.Caption := 'Version';
  FListView.Columns.Add.Caption := 'Publisher';
  FListView.Columns.Add.Caption := 'Description';
  FListView.Columns.Add.Caption := 'ID';
  FListView.Columns[0].Width := 180;
  FListView.Columns[1].Width := 80;
  FListView.Columns[2].Width := 180;
  FListView.Columns[3].Width := 430;
  FListView.Columns[4].Width := 0;

  LFooterPanel := TPanel.Create(Self);
  LFooterPanel.Parent := Self;
  LFooterPanel.Align := alBottom;
  LFooterPanel.Height := 52;
  LFooterPanel.BevelOuter := bvNone;
  LFooterPanel.ShowCaption := False;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := LFooterPanel;
  FStatusLabel.SetBounds(8, 17, 660, 24);
  FStatusLabel.Anchors := [akLeft, akTop, akRight];
  FStatusLabel.AutoSize := False;

  FInstallButton := TButton.Create(Self);
  FInstallButton.Parent := LFooterPanel;
  FInstallButton.SetBounds(686, 12, 110, 27);
  FInstallButton.Anchors := [akTop, akRight];
  FInstallButton.Caption := 'Download...';
  FInstallButton.Enabled := False;
  FInstallButton.OnClick := InstallClick;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := LFooterPanel;
  FCloseButton.SetBounds(804, 12, 88, 27);
  FCloseButton.Anchors := [akTop, akRight];
  FCloseButton.Caption := 'Close';
  FCloseButton.OnClick := CloseClick;

  try
    FUrlEdit.Text := FPreferences.LoadUrl;
  except
    on E: Exception do
      LPreferencesError := 'Saved catalog URL unavailable: ' + E.Message;
  end;
  if LPreferencesError <> '' then
    FStatusLabel.Caption := LPreferencesError
  else
    FStatusLabel.Caption := 'Enter an HTTPS catalog URL and click Load.';
end;

destructor TRadIAExtensionCatalogBrowserForm.Destroy;
begin
  (FLifecycleGuard as IRadIALifecycleGuard).Invalidate;
  if (ModalResult <> mrOk) and
    (FDownloadedPackageFileName <> '') and
    TFile.Exists(FDownloadedPackageFileName) then
    TFile.Delete(FDownloadedPackageFileName);
  FPreferences.Free;
  inherited Destroy;
end;

procedure TRadIAExtensionCatalogBrowserForm.ApplyCatalogResult(
  const AUrl: string;
  const ACatalog: TRadIAExtensionCatalog;
  const AError: string
);
begin
  SetBusy(False, '');
  if AError <> '' then
  begin
    FStatusLabel.Caption := 'Catalog rejected: ' + AError;
    Exit;
  end;
  FEntries := Copy(ACatalog.Entries);
  RefreshEntries;
  try
    FPreferences.SaveUrl(AUrl);
    FStatusLabel.Caption := Format(
      '%s loaded: %d extension(s).',
      [ACatalog.Name, Length(FEntries)]
    );
  except
    on E: Exception do
      FStatusLabel.Caption := Format(
        '%s loaded, but its URL could not be saved: %s',
        [ACatalog.Name, E.Message]
      );
  end;
end;

procedure TRadIAExtensionCatalogBrowserForm.ApplyCurrentTheme;
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

procedure TRadIAExtensionCatalogBrowserForm.ApplyDownloadResult(
  const APackageFileName: string;
  const AError: string
);
begin
  SetBusy(False, '');
  if AError <> '' then
  begin
    FStatusLabel.Caption := 'Package rejected: ' + AError;
    Exit;
  end;
  FDownloadedPackageFileName := APackageFileName;
  ModalResult := mrOk;
end;

procedure TRadIAExtensionCatalogBrowserForm.CloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TRadIAExtensionCatalogBrowserForm.CreateWnd;
begin
  inherited CreateWnd;
  ApplyCurrentTheme;
end;

class function TRadIAExtensionCatalogBrowserForm.DownloadPackage(
  const AEntry: TRadIAExtensionCatalogEntry;
  const AOutputFileName: string
): string;
var
  LClient: TRadIAExtensionCatalogClient;
begin
  Result := '';
  try
    LClient := TRadIAExtensionCatalogClient.Create;
    try
      LClient.DownloadAndVerify(AEntry, AOutputFileName);
    finally
      LClient.Free;
    end;
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TRadIAExtensionCatalogBrowserForm.FormCloseQuery(
  Sender: TObject;
  var CanClose: Boolean
);
begin
  CanClose := not FBusy;
  if not CanClose then
    FStatusLabel.Caption := 'Wait for the current catalog operation.';
end;

function TRadIAExtensionCatalogBrowserForm.GetSelectedEntry(
  out AEntry: TRadIAExtensionCatalogEntry
): Boolean;
var
  LEntry: TRadIAExtensionCatalogEntry;
  LExtensionId: string;
begin
  AEntry := Default(TRadIAExtensionCatalogEntry);
  Result := Assigned(FListView.Selected);
  if not Result then
    Exit;
  LExtensionId := FListView.Selected.SubItems[3];
  for LEntry in FEntries do
    if SameText(LEntry.ExtensionId, LExtensionId) then
    begin
      AEntry := LEntry;
      Exit(True);
    end;
  Result := False;
end;

procedure TRadIAExtensionCatalogBrowserForm.InstallClick(
  Sender: TObject
);
var
  LEntry: TRadIAExtensionCatalogEntry;
begin
  if GetSelectedEntry(LEntry) then
    StartDownload(LEntry);
end;

procedure TRadIAExtensionCatalogBrowserForm.ListSelectItem(
  Sender: TObject;
  Item: TListItem;
  Selected: Boolean
);
begin
  FInstallButton.Enabled := Selected and not FBusy;
end;

procedure TRadIAExtensionCatalogBrowserForm.LoadCatalogAsync(
  const AUrl: string
);
var
  LGuard: IRadIALifecycleGuard;
begin
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  SetBusy(True, 'Loading and validating catalog...');
  TInterlocked.Increment(GActiveThreadCount);
  try
    TTask.Run(
      procedure
      var
        LCatalog: TRadIAExtensionCatalog;
        LClient: TRadIAExtensionCatalogClient;
        LError: string;
      begin
        try
          try
            LClient := TRadIAExtensionCatalogClient.Create;
            try
              LCatalog := LClient.Load(AUrl);
            finally
              LClient.Free;
            end;
          except
            on E: Exception do
              LError := E.Message;
          end;
          if not GIsShuttingDown then
            TThread.Queue(
              nil,
              procedure
              begin
                if LGuard.IsAlive then
                  ApplyCatalogResult(AUrl, LCatalog, LError);
              end
            );
        finally
          TInterlocked.Decrement(GActiveThreadCount);
        end;
      end
    );
  except
    TInterlocked.Decrement(GActiveThreadCount);
    SetBusy(False, 'Unable to start the catalog operation.');
    raise;
  end;
end;

procedure TRadIAExtensionCatalogBrowserForm.LoadClick(Sender: TObject);
var
  LUrl: string;
begin
  LUrl := Trim(FUrlEdit.Text);
  if LUrl = '' then
  begin
    FStatusLabel.Caption := 'Catalog URL is required.';
    Exit;
  end;
  LoadCatalogAsync(LUrl);
end;

procedure TRadIAExtensionCatalogBrowserForm.RefreshEntries;
var
  LEntry: TRadIAExtensionCatalogEntry;
  LFilter: string;
  LIndex: Integer;
  LItem: TListItem;
  LSearchable: string;
begin
  LFilter := LowerCase(Trim(FSearchEdit.Text));
  FListView.Items.BeginUpdate;
  try
    FListView.Items.Clear;
    for LIndex := 0 to Length(FEntries) - 1 do
    begin
      LEntry := FEntries[LIndex];
      LSearchable := LowerCase(
        LEntry.Name + ' ' + LEntry.ExtensionId + ' ' +
        LEntry.Description + ' ' + LEntry.PublisherName
      );
      if (LFilter <> '') and not LSearchable.Contains(LFilter) then
        Continue;
      LItem := FListView.Items.Add;
      LItem.Caption := LEntry.Name;
      LItem.SubItems.Add(LEntry.Version);
      LItem.SubItems.Add(LEntry.PublisherName);
      LItem.SubItems.Add(LEntry.Description);
      LItem.SubItems.Add(LEntry.ExtensionId);
    end;
  finally
    FListView.Items.EndUpdate;
  end;
  FInstallButton.Enabled := False;
end;

procedure TRadIAExtensionCatalogBrowserForm.SearchChange(
  Sender: TObject
);
begin
  RefreshEntries;
end;

class procedure TRadIAExtensionCatalogBrowserForm.RunDownload(
  const AEntry: TRadIAExtensionCatalogEntry;
  const AOutputFileName: string;
  const AGuard: IRadIALifecycleGuard;
  const AForm: TRadIAExtensionCatalogBrowserForm
);
var
  LError: string;
begin
  LError := DownloadPackage(AEntry, AOutputFileName);
  if not GIsShuttingDown then
    TThread.Queue(
      nil,
      procedure
      begin
        if AGuard.IsAlive then
          AForm.ApplyDownloadResult(AOutputFileName, LError)
        else if TFile.Exists(AOutputFileName) then
          TFile.Delete(AOutputFileName);
      end
    )
  else if TFile.Exists(AOutputFileName) then
    TFile.Delete(AOutputFileName);
end;

procedure TRadIAExtensionCatalogBrowserForm.SetBusy(
  const AValue: Boolean;
  const AStatus: string
);
begin
  FBusy := AValue;
  FUrlEdit.Enabled := not AValue;
  FLoadButton.Enabled := not AValue;
  FSearchEdit.Enabled := not AValue;
  FListView.Enabled := not AValue;
  FCloseButton.Enabled := not AValue;
  FInstallButton.Enabled := not AValue and Assigned(FListView.Selected);
  if AStatus <> '' then
    FStatusLabel.Caption := AStatus;
end;

procedure TRadIAExtensionCatalogBrowserForm.StartDownload(
  const AEntry: TRadIAExtensionCatalogEntry
);
var
  LGuard: IRadIALifecycleGuard;
  LOutputFileName: string;
begin
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  LOutputFileName := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-Catalog-' + TGUID.NewGuid.ToString + '.radiaext'
  );
  SetBusy(True, 'Downloading and verifying signed package...');
  TInterlocked.Increment(GActiveThreadCount);
  try
    TTask.Run(
      procedure
      begin
        try
          RunDownload(AEntry, LOutputFileName, LGuard, Self);
        finally
          TInterlocked.Decrement(GActiveThreadCount);
        end;
      end
    );
  except
    TInterlocked.Decrement(GActiveThreadCount);
    SetBusy(False, 'Unable to start the package download.');
    raise;
  end;
end;

end.
