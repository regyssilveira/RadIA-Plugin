unit RadIA.OTA.RuntimeDiscovery;

interface

uses
  RadIA.Core.RuntimeAutomation;

type
  TRadIAWindowsRuntimeDiscoveryFacade = class(
    TInterfacedObject,
    IRadIARuntimeDiscoveryFacade,
    IRadIARuntimeActionFacade
  )
  private
    function ValidateSession(
      const ASession: TRadIARuntimeSessionIdentity
    ): Boolean;
  public
    function ExecuteAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
    function GetWindows(
      const ASession: TRadIARuntimeSessionIdentity
    ): TArray<TRadIARuntimeWindowSnapshot>;
    function GetControlTree(
      const ASession: TRadIARuntimeSessionIdentity;
      const AWindowId: string
    ): TArray<TRadIARuntimeControlSnapshot>;
    function ValidateAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
  end;

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.Hash,
  System.StrUtils,
  System.SysUtils,
  Winapi.Messages,
  Winapi.TlHelp32,
  Winapi.Windows,
  RadIA.OTA.RuntimeProcess;

const
  CMaxWindowTextLength = 4096;
  CMaxRuntimeMessageTimeoutMs = 1000;
  CPasswordStyle = $0020;
  CMessageTimeoutError = 'runtime_action_timeout';

type
  TRadIAWindowEnumerationContext = class
  private
    FAllowedProcessIds: TDictionary<LongWord, Boolean>;
    FHandles: TList<HWND>;
  public
    constructor Create(
      const AAllowedProcessIds: TDictionary<LongWord, Boolean>
    );
    destructor Destroy; override;
    class function EnumerateWindow(
      AWindow: HWND;
      AContext: LPARAM
    ): BOOL; static; stdcall;
    property Handles: TList<HWND> read FHandles;
  end;

  TRadIAControlEnumerationContext = class
  private
    FHandles: TList<HWND>;
  public
    constructor Create;
    destructor Destroy; override;
    class function EnumerateControl(
      AWindow: HWND;
      AContext: LPARAM
    ): BOOL; static; stdcall;
    property Handles: TList<HWND> read FHandles;
  end;

  TRadIARuntimeTarget = record
    ClassName: string;
    Handle: HWND;
    IsWindow: Boolean;
    State: TRadIARuntimeElementState;
    Text: string;
  end;

function WindowProcessId(const AWindow: HWND): LongWord;
var
  LProcessId: DWORD;
begin
  LProcessId := 0;
  GetWindowThreadProcessId(AWindow, @LProcessId);
  Result := LProcessId;
end;

function WindowClassName(const AWindow: HWND): string;
var
  LBuffer: array[0..255] of Char;
  LLength: Integer;
begin
  LLength := GetClassName(AWindow, LBuffer, Length(LBuffer));
  if LLength > 0 then
    SetString(Result, LBuffer, LLength)
  else
    Result := '';
end;

function IsPasswordControl(
  const AWindow: HWND;
  const AClassName: string
): Boolean;
begin
  Result :=
    ContainsText(AClassName, 'Edit') and
    ((GetWindowLongPtr(AWindow, GWL_STYLE) and CPasswordStyle) <> 0);
end;

function WindowText(
  const AWindow: HWND;
  const AClassName: string
): string;
var
  LBuffer: TArray<Char>;
  LLength: Integer;
  LMessageResult: DWORD_PTR;
begin
  if IsPasswordControl(AWindow, AClassName) then
    Exit('[redacted]');
  LMessageResult := 0;
  if SendMessageTimeout(
    AWindow,
    WM_GETTEXTLENGTH,
    0,
    0,
    SMTO_ABORTIFHUNG or SMTO_BLOCK,
    250,
    @LMessageResult
  ) = 0 then
    Exit('');
  if LMessageResult > CMaxWindowTextLength then
    LLength := CMaxWindowTextLength
  else if not TryStrToInt(LMessageResult.ToString, LLength) then
    Exit('');
  if LLength <= 0 then
    Exit('');
  SetLength(LBuffer, LLength + 1);
  LMessageResult := 0;
  if SendMessageTimeout(
    AWindow,
    WM_GETTEXT,
    Length(LBuffer),
    LPARAM(PChar(LBuffer)),
    SMTO_ABORTIFHUNG or SMTO_BLOCK,
    250,
    @LMessageResult
  ) = 0 then
    Exit('');
  if not TryStrToInt(LMessageResult.ToString, LLength) then
    Exit('');
  SetString(Result, PChar(LBuffer), LLength);
