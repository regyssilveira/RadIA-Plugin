unit RadIA.Runtime.VclAdapter;

interface

uses
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeVclAdapter,
  Vcl.Controls;

type
  TRadIARuntimeVclControlAdapter = class
  private
    function BuildControlId(
      const ASessionId: string;
      const APath: string
    ): string;
    function BuildPath(const AControl: TControl): string;
    function Capabilities(
      const AControl: TControl
    ): TRadIARuntimeAutomationCapabilities;
    procedure CollectControls(
      const ASession: TRadIARuntimeSessionIdentity;
      const AParent: TWinControl;
      const AParentId: string;
      const ADepth: Integer;
      const ALimits: TRadIARuntimeVclAdapterLimits;
      const AItems: TObject
    );
    function ControlText(const AControl: TControl): string;
    function FindControl(
      const ASelector: TRadIARuntimeSelector;
      out AControl: TControl
    ): Boolean;
    function FindControlInParent(
      const AParent: TWinControl;
      const ASelector: TRadIARuntimeSelector;
      var AMatch: TControl;
      var AMatchCount: Integer
    ): Boolean;
    function Matches(
      const AControl: TControl;
      const ASelector: TRadIARuntimeSelector
    ): Boolean;
    function ExecuteClose(const AControl: TControl): TRadIARuntimeActionResult;
    function ExecuteInvoke(const AControl: TControl): TRadIARuntimeActionResult;
    function ExecuteSelect(
      const AControl: TControl;
      const AValue: string
    ): TRadIARuntimeActionResult;
    function ExecuteSetValue(
      const AControl: TControl;
      const AValue: string
    ): TRadIARuntimeActionResult;
  public
    function Discover(
      const ASession: TRadIARuntimeSessionIdentity;
      const ALimits: TRadIARuntimeVclAdapterLimits
    ): TArray<TRadIARuntimeControlSnapshot>;
    function Execute(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction;
      const ALimits: TRadIARuntimeVclAdapterLimits
    ): TRadIARuntimeActionResult;
  end;

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.StrUtils,
  System.SysUtils,
  Vcl.Buttons,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TRadIAControlAccess = class(TControl);
  TRadIACheckBoxAccess = class(TCustomCheckBox);
  TRadIAComboBoxAccess = class(TCustomComboBox);
  TRadIAEditAccess = class(TCustomEdit);

function TRadIARuntimeVclControlAdapter.BuildControlId(
  const ASessionId: string;
  const APath: string
): string;
begin
  Result := LowerCase(THashSHA2.GetHashString(
    ASessionId + '|vcl-control|' + APath,
    THashSHA2.TSHA2Version.SHA256
  ));
end;

function TRadIARuntimeVclControlAdapter.BuildPath(
  const AControl: TControl
): string;
var
  LCurrent: TControl;
  LName: string;
  LParts: TList<string>;
begin
  LParts := TList<string>.Create;
  try
    LCurrent := AControl;
    while Assigned(LCurrent) do
    begin
      LName := Trim(LCurrent.Name);
      if LName = '' then
        LName := LCurrent.ClassName + '[' + LCurrent.ComponentIndex.ToString + ']';
      LParts.Insert(0, LName);
      LCurrent := LCurrent.Parent;
    end;
    Result := string.Join('/', LParts.ToArray);
  finally
    LParts.Free;
  end;
end;

function TRadIARuntimeVclControlAdapter.Capabilities(
  const AControl: TControl
): TRadIARuntimeAutomationCapabilities;
begin
  Result := [];
  if Assigned(TRadIAControlAccess(AControl).OnClick) or
    (AControl is TButton) or
    (AControl is TSpeedButton) then
    Include(Result, racInvoke);
  if AControl is TCustomEdit then
    Include(Result, racSetValue);
  if (AControl is TCustomComboBox) or
    (AControl is TCustomListBox) or
    (AControl is TCustomCheckBox) then
    Include(Result, racSelect);
  if AControl is TCustomForm then
    Include(Result, racClose);
end;

procedure TRadIARuntimeVclControlAdapter.CollectControls(
  const ASession: TRadIARuntimeSessionIdentity;
  const AParent: TWinControl;
  const AParentId: string;
  const ADepth: Integer;
  const ALimits: TRadIARuntimeVclAdapterLimits;
  const AItems: TObject
);
var
  LControl: TControl;
  LControlId: string;
  LIndex: Integer;
  LItems: TList<TRadIARuntimeControlSnapshot>;
  LPath: string;
