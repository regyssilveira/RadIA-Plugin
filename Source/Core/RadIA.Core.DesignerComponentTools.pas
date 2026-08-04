unit RadIA.Core.DesignerComponentTools;

interface

uses
  RadIA.Core.DesignerComponents,
  RadIA.Core.Tools;

procedure RegisterRadIADesignerComponentTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAComponentChangeService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Designer;

type
  TRadIADesignerComponentToolKind = (
    dctkPrepareAdd,
    dctkPrepareRemove,
    dctkApply,
    dctkRevert
  );

  TRadIADesignerComponentTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIADesignerComponentToolKind;
    FService: IRadIAComponentChangeService;
    function ExecutePrepareAdd(
      const AJson: TJSONObject
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetInteger(
      const AJson: TJSONObject;
      const AName: string
    ): Integer;
    function GetOptionalString(
      const AJson: TJSONObject;
      const AName: string
    ): string;
    function GetString(
      const AJson: TJSONObject;
      const AName: string
    ): string;
    function ToToolResult(
      const AResult: TRadIAComponentChangeResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIADesignerComponentToolKind;
      const AService: IRadIAComponentChangeService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CAddInput =
    '{"type":"object","required":["parentName","className","componentName",' +
    '"left","top","width","height"],"properties":{' +
    '"parentName":{"type":"string"},"className":{"type":"string"},' +
    '"componentName":{"type":"string"},"left":{"type":"integer"},' +
    '"top":{"type":"integer"},"width":{"type":"integer","minimum":1},' +
    '"height":{"type":"integer","minimum":1}},"additionalProperties":false}';
  CNameInput =
    '{"type":"object","required":["componentName"],"properties":{' +
    '"componentName":{"type":"string"}},"additionalProperties":false}';
  CPreviewInput =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string"}},"additionalProperties":false}';
  COutput =
    '{"type":"object","required":["previewId","action","formFileName",' +
    '"component"],"properties":{"previewId":{"type":"string"},' +
    '"action":{"type":"string"},"formFileName":{"type":"string"},' +
    '"component":{"type":"object"},"expiresAtUtc":{"type":"string"}}}';

procedure AddComponent(
  const AJson: TJSONObject;
  const ASnapshot: TRadIAFormComponentSnapshot
);
var
  LComponent: TJSONObject;
begin
  LComponent := TJSONObject.Create;
  LComponent.AddPair('name', ASnapshot.Name);
  LComponent.AddPair('className', ASnapshot.ClassName);
  LComponent.AddPair('parentName', ASnapshot.ParentName);
  LComponent.AddPair('left', TJSONNumber.Create(ASnapshot.Left));
  LComponent.AddPair('top', TJSONNumber.Create(ASnapshot.Top));
  LComponent.AddPair('width', TJSONNumber.Create(ASnapshot.Width));
  LComponent.AddPair('height', TJSONNumber.Create(ASnapshot.Height));
  AJson.AddPair('component', LComponent);
end;

procedure RegisterRadIADesignerComponentTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAComponentChangeService
);
var
  LKind: TRadIADesignerComponentToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  for LKind := Low(TRadIADesignerComponentToolKind) to
    High(TRadIADesignerComponentToolKind) do
    ARegistry.RegisterTool(
      TRadIADesignerComponentTool.Create(LKind, AService)
    );
end;

constructor TRadIADesignerComponentTool.Create(
  const AKind: TRadIADesignerComponentToolKind;
  const AService: IRadIAComponentChangeService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIADesignerComponentTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LValue: string;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Form Designer component arguments must be a JSON object.'
    ));
  try
    case FKind of
      dctkPrepareAdd:
        Result := ExecutePrepareAdd(LJson);
      dctkPrepareRemove:
        Result := ToToolResult(
          FService.PrepareRemove(GetString(LJson, 'componentName'))
        );
      dctkApply:
        begin
          LValue := GetString(LJson, 'previewId');
          Result := ToToolResult(FService.Apply(LValue));
        end;
      dctkRevert:
        begin
          LValue := GetString(LJson, 'previewId');
          Result := ToToolResult(FService.Revert(LValue));
        end;
    else
      Result := TRadIAToolResult.Failed(
        'unsupported_tool',
        'Form Designer component tool kind is not supported.'
      );
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerComponentTool.ExecutePrepareAdd(
  const AJson: TJSONObject
): TRadIAToolResult;
var
  LBounds: TRadIAComponentBounds;
begin
  LBounds := TRadIAComponentBounds.Create(
    GetInteger(AJson, 'left'),
    GetInteger(AJson, 'top'),
    GetInteger(AJson, 'width'),
    GetInteger(AJson, 'height')
  );
  Result := ToToolResult(
    FService.PrepareAdd(
      GetOptionalString(AJson, 'parentName'),
      GetString(AJson, 'className'),
      GetString(AJson, 'componentName'),
      LBounds
    )
  );
end;

function TRadIADesignerComponentTool.GetOptionalString(
  const AJson: TJSONObject;
  const AName: string
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
  Result := LValue.Value;
end;

function TRadIADesignerComponentTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    dctkPrepareAdd:
      Result := TRadIAToolDescriptor.Create(
        'PrepareAddFormComponent',
        '1.0',
        'Prepares a reviewed preview for adding an allowlisted VCL component.',
        CAddInput,
        COutput,
        trReadOnly
      );
    dctkPrepareRemove:
      Result := TRadIAToolDescriptor.Create(
        'PrepareRemoveFormComponent',
        '1.0',
        'Prepares a reviewed preview for removing an allowlisted VCL component.',
        CNameInput,
        COutput,
        trReadOnly
      );
    dctkApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyFormComponentChange',
        '1.0',
        'Applies a reviewed component creation or removal.',
        CPreviewInput,
        COutput,
        trStructuralWrite
      );
    dctkRevert:
      Result := TRadIAToolDescriptor.Create(
        'RevertFormComponentChange',
        '1.0',
        'Reverts an applied component creation or removal.',
        CPreviewInput,
        COutput,
        trStructuralWrite
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIADesignerComponentTool.GetInteger(
  const AJson: TJSONObject;
  const AName: string
): Integer;
var
  LValue: TJSONValue;
begin
  LValue := AJson.GetValue(AName);
  if not (LValue is TJSONNumber) then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must be an integer.',
      [AName]
    );
  Result := TJSONNumber(LValue).AsInt;
end;

function TRadIADesignerComponentTool.GetString(
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

function TRadIADesignerComponentTool.ToToolResult(
  const AResult: TRadIAComponentChangeResult
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
    if AResult.Preview.Kind = cckAdd then
      LJson.AddPair('action', 'add')
    else
      LJson.AddPair('action', 'remove');
    LJson.AddPair('formFileName', AResult.Preview.FormFileName);
    AddComponent(LJson, AResult.Preview.Snapshot);
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