end;

function OpaqueId(
  const ASessionId: string;
  const AKind: string;
  const AIdentity: string
): string;
begin
  Result := LowerCase(
    THashSHA2.GetHashString(
      ASessionId + '|' + AKind + '|' + AIdentity,
      THashSHA2.TSHA2Version.SHA256
    )
  );
end;

function WindowOpaqueId(
  const ASessionId: string;
  const AWindow: HWND
): string;
begin
  Result := OpaqueId(
    ASessionId,
    'window',
    Format(
      '%d|%d|%s|%s',
      [
        WindowProcessId(AWindow),
        NativeUInt(AWindow),
        WindowClassName(AWindow),
        WindowText(AWindow, WindowClassName(AWindow))
      ]
    )
  );
end;

function SiblingOrdinal(
  const AWindow: HWND;
  const AClassName: string
): Integer;
var
  LSibling: HWND;
begin
  Result := 0;
  LSibling := GetWindow(AWindow, GW_HWNDPREV);
  while LSibling <> 0 do
  begin
    if SameText(WindowClassName(LSibling), AClassName) then
      Inc(Result);
    LSibling := GetWindow(LSibling, GW_HWNDPREV);
  end;
end;

function ControlPath(
  const AWindow: HWND;
  const ARootWindow: HWND
): string;
var
  LClassName: string;
  LCurrent: HWND;
  LParts: TList<string>;
begin
  LParts := TList<string>.Create;
  try
    LCurrent := AWindow;
    while (LCurrent <> 0) and (LCurrent <> ARootWindow) do
    begin
      LClassName := WindowClassName(LCurrent);
      LParts.Insert(
        0,
        Format(
          '%s[%d]',
          [LClassName, SiblingOrdinal(LCurrent, LClassName)]
        )
      );
      LCurrent := GetParent(LCurrent);
    end;
    Result := string.Join('/', LParts.ToArray);
  finally
    LParts.Free;
  end;
end;

function ControlOpaqueId(
  const ASessionId: string;
  const ARootId: string;
  const AWindow: HWND;
  const ARootWindow: HWND
): string;
var
  LClassName: string;
begin
  LClassName := WindowClassName(AWindow);
  Result := OpaqueId(
    ASessionId,
    'control',
    ARootId + '|' +
    ControlPath(AWindow, ARootWindow) + '|' +
    LClassName + '|' +
    WindowText(AWindow, LClassName)
  );
end;

function ControlCapabilities(
  const AClassName: string
): TRadIARuntimeAutomationCapabilities;
begin
  Result := [];
  if ContainsText(AClassName, 'Button') then
    Include(Result, racInvoke);
  if ContainsText(AClassName, 'Edit') or
    ContainsText(AClassName, 'Memo') then
    Include(Result, racSetValue);
  if ContainsText(AClassName, 'Combo') or
    ContainsText(AClassName, 'List') then
    Include(Result, racSelect);
  if ContainsText(AClassName, 'Form') then
    Include(Result, racClose);
end;

function TryAddAuthorizedChild(
  const AAllowedProcessIds: TDictionary<LongWord, Boolean>;
  const AEntry: TProcessEntry32;
  const ARootCreatedAtUtc: TDateTime
): Boolean;
var
  LChildCreatedAtUtc: TDateTime;
  LChildExecutable: string;
begin
  Result := False;
  if AAllowedProcessIds.ContainsKey(AEntry.th32ProcessID) or
    not AAllowedProcessIds.ContainsKey(AEntry.th32ParentProcessID) then
    Exit;
  if not TryGetRadIARuntimeProcessIdentity(
    AEntry.th32ProcessID,
    LChildExecutable,
    LChildCreatedAtUtc
  ) then
    Exit;
  if LChildCreatedAtUtc < ARootCreatedAtUtc then
    Exit;
  AAllowedProcessIds.Add(AEntry.th32ProcessID, True);
  Result := True;
