unit RadIA.Core.StackTraceTools;

interface

uses
  RadIA.Core.StackTraceAnalysis,
  RadIA.Core.Tools;

procedure RegisterRadIAStackTraceTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAStackTraceAnalysisService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAAnalyzeProjectStackTraceTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIAStackTraceAnalysisService;
  public
    constructor Create(const AService: IRadIAStackTraceAnalysisService);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["stackTrace"],"properties":{' +
    '"stackTrace":{"type":"string","maxLength":524288},' +
    '"maxFrames":{"type":"integer","minimum":1,"maximum":500}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["format","frames"],"properties":{' +
    '"format":{"type":"string"},"frames":{"type":"array"}}}';

constructor TRadIAAnalyzeProjectStackTraceTool.Create(
  const AService: IRadIAStackTraceAnalysisService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAAnalyzeProjectStackTraceTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAnalysis: TRadIAStackTraceAnalysis;
  LArguments: TJSONObject;
  LFrame: TRadIAStackTraceFrame;
  LFrameJson: TJSONObject;
  LFrames: TJSONArray;
  LOutput: TJSONObject;
  LText: string;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed('invalid_request', 'Arguments must be a JSON object.'));
  try
    LText := LArguments.GetValue<string>('stackTrace', '');
    if Trim(LText) = '' then
      Exit(TRadIAToolResult.Failed('invalid_request', 'A stack trace is required.'));
    try
      LAnalysis := FService.Analyze(
        LText,
        LArguments.GetValue<Integer>('maxFrames', 100)
      );
    except
      on E: EArgumentOutOfRangeException do
        Exit(TRadIAToolResult.Failed('trace_too_large', E.Message));
    end;
    LOutput := TJSONObject.Create;
    try
      LOutput.AddPair('format', LAnalysis.DetectedFormat);
      LFrames := TJSONArray.Create;
      LOutput.AddPair('frames', LFrames);
      for LFrame in LAnalysis.Frames do
      begin
        LFrameJson := TJSONObject.Create;
        LFrameJson.AddPair('rawText', LFrame.RawText);
        LFrameJson.AddPair('fileName', LFrame.FileName);
        LFrameJson.AddPair('methodName', LFrame.MethodName);
        LFrameJson.AddPair('line', TJSONNumber.Create(LFrame.Line));
        LFrameJson.AddPair('resolved', TJSONBool.Create(LFrame.Resolved));
        LFrameJson.AddPair('confidence', LFrame.Confidence);
        LFrames.AddElement(LFrameJson);
      end;
      Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
    finally
      LOutput.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAAnalyzeProjectStackTraceTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'AnalyzeProjectStackTrace',
    '1.0.0',
    'Parses Delphi, MadExcept, or EurekaLog traces and resolves frames across project units.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(5000, True);
end;

procedure RegisterRadIAStackTraceTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAStackTraceAnalysisService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAAnalyzeProjectStackTraceTool.Create(AService));
end;

end.
