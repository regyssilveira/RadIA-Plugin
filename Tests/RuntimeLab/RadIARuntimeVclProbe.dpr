program RadIARuntimeVclProbe;

{$APPTYPE CONSOLE}

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeAutomation in '..\..\Source\Core\RadIA.Core.RuntimeAutomation.pas',
  RadIA.Core.RuntimeVclAdapter in '..\..\Source\Core\RadIA.Core.RuntimeVclAdapter.pas',
  RadIA.OTA.RuntimeVclTransport in '..\..\Source\Integration\RadIA.OTA.RuntimeVclTransport.pas',
  RadIA.OTA.RuntimeVclFacade in '..\..\Source\Integration\RadIA.OTA.RuntimeVclFacade.pas';

type
  TRadIAEmptyRuntimeFacade = class(
    TInterfacedObject,
    IRadIARuntimeDiscoveryFacade,
    IRadIARuntimeActionFacade
  )
  public
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

function TRadIAEmptyRuntimeFacade.ExecuteAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := ValidateAction(ASession, AAction);
end;

function TRadIAEmptyRuntimeFacade.GetControlTree(
  const ASession: TRadIARuntimeSessionIdentity;
  const AWindowId: string
): TArray<TRadIARuntimeControlSnapshot>;
begin
  SetLength(Result, 0);
end;

function TRadIAEmptyRuntimeFacade.GetWindows(
  const ASession: TRadIARuntimeSessionIdentity
): TArray<TRadIARuntimeWindowSnapshot>;
begin
  SetLength(Result, 0);
end;

function TRadIAEmptyRuntimeFacade.ValidateAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := TRadIARuntimeActionResult.Failed(
    'runtime_target_not_found',
    'The empty facade has no controls.'
  );
end;

function PayloadContainsExpectedControls(const APayload: string): Boolean;
var
  LItems: TJSONArray;
  LRoot: TJSONObject;
begin
  Result := False;
  LRoot := TJSONObject.ParseJSONValue(APayload) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    LItems := LRoot.GetValue<TJSONArray>('controls');
    Result := Assigned(LItems) and
      APayload.Contains('btnFailOnOpen') and
      APayload.Contains('lblInstructions') and
      APayload.Contains('TRadIARuntimeLabMainForm');
  finally
    LRoot.Free;
  end;
end;

var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LAction: TRadIARuntimeScenarioAction;
  LActionFacade: IRadIARuntimeActionFacade;
  LBase: TRadIAEmptyRuntimeFacade;
  LControls: TArray<TRadIARuntimeControlSnapshot>;
  LDiscoveryFacade: IRadIARuntimeDiscoveryFacade;
  LLocator: IRadIARuntimeVclEndpointLocator;
  LProcessId: LongWord;
  LResult: TRadIARuntimeVclTransportResult;
  LSession: TRadIARuntimeSessionIdentity;
  LTransport: IRadIARuntimeVclTransport;

begin
  try
    if ParamCount <> 2 then
      raise EArgumentException.Create('Usage: RadIARuntimeVclProbe <pid> <session-id>');
    LProcessId := StrToUInt(ParamStr(1));
    LSession := TRadIARuntimeSessionIdentity.Create(
      ParamStr(2),
      LProcessId,
      Now,
      'RadIARuntimeLab.exe',
      'RadIARuntimeLab.dproj',
      'runtime-vcl-e2e'
    );
    LLocator := TRadIARuntimeVclEndpointLocator.Create;
    if not LLocator.Locate(LSession, LIdentity) then
      raise EInvalidOpException.Create('Runtime VCL endpoint was not discovered.');
    LTransport := TRadIARuntimeVclNamedPipeTransport.Create;
    LResult := LTransport.Send(
      LIdentity,
      'discover',
      '{}',
      TRadIARuntimeVclAdapterLimits.Defaults
    );
    if not LResult.Success then
      raise EInvalidOpException.Create(
        LResult.ErrorCode + ': ' + LResult.ErrorMessage
      );
    if not PayloadContainsExpectedControls(LResult.Payload) then
      raise EInvalidOpException.Create('Expected VCL controls were not returned.');
    LResult := LTransport.Send(
      LIdentity,
      'execute',
      '{"action":"assert","selector":{"controlName":"lblInstructions"},' +
      '"value":"Choose a deterministic Access Violation scenario.",' +
      '"timeoutMs":5000}',
      TRadIARuntimeVclAdapterLimits.Defaults
    );
    if not LResult.Success or not LResult.Payload.Contains('"success":true') then
      raise EInvalidOpException.Create(
        'Runtime VCL label assertion failed: ' + LResult.ErrorCode + ' ' +
        LResult.ErrorMessage + ' ' + LResult.Payload
      );
    LBase := TRadIAEmptyRuntimeFacade.Create;
    LDiscoveryFacade := TRadIACompositeRuntimeFacade.Create(
      LBase,
      LBase,
      LLocator,
      LTransport
    );
    LActionFacade := LDiscoveryFacade as IRadIARuntimeActionFacade;
    LControls := LDiscoveryFacade.GetControlTree(LSession, 'test-window');
    if Length(LControls) = 0 then
      raise EInvalidOpException.Create('Composite facade did not merge VCL controls.');
    LAction := TRadIARuntimeScenarioAction.Create(
      rakAssert,
      TRadIARuntimeSelector.Create('', '', 'lblInstructions', '', ''),
      'Choose a deterministic Access Violation scenario.',
      5000
    );
    LResult := Default(TRadIARuntimeVclTransportResult);
    if not LActionFacade.ValidateAction(LSession, LAction).Success then
      raise EInvalidOpException.Create('Composite facade did not validate the VCL label.');
    if not LActionFacade.ExecuteAction(LSession, LAction).Success then
      raise EInvalidOpException.Create('Composite facade did not assert the VCL label.');
    Writeln('Runtime VCL cross-process discovery passed.');
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