end;

function BuildAllowedProcessIds(
  const ARootProcessId: LongWord;
  const ARootCreatedAtUtc: TDateTime
): TDictionary<LongWord, Boolean>;
var
  LChanged: Boolean;
  LEntry: TProcessEntry32;
  LSnapshot: THandle;
begin
  Result := TDictionary<LongWord, Boolean>.Create;
  Result.Add(ARootProcessId, True);
  LSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if LSnapshot = INVALID_HANDLE_VALUE then
    Exit;
  try
    repeat
      LChanged := False;
      LEntry.dwSize := SizeOf(LEntry);
      if Process32First(LSnapshot, LEntry) then
      repeat
        if TryAddAuthorizedChild(
          Result,
          LEntry,
          ARootCreatedAtUtc
        ) then
          LChanged := True;
      until not Process32Next(LSnapshot, LEntry);
    until not LChanged;
  finally
    CloseHandle(LSnapshot);
  end;
end;

function FindWindowById(
  const ASessionId: string;
  const AWindowId: string;
  const AAllowedProcessIds: TDictionary<LongWord, Boolean>
): HWND;
var
  LContext: TRadIAWindowEnumerationContext;
  LWindow: HWND;
begin
  Result := 0;
  LContext := TRadIAWindowEnumerationContext.Create(AAllowedProcessIds);
  try
    EnumWindows(
      @TRadIAWindowEnumerationContext.EnumerateWindow,
      LPARAM(LContext)
    );
    for LWindow in LContext.Handles do
      if SameText(WindowOpaqueId(ASessionId, LWindow), AWindowId) then
        Exit(LWindow);
  finally
    LContext.Free;
  end;
end;

function FindControlById(
  const ASessionId: string;
  const AControlId: string;
  const AAllowedProcessIds: TDictionary<LongWord, Boolean>;
  out ARootWindow: HWND
): HWND;
var
  LControl: HWND;
  LControlContext: TRadIAControlEnumerationContext;
  LRootContext: TRadIAWindowEnumerationContext;
  LRootId: string;
  LRootWindow: HWND;
begin
  Result := 0;
  ARootWindow := 0;
  LRootContext := TRadIAWindowEnumerationContext.Create(
    AAllowedProcessIds
  );
  try
    EnumWindows(
      @TRadIAWindowEnumerationContext.EnumerateWindow,
      LPARAM(LRootContext)
    );
    for LRootWindow in LRootContext.Handles do
    begin
      LRootId := WindowOpaqueId(ASessionId, LRootWindow);
      LControlContext := TRadIAControlEnumerationContext.Create;
      try
        EnumChildWindows(
          LRootWindow,
          @TRadIAControlEnumerationContext.EnumerateControl,
          LPARAM(LControlContext)
        );
        for LControl in LControlContext.Handles do
          if AAllowedProcessIds.ContainsKey(
            WindowProcessId(LControl)
          ) and SameText(
            ControlOpaqueId(
              ASessionId,
              LRootId,
              LControl,
              LRootWindow
            ),
            AControlId
          ) then
          begin
            ARootWindow := LRootWindow;
            Exit(LControl);
          end;
      finally
        LControlContext.Free;
      end;
    end;
  finally
    LRootContext.Free;
  end;
end;

function SendRuntimeMessage(
  const AWindow: HWND;
  const AMessage: Cardinal;
  const AWParam: WPARAM;
  const ALParam: LPARAM;
  const ATimeoutMs: Cardinal;
  out AMessageResult: DWORD_PTR
): Boolean;
var
  LTimeoutMs: Cardinal;
begin
  AMessageResult := 0;
  LTimeoutMs := ATimeoutMs;
  if LTimeoutMs > CMaxRuntimeMessageTimeoutMs then
    LTimeoutMs := CMaxRuntimeMessageTimeoutMs;
  Result := SendMessageTimeout(
    AWindow,
    AMessage,
    AWParam,
    ALParam,
    SMTO_ABORTIFHUNG or SMTO_BLOCK,
    LTimeoutMs,
    @AMessageResult
  ) <> 0;
