unit RadIA.Core.DesignerProperties;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Designer;

type
  TRadIAComponentPropertyPreview = record
  private
    FComponentName: string;
    FExpiresAtUtc: TDateTime;
    FFormFileName: string;
    FId: string;
    FOriginalValue: TRadIAComponentPropertyValue;
    FProposedValue: TRadIAComponentPropertyValue;
  public
    constructor Create(
      const AId: string;
      const AFormFileName: string;
      const AComponentName: string;
      const AOriginalValue: TRadIAComponentPropertyValue;
      const AProposedValue: TRadIAComponentPropertyValue;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property FormFileName: string read FFormFileName;
    property ComponentName: string read FComponentName;
    property OriginalValue: TRadIAComponentPropertyValue read FOriginalValue;
    property ProposedValue: TRadIAComponentPropertyValue read FProposedValue;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIAComponentPropertyResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAComponentPropertyPreview;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAComponentPropertyResult; static;
    class function Succeeded(
      const APreview: TRadIAComponentPropertyPreview
    ): TRadIAComponentPropertyResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAComponentPropertyPreview read FPreview;
  end;

  IRadIAComponentPropertyService = interface
    ['{6F09E55C-1DE6-46CE-B0B7-C0FBCC5FA87D}']
    function Prepare(
      const AComponentName: string;
      const APropertyName: string;
      const AProposedValue: string
    ): TRadIAComponentPropertyResult;
    function Apply(
      const APreviewId: string
    ): TRadIAComponentPropertyResult;
    function Revert(
      const APreviewId: string
    ): TRadIAComponentPropertyResult;
    procedure Clear;
  end;

  TRadIAComponentPropertyService = class(
    TInterfacedObject,
    IRadIAComponentPropertyService
  )
  private
    FExpirationMinutes: Integer;
    FMutation: IRadIAFormDesignerMutationFacade;
    FPreviews: TDictionary<string, TRadIAComponentPropertyPreview>;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAComponentPropertyPreview
    ): TRadIAComponentPropertyResult;
    procedure RemoveExpiredPreviews;
  public
    constructor Create(
      const AMutation: IRadIAFormDesignerMutationFacade;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function Prepare(
      const AComponentName: string;
      const APropertyName: string;
      const AProposedValue: string
    ): TRadIAComponentPropertyResult;
    function Apply(
      const APreviewId: string
    ): TRadIAComponentPropertyResult;
    function Revert(
      const APreviewId: string
    ): TRadIAComponentPropertyResult;
    procedure Clear;
  end;

implementation

uses
  System.DateUtils,
  System.SysUtils;

const
  CApplyFailed = 'apply_failed';
  CInvalidProperty = 'invalid_property';
  CPreconditionFailed = 'precondition_failed';
  CPreviewExpired = 'preview_expired';
  CPreviewNotFound = 'preview_not_found';
  CResourceLimit = 'resource_limit';
  CMaxPropertyPreviews = 64;
  CMaxPropertyValueLength = 4096;

{ TRadIAComponentPropertyPreview }

constructor TRadIAComponentPropertyPreview.Create(
  const AId: string;
  const AFormFileName: string;
  const AComponentName: string;
  const AOriginalValue: TRadIAComponentPropertyValue;
  const AProposedValue: TRadIAComponentPropertyValue;
  const AExpiresAtUtc: TDateTime
);
begin
  FId := AId;
  FFormFileName := AFormFileName;
  FComponentName := AComponentName;
  FOriginalValue := AOriginalValue;
  FProposedValue := AProposedValue;
  FExpiresAtUtc := AExpiresAtUtc;
end;

{ TRadIAComponentPropertyResult }

class function TRadIAComponentPropertyResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAComponentPropertyResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
  Result.FPreview := Default(TRadIAComponentPropertyPreview);
end;

class function TRadIAComponentPropertyResult.Succeeded(
  const APreview: TRadIAComponentPropertyPreview
): TRadIAComponentPropertyResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FPreview := APreview;
end;

{ TRadIAComponentPropertyService }

function TRadIAComponentPropertyService.Apply(
  const APreviewId: string
): TRadIAComponentPropertyResult;
var
  LActualValue: TRadIAComponentPropertyValue;
  LPreview: TRadIAComponentPropertyPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;

  if not FMutation.ApplyComponentProperty(
    LPreview.FormFileName,
    LPreview.ComponentName,
    LPreview.OriginalValue,
    LPreview.ProposedValue,
    LActualValue
  ) then
  begin
    if LActualValue.Equals(LPreview.OriginalValue) then
      Exit(TRadIAComponentPropertyResult.Failed(
        CApplyFailed,
        'The Form Designer rejected the proposed property value.'
      ));
    Exit(TRadIAComponentPropertyResult.Failed(
      CPreconditionFailed,
      'The component property changed after the preview.'
    ));
  end;
  Result := TRadIAComponentPropertyResult.Succeeded(LPreview);
end;

procedure TRadIAComponentPropertyService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

constructor TRadIAComponentPropertyService.Create(
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
  FPreviews := TDictionary<string, TRadIAComponentPropertyPreview>.Create;
end;

destructor TRadIAComponentPropertyService.Destroy;
begin
  FPreviews.Free;
  inherited;
end;

function TRadIAComponentPropertyService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAComponentPropertyPreview
): TRadIAComponentPropertyResult;
begin
  APreview := Default(TRadIAComponentPropertyPreview);
  TMonitor.Enter(FPreviews);
  try
    if not FPreviews.TryGetValue(APreviewId, APreview) then
      Exit(TRadIAComponentPropertyResult.Failed(
        CPreviewNotFound,
        'Component property preview was not found.'
      ));
    if TTimeZone.Local.ToUniversalTime(Now) > APreview.ExpiresAtUtc then
    begin
      FPreviews.Remove(APreviewId);
      Exit(TRadIAComponentPropertyResult.Failed(
        CPreviewExpired,
        'Component property preview expired.'
      ));
    end;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAComponentPropertyResult.Succeeded(APreview);
end;

function TRadIAComponentPropertyService.Prepare(
  const AComponentName: string;
  const APropertyName: string;
  const AProposedValue: string
): TRadIAComponentPropertyResult;
var
  LFormFileName: string;
  LOriginalValue: TRadIAComponentPropertyValue;
  LPreview: TRadIAComponentPropertyPreview;
  LProposedValue: TRadIAComponentPropertyValue;
begin
  if (Trim(AComponentName) = '') or (Trim(APropertyName) = '') then
    Exit(TRadIAComponentPropertyResult.Failed(
      CInvalidProperty,
      'Component and property names must not be empty.'
    ));
  if Length(AProposedValue) > CMaxPropertyValueLength then
    Exit(TRadIAComponentPropertyResult.Failed(
      CInvalidProperty,
      'The proposed property value exceeds 4096 characters.'
    ));

  RemoveExpiredPreviews;
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPropertyPreviews then
      Exit(TRadIAComponentPropertyResult.Failed(
        CResourceLimit,
        'Too many component property previews are active.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;

  if not FMutation.GetComponentProperty(
    AComponentName,
    APropertyName,
    LFormFileName,
    LOriginalValue
  ) then
    Exit(TRadIAComponentPropertyResult.Failed(
      CPreconditionFailed,
      'The property is not safely editable in the active Form Designer.'
    ));

  LProposedValue := TRadIAComponentPropertyValue.Create(
    LOriginalValue.Name,
    LOriginalValue.TypeName,
    AProposedValue
  );
  if LOriginalValue.Equals(LProposedValue) then
    Exit(TRadIAComponentPropertyResult.Failed(
      CInvalidProperty,
      'The proposed value is identical to the current value.'
    ));

  LPreview := TRadIAComponentPropertyPreview.Create(
    TGUID.NewGuid.ToString,
    LFormFileName,
    AComponentName,
    LOriginalValue,
    LProposedValue,
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
  Result := TRadIAComponentPropertyResult.Succeeded(LPreview);
end;

procedure TRadIAComponentPropertyService.RemoveExpiredPreviews;
var
  LExpiredIds: TList<string>;
  LId: string;
  LPair: TPair<string, TRadIAComponentPropertyPreview>;
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

function TRadIAComponentPropertyService.Revert(
  const APreviewId: string
): TRadIAComponentPropertyResult;
var
  LActualValue: TRadIAComponentPropertyValue;
  LPreview: TRadIAComponentPropertyPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;

  if not FMutation.ApplyComponentProperty(
    LPreview.FormFileName,
    LPreview.ComponentName,
    LPreview.ProposedValue,
    LPreview.OriginalValue,
    LActualValue
  ) then
  begin
    if LActualValue.Equals(LPreview.ProposedValue) then
      Exit(TRadIAComponentPropertyResult.Failed(
        CApplyFailed,
        'The Form Designer rejected the original property value.'
      ));
    Exit(TRadIAComponentPropertyResult.Failed(
      CPreconditionFailed,
      'The component property changed after it was applied.'
    ));
  end;
  Result := TRadIAComponentPropertyResult.Succeeded(LPreview);
end;

end.
