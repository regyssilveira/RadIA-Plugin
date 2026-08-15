unit RadIA.Core.ThreadingAssistantTools;

interface

uses
  RadIA.Core.ThreadingAssistant,
  RadIA.Core.Tools;

procedure RegisterRadIAThreadingAssistantTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAThreadingAssistantService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAAnalyzeThreadingRisksTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIAThreadingAssistantService;
  public
    constructor Create(const AService: IRadIAThreadingAssistantService);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAPrepareThreadModernizationTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIAThreadingAssistantService;
  public
    constructor Create(const AService: IRadIAThreadingAssistantService);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIAAnalyzeThreadingRisksTool.Create(const AService: IRadIAThreadingAssistantService);
begin
  inherited Create;
  FService := AService;
end;

function TRadIAAnalyzeThreadingRisksTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAnalysis: TRadIAThreadAnalysis;
  LItem: TJSONObject;
  LOutput: TJSONObject;
  LRisk: TRadIAThreadRisk;
  LRisks: TJSONArray;
begin
  LAnalysis := FService.Analyze;
  LOutput := TJSONObject.Create;
  try
    LOutput.AddPair('backgroundWork', TJSONBool.Create(LAnalysis.BackgroundWork));
    LRisks := TJSONArray.Create;
    LOutput.AddPair('risks', LRisks);
    for LRisk in LAnalysis.Risks do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('code', LRisk.Code);
      LItem.AddPair('line', TJSONNumber.Create(LRisk.Line));
      LItem.AddPair('message', LRisk.Message);
      LRisks.AddElement(LItem);
    end;
    Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
  finally
    LOutput.Free;
  end;
end;

function TRadIAAnalyzeThreadingRisksTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'AnalyzeThreadingRisks',
    '1.0.0',
    'Detects VCL access, cancellation, and exception-handling risks in Delphi background work.',
    '{"type":"object","properties":{},"additionalProperties":false}',
    '{"type":"object","required":["backgroundWork","risks"]}',
    trReadOnly
  );
end;

constructor TRadIAPrepareThreadModernizationTool.Create(
  const AService: IRadIAThreadingAssistantService
);
begin
  inherited Create;
  FService := AService;
end;

function TRadIAPrepareThreadModernizationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LInput: TJSONObject;
  LOutput: TJSONObject;
  LResult: TRadIAThreadPreparation;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  try
    if not Assigned(LInput) then
      Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
    LResult := FService.PrepareReplacement(
      LInput.GetValue<string>('originalText', ''),
      LInput.GetValue<string>('replacementText', '')
    );
    if not LResult.Success then
      Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
    LOutput := TJSONObject.Create;
    try
      LOutput.AddPair('previewId', LResult.Patch.Preview.Id);
      LOutput.AddPair('proposedContent', LResult.Patch.Preview.ProposedContent);
      Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
end;

function TRadIAPrepareThreadModernizationTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareThreadModernization',
    '1.0.0',
    'Validates safeguards and prepares a reviewable Delphi threading patch.',
    '{"type":"object","required":["originalText","replacementText"],' +
      '"properties":{"originalText":{"type":"string"},"replacementText":{"type":"string"}},' +
      '"additionalProperties":false}',
    '{"type":"object","required":["previewId","proposedContent"]}',
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

procedure RegisterRadIAThreadingAssistantTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAThreadingAssistantService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAAnalyzeThreadingRisksTool.Create(AService));
  ARegistry.RegisterTool(TRadIAPrepareThreadModernizationTool.Create(AService));
end;

end.
