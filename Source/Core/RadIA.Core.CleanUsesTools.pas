unit RadIA.Core.CleanUsesTools;

interface

uses
  RadIA.Core.CleanUses,
  RadIA.Core.Tools;

procedure RegisterRadIACleanUsesTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIACleanUsesService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAPrepareCleanUsesTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIACleanUsesService;
  public
    constructor Create(const AService: IRadIACleanUsesService);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIAPrepareCleanUsesTool.Create(
  const AService: IRadIACleanUsesService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAPrepareCleanUsesTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCandidate: string;
  LCandidates: TJSONArray;
  LOutput: TJSONObject;
  LResult: TRadIACleanUsesResult;
begin
  LResult := FService.Prepare;
  if not LResult.Success then
    Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
  LOutput := TJSONObject.Create;
  try
    LOutput.AddPair('previewId', LResult.Patch.Preview.Id);
    LOutput.AddPair('proposedContent', LResult.Patch.Preview.ProposedContent);
    LCandidates := TJSONArray.Create;
    LOutput.AddPair('candidates', LCandidates);
    for LCandidate in LResult.Candidates do
      LCandidates.Add(LCandidate);
    Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
  finally
    LOutput.Free;
  end;
end;

function TRadIAPrepareCleanUsesTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareCleanUses',
    '1.0.0',
    'Prepares a conservative semantic preview that removes unused Pascal units.',
    '{"type":"object","properties":{},"additionalProperties":false}',
    '{"type":"object","required":["previewId","proposedContent","candidates"]}',
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

procedure RegisterRadIACleanUsesTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIACleanUsesService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareCleanUsesTool.Create(AService));
end;

end.
