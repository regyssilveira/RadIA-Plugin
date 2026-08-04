unit RadIA.Core.DevelopmentTransactionTools;

interface

uses
  RadIA.Core.DevelopmentTransactions,
  RadIA.Core.Tools;

procedure RegisterRadIADevelopmentTransactionTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADevelopmentTransactionService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIADevelopmentTransactionToolKind = (
    dttPrepare,
    dttApply,
    dttRevert
  );

  TRadIADevelopmentTransactionTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIADevelopmentTransactionToolKind;
    FService: IRadIADevelopmentTransactionService;
    function ParseKind(
      const AValue: string
    ): TRadIADevelopmentOperationKind;
    function ParseOperations(
      const AJson: TJSONObject
    ): TArray<TRadIADevelopmentOperation>;
    function ResultToToolResult(
      const AResult: TRadIADevelopmentTransactionResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIADevelopmentTransactionToolKind;
      const AService: IRadIADevelopmentTransactionService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CPrepareInputSchema =
    '{"type":"object","required":["operations"],"properties":{' +
    '"operations":{"type":"array","minItems":1,"maxItems":32,' +
    '"items":{"type":"object","required":["kind","previewId"],' +
    '"properties":{"kind":{"type":"string","enum":[' +
    '"multiFilePatch","projectFile","designerComponent",' +
    '"designerLayout","designerProperty","designerEvent"]},' +
    '"previewId":{"type":"string"}},"additionalProperties":false}}},' +
    '"additionalProperties":false}';
  CPreviewInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string"}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state","operations"],' +
    '"properties":{"previewId":{"type":"string"},' +
    '"state":{"type":"string"},"operations":{"type":"array"}}}';

constructor TRadIADevelopmentTransactionTool.Create(
  const AKind: TRadIADevelopmentTransactionToolKind;
  const AService: IRadIADevelopmentTransactionService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIADevelopmentTransactionTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LPreviewId: string;
  LResult: TRadIADevelopmentTransactionResult;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Development transaction arguments must be a valid JSON object.'
    ));
  try
    if FKind = dttPrepare then
      LResult := FService.Prepare(ParseOperations(LJson))
    else
    begin
      LPreviewId := LJson.GetValue<string>('previewId', '');
      if LPreviewId = '' then
        Exit(TRadIAToolResult.Failed(
          'invalid_request',
          'Argument "previewId" must not be empty.'
        ));
      if FKind = dttApply then
        LResult := FService.Apply(LPreviewId)
      else
        LResult := FService.Revert(LPreviewId);
    end;
    Result := ResultToToolResult(LResult);
  finally
    LJson.Free;
  end;
end;

function TRadIADevelopmentTransactionTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    dttPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareDevelopmentTransaction',
        '1.0.0',
        'Groups reviewed code, project, and Designer previews.',
        CPrepareInputSchema,
        COutputSchema,
        trReadOnly
      );
    dttApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyDevelopmentTransaction',
        '1.0.0',
        'Applies all grouped operations with reverse-order compensation.',
        CPreviewInputSchema,
        COutputSchema,
        trStructuralWrite
      );
  else
    Result := TRadIAToolDescriptor.Create(
      'RevertDevelopmentTransaction',
      '1.0.0',
      'Reverts all grouped operations with symmetric compensation.',
      CPreviewInputSchema,
      COutputSchema,
      trReversibleWrite
    );
  end;
end;

function TRadIADevelopmentTransactionTool.ParseKind(
  const AValue: string
): TRadIADevelopmentOperationKind;
begin
  if SameText(AValue, 'multiFilePatch') then
    Exit(dokMultiFilePatch);
  if SameText(AValue, 'projectFile') then
    Exit(dokProjectFile);
  if SameText(AValue, 'designerComponent') then
    Exit(dokDesignerComponent);
  if SameText(AValue, 'designerLayout') then
    Exit(dokDesignerLayout);
  if SameText(AValue, 'designerProperty') then
    Exit(dokDesignerProperty);
  if SameText(AValue, 'designerEvent') then
    Exit(dokDesignerEvent);
  raise EArgumentException.Create(
    'Development transaction contains an unsupported operation kind.'
  );
end;

function TRadIADevelopmentTransactionTool.ParseOperations(
  const AJson: TJSONObject
): TArray<TRadIADevelopmentOperation>;
var
  LArray: TJSONArray;
  LIndex: Integer;
  LOperationJson: TJSONObject;
begin
  LArray := AJson.GetValue<TJSONArray>('operations');
  if not Assigned(LArray) then
    raise EArgumentException.Create(
      'Argument "operations" must be an array.'
    );
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    if not (LArray.Items[LIndex] is TJSONObject) then
      raise EArgumentException.Create(
        'Each development operation must be an object.'
      );
    LOperationJson := TJSONObject(LArray.Items[LIndex]);
    Result[LIndex] := TRadIADevelopmentOperation.Create(
      ParseKind(LOperationJson.GetValue<string>('kind', '')),
      LOperationJson.GetValue<string>('previewId', '')
    );
  end;
end;

function TRadIADevelopmentTransactionTool.ResultToToolResult(
  const AResult: TRadIADevelopmentTransactionResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LOperation: TRadIADevelopmentOperation;
  LOperationJson: TJSONObject;
  LOperations: TJSONArray;
  LState: string;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));
  case AResult.Preview.State of
    dtsPrepared: LState := 'prepared';
    dtsApplied: LState := 'applied';
  else
    LState := 'reverted';
  end;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('state', LState);
    LJson.AddPair(
      'expiresAtUtc',
      DateToISO8601(AResult.Preview.ExpiresAtUtc, True)
    );
    LOperations := TJSONArray.Create;
    LJson.AddPair('operations', LOperations);
    for LOperation in AResult.Preview.Operations do
    begin
      LOperationJson := TJSONObject.Create;
      LOperationJson.AddPair(
        'kind',
        RadIADevelopmentOperationKindName(LOperation.Kind)
      );
      LOperationJson.AddPair('previewId', LOperation.PreviewId);
      LOperations.AddElement(LOperationJson);
    end;
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure RegisterRadIADevelopmentTransactionTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADevelopmentTransactionService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  ARegistry.RegisterTool(
    TRadIADevelopmentTransactionTool.Create(dttPrepare, AService)
  );
  ARegistry.RegisterTool(
    TRadIADevelopmentTransactionTool.Create(dttApply, AService)
  );
  ARegistry.RegisterTool(
    TRadIADevelopmentTransactionTool.Create(dttRevert, AService)
  );
end;

end.
