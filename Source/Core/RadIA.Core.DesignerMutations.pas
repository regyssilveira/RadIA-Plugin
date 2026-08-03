unit RadIA.Core.DesignerMutations;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Designer;

type
  TRadIAComponentLayoutPreview = record
  private
    FComponentName: string;
    FExpiresAtUtc: TDateTime;
    FFormFileName: string;
    FId: string;
    FOriginalBounds: TRadIAComponentBounds;
    FProposedBounds: TRadIAComponentBounds;
  public
    constructor Create(
      const AId: string;
      const AFormFileName: string;
      const AComponentName: string;
      const AOriginalBounds: TRadIAComponentBounds;
      const AProposedBounds: TRadIAComponentBounds;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property FormFileName: string read FFormFileName;
    property ComponentName: string read FComponentName;
    property OriginalBounds: TRadIAComponentBounds read FOriginalBounds;
    property ProposedBounds: TRadIAComponentBounds read FProposedBounds;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIAComponentLayoutResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAComponentLayoutPreview;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAComponentLayoutResult; static;
    class function Succeeded(
      const APreview: TRadIAComponentLayoutPreview
    ): TRadIAComponentLayoutResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAComponentLayoutPreview read FPreview;
  end;

  IRadIAComponentLayoutService = interface
    ['{E5850D66-C0F4-40DD-B49C-28D4C9E22FB6}']
    function Prepare(
      const AComponentName: string;
      const AProposedBounds: TRadIAComponentBounds
    ): TRadIAComponentLayoutResult;
    function Apply(
      const APreviewId: string
    ): TRadIAComponentLayoutResult;
    function Revert(
      const APreviewId: string
    ): TRadIAComponentLayoutResult;
    procedure Clear;
  end;

  TRadIAComponentLayoutService = class(
    TInterfacedObject,
    IRadIAComponentLayoutService
  )
  private
    FExpirationMinutes: Integer;
    FMutation: IRadIAFormDesignerMutationFacade;
    FPreviews: TDictionary<string, TRadIAComponentLayoutPreview>;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAComponentLayoutPreview
    ): TRadIAComponentLayoutResult;
    procedure RemoveExpiredPreviews;
    function ValidateBounds(
      const ABounds: TRadIAComponentBounds
    ): TRadIAComponentLayoutResult;
  public
    constructor Create(
      const AMutation: IRadIAFormDesignerMutationFacade;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function Prepare(
      const AComponentName: string;
      const AProposedBounds: TRadIAComponentBounds
    ): TRadIAComponentLayoutResult;
    function Apply(
      const APreviewId: string
    ): TRadIAComponentLayoutResult;
    function Revert(
      const APreviewId: string
    ): TRadIAComponentLayoutResult;
    procedure Clear;
  end;

implementation

uses
  System.DateUtils,
  System.SysUtils;

const
  CApplyFailed = 'apply_failed';
  CInvalidLayout = 'invalid_layout';
  CPreconditionFailed = 'precondition_failed';
  CPreviewExpired = 'preview_expired';
  CPreviewNotFound = 'preview_not_found';
  CResourceLimit = 'resource_limit';
  CMaxLayoutPreviews = 64;
  CMaxCoordinate = 32767;

{ TRadIAComponentLayoutPreview }

constructor TRadIAComponentLayoutPreview.Create(
  const AId: string;
  const AFormFileName: string;
  const AComponentName: string;
  const AOriginalBounds: TRadIAComponentBounds;
  const AProposedBounds: TRadIAComponentBounds;
  const AExpiresAtUtc: TDateTime
);
begin
  FId := AId;
  FFormFileName := AFormFileName;
  FComponentName := AComponentName;
  FOriginalBounds := AOriginalBounds;
  FProposedBounds := AProposedBounds;
  FExpiresAtUtc := AExpiresAtUtc;
end;

{ TRadIAComponentLayoutResult }

class function TRadIAComponentLayoutResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAComponentLayoutResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
  Result.FPreview := Default(TRadIAComponentLayoutPreview);
end;

class function TRadIAComponentLayoutResult.Succeeded(
  const APreview: TRadIAComponentLayoutPreview
): TRadIAComponentLayoutResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FPreview := APreview;
end;

{ TRadIAComponentLayoutService }

function TRadIAComponentLayoutService.Apply(
  const APreviewId: string
): TRadIAComponentLayoutResult;
var
  LActualBounds: TRadIAComponentBounds;
  LPreview: TRadIAComponentLayoutPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;

  if not FMutation.ApplyComponentBounds(
    LPreview.FormFileName,
    LPreview.ComponentName,
    LPreview.OriginalBounds,
    LPreview.ProposedBounds,
    LActualBounds
  ) then
  begin
    if LActualBounds.Equals(LPreview.OriginalBounds) then
      Exit(TRadIAComponentLayoutResult.Failed(
        CApplyFailed,
        'The Form Designer rejected the proposed layout.'
      ));
    Exit(TRadIAComponentLayoutResult.Failed(
      CPreconditionFailed,
      'The component layout changed after the preview.'
    ));
  end;
  Result := TRadIAComponentLayoutResult.Succeeded(LPreview);
end;

procedure TRadIAComponentLayoutService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

constructor TRadIAComponentLayoutService.Create(
  const AMutation: IRadIAFormDesignerMutationFacade;
  const AExpirationMinutes: Integer
);
begin
  inherited Create;
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if AExpirationMinutes <= 0 then
    raise EArgumentOutOfRangeException.Create('AExpirationMinutes');
  FMutation := AMutation;
  FExpirationMinutes := AExpirationMinutes;
  FPreviews :=
    TDictionary<string, TRadIAComponentLayoutPreview>.Create;
end;

destructor TRadIAComponentLayoutService.Destroy;
begin
  FPreviews.Free;
  inherited;
end;

function TRadIAComponentLayoutService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAComponentLayoutPreview
): TRadIAComponentLayoutResult;
begin
  APreview := Default(TRadIAComponentLayoutPreview);
  TMonitor.Enter(FPreviews);
  try
    if not FPreviews.TryGetValue(APreviewId, APreview) then
      Exit(TRadIAComponentLayoutResult.Failed(
        CPreviewNotFound,
        'Component layout preview was not found.'
      ));
    if TTimeZone.Local.ToUniversalTime(Now) >
      APreview.ExpiresAtUtc then
    begin
      FPreviews.Remove(APreviewId);
      Exit(TRadIAComponentLayoutResult.Failed(
        CPreviewExpired,
        'Component layout preview expired.'
      ));
    end;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAComponentLayoutResult.Succeeded(APreview);
