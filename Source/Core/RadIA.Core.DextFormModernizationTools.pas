unit RadIA.Core.DextFormModernizationTools;

interface

uses
  RadIA.Core.DextFormModernization,
  RadIA.Core.Tools;

procedure RegisterRadIADextFormModernizationTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADextFormModernizationService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIADextFormModernizationToolKind = (fmtPrepare, fmtRecordGate);

  TRadIADextFormModernizationTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIADextFormModernizationToolKind;
    FService: IRadIADextFormModernizationService;
  public
    constructor Create(
      const AKind: TRadIADextFormModernizationToolKind;
      const AService: IRadIADextFormModernizationService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CPrepareSchema =
    '{"type":"object","required":["migrationReport","parityEvidence","files"],' +
    '"properties":{"migrationReport":{"type":"object"},"parityEvidence":{"type":"string"},' +
    '"files":{"type":"array","minItems":3,"maxItems":32,"items":{"type":"object",' +
    '"required":["targetFile","baseRevision","proposedContent"],"properties":{' +
    '"targetFile":{"type":"string"},"baseRevision":{"type":"string"},' +
    '"proposedContent":{"type":"string"}}}}},"additionalProperties":false}';
  CGateSchema =
    '{"type":"object","required":["previewId","buildPassed","testsPassed",' +
    '"buildEvidence","testEvidence"],"properties":{"previewId":{"type":"string"},' +
    '"buildPassed":{"type":"boolean"},"testsPassed":{"type":"boolean"},' +
    '"buildEvidence":{"type":"string"},"testEvidence":{"type":"string"}},' +
    '"additionalProperties":false}';

constructor TRadIADextFormModernizationTool.Create(
  const AKind: TRadIADextFormModernizationToolKind;
  const AService: IRadIADextFormModernizationService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIADextFormModernizationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  try
    if not Assigned(LArguments) then
      Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
    if FKind = fmtPrepare then
      Result := FService.Prepare(LArguments)
    else
      Result := FService.RecordGate(LArguments);
  finally
    LArguments.Free;
  end;
end;

function TRadIADextFormModernizationTool.GetDescriptor: TRadIAToolDescriptor;
begin
  if FKind = fmtPrepare then
    Result := TRadIAToolDescriptor.Create(
      'PrepareDextFormModernization',
      '1.0.0',
      'Validates migration, parity, DEXT boundaries, and DFM/Pascal consistency before a reversible patch.',
      CPrepareSchema,
      '{"type":"object","required":["previewId","state","files"]}',
      trReversibleWrite
    ).WithExecutionOptions(30000, True)
  else
    Result := TRadIAToolDescriptor.Create(
      'RecordDextFormModernizationGate',
      '1.0.0',
      'Records build and test evidence and reverts the modernization when a gate fails.',
      CGateSchema,
      '{"type":"object","required":["previewId","state"]}',
      trReversibleWrite
    ).WithExecutionOptions(30000, True);
end;

procedure RegisterRadIADextFormModernizationTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADextFormModernizationService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIADextFormModernizationTool.Create(fmtPrepare, AService));
  ARegistry.RegisterTool(TRadIADextFormModernizationTool.Create(fmtRecordGate, AService));
end;

end.
