unit RadIA.Core.DesignerEventTools;

interface

uses
  RadIA.Core.DesignerEvents,
  RadIA.Core.Tools;

procedure RegisterRadIADesignerEventTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAFormEventService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIADesignerEventToolKind = (
    detkPrepare,
    detkApply,
    detkRevert
  );

  TRadIADesignerEventTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIADesignerEventToolKind;
    FService: IRadIAFormEventService;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetRequiredString(
      const AJson: TJSONObject;
      const AName: string
    ): string;
    function ToToolResult(
      const AResult: TRadIAFormEventResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIADesignerEventToolKind;
      const AService: IRadIAFormEventService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CPrepareInput =
    '{"type":"object","required":["componentName","eventName","handlerName"],' +
    '"properties":{"componentName":{"type":"string"},' +
    '"eventName":{"type":"string"},"handlerName":{"type":"string"}},' +
    '"additionalProperties":false}';
  CPreviewInput =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string"}},"additionalProperties":false}';
  COutput =
    '{"type":"object","required":["previewId","formFileName","unitFileName",' +
    '"componentName","eventName","eventTypeName","handlerName"],"properties":{' +
    '"previewId":{"type":"string"},"formFileName":{"type":"string"},' +
    '"unitFileName":{"type":"string"},"componentName":{"type":"string"},' +
    '"eventName":{"type":"string"},"eventTypeName":{"type":"string"},' +
    '"handlerName":{"type":"string"},"expiresAtUtc":{"type":"string"}}}';

procedure RegisterRadIADesignerEventTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAFormEventService
);
var
  LKind: TRadIADesignerEventToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  for LKind := Low(TRadIADesignerEventToolKind) to
    High(TRadIADesignerEventToolKind) do
    ARegistry.RegisterTool(
      TRadIADesignerEventTool.Create(LKind, AService)
    );
end;

constructor TRadIADesignerEventTool.Create(
  const AKind: TRadIADesignerEventToolKind;
  const AService: IRadIAFormEventService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIADesignerEventTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LPreviewId: string;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Form Designer event arguments must be a JSON object.'
    ));
  try
    case FKind of
      detkPrepare:
        Result := ToToolResult(
          FService.Prepare(
            GetRequiredString(LJson, 'componentName'),
            GetRequiredString(LJson, 'eventName'),
            GetRequiredString(LJson, 'handlerName')
          )
        );
      detkApply:
        begin
          LPreviewId := GetRequiredString(LJson, 'previewId');
          Result := ToToolResult(FService.Apply(LPreviewId));
        end;
      detkRevert:
        begin
          LPreviewId := GetRequiredString(LJson, 'previewId');
          Result := ToToolResult(FService.Revert(LPreviewId));
        end;
    else
      Result := TRadIAToolResult.Failed(
        'unsupported_tool',
        'Form Designer event tool kind is not supported.'
      );
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerEventTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    detkPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareFormEventHandler',
        '1.0',
        'Prepares an atomic source and Form Designer event handler preview.',
        CPrepareInput,
        COutput,
        trReadOnly
      );
    detkApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyFormEventHandler',
        '1.0',
        'Creates and binds a reviewed handler through the live Form Designer.',
        CPreviewInput,
        COutput,
        trStructuralWrite
      );
    detkRevert:
      Result := TRadIAToolDescriptor.Create(
        'RevertFormEventHandler',
        '1.0',
        'Unbinds the handler and restores the reviewed Pascal source snapshot.',
        CPreviewInput,
        COutput,
        trStructuralWrite
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIADesignerEventTool.GetRequiredString(
  const AJson: TJSONObject;
  const AName: string
): string;
begin
  Result := AJson.GetValue<string>(AName, '');
  if Trim(Result) = '' then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must not be empty.',
      [AName]
    );
end;

function TRadIADesignerEventTool.ToToolResult(
  const AResult: TRadIAFormEventResult
): TRadIAToolResult;
var
  LIdentity: TRadIAFormEventIdentity;
  LJson: TJSONObject;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));
  LIdentity := AResult.Preview.State.Identity;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('formFileName', LIdentity.FormFileName);
    LJson.AddPair('unitFileName', LIdentity.UnitFileName);
    LJson.AddPair('componentName', LIdentity.ComponentName);
    LJson.AddPair('eventName', LIdentity.EventName);
    LJson.AddPair('eventTypeName', LIdentity.EventTypeName);
    LJson.AddPair('handlerName', LIdentity.HandlerName);
    LJson.AddPair(
      'expiresAtUtc',
      DateToISO8601(AResult.Preview.ExpiresAtUtc, True)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

end.
