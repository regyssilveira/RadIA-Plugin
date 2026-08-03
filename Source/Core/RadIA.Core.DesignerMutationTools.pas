unit RadIA.Core.DesignerMutationTools;

interface

uses
  RadIA.Core.DesignerMutations,
  RadIA.Core.Tools;

procedure RegisterRadIADesignerMutationTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAComponentLayoutService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Designer;

type
  TRadIADesignerMutationToolKind = (
    dmtkPrepare,
    dmtkApply,
    dmtkRevert
  );

  TRadIADesignerMutationTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIADesignerMutationToolKind;
    FService: IRadIAComponentLayoutService;
    function ExecutePrepare(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecutePreviewAction(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetRequiredInteger(
      const AJson: TJSONObject;
      const AName: string
    ): Integer;
    function GetRequiredString(
      const AJson: TJSONObject;
      const AName: string
    ): string;
    function ResultToToolResult(
      const AResult: TRadIAComponentLayoutResult
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIADesignerMutationToolKind;
      const AService: IRadIAComponentLayoutService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CLayoutOutputSchema =
    '{"type":"object","required":["previewId","formFileName","componentName"],' +
    '"properties":{"previewId":{"type":"string"},' +
    '"formFileName":{"type":"string"},"componentName":{"type":"string"},' +
    '"originalBounds":{"type":"object"},"proposedBounds":{"type":"object"}}}';
  CPrepareInputSchema =
    '{"type":"object","required":["componentName","left","top","width","height"],' +
    '"properties":{"componentName":{"type":"string"},' +
    '"left":{"type":"integer"},"top":{"type":"integer"},' +
    '"width":{"type":"integer","minimum":1},' +
    '"height":{"type":"integer","minimum":1}},' +
    '"additionalProperties":false}';
  CPreviewInputSchema =
    '{"type":"object","required":["previewId"],' +
    '"properties":{"previewId":{"type":"string"}},' +
    '"additionalProperties":false}';

procedure AddBounds(
  const AParent: TJSONObject;
  const AName: string;
  const ABounds: TRadIAComponentBounds
);
var
  LBounds: TJSONObject;
begin
  LBounds := TJSONObject.Create;
  LBounds.AddPair('left', TJSONNumber.Create(ABounds.Left));
  LBounds.AddPair('top', TJSONNumber.Create(ABounds.Top));
  LBounds.AddPair('width', TJSONNumber.Create(ABounds.Width));
  LBounds.AddPair('height', TJSONNumber.Create(ABounds.Height));
  AParent.AddPair(AName, LBounds);
end;

procedure RegisterRadIADesignerMutationTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAComponentLayoutService
);
var
  LKind: TRadIADesignerMutationToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');

  for LKind := Low(TRadIADesignerMutationToolKind) to
    High(TRadIADesignerMutationToolKind) do
    ARegistry.RegisterTool(
      TRadIADesignerMutationTool.Create(LKind, AService)
    );
end;

{ TRadIADesignerMutationTool }

constructor TRadIADesignerMutationTool.Create(
  const AKind: TRadIADesignerMutationToolKind;
  const AService: IRadIAComponentLayoutService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIADesignerMutationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    dmtkPrepare:
      Result := ExecutePrepare(ARequest);
    dmtkApply,
    dmtkRevert:
      Result := ExecutePreviewAction(ARequest);
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Designer mutation tool kind is not supported.'
    );
  end;
end;

function TRadIADesignerMutationTool.ExecutePrepare(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LBounds: TRadIAComponentBounds;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Component layout arguments must be a JSON object.'
    ));
  try
    LBounds := TRadIAComponentBounds.Create(
      GetRequiredInteger(LJson, 'left'),
      GetRequiredInteger(LJson, 'top'),
      GetRequiredInteger(LJson, 'width'),
      GetRequiredInteger(LJson, 'height')
    );
    Result := ResultToToolResult(
      FService.Prepare(
        GetRequiredString(LJson, 'componentName'),
        LBounds
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerMutationTool.ExecutePreviewAction(
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
      'Component layout arguments must be a JSON object.'
    ));
  try
    LPreviewId := GetRequiredString(LJson, 'previewId');
    if FKind = dmtkApply then
      Result := ResultToToolResult(FService.Apply(LPreviewId))
    else
      Result := ResultToToolResult(FService.Revert(LPreviewId));
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerMutationTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    dmtkPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareComponentLayout',
        '1.0',
        'Prepares an immutable preview for a component layout change.',
        CPrepareInputSchema,
        CLayoutOutputSchema,
        trReadOnly
      );
    dmtkApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyComponentLayout',
        '1.0',
        'Applies a reviewed layout change to the live Form Designer.',
        CPreviewInputSchema,
        CLayoutOutputSchema,
        trStructuralWrite
      );
    dmtkRevert:
      Result := TRadIAToolDescriptor.Create(
        'RevertComponentLayout',
        '1.0',
        'Reverts an applied layout change when preconditions still match.',
        CPreviewInputSchema,
        CLayoutOutputSchema,
        trStructuralWrite
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIADesignerMutationTool.GetRequiredInteger(
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

function TRadIADesignerMutationTool.GetRequiredString(
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

function TRadIADesignerMutationTool.ResultToToolResult(
  const AResult: TRadIAComponentLayoutResult
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
    AddBounds(
      LJson,
      'originalBounds',
      AResult.Preview.OriginalBounds
    );
    AddBounds(
      LJson,
      'proposedBounds',
      AResult.Preview.ProposedBounds
    );
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
