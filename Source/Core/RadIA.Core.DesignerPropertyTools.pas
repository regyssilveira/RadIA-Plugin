unit RadIA.Core.DesignerPropertyTools;

interface

uses
  RadIA.Core.DesignerProperties,
  RadIA.Core.Tools;

procedure RegisterRadIADesignerPropertyTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAComponentPropertyService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Designer;

type
  TRadIADesignerPropertyToolKind = (
    dptkPrepare,
    dptkApply,
    dptkRevert
  );

  TRadIADesignerPropertyTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIADesignerPropertyToolKind;
    FService: IRadIAComponentPropertyService;
    function ExecutePrepare(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecutePreviewAction(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetRequiredString(
      const AJson: TJSONObject;
      const AName: string;
      const AAllowEmpty: Boolean = False
    ): string;
    function ResultToToolResult(
      const AResult: TRadIAComponentPropertyResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIADesignerPropertyToolKind;
      const AService: IRadIAComponentPropertyService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CPropertyOutputSchema =
    '{"type":"object","required":["previewId","formFileName","componentName"],' +
    '"properties":{"previewId":{"type":"string"},' +
    '"formFileName":{"type":"string"},"componentName":{"type":"string"},' +
    '"propertyName":{"type":"string"},"propertyType":{"type":"string"},' +
    '"originalValue":{"type":"string"},"proposedValue":{"type":"string"}}}';
  CPrepareInputSchema =
    '{"type":"object","required":["componentName","propertyName","value"],' +
    '"properties":{"componentName":{"type":"string"},' +
    '"propertyName":{"type":"string"},"value":{"type":"string","maxLength":4096}},' +
    '"additionalProperties":false}';
  CPreviewInputSchema =
    '{"type":"object","required":["previewId"],' +
    '"properties":{"previewId":{"type":"string"}},' +
    '"additionalProperties":false}';

procedure RegisterRadIADesignerPropertyTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAComponentPropertyService
);
var
  LKind: TRadIADesignerPropertyToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');

  for LKind := Low(TRadIADesignerPropertyToolKind) to
    High(TRadIADesignerPropertyToolKind) do
    ARegistry.RegisterTool(
      TRadIADesignerPropertyTool.Create(LKind, AService)
    );
end;

{ TRadIADesignerPropertyTool }

constructor TRadIADesignerPropertyTool.Create(
  const AKind: TRadIADesignerPropertyToolKind;
  const AService: IRadIAComponentPropertyService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIADesignerPropertyTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    dptkPrepare:
      Result := ExecutePrepare(ARequest);
    dptkApply,
    dptkRevert:
      Result := ExecutePreviewAction(ARequest);
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Designer property tool kind is not supported.'
    );
  end;
end;

function TRadIADesignerPropertyTool.ExecutePrepare(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Component property arguments must be a JSON object.'
    ));
  try
    Result := ResultToToolResult(
      FService.Prepare(
        GetRequiredString(LJson, 'componentName'),
        GetRequiredString(LJson, 'propertyName'),
        GetRequiredString(LJson, 'value', True)
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerPropertyTool.ExecutePreviewAction(
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
      'Component property arguments must be a JSON object.'
    ));
  try
    LPreviewId := GetRequiredString(LJson, 'previewId');
    if FKind = dptkApply then
      Result := ResultToToolResult(FService.Apply(LPreviewId))
    else
      Result := ResultToToolResult(FService.Revert(LPreviewId));
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerPropertyTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    dptkPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareComponentProperty',
        '1.0',
        'Prepares an immutable preview for a safe component property change.',
        CPrepareInputSchema,
        CPropertyOutputSchema,
        trReadOnly
      );
    dptkApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyComponentProperty',
        '1.0',
        'Applies a reviewed property change to the live Form Designer.',
        CPreviewInputSchema,
        CPropertyOutputSchema,
        trStructuralWrite
      );
    dptkRevert:
      Result := TRadIAToolDescriptor.Create(
        'RevertComponentProperty',
        '1.0',
        'Reverts an applied property change when preconditions still match.',
        CPreviewInputSchema,
        CPropertyOutputSchema,
        trStructuralWrite
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIADesignerPropertyTool.GetRequiredString(
  const AJson: TJSONObject;
  const AName: string;
  const AAllowEmpty: Boolean
): string;
var
  LValue: TJSONValue;
begin
  LValue := AJson.GetValue(AName);
  if not (LValue is TJSONString) then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must be a string.',
      [AName]
    );
  Result := TJSONString(LValue).Value;
  if (not AAllowEmpty) and (Trim(Result) = '') then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must not be empty.',
      [AName]
    );
end;

function TRadIADesignerPropertyTool.ResultToToolResult(
  const AResult: TRadIAComponentPropertyResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(
      AResult.ErrorCode,
      AResult.ErrorMessage
    ));

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', AResult.Preview.Id);
    LJson.AddPair('formFileName', AResult.Preview.FormFileName);
    LJson.AddPair('componentName', AResult.Preview.ComponentName);
    LJson.AddPair('propertyName', AResult.Preview.OriginalValue.Name);
    LJson.AddPair('propertyType', AResult.Preview.OriginalValue.TypeName);
    LJson.AddPair('originalValue', AResult.Preview.OriginalValue.Value);
    LJson.AddPair('proposedValue', AResult.Preview.ProposedValue.Value);
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
