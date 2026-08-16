unit RadIA.OTA.RuntimeVclFacade;

interface

uses
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeVclAdapter;

type
  TRadIACompositeRuntimeFacade = class(
    TInterfacedObject,
    IRadIARuntimeDiscoveryFacade,
    IRadIARuntimeActionFacade
  )
  private
    FBaseAction: IRadIARuntimeActionFacade;
    FBaseDiscovery: IRadIARuntimeDiscoveryFacade;
    FLocator: IRadIARuntimeVclEndpointLocator;
    FTransport: IRadIARuntimeVclTransport;
    function DiscoverVcl(
      const ASession: TRadIARuntimeSessionIdentity;
      out AControls: TArray<TRadIARuntimeControlSnapshot>
    ): Boolean;
    function ExecuteVcl(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
    function FindVclTarget(
      const AControls: TArray<TRadIARuntimeControlSnapshot>;
      const AAction: TRadIARuntimeScenarioAction;
      out ATarget: TRadIARuntimeControlSnapshot
    ): Boolean;
    function ValidateVcl(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
  public
    constructor Create(
      const ABaseDiscovery: IRadIARuntimeDiscoveryFacade;
      const ABaseAction: IRadIARuntimeActionFacade;
      const ALocator: IRadIARuntimeVclEndpointLocator;
      const ATransport: IRadIARuntimeVclTransport
    );
    function ExecuteAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
    function GetControlTree(
      const ASession: TRadIARuntimeSessionIdentity;
      const AWindowId: string
    ): TArray<TRadIARuntimeControlSnapshot>;
    function GetWindows(
      const ASession: TRadIARuntimeSessionIdentity
    ): TArray<TRadIARuntimeWindowSnapshot>;
    function ValidateAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
  end;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.SysUtils;

function CapabilityFromName(
  const AName: string;
  out ACapability: TRadIARuntimeAutomationCapability
): Boolean;
begin
  Result := True;
  if SameText(AName, 'invoke') then
    ACapability := racInvoke
  else if SameText(AName, 'setValue') then
    ACapability := racSetValue
  else if SameText(AName, 'select') then
    ACapability := racSelect
  else if SameText(AName, 'close') then
    ACapability := racClose
  else
    Result := False;
end;

function ParseControl(const AJson: TJSONObject): TRadIARuntimeControlSnapshot;
var
  LCapabilities: TRadIARuntimeAutomationCapabilities;
  LCapability: TRadIARuntimeAutomationCapability;
  LCapabilityValue: TJSONValue;
  LCapabilityValues: TJSONArray;
  LState: TJSONObject;
begin
  LState := AJson.GetValue<TJSONObject>('state');
  if not Assigned(LState) then
    raise EJSONParseException.Create('Runtime VCL control state is missing.');
  LCapabilities := [];
  LCapabilityValues := LState.GetValue<TJSONArray>('capabilities');
  if Assigned(LCapabilityValues) then
    for LCapabilityValue in LCapabilityValues do
      if CapabilityFromName(LCapabilityValue.Value, LCapability) then
        Include(LCapabilities, LCapability);
  Result := TRadIARuntimeControlSnapshot.Create(
    AJson.GetValue<string>('controlId', ''),
    AJson.GetValue<string>('parentId', ''),
    AJson.GetValue<string>('className', ''),
    AJson.GetValue<string>('text', ''),
    AJson.GetValue<string>('path', ''),
    TRadIARuntimeElementState.Create(
      LState.GetValue<Boolean>('visible', False),
      LState.GetValue<Boolean>('enabled', False),
      LCapabilities
    )
  );
end;

function ActionName(const AKind: TRadIARuntimeActionKind): string;
begin
  case AKind of
    rakInvoke: Result := 'invoke';
    rakSetValue: Result := 'setValue';
    rakSelect: Result := 'select';
    rakClose: Result := 'close';
    rakAssert: Result := 'assert';
  else
    Result := '';
  end;
end;

function ControlNameFromPath(const APath: string): string;
var
  LDelimiter: Integer;
begin
  LDelimiter := LastDelimiter('/\', APath);
  if LDelimiter > 0 then
    Result := Copy(APath, LDelimiter + 1, MaxInt)
  else
    Result := APath;
end;

function BuildActionJson(const AAction: TRadIARuntimeScenarioAction): string;
var
  LRoot: TJSONObject;
  LSelector: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('action', ActionName(AAction.Kind));
    LRoot.AddPair('value', AAction.Value);
    LRoot.AddPair('timeoutMs', TJSONNumber.Create(AAction.TimeoutMs));
    LSelector := TJSONObject.Create;
    LSelector.AddPair('automationId', AAction.Selector.AutomationId);
    LSelector.AddPair('className', AAction.Selector.ClassName);
    LSelector.AddPair('controlName', AAction.Selector.ControlName);
    LSelector.AddPair('text', AAction.Selector.Text);
    LSelector.AddPair('parentPath', AAction.Selector.ParentPath);
    LRoot.AddPair('selector', LSelector);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

constructor TRadIACompositeRuntimeFacade.Create(
  const ABaseDiscovery: IRadIARuntimeDiscoveryFacade;
  const ABaseAction: IRadIARuntimeActionFacade;
  const ALocator: IRadIARuntimeVclEndpointLocator;
  const ATransport: IRadIARuntimeVclTransport
);
begin
  inherited Create;
  if not Assigned(ABaseDiscovery) or not Assigned(ABaseAction) or
    not Assigned(ALocator) or not Assigned(ATransport) then
    raise EArgumentNilException.Create('Composite runtime facade dependency');
  FBaseDiscovery := ABaseDiscovery;
  FBaseAction := ABaseAction;
  FLocator := ALocator;
  FTransport := ATransport;
end;

function TRadIACompositeRuntimeFacade.DiscoverVcl(
  const ASession: TRadIARuntimeSessionIdentity;
  out AControls: TArray<TRadIARuntimeControlSnapshot>
): Boolean;
var
  LControl: TJSONValue;
  LControls: TJSONArray;
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LItems: TList<TRadIARuntimeControlSnapshot>;
  LResult: TRadIARuntimeVclTransportResult;
  LRoot: TJSONObject;
begin
  SetLength(AControls, 0);
  Result := False;
  if not FLocator.Locate(ASession, LIdentity) then
    Exit;
  LResult := FTransport.Send(
    LIdentity,
    'discover',
    '{}',
    TRadIARuntimeVclAdapterLimits.Defaults
  );
  if not LResult.Success then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(LResult.Payload) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    if not LRoot.GetValue<Boolean>('success', False) then
      Exit;
    LControls := LRoot.GetValue<TJSONArray>('controls');
    if not Assigned(LControls) then
      Exit;
    LItems := TList<TRadIARuntimeControlSnapshot>.Create;
    try
      for LControl in LControls do
        if LControl is TJSONObject then
          LItems.Add(ParseControl(TJSONObject(LControl)));
      AControls := LItems.ToArray;
      Result := True;
    finally
      LItems.Free;
    end;
  finally
    LRoot.Free;
  end;
end;

function TRadIACompositeRuntimeFacade.ExecuteVcl(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
var
  LError: TJSONObject;
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LResult: TRadIARuntimeVclTransportResult;
  LRoot: TJSONObject;
begin
  if not FLocator.Locate(ASession, LIdentity) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_unavailable',
      'Runtime VCL adapter is not available for this debug session.'
    ));
  LResult := FTransport.Send(
    LIdentity,
    'execute',
    BuildActionJson(AAction),
    TRadIARuntimeVclAdapterLimits.Defaults
  );
  if not LResult.Success then
    Exit(TRadIARuntimeActionResult.Failed(
      LResult.ErrorCode,
      LResult.ErrorMessage
    ));
  LRoot := TJSONObject.ParseJSONValue(LResult.Payload) as TJSONObject;
  if not Assigned(LRoot) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_invalid_response',
      'Runtime VCL adapter returned invalid JSON.'
    ));
  try
    if LRoot.GetValue<Boolean>('success', False) then
      Exit(TRadIARuntimeActionResult.Succeeded(
        LRoot.GetValue<string>('observedValue', '')
      ));
    LError := LRoot.GetValue<TJSONObject>('error');
    if Assigned(LError) then
      Exit(TRadIARuntimeActionResult.Failed(
        LError.GetValue<string>('code', 'runtime_vcl_failed'),
        LError.GetValue<string>('message', 'Runtime VCL action failed.')
      ));
    Result := TRadIARuntimeActionResult.Failed(
      'runtime_vcl_failed',
      'Runtime VCL action failed.'
    );
  finally
    LRoot.Free;
  end;
