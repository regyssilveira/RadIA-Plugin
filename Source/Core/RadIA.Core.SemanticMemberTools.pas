unit RadIA.Core.SemanticMemberTools;

interface

uses
  RadIA.Core.SemanticMembers,
  RadIA.Core.Tools;

procedure RegisterRadIASemanticMemberTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticMemberService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIAPrepareMissingMembersTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIASemanticMemberService;
  public
    constructor Create(const AService: IRadIASemanticMemberService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["targetFile","baseRevision",' +
    '"container"],"properties":{"targetFile":{"type":"string"},' +
    '"baseRevision":{"type":"string"},"container":{"type":"string"}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["changed","targetFile",' +
    '"missingCount"],"properties":{"changed":{"type":"boolean"},' +
    '"previewId":{"type":"string"},"targetFile":{"type":"string"},' +
    '"baseRevision":{"type":"string"},"proposedRevision":' +
    '{"type":"string"},"missingCount":{"type":"integer"},' +
    '"expiresAtUtc":{"type":"string"}}}';

constructor TRadIAPrepareMissingMembersTool.Create(
  const AService: IRadIASemanticMemberService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAPrepareMissingMembersTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LOutput: TJSONObject;
  LResult: TRadIASemanticMemberPreviewResult;
begin
  LArguments := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Semantic member arguments must be a JSON object.'
    ));
  try
    LResult := FService.PrepareMissingMembers(
      LArguments.GetValue<string>('targetFile', ''),
      LArguments.GetValue<string>('baseRevision', ''),
      LArguments.GetValue<string>('container', '')
    );
    if not LResult.Success then
      Exit(TRadIAToolResult.Failed(
        LResult.ErrorCode,
        LResult.ErrorMessage
      ));
    LOutput := TJSONObject.Create;
    try
      LOutput.AddPair('changed', TJSONBool.Create(LResult.Changed));
      LOutput.AddPair(
        'targetFile',
        LArguments.GetValue<string>('targetFile', '')
      );
      LOutput.AddPair(
        'missingCount',
        TJSONNumber.Create(LResult.MissingCount)
      );
      if LResult.Changed then
      begin
        LOutput.AddPair('previewId', LResult.PatchResult.Preview.Id);
        LOutput.AddPair(
          'baseRevision',
          LResult.PatchResult.Preview.Spec.BaseRevision
        );
        LOutput.AddPair(
          'proposedRevision',
          LResult.PatchResult.Preview.ProposedRevision
        );
        LOutput.AddPair(
          'expiresAtUtc',
          DateToISO8601(
            LResult.PatchResult.Preview.ExpiresAtUtc,
            True
          )
        );
      end;
      Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
    finally
      LOutput.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAPrepareMissingMembersTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareMissingMembers',
    '1.0.0',
    'Prepares an idempotent patch for indexed interface members missing from a class.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

procedure RegisterRadIASemanticMemberTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticMemberService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareMissingMembersTool.Create(AService));
end;

end.