begin
  LItems := TList<TRadIARuntimeControlSnapshot>(AItems);
  if (ADepth > ALimits.MaxDepth) or
    (LItems.Count >= ALimits.MaxTargets) then
    Exit;
  for LIndex := 0 to AParent.ControlCount - 1 do
  begin
    if LItems.Count >= ALimits.MaxTargets then
      Exit;
    LControl := AParent.Controls[LIndex];
    LPath := BuildPath(LControl);
    LControlId := BuildControlId(ASession.SessionId, LPath);
    LItems.Add(TRadIARuntimeControlSnapshot.Create(
      LControlId,
      AParentId,
      LControl.ClassName,
      ControlText(LControl),
      LPath,
      TRadIARuntimeElementState.Create(
        LControl.Visible,
        LControl.Enabled,
        Capabilities(LControl)
      )
    ));
    if LControl is TWinControl then
      CollectControls(
        ASession,
        TWinControl(LControl),
        LControlId,
        ADepth + 1,
        ALimits,
        LItems
      );
  end;
end;

function TRadIARuntimeVclControlAdapter.ControlText(
  const AControl: TControl
): string;
begin
  if AControl is TCustomEdit then
    Result := TRadIAEditAccess(AControl).Text
  else if AControl is TCustomComboBox then
    Result := TRadIAComboBoxAccess(AControl).Text
  else
    Result := TRadIAControlAccess(AControl).Caption;
  if Length(Result) > 1024 then
    SetLength(Result, 1024);
end;

function TRadIARuntimeVclControlAdapter.Discover(
  const ASession: TRadIARuntimeSessionIdentity;
  const ALimits: TRadIARuntimeVclAdapterLimits
): TArray<TRadIARuntimeControlSnapshot>;
var
  LForm: TCustomForm;
  LFormId: string;
  LFormIndex: Integer;
  LItems: TList<TRadIARuntimeControlSnapshot>;
  LPath: string;
begin
  if not ASession.IsComplete then
    raise EArgumentException.Create('Runtime session identity is incomplete.');
  if not ALimits.IsValid then
    raise EArgumentException.Create('Runtime VCL adapter limits are invalid.');
  LItems := TList<TRadIARuntimeControlSnapshot>.Create;
  try
    for LFormIndex := 0 to Screen.FormCount - 1 do
    begin
      if LItems.Count >= ALimits.MaxTargets then
        Break;
      LForm := Screen.Forms[LFormIndex];
      LPath := BuildPath(LForm);
      LFormId := BuildControlId(ASession.SessionId, LPath);
      LItems.Add(TRadIARuntimeControlSnapshot.Create(
        LFormId,
        '',
        LForm.ClassName,
        ControlText(LForm),
        LPath,
        TRadIARuntimeElementState.Create(
          LForm.Visible,
          LForm.Enabled,
          Capabilities(LForm)
        )
      ));
      CollectControls(ASession, LForm, LFormId, 1, ALimits, LItems);
    end;
    Result := LItems.ToArray;
  finally
    LItems.Free;
  end;
end;

function TRadIARuntimeVclControlAdapter.FindControl(
  const ASelector: TRadIARuntimeSelector;
  out AControl: TControl
): Boolean;
var
  LFormIndex: Integer;
  LMatchCount: Integer;
begin
  AControl := nil;
  LMatchCount := 0;
  for LFormIndex := 0 to Screen.FormCount - 1 do
  begin
    if Matches(Screen.Forms[LFormIndex], ASelector) then
    begin
      Inc(LMatchCount);
      AControl := Screen.Forms[LFormIndex];
    end;
    FindControlInParent(
      Screen.Forms[LFormIndex],
      ASelector,
      AControl,
      LMatchCount
    );
    if LMatchCount > 1 then
      Break;
  end;
  Result := LMatchCount = 1;
end;

function TRadIARuntimeVclControlAdapter.FindControlInParent(
  const AParent: TWinControl;
  const ASelector: TRadIARuntimeSelector;
  var AMatch: TControl;
  var AMatchCount: Integer
): Boolean;
var
  LControl: TControl;
  LIndex: Integer;
begin
  for LIndex := 0 to AParent.ControlCount - 1 do
  begin
    LControl := AParent.Controls[LIndex];
    if Matches(LControl, ASelector) then
    begin
      Inc(AMatchCount);
      AMatch := LControl;
    end;
    if LControl is TWinControl then
      FindControlInParent(
        TWinControl(LControl),
        ASelector,
        AMatch,
        AMatchCount
      );
    if AMatchCount > 1 then
      Exit(False);
  end;
  Result := AMatchCount = 1;
end;

