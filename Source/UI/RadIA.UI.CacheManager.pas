unit RadIA.UI.CacheManager;

interface

uses
  RadIA.Core.Interfaces;

type
  TRadIACacheManagerForm = class
  public
    class procedure ShowManager(const AService: IRadIAService); static;
  end;

implementation

uses
  RadIA.Core.Cache,
  System.Classes,
  System.SysUtils,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TRadIACacheManagerWindow = class(TForm)
  private
    FCacheList: TListView;
    FClearAllButton: TButton;
    FCloseButton: TButton;
    FRefreshButton: TButton;
    FRemoveButton: TButton;
    FService: IRadIAService;
    FSummaryLabel: TLabel;
    procedure ClearAllClick(Sender: TObject);
    procedure RefreshClick(Sender: TObject);
    procedure RefreshEntries;
    procedure RemoveSelectedClick(Sender: TObject);
  public
    constructor Create(
      AOwner: TComponent;
      const AService: IRadIAService
    ); reintroduce;
  end;

constructor TRadIACacheManagerWindow.Create(
  AOwner: TComponent;
  const AService: IRadIAService
);
begin
  inherited CreateNew(AOwner);
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
  Caption := 'Rad IA Cache Manager';
  ClientHeight := 430;
  ClientWidth := 760;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;

  FSummaryLabel := TLabel.Create(Self);
  FSummaryLabel.Parent := Self;
  FSummaryLabel.SetBounds(12, 12, 730, 32);
  FSummaryLabel.AutoSize := False;
  FSummaryLabel.WordWrap := True;

  FCacheList := TListView.Create(Self);
  FCacheList.Parent := Self;
  FCacheList.SetBounds(12, 52, 736, 326);
  FCacheList.Anchors := [akLeft, akTop, akRight, akBottom];
  FCacheList.ReadOnly := True;
  FCacheList.RowSelect := True;
  FCacheList.ViewStyle := vsReport;
  FCacheList.Columns.Add.Caption := 'Entry';
  FCacheList.Columns[0].Width := 250;
  FCacheList.Columns.Add.Caption := 'Characters';
  FCacheList.Columns[1].Width := 90;
  FCacheList.Columns.Add.Caption := 'Created';
  FCacheList.Columns[2].Width := 150;
  FCacheList.Columns.Add.Caption := 'Last used';
  FCacheList.Columns[3].Width := 150;

  FRefreshButton := TButton.Create(Self);
  FRefreshButton.Parent := Self;
  FRefreshButton.SetBounds(12, 390, 90, 28);
  FRefreshButton.Anchors := [akLeft, akBottom];
  FRefreshButton.Caption := 'Refresh';
  FRefreshButton.OnClick := RefreshClick;

  FRemoveButton := TButton.Create(Self);
  FRemoveButton.Parent := Self;
  FRemoveButton.SetBounds(110, 390, 120, 28);
  FRemoveButton.Anchors := [akLeft, akBottom];
  FRemoveButton.Caption := 'Remove selected';
  FRemoveButton.OnClick := RemoveSelectedClick;

  FClearAllButton := TButton.Create(Self);
  FClearAllButton.Parent := Self;
  FClearAllButton.SetBounds(238, 390, 100, 28);
  FClearAllButton.Anchors := [akLeft, akBottom];
  FClearAllButton.Caption := 'Clear all';
  FClearAllButton.OnClick := ClearAllClick;

  FCloseButton := TButton.Create(Self);
  FCloseButton.Parent := Self;
  FCloseButton.SetBounds(658, 390, 90, 28);
  FCloseButton.Anchors := [akRight, akBottom];
  FCloseButton.Caption := 'Close';
  FCloseButton.ModalResult := mrClose;
  RefreshEntries;
end;

procedure TRadIACacheManagerWindow.ClearAllClick(Sender: TObject);
begin
  if MessageDlg(
    'Clear every local AI response cache entry? Entries will be rebuilt by future requests.',
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  FService.ClearCache;
  RefreshEntries;
end;

procedure TRadIACacheManagerWindow.RefreshClick(Sender: TObject);
begin
  RefreshEntries;
end;

procedure TRadIACacheManagerWindow.RefreshEntries;
var
  LEntry: TRadIACacheEntrySnapshot;
  LEntries: TArray<TRadIACacheEntrySnapshot>;
  LItem: TListItem;
  LTotalCharacters: Int64;
begin
  LEntries := FService.ListCacheEntries;
  LTotalCharacters := 0;
  FCacheList.Items.BeginUpdate;
  try
    FCacheList.Items.Clear;
    for LEntry in LEntries do
    begin
      LItem := FCacheList.Items.Add;
      LItem.Caption := LEntry.Hash;
      LItem.SubItems.Add(IntToStr(LEntry.ResponseCharacters));
      LItem.SubItems.Add(DateTimeToStr(LEntry.Timestamp));
      LItem.SubItems.Add(DateTimeToStr(LEntry.LastAccessed));
      LTotalCharacters := LTotalCharacters + LEntry.ResponseCharacters;
    end;
  finally
    FCacheList.Items.EndUpdate;
  end;
  FSummaryLabel.Caption := Format(
    '%d local AI response entries · %d characters. Removed entries are rebuilt on demand.',
    [Length(LEntries), LTotalCharacters]
  );
end;

procedure TRadIACacheManagerWindow.RemoveSelectedClick(Sender: TObject);
begin
  if not Assigned(FCacheList.Selected) then
    Exit;
  if MessageDlg(
    'Remove the selected local AI response cache entry?',
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  FService.RemoveCacheEntry(FCacheList.Selected.Caption);
  RefreshEntries;
end;

class procedure TRadIACacheManagerForm.ShowManager(
  const AService: IRadIAService
);
var
  LForm: TRadIACacheManagerWindow;
begin
  LForm := TRadIACacheManagerWindow.Create(nil, AService);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

end.