end;

function RequiredCapability(
  const AKind: TRadIARuntimeActionKind;
  const ATargetIsWindow: Boolean
): TRadIARuntimeAutomationCapabilities;
begin
  case AKind of
    rakInvoke:
      Result := [racInvoke];
    rakSetValue:
      Result := [racSetValue];
    rakSelect:
      Result := [racSelect];
    rakClose:
      Result := [racClose];
    rakCancel:
      if ATargetIsWindow then
        Result := [racClose]
      else
        Result := [racInvoke];
  else
    Result := [];
  end;
end;

function ResolveRuntimeTarget(
  const ASession: TRadIARuntimeSessionIdentity;
  const ATargetId: string;
  out ATarget: TRadIARuntimeTarget
): Boolean;
var
  LAllowedProcessIds: TDictionary<LongWord, Boolean>;
  LCapabilities: TRadIARuntimeAutomationCapabilities;
  LRootWindow: HWND;
begin
  ATarget := Default(TRadIARuntimeTarget);
  Result := False;
  if Length(ATargetId) <> 64 then
    Exit;
  LAllowedProcessIds := BuildAllowedProcessIds(
    ASession.ProcessId,
    ASession.CreatedAtUtc
  );
  try
    ATarget.Handle := FindWindowById(
      ASession.SessionId,
      ATargetId,
      LAllowedProcessIds
    );
    ATarget.IsWindow := ATarget.Handle <> 0;
    if not ATarget.IsWindow then
      ATarget.Handle := FindControlById(
        ASession.SessionId,
        ATargetId,
        LAllowedProcessIds,
        LRootWindow
      );
    if ATarget.Handle = 0 then
      Exit;
    ATarget.ClassName := WindowClassName(ATarget.Handle);
    if ATarget.IsWindow then
      LCapabilities := [racClose]
    else
      LCapabilities := ControlCapabilities(ATarget.ClassName);
    ATarget.Text := WindowText(
      ATarget.Handle,
      ATarget.ClassName
    );
    ATarget.State := TRadIARuntimeElementState.Create(
      IsWindowVisible(ATarget.Handle),
      IsWindowEnabled(ATarget.Handle),
      LCapabilities
    );
    Result := True;
  finally
    LAllowedProcessIds.Free;
  end;
end;

{ TRadIAWindowEnumerationContext }

constructor TRadIAWindowEnumerationContext.Create(
  const AAllowedProcessIds: TDictionary<LongWord, Boolean>
);
begin
  inherited Create;
  FAllowedProcessIds := AAllowedProcessIds;
  FHandles := TList<HWND>.Create;
end;

destructor TRadIAWindowEnumerationContext.Destroy;
begin
  FHandles.Free;
  inherited Destroy;
end;

class function TRadIAWindowEnumerationContext.EnumerateWindow(
  AWindow: HWND;
  AContext: LPARAM
): BOOL;
var
  LContext: TRadIAWindowEnumerationContext;
begin
  LContext := TRadIAWindowEnumerationContext(Pointer(AContext));
  if LContext.FAllowedProcessIds.ContainsKey(WindowProcessId(AWindow)) then
    LContext.FHandles.Add(AWindow);
  Result := True;
end;

{ TRadIAControlEnumerationContext }

constructor TRadIAControlEnumerationContext.Create;
begin
  inherited Create;
  FHandles := TList<HWND>.Create;
end;

destructor TRadIAControlEnumerationContext.Destroy;
begin
  FHandles.Free;
  inherited Destroy;
end;

class function TRadIAControlEnumerationContext.EnumerateControl(
  AWindow: HWND;
  AContext: LPARAM
): BOOL;
begin
  TRadIAControlEnumerationContext(
    Pointer(AContext)
  ).FHandles.Add(AWindow);
  Result := True;
end;

function InvokeRuntimeTarget(
  const ATarget: TRadIARuntimeTarget;
  const ATimeoutMs: Cardinal
): TRadIARuntimeActionResult;
var
  LMessageResult: DWORD_PTR;