function TRadIARuntimeVclControlAdapter.Matches(
  const AControl: TControl;
  const ASelector: TRadIARuntimeSelector
): Boolean;
begin
  Result :=
    ((ASelector.ControlName = '') or
      SameText(ASelector.ControlName, AControl.Name)) and
    ((ASelector.ClassName = '') or
      SameText(ASelector.ClassName, AControl.ClassName)) and
    ((ASelector.Text = '') or
      SameText(ASelector.Text, ControlText(AControl))) and
    ((ASelector.ParentPath = '') or
      StartsText(ASelector.ParentPath + '/', BuildPath(AControl)));
end;

function TRadIARuntimeVclControlAdapter.Execute(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction;
  const ALimits: TRadIARuntimeVclAdapterLimits
): TRadIARuntimeActionResult;
var
  LControl: TControl;
begin
  if not ASession.IsComplete or not ALimits.IsValid then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_invalid_session',
      'Runtime VCL session or limits are invalid.'
    ));
  if not FindControl(AAction.Selector, LControl) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_target_not_found',
      'A unique VCL control was not found for the selector.'
    ));
  if not LControl.Visible or
    ((AAction.Kind <> rakAssert) and not LControl.Enabled) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_target_unavailable',
      'The VCL control is not visible or enabled.'
    ));
  case AAction.Kind of
    rakInvoke:
      Exit(ExecuteInvoke(LControl));
    rakSetValue:
      Exit(ExecuteSetValue(LControl, AAction.Value));
    rakSelect:
      Exit(ExecuteSelect(LControl, AAction.Value));
    rakClose:
      Exit(ExecuteClose(LControl));
    rakAssert:
      if not SameText(ControlText(LControl), AAction.Value) then
        Exit(TRadIARuntimeActionResult.Failed(
          'runtime_vcl_assertion_failed',
          'The VCL control text did not match the expected value.'
        ));
  else
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_action_unsupported',
      'The requested VCL action is not supported.'
    ));
  end;
  Result := TRadIARuntimeActionResult.Succeeded(ControlText(LControl));
end;

function TRadIARuntimeVclControlAdapter.ExecuteClose(
  const AControl: TControl
): TRadIARuntimeActionResult;
begin
  if not (AControl is TCustomForm) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_capability_unavailable',
      'Only a VCL form can be closed.'
    ));
  TCustomForm(AControl).Close;
  Result := TRadIARuntimeActionResult.Succeeded(ControlText(AControl));
end;

function TRadIARuntimeVclControlAdapter.ExecuteInvoke(
  const AControl: TControl
): TRadIARuntimeActionResult;
begin
  if not (racInvoke in Capabilities(AControl)) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_capability_unavailable',
      'The VCL control cannot be invoked.'
    ));
  TRadIAControlAccess(AControl).Click;
  Result := TRadIARuntimeActionResult.Succeeded(ControlText(AControl));
end;

function TRadIARuntimeVclControlAdapter.ExecuteSelect(
  const AControl: TControl;
  const AValue: string
): TRadIARuntimeActionResult;
var
  LIndex: Integer;
begin
  if AControl is TCustomCheckBox then
    TRadIACheckBoxAccess(AControl).Checked := SameText(AValue, 'true')
  else if AControl is TCustomComboBox then
  begin
    LIndex := TCustomComboBox(AControl).Items.IndexOf(AValue);
    if LIndex < 0 then
      Exit(TRadIARuntimeActionResult.Failed(
        'runtime_vcl_value_not_found',
        'The requested combo box value was not found.'
      ));
    TCustomComboBox(AControl).ItemIndex := LIndex;
  end
  else if AControl is TCustomListBox then
  begin
    LIndex := TCustomListBox(AControl).Items.IndexOf(AValue);
    if LIndex < 0 then
      Exit(TRadIARuntimeActionResult.Failed(
        'runtime_vcl_value_not_found',
        'The requested list value was not found.'
      ));
    TCustomListBox(AControl).ItemIndex := LIndex;
  end
  else
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_capability_unavailable',
      'The VCL control does not support selection.'
    ));
  Result := TRadIARuntimeActionResult.Succeeded(ControlText(AControl));
end;

function TRadIARuntimeVclControlAdapter.ExecuteSetValue(
  const AControl: TControl;
  const AValue: string
): TRadIARuntimeActionResult;
begin
  if not (AControl is TCustomEdit) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_vcl_capability_unavailable',
      'The VCL control does not accept text.'
    ));
  TRadIAEditAccess(AControl).Text := AValue;
  Result := TRadIARuntimeActionResult.Succeeded(ControlText(AControl));
end;

end.
