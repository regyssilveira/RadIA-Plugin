unit RadIA.Core.DesignerVisualDiff;

interface

uses
  RadIA.Core.Designer;

type
  TRadIADesignerVisualChangeKind = (
    dvkAdded,
    dvkRemoved,
    dvkMoved,
    dvkResized,
    dvkReparented,
    dvkClassChanged,
    dvkPropertyChanged,
    dvkSelectionChanged
  );

  TRadIADesignerVisualChange = record
  private
    FAfter: TRadIAFormComponentSnapshot;
    FBefore: TRadIAFormComponentSnapshot;
    FComponentName: string;
    FKind: TRadIADesignerVisualChangeKind;
  public
    constructor Create(
      const AKind: TRadIADesignerVisualChangeKind;
      const AComponentName: string;
      const ABefore: TRadIAFormComponentSnapshot;
      const AAfter: TRadIAFormComponentSnapshot
    );
    property Kind: TRadIADesignerVisualChangeKind read FKind;
    property ComponentName: string read FComponentName;
    property Before: TRadIAFormComponentSnapshot read FBefore;
    property After: TRadIAFormComponentSnapshot read FAfter;
  end;

  TRadIADesignerVisualSnapshot = record
  private
    FComponents: TArray<TRadIAFormComponentSnapshot>;
    FCreatedAtUtc: TDateTime;
    FFormClassName: string;
    FFormName: string;
    FId: string;
  public
    constructor Create(
      const AId: string;
      const AFormName: string;
      const AFormClassName: string;
      const ACreatedAtUtc: TDateTime;
      const AComponents: TArray<TRadIAFormComponentSnapshot>
    );
    property Id: string read FId;
    property FormName: string read FFormName;
    property FormClassName: string read FFormClassName;
    property CreatedAtUtc: TDateTime read FCreatedAtUtc;
    property Components: TArray<TRadIAFormComponentSnapshot> read FComponents;
  end;

  TRadIADesignerVisualDiffState = (
    dvsPrepared,
    dvsAccepted,
    dvsRejected
  );

  TRadIADesignerVisualComparison = record
  private
    FAfterId: string;
    FBeforeId: string;
    FChanges: TArray<TRadIADesignerVisualChange>;
    FId: string;
    FState: TRadIADesignerVisualDiffState;
  public
    constructor Create(
      const AId: string;
      const ABeforeId: string;
      const AAfterId: string;
      const AChanges: TArray<TRadIADesignerVisualChange>
    );
    procedure SetState(const AState: TRadIADesignerVisualDiffState);
    property Id: string read FId;
    property BeforeId: string read FBeforeId;
    property AfterId: string read FAfterId;
    property Changes: TArray<TRadIADesignerVisualChange> read FChanges;
    property State: TRadIADesignerVisualDiffState read FState;
  end;

  IRadIADesignerVisualDiffService = interface
    ['{9437394F-71B0-4638-8F88-0F3EB4B0A63A}']
    function Capture: TRadIADesignerVisualSnapshot;
    function Compare(
      const ABeforeId: string;
      const AAfterId: string
    ): TArray<TRadIADesignerVisualChange>;
    function PrepareComparison(
      const ABeforeId: string;
      const AAfterId: string
    ): TRadIADesignerVisualComparison;
    function Decide(
      const AComparisonId: string;
      const AAccept: Boolean
    ): TRadIADesignerVisualComparison;
    procedure Clear;
  end;

  TRadIADesignerVisualDiffService = class(
    TInterfacedObject,
    IRadIADesignerVisualDiffService
  )
  private
    FDesigner: IRadIAFormDesignerFacade;
    FComparisons: TArray<TRadIADesignerVisualComparison>;
    FSnapshots: TArray<TRadIADesignerVisualSnapshot>;
    function FindSnapshot(
      const AId: string;
      out ASnapshot: TRadIADesignerVisualSnapshot
    ): Boolean;
    function FindComparisonIndex(const AId: string): Integer;
  public
    constructor Create(const ADesigner: IRadIAFormDesignerFacade);
    function Capture: TRadIADesignerVisualSnapshot;
    function Compare(
      const ABeforeId: string;
      const AAfterId: string
    ): TArray<TRadIADesignerVisualChange>;
    function PrepareComparison(
      const ABeforeId: string;
      const AAfterId: string
    ): TRadIADesignerVisualComparison;
    function Decide(
      const AComparisonId: string;
      const AAccept: Boolean
    ): TRadIADesignerVisualComparison;
    procedure Clear;
  end;