end;

function TRadIACompositeRuntimeFacade.FindVclTarget(
  const AControls: TArray<TRadIARuntimeControlSnapshot>;
  const AAction: TRadIARuntimeScenarioAction;
  out ATarget: TRadIARuntimeControlSnapshot
): Boolean;
var
  LControl: TRadIARuntimeControlSnapshot;
  LCount: Integer;
begin
  LCount := 0;
  for LControl in AControls do
    if ((AAction.Selector.ControlName = '') or
      SameText(AAction.Selector.ControlName, ControlNameFromPath(LControl.Path))) and
      ((AAction.Selector.ClassName = '') or
      SameText(AAction.Selector.ClassName, LControl.ClassName)) and
      ((AAction.Selector.Text = '') or
      SameText(AAction.Selector.Text, LControl.Text)) and
      ((AAction.Selector.ParentPath = '') or
      StartsText(AAction.Selector.ParentPath + '/', LControl.Path)) then
    begin
      Inc(LCount);
      ATarget := LControl;
    end;
  Result := LCount = 1;
end;

function TRadIACompositeRuntimeFacade.ValidateVcl(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
var
  LControls: TArray<TRadIARuntimeControlSnapshot>;
  LRequired: TRadIARuntimeAutomationCapability;
  LTarget: TRadIARuntimeControlSnapshot;
begin
  if not DiscoverVcl(ASession, LControls) or
    not FindVclTarget(LControls, AAction, LTarget) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_not_found',
      'Runtime target was not found in the Win32 or VCL control tree.'
    ));
  if not LTarget.State.Visible then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_not_visible', 'Runtime target is not visible.'
    ));
  if (AAction.Kind <> rakAssert) and not LTarget.State.Enabled then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_not_enabled', 'Runtime target is not enabled.'
    ));
  case AAction.Kind of
    rakInvoke: LRequired := racInvoke;
    rakSetValue: LRequired := racSetValue;
    rakSelect: LRequired := racSelect;
    rakClose: LRequired := racClose;
    rakAssert:
      Exit(TRadIARuntimeActionResult.Succeeded(LTarget.Text));
  else
    Exit(TRadIARuntimeActionResult.Failed(
      'unsupported_runtime_action',
      'Runtime action is not supported by the VCL adapter.'
    ));
  end;
  if not (LRequired in LTarget.State.Capabilities) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_capability_unavailable',
      'Runtime target does not support the requested action.'
    ));
  Result := TRadIARuntimeActionResult.Succeeded(LTarget.Text);