begin
  if SendRuntimeMessage(
    ATarget.Handle,
    BM_CLICK,
    0,
    0,
    ATimeoutMs,
    LMessageResult
  ) then
    Result := TRadIARuntimeActionResult.Succeeded
  else
    Result := TRadIARuntimeActionResult.Failed(
      CMessageTimeoutError,
      'Invoking the runtime control timed out.'
    );
end;

function SetRuntimeValue(
  const ATarget: TRadIARuntimeTarget;
  const AValue: string;
  const ATimeoutMs: Cardinal
): TRadIARuntimeActionResult;
var
  LMessageResult: DWORD_PTR;
begin
  if SendRuntimeMessage(
    ATarget.Handle,
    WM_SETTEXT,
    0,
    LPARAM(PChar(AValue)),
    ATimeoutMs,
    LMessageResult
  ) then
    Result := TRadIARuntimeActionResult.Succeeded
  else
    Result := TRadIARuntimeActionResult.Failed(
      CMessageTimeoutError,
      'Setting the runtime control value timed out.'
    );
end;

function SelectRuntimeValue(
  const ATarget: TRadIARuntimeTarget;
  const AValue: string;
  const ATimeoutMs: Cardinal
): TRadIARuntimeActionResult;
var
  LMessage: Cardinal;
  LMessageResult: DWORD_PTR;
begin
  if ContainsText(ATarget.ClassName, 'Combo') then
    LMessage := CB_SELECTSTRING
  else
    LMessage := LB_SELECTSTRING;
  if SendRuntimeMessage(
    ATarget.Handle,
    LMessage,
    High(WPARAM),
    LPARAM(PChar(AValue)),
    ATimeoutMs,
    LMessageResult
  ) and (LMessageResult <> High(NativeUInt)) then
    Result := TRadIARuntimeActionResult.Succeeded
  else
    Result := TRadIARuntimeActionResult.Failed(
      'runtime_value_not_found',
      'Requested runtime selection was not found.'
    );
end;

function CloseRuntimeTarget(
  const ATarget: TRadIARuntimeTarget;
  const ATimeoutMs: Cardinal
): TRadIARuntimeActionResult;
var
  LMessageResult: DWORD_PTR;
begin
  if SendRuntimeMessage(
    ATarget.Handle,
    WM_CLOSE,
    0,
    0,
    ATimeoutMs,
    LMessageResult
  ) then
    Result := TRadIARuntimeActionResult.Succeeded
  else
    Result := TRadIARuntimeActionResult.Failed(
      CMessageTimeoutError,
      'Closing the runtime window timed out.'
    );
end;

function CancelRuntimeTarget(
  const ATarget: TRadIARuntimeTarget;
  const ATimeoutMs: Cardinal
): TRadIARuntimeActionResult;
var
  LMessageResult: DWORD_PTR;
begin
  if not ATarget.IsWindow then
    Exit(InvokeRuntimeTarget(ATarget, ATimeoutMs));
  if SendRuntimeMessage(
    ATarget.Handle,
    WM_COMMAND,
    IDCANCEL,
    0,
    ATimeoutMs,
    LMessageResult
  ) then
    Result := TRadIARuntimeActionResult.Succeeded
  else
    Result := TRadIARuntimeActionResult.Failed(
      CMessageTimeoutError,
      'Cancelling the runtime window timed out.'
    );
end;

function AssertRuntimeValue(
  const ATarget: TRadIARuntimeTarget;
  const AExpectedValue: string
): TRadIARuntimeActionResult;
begin
  if SameText(ATarget.Text, AExpectedValue) then
    Result := TRadIARuntimeActionResult.Succeeded(ATarget.Text)
  else
    Result := TRadIARuntimeActionResult.Failed(
      'runtime_assertion_failed',
      'Runtime target text did not match the expected value.'
    );
end;

{ TRadIAWindowsRuntimeDiscoveryFacade }

function TRadIAWindowsRuntimeDiscoveryFacade.ExecuteAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
var
  LTarget: TRadIARuntimeTarget;
