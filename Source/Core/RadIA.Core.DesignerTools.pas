unit RadIA.Core.DesignerTools;

interface

uses
  RadIA.Core.Designer,
  RadIA.Core.Tools;

procedure RegisterRadIADesignerTools(
  const ARegistry: IRadIAToolRegistry;
  const ADesigner: IRadIAFormDesignerFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIADesignerToolKind = (
    dtkGetActiveForm,
    dtkListFormComponents
  );

  TRadIADesignerTool = class(TInterfacedObject, IRadIATool)
  private
    FDesigner: IRadIAFormDesignerFacade;
    FKind: TRadIADesignerToolKind;
    function ExecuteGetActiveForm: TRadIAToolResult;
    function ExecuteListComponents(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetMaxCount(const AArgumentsJson: string): Integer;
  public
    constructor Create(
      const AKind: TRadIADesignerToolKind;
      const ADesigner: IRadIAFormDesignerFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CListInputSchema =
    '{"type":"object","properties":{"maxCount":{"type":"integer","minimum":1,' +
    '"maximum":1000}},"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

procedure RegisterRadIADesignerTools(
  const ARegistry: IRadIAToolRegistry;
  const ADesigner: IRadIAFormDesignerFacade
);
var
  LKind: TRadIADesignerToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ADesigner) then
    raise EArgumentNilException.Create('ADesigner');

  for LKind := Low(TRadIADesignerToolKind) to
    High(TRadIADesignerToolKind) do
    ARegistry.RegisterTool(
      TRadIADesignerTool.Create(LKind, ADesigner)
    );
end;

{ TRadIADesignerTool }

constructor TRadIADesignerTool.Create(
  const AKind: TRadIADesignerToolKind;
  const ADesigner: IRadIAFormDesignerFacade
);
begin
  inherited Create;
  if not Assigned(ADesigner) then
    raise EArgumentNilException.Create('ADesigner');
  FKind := AKind;
  FDesigner := ADesigner;
end;

function TRadIADesignerTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    dtkGetActiveForm:
      Result := ExecuteGetActiveForm;
    dtkListFormComponents:
      Result := ExecuteListComponents(ARequest);
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Designer tool kind is not supported.'
    );
  end;
end;

function TRadIADesignerTool.ExecuteGetActiveForm:
  TRadIAToolResult;
var
  LForm: TRadIAFormSnapshot;
  LJson: TJSONObject;
begin
  LForm := FDesigner.GetActiveForm;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('available', TJSONBool.Create(LForm.Available));
    LJson.AddPair('name', LForm.Name);
    LJson.AddPair('className', LForm.ClassName);
    LJson.AddPair('unitFileName', LForm.UnitFileName);
    LJson.AddPair('formFileName', LForm.FormFileName);
    LJson.AddPair(
      'componentCount',
      TJSONNumber.Create(LForm.ComponentCount)
    );
    LJson.AddPair(
      'selectionCount',
      TJSONNumber.Create(LForm.SelectionCount)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerTool.ExecuteListComponents(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LComponent: TRadIAFormComponentSnapshot;
  LComponents: TArray<TRadIAFormComponentSnapshot>;
  LItem: TJSONObject;
  LRoot: TJSONObject;
begin
  LComponents := FDesigner.ListFormComponents(
    GetMaxCount(ARequest.ArgumentsJson)
  );
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('components', LArray);
    for LComponent in LComponents do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('name', LComponent.Name);
      LItem.AddPair('className', LComponent.ClassName);
      LItem.AddPair('parentName', LComponent.ParentName);
      LItem.AddPair(
        'isControl',
        TJSONBool.Create(LComponent.IsControl)
      );
      LItem.AddPair(
        'selected',
        TJSONBool.Create(LComponent.Selected)
      );
      LItem.AddPair('left', TJSONNumber.Create(LComponent.Left));
      LItem.AddPair('top', TJSONNumber.Create(LComponent.Top));
      LItem.AddPair('width', TJSONNumber.Create(LComponent.Width));
      LItem.AddPair('height', TJSONNumber.Create(LComponent.Height));
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair(
      'count',
      TJSONNumber.Create(Length(LComponents))
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIADesignerTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    dtkGetActiveForm:
      Result := TRadIAToolDescriptor.Create(
        'GetActiveForm',
        '1.0',
        'Returns a snapshot of the active live Form Designer.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    dtkListFormComponents:
      Result := TRadIAToolDescriptor.Create(
        'ListFormComponents',
        '1.0',
        'Lists components from the active live Form Designer.',
        CListInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIADesignerTool.GetMaxCount(
  const AArgumentsJson: string
): Integer;
var
  LJson: TJSONObject;
  LValue: TJSONValue;
begin
  Result := 200;
  if Trim(AArgumentsJson) = '' then
    Exit;

  LJson := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create('Arguments must be a JSON object.');
  try
    LValue := LJson.GetValue('maxCount');
    if Assigned(LValue) then
    begin
      if not (LValue is TJSONNumber) then
        raise EArgumentException.Create('maxCount must be an integer.');
      Result := TJSONNumber(LValue).AsInt;
    end;
    if (Result < 1) or (Result > 1000) then
      raise EArgumentOutOfRangeException.Create(
        'maxCount must be between 1 and 1000.'
      );
  finally
    LJson.Free;
  end;
end;

end.