function RadIADesignerVisualChangeKindName(
  const AKind: TRadIADesignerVisualChangeKind
): string;
function RadIADesignerVisualDiffStateName(
  const AState: TRadIADesignerVisualDiffState
): string;

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.SysUtils;

const
  CMaxComponents = 1000;
  CMaxSnapshots = 20;
  CMaxComparisons = 20;

function RadIADesignerVisualChangeKindName(
  const AKind: TRadIADesignerVisualChangeKind
): string;
begin
  case AKind of
    dvkAdded: Result := 'added';
    dvkRemoved: Result := 'removed';
    dvkMoved: Result := 'moved';
    dvkResized: Result := 'resized';
    dvkReparented: Result := 'reparented';
    dvkClassChanged: Result := 'classChanged';
    dvkPropertyChanged: Result := 'propertyChanged';
    dvkSelectionChanged: Result := 'selectionChanged';
  else
    Result := 'unknown';
  end;
end;

function RadIADesignerVisualDiffStateName(
  const AState: TRadIADesignerVisualDiffState
): string;
begin
  case AState of
    dvsPrepared: Result := 'prepared';
    dvsAccepted: Result := 'accepted';
    dvsRejected: Result := 'rejected';
  else
    Result := 'unknown';
  end;
end;

procedure AddChange(
  const AChanges: TList<TRadIADesignerVisualChange>;
  const AKind: TRadIADesignerVisualChangeKind;
  const ABefore: TRadIAFormComponentSnapshot;
  const AAfter: TRadIAFormComponentSnapshot
);
var
  LName: string;
begin
  LName := AAfter.Name;
  if LName = '' then
    LName := ABefore.Name;
  AChanges.Add(
    TRadIADesignerVisualChange.Create(
      AKind,
      LName,
      ABefore,
      AAfter
    )
  );
end;

function ToMap(
  const AComponents: TArray<TRadIAFormComponentSnapshot>
): TDictionary<string, TRadIAFormComponentSnapshot>;
var
  LComponent: TRadIAFormComponentSnapshot;
begin
  Result := TDictionary<string, TRadIAFormComponentSnapshot>.Create;
  for LComponent in AComponents do
    Result.AddOrSetValue(LowerCase(LComponent.Name), LComponent);
end;

function PropertiesEqual(
  const ABefore: TArray<TRadIAComponentPropertyValue>;
  const AAfter: TArray<TRadIAComponentPropertyValue>
): Boolean;
var
  LAfter: TRadIAComponentPropertyValue;
  LBefore: TRadIAComponentPropertyValue;
  LFound: Boolean;
begin
  if Length(ABefore) <> Length(AAfter) then
    Exit(False);
  for LBefore in ABefore do
  begin
    LFound := False;
    for LAfter in AAfter do
      if SameText(LBefore.Name, LAfter.Name) then
      begin
        if not LBefore.Equals(LAfter) then
          Exit(False);
        LFound := True;
        Break;
      end;
    if not LFound then
      Exit(False);
  end;
  Result := True;
end;

procedure CompareExistingComponent(
  const ABefore: TRadIAFormComponentSnapshot;
  const AAfter: TRadIAFormComponentSnapshot;
  const AChanges: TList<TRadIADesignerVisualChange>
);
begin
  if not SameText(ABefore.ClassName, AAfter.ClassName) then
    AddChange(AChanges, dvkClassChanged, ABefore, AAfter);
  if not SameText(ABefore.ParentName, AAfter.ParentName) then
    AddChange(AChanges, dvkReparented, ABefore, AAfter);
  if not PropertiesEqual(ABefore.Properties, AAfter.Properties) then
    AddChange(AChanges, dvkPropertyChanged, ABefore, AAfter);
  if (ABefore.Left <> AAfter.Left) or (ABefore.Top <> AAfter.Top) then
    AddChange(AChanges, dvkMoved, ABefore, AAfter);
  if (ABefore.Width <> AAfter.Width) or (ABefore.Height <> AAfter.Height) then
    AddChange(AChanges, dvkResized, ABefore, AAfter);
  if ABefore.Selected <> AAfter.Selected then
    AddChange(AChanges, dvkSelectionChanged, ABefore, AAfter);