begin
  Result := ValidateAction(ASession, AAction);
  if not Result.Success then
    Exit;
  if not ResolveRuntimeTarget(
    ASession,
    AAction.Selector.AutomationId,
    LTarget
  ) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_changed',
      'Runtime target disappeared after validation.'
    ));

  case AAction.Kind of
    rakInvoke:
      Result := InvokeRuntimeTarget(
        LTarget,
        AAction.TimeoutMs
      );
    rakSetValue:
      Result := SetRuntimeValue(
        LTarget,
        AAction.Value,
        AAction.TimeoutMs
      );
    rakSelect:
      Result := SelectRuntimeValue(
        LTarget,
        AAction.Value,
        AAction.TimeoutMs
      );
    rakClose:
      Result := CloseRuntimeTarget(
        LTarget,
        AAction.TimeoutMs
      );
    rakCancel:
      Result := CancelRuntimeTarget(
        LTarget,
        AAction.TimeoutMs
      );
    rakAssert:
      Result := AssertRuntimeValue(LTarget, AAction.Value);
  else
    Result := TRadIARuntimeActionResult.Failed(
      'unsupported_runtime_action',
      'Runtime action kind is not supported by this adapter.'
    );
  end;
end;

function TRadIAWindowsRuntimeDiscoveryFacade.GetControlTree(
  const ASession: TRadIARuntimeSessionIdentity;
  const AWindowId: string
): TArray<TRadIARuntimeControlSnapshot>;
var
  LAllowedProcessIds: TDictionary<LongWord, Boolean>;
  LCapabilities: TRadIARuntimeAutomationCapabilities;
  LClassName: string;
  LContext: TRadIAControlEnumerationContext;
  LControl: HWND;
  LParent: HWND;
  LParentId: string;
  LRootWindow: HWND;
  LSnapshots: TList<TRadIARuntimeControlSnapshot>;
begin
  if not ValidateSession(ASession) then
    raise EInvalidOp.Create('Runtime debug session identity changed.');
  if Trim(AWindowId) = '' then
    raise EArgumentException.Create('Window id is required.');
  LAllowedProcessIds := BuildAllowedProcessIds(
    ASession.ProcessId,
    ASession.CreatedAtUtc
  );
  try
    LRootWindow := FindWindowById(
      ASession.SessionId,
      AWindowId,
      LAllowedProcessIds
    );
    if LRootWindow = 0 then
      raise EArgumentException.Create(
        'Window id does not belong to the active runtime session.'
      );
    LContext := TRadIAControlEnumerationContext.Create;
    try
      EnumChildWindows(
        LRootWindow,
        @TRadIAControlEnumerationContext.EnumerateControl,
        LPARAM(LContext)
      );
      LSnapshots := TList<TRadIARuntimeControlSnapshot>.Create;
      try
        for LControl in LContext.Handles do
        begin
          if not LAllowedProcessIds.ContainsKey(
            WindowProcessId(LControl)
          ) then
            Continue;
          LClassName := WindowClassName(LControl);
          LCapabilities := ControlCapabilities(LClassName);
          LParent := GetParent(LControl);
          if LParent = LRootWindow then
            LParentId := AWindowId
          else
            LParentId := ControlOpaqueId(
              ASession.SessionId,
              AWindowId,
              LParent,
              LRootWindow
            );
          LSnapshots.Add(
            TRadIARuntimeControlSnapshot.Create(
              ControlOpaqueId(
                ASession.SessionId,
                AWindowId,
                LControl,
                LRootWindow
              ),
              LParentId,
              LClassName,
              WindowText(LControl, LClassName),
              ControlPath(LControl, LRootWindow),
              TRadIARuntimeElementState.Create(
                IsWindowVisible(LControl),
                IsWindowEnabled(LControl),
                LCapabilities
              )
            )
          );
        end;
        Result := LSnapshots.ToArray;
      finally
        LSnapshots.Free;
      end;
    finally
      LContext.Free;
    end;
  finally
    LAllowedProcessIds.Free;
  end;
end;

function TRadIAWindowsRuntimeDiscoveryFacade.GetWindows(
  const ASession: TRadIARuntimeSessionIdentity
): TArray<TRadIARuntimeWindowSnapshot>;
var
  LAllowedProcessIds: TDictionary<LongWord, Boolean>;
  LClassName: string;
  LContext: TRadIAWindowEnumerationContext;
  LOwner: HWND;
  LOwnerId: string;
  LSnapshots: TList<TRadIARuntimeWindowSnapshot>;
  LWindow: HWND;
