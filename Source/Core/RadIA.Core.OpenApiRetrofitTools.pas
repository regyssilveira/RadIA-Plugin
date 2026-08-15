unit RadIA.Core.OpenApiRetrofitTools;

interface

uses
  RadIA.Core.OpenApiRetrofit,
  RadIA.Core.Tools;

procedure RegisterRadIAOpenApiRetrofitTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAOpenApiRetrofitService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAInventoryExistingApiRoutesTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIAOpenApiRetrofitService;
  public
    constructor Create(const AService: IRadIAOpenApiRetrofitService);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAPrepareOpenApiRetrofitTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIAOpenApiRetrofitService;
  public
    constructor Create(const AService: IRadIAOpenApiRetrofitService);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIAInventoryExistingApiRoutesTool.Create(
  const AService: IRadIAOpenApiRetrofitService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAInventoryExistingApiRoutesTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LOutput: TJSONObject;
  LRoute: TRadIAExistingApiRoute;
  LRoutes: TArray<TRadIAExistingApiRoute>;
begin
  LRoutes := FService.InventoryRoutes;
  LOutput := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LOutput.AddPair('routes', LArray);
    for LRoute in LRoutes do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('method', LRoute.Method);
      LItem.AddPair('path', LRoute.Path);
      LItem.AddPair('fileName', LRoute.FileName);
      LItem.AddPair('line', TJSONNumber.Create(LRoute.Line));
      LArray.AddElement(LItem);
    end;
    LOutput.AddPair('routeCount', TJSONNumber.Create(Length(LRoutes)));
    Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
  finally
    LOutput.Free;
  end;
end;

function TRadIAInventoryExistingApiRoutesTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'InventoryExistingApiRoutes',
    '1.0.0',
    'Inventories existing DEXT minimal routes and controller attributes without changing the project.',
    '{"type":"object","properties":{},"additionalProperties":false}',
    '{"type":"object","required":["routes","routeCount"]}',
    trReadOnly
  );
end;

constructor TRadIAPrepareOpenApiRetrofitTool.Create(
  const AService: IRadIAOpenApiRetrofitService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAPrepareOpenApiRetrofitTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LInput: TJSONObject;
  LOutput: TJSONObject;
  LResult: TRadIAOpenApiRetrofitResult;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  try
    if not Assigned(LInput) then
      Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
    LResult := FService.Prepare(
      LInput.GetValue<string>('title', ''),
      LInput.GetValue<string>('version', '1.0.0')
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

function TRadIAPrepareOpenApiRetrofitTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareOpenApiRetrofit',
    '1.0.0',
    'Prepares a reviewable Swagger integration patch for an existing DEXT startup unit.',
    '{"type":"object","required":["title"],"properties":{' +
      '"title":{"type":"string"},"version":{"type":"string"}},' +
      '"additionalProperties":false}',
    '{"type":"object","required":["previewId","proposedContent"]}',
    trReadOnly
  ).WithExecutionOptions(15000, True);
end;

procedure RegisterRadIAOpenApiRetrofitTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAOpenApiRetrofitService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAInventoryExistingApiRoutesTool.Create(AService));
  ARegistry.RegisterTool(TRadIAPrepareOpenApiRetrofitTool.Create(AService));
end;

end.