end;

procedure CompareBeforeComponents(
  const ABeforeMap: TDictionary<string, TRadIAFormComponentSnapshot>;
  const AAfterMap: TDictionary<string, TRadIAFormComponentSnapshot>;
  const AChanges: TList<TRadIADesignerVisualChange>
);
var
  LAfter: TRadIAFormComponentSnapshot;
  LPair: TPair<string, TRadIAFormComponentSnapshot>;
begin
  for LPair in ABeforeMap do
    if AAfterMap.TryGetValue(LPair.Key, LAfter) then
      CompareExistingComponent(LPair.Value, LAfter, AChanges)
    else
      AddChange(
        AChanges,
        dvkRemoved,
        LPair.Value,
        Default(TRadIAFormComponentSnapshot)
      );
end;

procedure CompareAddedComponents(
  const ABeforeMap: TDictionary<string, TRadIAFormComponentSnapshot>;
  const AAfterMap: TDictionary<string, TRadIAFormComponentSnapshot>;
  const AChanges: TList<TRadIADesignerVisualChange>
);
var
  LPair: TPair<string, TRadIAFormComponentSnapshot>;
begin
  for LPair in AAfterMap do
    if not ABeforeMap.ContainsKey(LPair.Key) then
      AddChange(
        AChanges,
        dvkAdded,
        Default(TRadIAFormComponentSnapshot),
        LPair.Value
      );
end;

{ TRadIADesignerVisualChange }

constructor TRadIADesignerVisualChange.Create(
  const AKind: TRadIADesignerVisualChangeKind;
  const AComponentName: string;
  const ABefore: TRadIAFormComponentSnapshot;
  const AAfter: TRadIAFormComponentSnapshot
);
begin
  FKind := AKind;
  FComponentName := AComponentName;
  FBefore := ABefore;
  FAfter := AAfter;
end;

{ TRadIADesignerVisualSnapshot }

constructor TRadIADesignerVisualSnapshot.Create(
  const AId: string;
  const AFormName: string;
  const AFormClassName: string;
  const ACreatedAtUtc: TDateTime;
  const AComponents: TArray<TRadIAFormComponentSnapshot>
);
begin
  FId := AId;
  FFormName := AFormName;
  FFormClassName := AFormClassName;
  FCreatedAtUtc := ACreatedAtUtc;
  FComponents := AComponents;
end;

{ TRadIADesignerVisualComparison }

constructor TRadIADesignerVisualComparison.Create(
  const AId: string;
  const ABeforeId: string;
  const AAfterId: string;
  const AChanges: TArray<TRadIADesignerVisualChange>
);
begin
  FId := AId;
  FBeforeId := ABeforeId;
  FAfterId := AAfterId;
  FChanges := Copy(AChanges);
  FState := dvsPrepared;
end;

procedure TRadIADesignerVisualComparison.SetState(
  const AState: TRadIADesignerVisualDiffState
);
begin
  FState := AState;
end;

{ TRadIADesignerVisualDiffService }

function TRadIADesignerVisualDiffService.Capture:
  TRadIADesignerVisualSnapshot;
var
  LForm: TRadIAFormSnapshot;
  LIndex: Integer;
begin
  LForm := FDesigner.GetActiveForm;
  if not LForm.Available then
    raise EInvalidOpException.Create('An active Form Designer is required.');
  Result := TRadIADesignerVisualSnapshot.Create(
    TGUID.NewGuid.ToString,
    LForm.Name,
    LForm.ClassName,
    TTimeZone.Local.ToUniversalTime(Now),
    FDesigner.ListFormComponents(CMaxComponents)
  );
  if Length(FSnapshots) = CMaxSnapshots then
  begin
    for LIndex := 1 to High(FSnapshots) do
      FSnapshots[LIndex - 1] := FSnapshots[LIndex];
    SetLength(FSnapshots, CMaxSnapshots - 1);
  end;
  SetLength(FSnapshots, Length(FSnapshots) + 1);
  FSnapshots[High(FSnapshots)] := Result;
end;

