unit RadIA.Core.DesignerEvents;

interface

uses
  System.Generics.Collections;

type
  TRadIAFormEventIdentity = record
  private
    FComponentName: string;
    FEventName: string;
    FEventTypeName: string;
    FFormFileName: string;
    FHandlerName: string;
    FUnitFileName: string;
  public
    constructor Create(
      const AFormFileName: string;
      const AUnitFileName: string;
      const AComponentName: string;
      const AEventName: string;
      const AEventTypeName: string;
      const AHandlerName: string
    );
    property FormFileName: string read FFormFileName;
    property UnitFileName: string read FUnitFileName;
    property ComponentName: string read FComponentName;
    property EventName: string read FEventName;
    property EventTypeName: string read FEventTypeName;
    property HandlerName: string read FHandlerName;
  end;

  TRadIAFormEventState = record
  private
    FAfterSource: string;
    FBeforeSource: string;
    FIdentity: TRadIAFormEventIdentity;
    FOriginalHandlerName: string;
  public
    constructor Create(
      const AIdentity: TRadIAFormEventIdentity;
      const AOriginalHandlerName: string;
      const ABeforeSource: string;
      const AAfterSource: string
    );
    function WithAfterSource(
      const AAfterSource: string
    ): TRadIAFormEventState;
    property Identity: TRadIAFormEventIdentity read FIdentity;
    property OriginalHandlerName: string read FOriginalHandlerName;
    property BeforeSource: string read FBeforeSource;
    property AfterSource: string read FAfterSource;
  end;

  IRadIAFormDesignerEventFacade = interface
    ['{B67A756A-98C5-4927-B0CB-D0C9241C2A6C}']
    function PrepareEvent(
      const AComponentName: string;
      const AEventName: string;
      const AHandlerName: string;
      out AState: TRadIAFormEventState
    ): Boolean;
    function ApplyEvent(
      const AExpected: TRadIAFormEventState;
      out AApplied: TRadIAFormEventState
    ): Boolean;
    function RevertEvent(
      const AExpected: TRadIAFormEventState
    ): Boolean;
  end;

  TRadIAFormEventPreview = record
  private
    FExpiresAtUtc: TDateTime;
    FId: string;
    FState: TRadIAFormEventState;
  public
    constructor Create(
      const AId: string;
      const AState: TRadIAFormEventState;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property State: TRadIAFormEventState read FState;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIAFormEventResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAFormEventPreview;
    FSuccess: Boolean;
  public
    class function Failed(
      const ACode: string;
      const AMessage: string
    ): TRadIAFormEventResult; static;
    class function Succeeded(
      const APreview: TRadIAFormEventPreview
    ): TRadIAFormEventResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAFormEventPreview read FPreview;
  end;

  IRadIAFormEventService = interface
    ['{60DC1C3C-A794-4AC7-88B3-A0355BD64441}']
    function Prepare(
      const AComponentName: string;
      const AEventName: string;
      const AHandlerName: string
    ): TRadIAFormEventResult;
    function Apply(
      const APreviewId: string
    ): TRadIAFormEventResult;
    function Revert(
      const APreviewId: string
    ): TRadIAFormEventResult;
    procedure Clear;
  end;

  TRadIAFormEventService = class(
    TInterfacedObject,
    IRadIAFormEventService
  )
  private
    FApplied: TDictionary<string, Boolean>;
    FExpirationMinutes: Integer;
    FFacade: IRadIAFormDesignerEventFacade;
    FPreviews: TDictionary<string, TRadIAFormEventPreview>;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAFormEventPreview
    ): TRadIAFormEventResult;
    function IsValidIdentifier(const AValue: string): Boolean;
    procedure RemoveExpired;
  public
    constructor Create(
      const AFacade: IRadIAFormDesignerEventFacade;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function Prepare(
      const AComponentName: string;
      const AEventName: string;
      const AHandlerName: string
    ): TRadIAFormEventResult;
    function Apply(
      const APreviewId: string
    ): TRadIAFormEventResult;
    function Revert(
      const APreviewId: string
    ): TRadIAFormEventResult;
    procedure Clear;
  end;

implementation

uses
  System.Character,
  System.DateUtils,
  System.SysUtils;

const
  CMaxPreviews = 32;

constructor TRadIAFormEventIdentity.Create(
  const AFormFileName: string;
  const AUnitFileName: string;
  const AComponentName: string;
  const AEventName: string;
  const AEventTypeName: string;
  const AHandlerName: string
);
begin
  FFormFileName := AFormFileName;
  FUnitFileName := AUnitFileName;
  FComponentName := AComponentName;
  FEventName := AEventName;
  FEventTypeName := AEventTypeName;
  FHandlerName := AHandlerName;
end;

constructor TRadIAFormEventState.Create(
  const AIdentity: TRadIAFormEventIdentity;
  const AOriginalHandlerName: string;
  const ABeforeSource: string;
  const AAfterSource: string
);
begin
  FIdentity := AIdentity;
  FOriginalHandlerName := AOriginalHandlerName;
  FBeforeSource := ABeforeSource;
  FAfterSource := AAfterSource;
end;

function TRadIAFormEventState.WithAfterSource(
  const AAfterSource: string
): TRadIAFormEventState;
begin
  Result := TRadIAFormEventState.Create(
    FIdentity,
    FOriginalHandlerName,
    FBeforeSource,
    AAfterSource
  );
end;

constructor TRadIAFormEventPreview.Create(
  const AId: string;
  const AState: TRadIAFormEventState;
  const AExpiresAtUtc: TDateTime
);
begin
  FId := AId;
  FState := AState;
  FExpiresAtUtc := AExpiresAtUtc;
end;

class function TRadIAFormEventResult.Failed(
  const ACode: string;
  const AMessage: string
): TRadIAFormEventResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := ACode;
  Result.FErrorMessage := AMessage;
  Result.FPreview := Default(TRadIAFormEventPreview);
end;

class function TRadIAFormEventResult.Succeeded(
  const APreview: TRadIAFormEventPreview
): TRadIAFormEventResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FPreview := APreview;
end;

function TRadIAFormEventService.Apply(
  const APreviewId: string
): TRadIAFormEventResult;
var
  LApplied: TRadIAFormEventState;
  LPreview: TRadIAFormEventPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;
  TMonitor.Enter(FPreviews);
  try
    if FApplied[LPreview.Id] then
      Exit(TRadIAFormEventResult.Failed(
        'precondition_failed',
        'The Form Designer event preview was already applied.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;
  if not FFacade.ApplyEvent(LPreview.State, LApplied) then
    Exit(TRadIAFormEventResult.Failed(
      'precondition_failed',
      'The event or source buffer changed after the preview.'
    ));
  LPreview := TRadIAFormEventPreview.Create(
    LPreview.Id,
    LApplied,
    LPreview.ExpiresAtUtc
  );
  TMonitor.Enter(FPreviews);
  try
    FPreviews[LPreview.Id] := LPreview;
    FApplied[LPreview.Id] := True;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAFormEventResult.Succeeded(LPreview);
end;

procedure TRadIAFormEventService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
    FApplied.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

constructor TRadIAFormEventService.Create(
  const AFacade: IRadIAFormDesignerEventFacade;
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
  FPreviews := TDictionary<string, TRadIAFormEventPreview>.Create;
end;

destructor TRadIAFormEventService.Destroy;
begin
  FPreviews.Free;
  FApplied.Free;
  inherited;
end;

function TRadIAFormEventService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAFormEventPreview
): TRadIAFormEventResult;
begin
  APreview := Default(TRadIAFormEventPreview);
  TMonitor.Enter(FPreviews);
  try
    if not FPreviews.TryGetValue(APreviewId, APreview) then
      Exit(TRadIAFormEventResult.Failed(
        'preview_not_found',
        'Form Designer event preview was not found.'
      ));
    if TTimeZone.Local.ToUniversalTime(Now) > APreview.ExpiresAtUtc then
    begin
      FPreviews.Remove(APreviewId);
      FApplied.Remove(APreviewId);
      Exit(TRadIAFormEventResult.Failed(
        'preview_expired',
        'Form Designer event preview expired.'
      ));
    end;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAFormEventResult.Succeeded(APreview);
end;

function TRadIAFormEventService.IsValidIdentifier(
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

function TRadIAFormEventService.Prepare(
  const AComponentName: string;
  const AEventName: string;
  const AHandlerName: string
): TRadIAFormEventResult;
var
  LPreview: TRadIAFormEventPreview;
  LState: TRadIAFormEventState;
begin
  if not IsValidIdentifier(AComponentName) or
    not IsValidIdentifier(AEventName) or
    not IsValidIdentifier(AHandlerName) then
    Exit(TRadIAFormEventResult.Failed(
      'invalid_event',
      'Component, event and handler names must be valid Pascal identifiers.'
    ));
  RemoveExpired;
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPreviews then
      Exit(TRadIAFormEventResult.Failed(
        'resource_limit',
        'Too many Form Designer event previews are active.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;
  if not FFacade.PrepareEvent(
    AComponentName,
    AEventName,
    AHandlerName,
    LState
  ) then
    Exit(TRadIAFormEventResult.Failed(
      'precondition_failed',
      'The event is unavailable, assigned, read-only or the handler exists.'
    ));
  LPreview := TRadIAFormEventPreview.Create(
    TGUID.NewGuid.ToString,
    LState,
    IncMinute(
      TTimeZone.Local.ToUniversalTime(Now),
      FExpirationMinutes
    )
  );
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Add(LPreview.Id, LPreview);
    FApplied.Add(LPreview.Id, False);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAFormEventResult.Succeeded(LPreview);
end;

procedure TRadIAFormEventService.RemoveExpired;
var
  LIds: TList<string>;
  LPair: TPair<string, TRadIAFormEventPreview>;
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

function TRadIAFormEventService.Revert(
  const APreviewId: string
): TRadIAFormEventResult;
var
  LPreview: TRadIAFormEventPreview;
begin
  Result := GetPreview(APreviewId, LPreview);
  if not Result.Success then
    Exit;
  TMonitor.Enter(FPreviews);
  try
    if not FApplied[LPreview.Id] then
      Exit(TRadIAFormEventResult.Failed(
        'precondition_failed',
        'The Form Designer event preview has not been applied.'
      ));
  finally
    TMonitor.Exit(FPreviews);
  end;
  if not FFacade.RevertEvent(LPreview.State) then
    Exit(TRadIAFormEventResult.Failed(
      'precondition_failed',
      'The event or source buffer changed after the handler was applied.'
    ));
  TMonitor.Enter(FPreviews);
  try
    FApplied[LPreview.Id] := False;
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAFormEventResult.Succeeded(LPreview);
end;

end.