end;

function TRadIACompositeRuntimeFacade.ExecuteAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := FBaseAction.ValidateAction(ASession, AAction);
  if Result.Success then
    Exit(FBaseAction.ExecuteAction(ASession, AAction));
  Result := ValidateVcl(ASession, AAction);
  if Result.Success then
    Result := ExecuteVcl(ASession, AAction);
end;

function TRadIACompositeRuntimeFacade.GetControlTree(
  const ASession: TRadIARuntimeSessionIdentity;
  const AWindowId: string
): TArray<TRadIARuntimeControlSnapshot>;
var
  LBase: TArray<TRadIARuntimeControlSnapshot>;
  LControl: TRadIARuntimeControlSnapshot;
  LItems: TList<TRadIARuntimeControlSnapshot>;
  LVcl: TArray<TRadIARuntimeControlSnapshot>;
begin
  LBase := FBaseDiscovery.GetControlTree(ASession, AWindowId);
  if not DiscoverVcl(ASession, LVcl) then
    Exit(LBase);
  LItems := TList<TRadIARuntimeControlSnapshot>.Create;
  try
    LItems.AddRange(LBase);
    for LControl in LVcl do
      LItems.Add(LControl);
    Result := LItems.ToArray;
  finally
    LItems.Free;
  end;
end;

function TRadIACompositeRuntimeFacade.GetWindows(
  const ASession: TRadIARuntimeSessionIdentity
): TArray<TRadIARuntimeWindowSnapshot>;
begin
  Result := FBaseDiscovery.GetWindows(ASession);
end;

function TRadIACompositeRuntimeFacade.ValidateAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := FBaseAction.ValidateAction(ASession, AAction);
  if not Result.Success then
    Result := ValidateVcl(ASession, AAction);
end;

end.
