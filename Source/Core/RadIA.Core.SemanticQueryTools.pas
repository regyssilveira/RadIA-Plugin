unit RadIA.Core.SemanticQueryTools;

interface

uses
  RadIA.Core.SemanticQueries,
  RadIA.Core.Tools;

procedure RegisterRadIASemanticQueryTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticQueryService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAGetSemanticContextTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIASemanticQueryService;
  public
    constructor Create(const AService: IRadIASemanticQueryService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["symbol"],"properties":{' +
    '"symbol":{"type":"string"},"maxCharacters":{"type":"integer",' +
    '"minimum":256,"maximum":32768}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["symbol","context"],"properties":{' +
    '"symbol":{"type":"string"},"context":{"type":"string"}}}';

constructor TRadIAGetSemanticContextTool.Create(
  const AService: IRadIASemanticQueryService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAGetSemanticContextTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LContext: string;
  LError: string;
  LMaxCharacters: Integer;
  LOutput: TJSONObject;
  LSymbol: string;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Semantic context arguments must be a JSON object.'
    ));
  try
    LSymbol := Trim(LArguments.GetValue<string>('symbol', ''));
    LMaxCharacters := LArguments.GetValue<Integer>('maxCharacters', 8192);
    if LSymbol = '' then
      Exit(TRadIAToolResult.Failed(
        'invalid_request',
        'A symbol name is required.'
      ));
    if not FService.BuildContext(
      LSymbol,
      LMaxCharacters,
      LContext,
      LError
    ) then
      Exit(TRadIAToolResult.Failed(
        'semantic_context_unavailable',
        LError +
        ' Use GetEditorSemanticContext for bounded active-unit fallback.'
      ));
    LOutput := TJSONObject.Create;
    try
      LOutput.AddPair('symbol', LSymbol);
      LOutput.AddPair('context', LContext);
      Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
    finally
      LOutput.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAGetSemanticContextTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetSemanticContext',
    '1.0.0',
    'Returns indexed declarations and resolved inherited members for a Delphi symbol.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(5000, True);
end;

procedure RegisterRadIASemanticQueryTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticQueryService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAGetSemanticContextTool.Create(AService));
end;

end.