begin
  if not ValidateSession(ASession) then
    raise EInvalidOp.Create('Runtime debug session identity changed.');
  LAllowedProcessIds := BuildAllowedProcessIds(
    ASession.ProcessId,
    ASession.CreatedAtUtc
  );
  try
    LContext := TRadIAWindowEnumerationContext.Create(LAllowedProcessIds);
    try
      EnumWindows(
        @TRadIAWindowEnumerationContext.EnumerateWindow,
        LPARAM(LContext)
      );
      LSnapshots := TList<TRadIARuntimeWindowSnapshot>.Create;
      try
        for LWindow in LContext.Handles do
        begin
          LOwner := GetWindow(LWindow, GW_OWNER);
          if (LOwner <> 0) and
            LAllowedProcessIds.ContainsKey(WindowProcessId(LOwner)) then
            LOwnerId := WindowOpaqueId(ASession.SessionId, LOwner)
          else
            LOwnerId := '';
          LClassName := WindowClassName(LWindow);
          LSnapshots.Add(
            TRadIARuntimeWindowSnapshot.Create(
              WindowOpaqueId(ASession.SessionId, LWindow),
              WindowProcessId(LWindow),
              LClassName,
              WindowText(LWindow, LClassName),
              LOwnerId,
              (LOwner <> 0) and not IsWindowEnabled(LOwner),
              TRadIARuntimeElementState.Create(
                IsWindowVisible(LWindow),
                IsWindowEnabled(LWindow),
                [racClose]
              )
            )
          );
        end;
        Result := LSnapshots.ToArray;
      finally
        LSnapshots.Free;
      end;
    finally
      LContext.Free;
    end;
  finally
    LAllowedProcessIds.Free;
  end;
end;

function TRadIAWindowsRuntimeDiscoveryFacade.ValidateAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
var
  LRequired: TRadIARuntimeAutomationCapabilities;
  LTarget: TRadIARuntimeTarget;
begin
  if not ValidateSession(ASession) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_session_changed',
      'Runtime debug session identity changed.'
    ));
  if not ResolveRuntimeTarget(
    ASession,
    AAction.Selector.AutomationId,
    LTarget
  ) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_not_found',
      'Runtime target does not belong to the active debug session.'
    ));
  if SameText(LTarget.Text, '[redacted]') then
    Exit(TRadIARuntimeActionResult.Failed(
      'sensitive_runtime_target',
      'Password controls cannot be used in runtime scenarios.'
    ));
  if not LTarget.State.Visible then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_not_visible',
      'Runtime target is not visible.'
    ));
  if (AAction.Kind <> rakAssert) and
    not LTarget.State.Enabled then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_not_enabled',
      'Runtime target is not enabled.'
    ));
  if (AAction.Kind = rakClose) and not LTarget.IsWindow then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_capability_unavailable',
      'Close is available only for an authorized top-level window.'
    ));
  LRequired := RequiredCapability(
    AAction.Kind,
    LTarget.IsWindow
  );
  if (LRequired - LTarget.State.Capabilities) <> [] then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_capability_unavailable',
      'Runtime target does not support the requested action.'
    ));
  Result := TRadIARuntimeActionResult.Succeeded(LTarget.Text);
end;

function TRadIAWindowsRuntimeDiscoveryFacade.ValidateSession(
  const ASession: TRadIARuntimeSessionIdentity
): Boolean;
var
  LCreatedAtUtc: TDateTime;
  LExecutablePath: string;
begin
  Result :=
    ASession.IsComplete and
    TryGetRadIARuntimeProcessIdentity(
      ASession.ProcessId,
      LExecutablePath,
      LCreatedAtUtc
    ) and
    SameFileName(LExecutablePath, ASession.ExecutablePath) and
    (Abs(MilliSecondsBetween(
      LCreatedAtUtc,
      ASession.CreatedAtUtc
    )) < 1000);
end;

end.
