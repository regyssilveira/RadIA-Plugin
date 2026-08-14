unit RadIA.Core.ProductivityGenerationTools;

interface

uses
  RadIA.Core.GeneratedArtifacts,
  RadIA.Core.ProductivityGeneration,
  RadIA.Core.Tools;

procedure RegisterRadIAProductivityGenerationTools(
  const ARegistry: IRadIAToolRegistry;
  const AGeneration: IRadIAProductivityGenerationService;
  const AArtifacts: IRadIAGeneratedArtifactService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIAProductivityToolKind = (
    ptkPrepareApi,
    ptkPrepareMock,
    ptkApply,
    ptkRevert
  );

  TRadIAProductivityTool = class(TInterfacedObject, IRadIATool)
  private
    FArtifacts: IRadIAGeneratedArtifactService;
    FGeneration: IRadIAProductivityGenerationService;
    FKind: TRadIAProductivityToolKind;
    function ResultToToolResult(
      const AResult: TRadIAGeneratedArtifactResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIAProductivityToolKind;
      const AGeneration: IRadIAProductivityGenerationService;
      const AArtifacts: IRadIAGeneratedArtifactService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CApiInputSchema =
    '{"type":"object","properties":{"fileName":{"type":"string"}},' +
    '"additionalProperties":false}';
  CMockInputSchema =
    '{"type":"object","required":["interfaceName","unitName"],' +
    '"properties":{"interfaceName":{"type":"string"},' +
    '"unitName":{"type":"string"},"relativeDirectory":{"type":"string"},' +
    '"registerInProject":{"type":"boolean"}},"additionalProperties":false}';
  CPreviewInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string"}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","fileName","content",' +
    '"sha256","state"],"properties":{"previewId":{"type":"string"},' +
    '"fileName":{"type":"string"},"content":{"type":"string"},' +
    '"sha256":{"type":"string"},"state":{"type":"string"},' +
    '"registerInProject":{"type":"boolean"}}}';

constructor TRadIAProductivityTool.Create(
  const AKind: TRadIAProductivityToolKind;
  const AGeneration: IRadIAProductivityGenerationService;
  const AArtifacts: IRadIAGeneratedArtifactService
);
begin
  inherited Create;
  if not Assigned(AGeneration) then
    raise EArgumentNilException.Create('AGeneration');
  if not Assigned(AArtifacts) then
    raise EArgumentNilException.Create('AArtifacts');
  FKind := AKind;
  FGeneration := AGeneration;
  FArtifacts := AArtifacts;
end;

function TRadIAProductivityTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LPreviewId: string;
  LResult: TRadIAGeneratedArtifactResult;
begin
  LArguments := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Productivity generation arguments must be a JSON object.'
    ));
  try
    case FKind of
      ptkPrepareApi:
        LResult := FGeneration.PrepareApiDocumentation(
          LArguments.GetValue<string>('fileName', 'API.md')
        );
      ptkPrepareMock:
        LResult := FGeneration.PrepareMockUnit(
          LArguments.GetValue<string>('interfaceName', ''),
          LArguments.GetValue<string>('unitName', ''),
          LArguments.GetValue<string>('relativeDirectory', 'Tests'),
          LArguments.GetValue<Boolean>('registerInProject', False)
        );
    else
      LPreviewId := LArguments.GetValue<string>('previewId', '');
      if LPreviewId = '' then
        Exit(TRadIAToolResult.Failed(
          'invalid_request',
          'A generated artifact preview ID is required.'
        ));
      if FKind = ptkApply then
        LResult := FArtifacts.Apply(LPreviewId)
      else
        LResult := FArtifacts.Revert(LPreviewId);
    end;
    Result := ResultToToolResult(LResult);
  finally
    LArguments.Free;
  end;
end;

function TRadIAProductivityTool.GetDescriptor: TRadIAToolDescriptor;
begin
  case FKind of
    ptkPrepareApi:
      Result := TRadIAToolDescriptor.Create(
        'PrepareApiDocumentation',
        '1.0.0',
        'Previews deterministic API.md content from indexed public project symbols.',
        CApiInputSchema,
        COutputSchema,
        trReadOnly
      ).WithExecutionOptions(10000, True);
    ptkPrepareMock:
      Result := TRadIAToolDescriptor.Create(
        'PrepareMockUnit',
        '1.0.0',
        'Previews an isolated Pascal mock unit for an indexed interface.',
        CMockInputSchema,
        COutputSchema,
        trReadOnly
      ).WithExecutionOptions(10000, True);
    ptkApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyGeneratedArtifact',
        '1.0.0',
        'Creates one reviewed artifact and optionally registers a Pascal unit.',
        CPreviewInputSchema,
        COutputSchema,
        trStructuralWrite
      );
  else
    Result := TRadIAToolDescriptor.Create(
      'RevertGeneratedArtifact',
      '1.0.0',
      'Removes an unchanged artifact created from the reviewed preview.',
      CPreviewInputSchema,
      COutputSchema,
      trReversibleWrite
    );
  end;
end;

function TRadIAProductivityTool.ResultToToolResult(
  const AResult: TRadIAGeneratedArtifactResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LState: string;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));
  case AResult.Preview.State of
    gasPrepared: LState := 'prepared';
    gasApplied: LState := 'applied';
  else
    LState := 'reverted';
  end;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('fileName', AResult.Preview.FileName);
    LJson.AddPair('content', AResult.Preview.Content);
    LJson.AddPair('sha256', AResult.Preview.Revision);
    LJson.AddPair('state', LState);
    LJson.AddPair(
      'registerInProject',
      TJSONBool.Create(AResult.Preview.RegisterInProject)
    );
    LJson.AddPair(
      'expiresAtUtc',
      DateToISO8601(AResult.Preview.ExpiresAtUtc, True)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure RegisterRadIAProductivityGenerationTools(
  const ARegistry: IRadIAToolRegistry;
  const AGeneration: IRadIAProductivityGenerationService;
  const AArtifacts: IRadIAGeneratedArtifactService
);
var
  LKind: TRadIAProductivityToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  for LKind := Low(TRadIAProductivityToolKind) to
    High(TRadIAProductivityToolKind) do
    ARegistry.RegisterTool(TRadIAProductivityTool.Create(
      LKind,
      AGeneration,
      AArtifacts
    ));
end;

end.