end;

function TRadIAComponentLayoutService.Prepare(
  const AComponentName: string;
  const AProposedBounds: TRadIAComponentBounds
): TRadIAComponentLayoutResult;
var
  LFormFileName: string;
  LOriginalBounds: TRadIAComponentBounds;
  LPreview: TRadIAComponentLayoutPreview;
begin
  if Trim(AComponentName) = '' then
    Exit(TRadIAComponentLayoutResult.Failed(
      CInvalidLayout,
      'Component name must not be empty.'
    ));
  Result := ValidateBounds(AProposedBounds);
  if not Result.Success then
    Exit;

  RemoveExpiredPreviews;
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxLayoutPreviews then
      Exit(TRadIAComponentLayoutResult.Failed(
        CResourceLimit,
        'Too many component layout previews are active.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;

  if not FMutation.GetComponentBounds(
    AComponentName,
    LFormFileName,
    LOriginalBounds
  ) then
    Exit(TRadIAComponentLayoutResult.Failed(
      CPreconditionFailed,
      'The component is not available in the active Form Designer.'
    ));
  if LOriginalBounds.Equals(AProposedBounds) then
    Exit(TRadIAComponentLayoutResult.Failed(
      CInvalidLayout,
      'The proposed layout is identical to the current layout.'
    ));

  LPreview := TRadIAComponentLayoutPreview.Create(
    TGUID.NewGuid.ToString,
    LFormFileName,
    AComponentName,
    LOriginalBounds,
    AProposedBounds,
    IncMinute(
      TTimeZone.Local.ToUniversalTime(Now),
      FExpirationMinutes
    )
  );
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Add(LPreview.Id, LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAComponentLayoutResult.Succeeded(LPreview);
end;

procedure TRadIAComponentLayoutService.RemoveExpiredPreviews;
var
  LExpiredIds: TList<string>;
  LId: string;
  LPair: TPair<string, TRadIAComponentLayoutPreview>;
  LUtcNow: TDateTime;
begin
  LExpiredIds := TList<string>.Create;
  try
    LUtcNow := TTimeZone.Local.ToUniversalTime(Now);
    TMonitor.Enter(FPreviews);
    try
      for LPair in FPreviews do
      begin
        if LUtcNow > LPair.Value.ExpiresAtUtc then
          LExpiredIds.Add(LPair.Key);
      end;
      for LId in LExpiredIds do
        FPreviews.Remove(LId);
    finally
      TMonitor.Exit(FPreviews);
    end;
  finally
    LExpiredIds.Free;
  end;
end;

function TRadIAComponentLayoutService.Revert(
  const APreviewId: string
): TRadIAComponentLayoutResult;
var
  LActualBounds: TRadIAComponentBounds;
  LPreview: TRadIAComponentLayoutPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;

  if not FMutation.ApplyComponentBounds(
    LPreview.FormFileName,
    LPreview.ComponentName,
    LPreview.ProposedBounds,
    LPreview.OriginalBounds,
    LActualBounds
  ) then
  begin
    if LActualBounds.Equals(LPreview.ProposedBounds) then
      Exit(TRadIAComponentLayoutResult.Failed(
        CApplyFailed,
        'The Form Designer rejected the original layout.'
      ));
    Exit(TRadIAComponentLayoutResult.Failed(
      CPreconditionFailed,
      'The component layout changed after it was applied.'
    ));
  end;
  Result := TRadIAComponentLayoutResult.Succeeded(LPreview);
end;

function TRadIAComponentLayoutService.ValidateBounds(
  const ABounds: TRadIAComponentBounds
): TRadIAComponentLayoutResult;
begin
  if (ABounds.Left < -CMaxCoordinate) or
    (ABounds.Left > CMaxCoordinate) or
    (ABounds.Top < -CMaxCoordinate) or
    (ABounds.Top > CMaxCoordinate) then
    Exit(TRadIAComponentLayoutResult.Failed(
      CInvalidLayout,
      'Component coordinates exceed the supported range.'
    ));
  if (ABounds.Width < 1) or
    (ABounds.Width > CMaxCoordinate) or
    (ABounds.Height < 1) or
    (ABounds.Height > CMaxCoordinate) then
    Exit(TRadIAComponentLayoutResult.Failed(
      CInvalidLayout,
      'Component size must be between 1 and 32767.'
    ));
  Result := TRadIAComponentLayoutResult.Succeeded(
    Default(TRadIAComponentLayoutPreview)
  );
end;

end.
