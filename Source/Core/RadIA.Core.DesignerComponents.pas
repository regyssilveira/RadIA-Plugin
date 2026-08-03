unit RadIA.Core.DesignerComponents;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Designer;

type
  TRadIAComponentChangeKind = (cckAdd, cckRemove);

  TRadIAComponentChangePreview = record
  private
    FExpiresAtUtc: TDateTime;
    FFormFileName: string;
    FId: string;
    FKind: TRadIAComponentChangeKind;
    FSnapshot: TRadIAFormComponentSnapshot;
  public
    constructor Create(
      const AId: string;
      const AFormFileName: string;
      const AKind: TRadIAComponentChangeKind;
      const ASnapshot: TRadIAFormComponentSnapshot;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property FormFileName: string read FFormFileName;
    property Kind: TRadIAComponentChangeKind read FKind;
    property Snapshot: TRadIAFormComponentSnapshot read FSnapshot;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIAComponentChangeResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAComponentChangePreview;
    FSuccess: Boolean;
  public
    class function Failed(
      const ACode: string;
      const AMessage: string
    ): TRadIAComponentChangeResult; static;
    class function Succeeded(
      const APreview: TRadIAComponentChangePreview
    ): TRadIAComponentChangeResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAComponentChangePreview read FPreview;
  end;

  IRadIAComponentChangeService = interface
    ['{1918B0B6-435F-43D8-BFA7-C4355CC73D56}']
    function PrepareAdd(
      const AParentName: string;
      const AClassName: string;
      const AComponentName: string;
      const ABounds: TRadIAComponentBounds
    ): TRadIAComponentChangeResult;
    function PrepareRemove(
      const AComponentName: string
    ): TRadIAComponentChangeResult;
    function Apply(
      const APreviewId: string
    ): TRadIAComponentChangeResult;
    function Revert(
      const APreviewId: string
    ): TRadIAComponentChangeResult;
    procedure Clear;
  end;

  TRadIAComponentChangeService = class(
    TInterfacedObject,
    IRadIAComponentChangeService
  )
  private
    FExpirationMinutes: Integer;
    FFacade: IRadIAFormDesignerComponentFacade;
    FApplied: TDictionary<string, Boolean>;
    FPreviews: TDictionary<string, TRadIAComponentChangePreview>;
    function AddPreview(
      const AFormFileName: string;
      const AKind: TRadIAComponentChangeKind;
      const ASnapshot: TRadIAFormComponentSnapshot
    ): TRadIAComponentChangeResult;
    function CreateFromPreview(
      const APreview: TRadIAComponentChangePreview
    ): Boolean;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAComponentChangePreview
    ): TRadIAComponentChangeResult;
    function IsAllowedClass(const AClassName: string): Boolean;
    function IsValidIdentifier(const AValue: string): Boolean;
    function RemoveFromPreview(
      const APreview: TRadIAComponentChangePreview
    ): Boolean;
    procedure RemoveExpired;
  public
    constructor Create(
      const AFacade: IRadIAFormDesignerComponentFacade;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function PrepareAdd(
      const AParentName: string;
      const AClassName: string;
      const AComponentName: string;
      const ABounds: TRadIAComponentBounds
    ): TRadIAComponentChangeResult;
    function PrepareRemove(
      const AComponentName: string
    ): TRadIAComponentChangeResult;
    function Apply(
      const APreviewId: string
    ): TRadIAComponentChangeResult;
    function Revert(
      const APreviewId: string
    ): TRadIAComponentChangeResult;
    procedure Clear;
  end;

implementation

uses
  System.Character,
  System.DateUtils,
  System.SysUtils;

const
  CMaxPreviews = 64;
  CAllowedClasses: array[0..9] of string = (
    'TButton',
    'TCheckBox',
    'TComboBox',
    'TEdit',
    'TGroupBox',
    'TLabel',
    'TListBox',
    'TMemo',
    'TPanel',
    'TRadioButton'
  );

constructor TRadIAComponentChangePreview.Create(
  const AId: string;
  const AFormFileName: string;
  const AKind: TRadIAComponentChangeKind;
  const ASnapshot: TRadIAFormComponentSnapshot;
  const AExpiresAtUtc: TDateTime
);
begin
  FId := AId;
  FFormFileName := AFormFileName;
  FKind := AKind;
  FSnapshot := ASnapshot;
  FExpiresAtUtc := AExpiresAtUtc;
end;

class function TRadIAComponentChangeResult.Failed(
  const ACode: string;
  const AMessage: string
): TRadIAComponentChangeResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := ACode;
  Result.FErrorMessage := AMessage;
  Result.FPreview := Default(TRadIAComponentChangePreview);
end;

class function TRadIAComponentChangeResult.Succeeded(
  const APreview: TRadIAComponentChangePreview
): TRadIAComponentChangeResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FPreview := APreview;
end;

function TRadIAComponentChangeService.AddPreview(
  const AFormFileName: string;
  const AKind: TRadIAComponentChangeKind;
  const ASnapshot: TRadIAFormComponentSnapshot
): TRadIAComponentChangeResult;
var
  LPreview: TRadIAComponentChangePreview;
begin
  RemoveExpired;
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPreviews then
      Exit(TRadIAComponentChangeResult.Failed(
        'resource_limit',
        'Too many Form Designer component previews are active.'
      ));
    LPreview := TRadIAComponentChangePreview.Create(
      TGUID.NewGuid.ToString,
      AFormFileName,
      AKind,
      ASnapshot,
      IncMinute(
        TTimeZone.Local.ToUniversalTime(Now),
        FExpirationMinutes
      )
    );
    FPreviews.Add(LPreview.Id, LPreview);
    FApplied.Add(LPreview.Id, False);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAComponentChangeResult.Succeeded(LPreview);
end;

function TRadIAComponentChangeService.Apply(
  const APreviewId: string
): TRadIAComponentChangeResult;
var
  LPreview: TRadIAComponentChangePreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;
  TMonitor.Enter(FPreviews);
  try
    if FApplied[LPreview.Id] then
      Exit(TRadIAComponentChangeResult.Failed(
        'precondition_failed',
        'The Form Designer component preview was already applied.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;
  if LPreview.Kind = cckAdd then
  begin
    if not CreateFromPreview(LPreview) then
      Exit(TRadIAComponentChangeResult.Failed(
        'precondition_failed',
        'The component could not be created in the expected form state.'
      ));
  end
  else if not RemoveFromPreview(LPreview) then
    Exit(TRadIAComponentChangeResult.Failed(
      'precondition_failed',
      'The component no longer matches the reviewed removal preview.'
    ));
  TMonitor.Enter(FPreviews);
  try
    FApplied[LPreview.Id] := True;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAComponentChangeResult.Succeeded(LPreview);
end;

procedure TRadIAComponentChangeService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
    FApplied.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

constructor TRadIAComponentChangeService.Create(
  const AFacade: IRadIAFormDesignerComponentFacade;
  const AExpirationMinutes: Integer
);
begin
  inherited Create;
  if not Assigned(AFacade) then
    raise EArgumentNilException.Create('AFacade');
  if AExpirationMinutes <= 0 then
    raise EArgumentOutOfRangeException.Create('AExpirationMinutes');
  FFacade := AFacade;
  FExpirationMinutes := AExpirationMinutes;
  FApplied := TDictionary<string, Boolean>.Create;
  FPreviews := TDictionary<string, TRadIAComponentChangePreview>.Create;
end;

function TRadIAComponentChangeService.CreateFromPreview(
  const APreview: TRadIAComponentChangePreview
): Boolean;
var
  LActual: TRadIAFormComponentSnapshot;
  LBounds: TRadIAComponentBounds;
  LExisting: TRadIAFormComponentSnapshot;
  LFileName: string;
begin
  if FFacade.GetComponentSnapshot(
    APreview.Snapshot.Name,
    LFileName,
    LExisting
  ) then
    Exit(False);
  LBounds := TRadIAComponentBounds.Create(
    APreview.Snapshot.Left,
    APreview.Snapshot.Top,
    APreview.Snapshot.Width,
    APreview.Snapshot.Height
  );
  Result := FFacade.CreateComponent(
    APreview.FormFileName,
    APreview.Snapshot.ParentName,
    APreview.Snapshot.ClassName,
    APreview.Snapshot.Name,
    LBounds,
    LActual
  );
end;

destructor TRadIAComponentChangeService.Destroy;
begin
  FApplied.Free;
  FPreviews.Free;
  inherited;
end;

function TRadIAComponentChangeService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAComponentChangePreview
): TRadIAComponentChangeResult;
begin
  APreview := Default(TRadIAComponentChangePreview);
  TMonitor.Enter(FPreviews);
  try
    if not FPreviews.TryGetValue(APreviewId, APreview) then
      Exit(TRadIAComponentChangeResult.Failed(
        'preview_not_found',
        'Form Designer component preview was not found.'
      ));
    if TTimeZone.Local.ToUniversalTime(Now) > APreview.ExpiresAtUtc then
    begin
      FPreviews.Remove(APreviewId);
      FApplied.Remove(APreviewId);
      Exit(TRadIAComponentChangeResult.Failed(
        'preview_expired',
        'Form Designer component preview expired.'
      ));
    end;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAComponentChangeResult.Succeeded(APreview);
end;

function TRadIAComponentChangeService.IsAllowedClass(
  const AClassName: string
): Boolean;
var
  LAllowed: string;
begin
  for LAllowed in CAllowedClasses do
  begin
    if SameText(LAllowed, AClassName) then
      Exit(True);
  end;
  Result := False;
end;

function TRadIAComponentChangeService.IsValidIdentifier(
  const AValue: string
): Boolean;
var
  LCharacter: Char;
  LIndex: Integer;
begin
  if (AValue = '') or not (AValue[Low(AValue)].IsLetter or
    (AValue[Low(AValue)] = '_')) then
    Exit(False);
  for LIndex := Low(AValue) to High(AValue) do
  begin
    LCharacter := AValue[LIndex];
    if not (LCharacter.IsLetterOrDigit or (LCharacter = '_')) then
      Exit(False);
  end;
  Result := True;
end;

function TRadIAComponentChangeService.PrepareAdd(
  const AParentName: string;
  const AClassName: string;
  const AComponentName: string;
  const ABounds: TRadIAComponentBounds
): TRadIAComponentChangeResult;
var
  LExisting: TRadIAFormComponentSnapshot;
  LFileName: string;
  LParent: TRadIAFormComponentSnapshot;
  LSnapshot: TRadIAFormComponentSnapshot;
begin
  if not IsAllowedClass(AClassName) then
    Exit(TRadIAComponentChangeResult.Failed(
      'unsupported_component_class',
      'The component class is not in the safe VCL allowlist.'
    ));
  if not IsValidIdentifier(AComponentName) or
    not IsValidIdentifier(AParentName) then
    Exit(TRadIAComponentChangeResult.Failed(
      'invalid_component',
      'Component and parent names must be valid Pascal identifiers.'
    ));
  if (ABounds.Width < 1) or (ABounds.Height < 1) then
    Exit(TRadIAComponentChangeResult.Failed(
      'invalid_layout',
      'Component width and height must be positive.'
    ));
  if FFacade.GetComponentSnapshot(
    AComponentName,
    LFileName,
    LExisting
  ) then
    Exit(TRadIAComponentChangeResult.Failed(
      'precondition_failed',
      'A component with the requested name already exists.'
    ));
  if not FFacade.GetComponentSnapshot(
    AParentName,
    LFileName,
    LParent
  ) then
    Exit(TRadIAComponentChangeResult.Failed(
      'precondition_failed',
      'The requested parent is not available in the active Form Designer.'
    ));
  LSnapshot := TRadIAFormComponentSnapshot.Create(
    AComponentName,
    AClassName,
    AParentName,
    True,
    False,
    ABounds.Left,
    ABounds.Top
  );
  LSnapshot.SetSize(ABounds.Width, ABounds.Height);
  Result := AddPreview(LFileName, cckAdd, LSnapshot);
end;

function TRadIAComponentChangeService.PrepareRemove(
  const AComponentName: string
): TRadIAComponentChangeResult;
var
  LFileName: string;
  LSnapshot: TRadIAFormComponentSnapshot;
begin
  if not IsValidIdentifier(AComponentName) then
    Exit(TRadIAComponentChangeResult.Failed(
      'invalid_component',
      'Component name must be a valid Pascal identifier.'
    ));
  if not FFacade.GetComponentSnapshot(
    AComponentName,
    LFileName,
    LSnapshot
  ) then
    Exit(TRadIAComponentChangeResult.Failed(
      'precondition_failed',
      'The component is not available in the active Form Designer.'
    ));
  if not LSnapshot.IsControl or
    not IsAllowedClass(LSnapshot.ClassName) then
    Exit(TRadIAComponentChangeResult.Failed(
      'unsupported_component_class',
      'Only allowlisted visual VCL components can be removed.'
    ));
  Result := AddPreview(LFileName, cckRemove, LSnapshot);
end;

procedure TRadIAComponentChangeService.RemoveExpired;
var
  LIds: TList<string>;
  LPair: TPair<string, TRadIAComponentChangePreview>;
  LValue: string;
begin
  LIds := TList<string>.Create;
  try
    TMonitor.Enter(FPreviews);
    try
      for LPair in FPreviews do
      begin
        if TTimeZone.Local.ToUniversalTime(Now) >
          LPair.Value.ExpiresAtUtc then
          LIds.Add(LPair.Key);
      end;
      for LValue in LIds do
      begin
        FPreviews.Remove(LValue);
        FApplied.Remove(LValue);
      end;
    finally
      TMonitor.Exit(FPreviews);
    end;
  finally
    LIds.Free;
  end;
end;

function TRadIAComponentChangeService.RemoveFromPreview(
  const APreview: TRadIAComponentChangePreview
): Boolean;
var
  LActual: TRadIAFormComponentSnapshot;
begin
  Result := FFacade.RemoveComponent(
    APreview.FormFileName,
    APreview.Snapshot,
    LActual
  );
end;

function TRadIAComponentChangeService.Revert(
  const APreviewId: string
): TRadIAComponentChangeResult;
var
  LPreview: TRadIAComponentChangePreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;
  TMonitor.Enter(FPreviews);
  try
    if not FApplied[LPreview.Id] then
      Exit(TRadIAComponentChangeResult.Failed(
        'precondition_failed',
        'The Form Designer component preview has not been applied.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;

  if ((LPreview.Kind = cckAdd) and not RemoveFromPreview(LPreview)) or
    ((LPreview.Kind = cckRemove) and not CreateFromPreview(LPreview)) then
    Exit(TRadIAComponentChangeResult.Failed(
      'precondition_failed',
      'The component state changed after the operation was applied.'
    ));
  TMonitor.Enter(FPreviews);
  try
    FApplied[LPreview.Id] := False;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAComponentChangeResult.Succeeded(LPreview);
end;

end.