procedure TRadIADesignerVisualDiffService.Clear;
begin
  SetLength(FSnapshots, 0);
  SetLength(FComparisons, 0);
end;

function TRadIADesignerVisualDiffService.Compare(
  const ABeforeId: string;
  const AAfterId: string
): TArray<TRadIADesignerVisualChange>;
var
  LAfterMap: TDictionary<string, TRadIAFormComponentSnapshot>;
  LBeforeMap: TDictionary<string, TRadIAFormComponentSnapshot>;
  LChanges: TList<TRadIADesignerVisualChange>;
  LSnapshotAfter: TRadIADesignerVisualSnapshot;
  LSnapshotBefore: TRadIADesignerVisualSnapshot;
begin
  if not FindSnapshot(ABeforeId, LSnapshotBefore) or
    not FindSnapshot(AAfterId, LSnapshotAfter) then
    raise EArgumentException.Create('Designer visual snapshot was not found.');
  if not SameText(LSnapshotBefore.FormClassName, LSnapshotAfter.FormClassName) then
    raise EArgumentException.Create('Designer visual snapshots belong to different forms.');
  LBeforeMap := ToMap(LSnapshotBefore.Components);
  LAfterMap := ToMap(LSnapshotAfter.Components);
  LChanges := TList<TRadIADesignerVisualChange>.Create;
  try
    CompareBeforeComponents(LBeforeMap, LAfterMap, LChanges);
    CompareAddedComponents(LBeforeMap, LAfterMap, LChanges);
    Result := LChanges.ToArray;
  finally
    LChanges.Free;
    LAfterMap.Free;
    LBeforeMap.Free;
  end;
end;

function TRadIADesignerVisualDiffService.Decide(
  const AComparisonId: string;
  const AAccept: Boolean
): TRadIADesignerVisualComparison;
var
  LIndex: Integer;
begin
  LIndex := FindComparisonIndex(AComparisonId);
  if LIndex < 0 then
    raise EArgumentException.Create('Designer visual comparison was not found.');
  if FComparisons[LIndex].State <> dvsPrepared then
    raise EInvalidOpException.Create(
      'Designer visual comparison was already decided.'
    );
  if AAccept then
    FComparisons[LIndex].SetState(dvsAccepted)
  else
    FComparisons[LIndex].SetState(dvsRejected);
  Result := FComparisons[LIndex];
end;

constructor TRadIADesignerVisualDiffService.Create(
  const ADesigner: IRadIAFormDesignerFacade
);
begin
  inherited Create;
  if not Assigned(ADesigner) then
    raise EArgumentNilException.Create('ADesigner');
  FDesigner := ADesigner;
end;

function TRadIADesignerVisualDiffService.FindSnapshot(
  const AId: string;
  out ASnapshot: TRadIADesignerVisualSnapshot
): Boolean;
var
  LSnapshot: TRadIADesignerVisualSnapshot;
begin
  for LSnapshot in FSnapshots do
    if SameText(LSnapshot.Id, AId) then
    begin
      ASnapshot := LSnapshot;
      Exit(True);
    end;
  ASnapshot := Default(TRadIADesignerVisualSnapshot);
  Result := False;
end;

function TRadIADesignerVisualDiffService.FindComparisonIndex(
  const AId: string
): Integer;
var
  LIndex: Integer;
begin
  for LIndex := Low(FComparisons) to High(FComparisons) do
    if SameText(FComparisons[LIndex].Id, AId) then
      Exit(LIndex);
  Result := -1;
end;

function TRadIADesignerVisualDiffService.PrepareComparison(
  const ABeforeId: string;
  const AAfterId: string
): TRadIADesignerVisualComparison;
var
  LIndex: Integer;
begin
  Result := TRadIADesignerVisualComparison.Create(
    TGUID.NewGuid.ToString,
    ABeforeId,
    AAfterId,
    Compare(ABeforeId, AAfterId)
  );
  if Length(FComparisons) = CMaxComparisons then
  begin
    for LIndex := 1 to High(FComparisons) do
      FComparisons[LIndex - 1] := FComparisons[LIndex];
    SetLength(FComparisons, CMaxComparisons - 1);
  end;
  SetLength(FComparisons, Length(FComparisons) + 1);
  FComparisons[High(FComparisons)] := Result;
end;

end.
