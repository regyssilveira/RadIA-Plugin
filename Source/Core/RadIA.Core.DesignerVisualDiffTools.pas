unit RadIA.Core.DesignerVisualDiffTools;

interface

uses
  RadIA.Core.DesignerVisualDiff,
  RadIA.Core.Tools;

procedure RegisterRadIADesignerVisualDiffTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADesignerVisualDiffService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Designer;

type
  TRadIADesignerVisualDiffToolKind = (
    dvtCapture,
    dvtCompare,
    dvtDecide,
    dvtClear
  );

  TRadIADesignerVisualDiffTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIADesignerVisualDiffToolKind;
    FService: IRadIADesignerVisualDiffService;
    function ExecuteCapture: TRadIAToolResult;
    function ExecuteClear: TRadIAToolResult;
    function ExecuteCompare(
      const AArgumentsJson: string
    ): TRadIAToolResult;
    function ExecuteDecide(
      const AArgumentsJson: string
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  public
    constructor Create(
      const AKind: TRadIADesignerVisualDiffToolKind;
      const AService: IRadIADesignerVisualDiffService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CCompareInputSchema =
    '{"type":"object","required":["beforeId","afterId"],' +
    '"properties":{"beforeId":{"type":"string"},' +
    '"afterId":{"type":"string"}},"additionalProperties":false}';
  CDecideInputSchema =
    '{"type":"object","required":["comparisonId","decision"],' +
    '"properties":{"comparisonId":{"type":"string"},' +
    '"decision":{"type":"string","enum":["accept","reject"]}},' +
    '"additionalProperties":false}';
  COutputSchema = '{"type":"object"}';

procedure RegisterRadIADesignerVisualDiffTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADesignerVisualDiffService
);
var
  LKind: TRadIADesignerVisualDiffToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  for LKind := Low(TRadIADesignerVisualDiffToolKind) to
    High(TRadIADesignerVisualDiffToolKind) do
    ARegistry.RegisterTool(
      TRadIADesignerVisualDiffTool.Create(LKind, AService)
    );
end;

function GetRequiredString(
  const AJson: TJSONObject;
  const AName: string
): string;
begin
  Result := Trim(AJson.GetValue<string>(AName, ''));
  if Result = '' then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must not be empty.',
      [AName]
    );
end;

procedure AddProperties(
  const AJson: TJSONObject;
  const AProperties: TArray<TRadIAComponentPropertyValue>
);
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LProperty: TRadIAComponentPropertyValue;
begin
  LArray := TJSONArray.Create;
  AJson.AddPair('properties', LArray);
  for LProperty in AProperties do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('name', LProperty.Name);
    LItem.AddPair('typeName', LProperty.TypeName);
    LItem.AddPair('value', LProperty.Value);
    LArray.AddElement(LItem);
  end;
end;

function ComponentToJson(
  const AComponent: TRadIAFormComponentSnapshot
): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AComponent.Name);
  Result.AddPair('className', AComponent.ClassName);
  Result.AddPair('parentName', AComponent.ParentName);
  Result.AddPair('selected', TJSONBool.Create(AComponent.Selected));
  Result.AddPair('left', TJSONNumber.Create(AComponent.Left));
  Result.AddPair('top', TJSONNumber.Create(AComponent.Top));
  Result.AddPair('width', TJSONNumber.Create(AComponent.Width));
  Result.AddPair('height', TJSONNumber.Create(AComponent.Height));
  AddProperties(Result, AComponent.Properties);
end;

procedure AddComparison(
  const AJson: TJSONObject;
  const AComparison: TRadIADesignerVisualComparison
);
var
  LArray: TJSONArray;
  LChange: TRadIADesignerVisualChange;
  LItem: TJSONObject;
begin
  AJson.AddPair('comparisonId', AComparison.Id);
  AJson.AddPair('beforeId', AComparison.BeforeId);
  AJson.AddPair('afterId', AComparison.AfterId);
  AJson.AddPair(
    'state',
    RadIADesignerVisualDiffStateName(AComparison.State)
  );
  LArray := TJSONArray.Create;
  AJson.AddPair('changes', LArray);
  for LChange in AComparison.Changes do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair(
      'kind',
      RadIADesignerVisualChangeKindName(LChange.Kind)
    );
    LItem.AddPair('componentName', LChange.ComponentName);
    LItem.AddPair('before', ComponentToJson(LChange.Before));
    LItem.AddPair('after', ComponentToJson(LChange.After));
    LArray.AddElement(LItem);
  end;
  AJson.AddPair(
    'changeCount',
    TJSONNumber.Create(Length(AComparison.Changes))
  );
end;

{ TRadIADesignerVisualDiffTool }

constructor TRadIADesignerVisualDiffTool.Create(
  const AKind: TRadIADesignerVisualDiffToolKind;
  const AService: IRadIADesignerVisualDiffService
);
begin
  inherited Create;
  FKind := AKind;
  FService := AService;
end;

function TRadIADesignerVisualDiffTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    dvtCapture: Result := ExecuteCapture;
    dvtCompare: Result := ExecuteCompare(ARequest.ArgumentsJson);
    dvtDecide: Result := ExecuteDecide(ARequest.ArgumentsJson);
    dvtClear: Result := ExecuteClear;
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Designer visual diff tool kind is unsupported.'
    );
  end;
end;

function TRadIADesignerVisualDiffTool.ExecuteCapture: TRadIAToolResult;
var
  LJson: TJSONObject;
  LSnapshot: TRadIADesignerVisualSnapshot;
begin
  LSnapshot := FService.Capture;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('snapshotId', LSnapshot.Id);
    LJson.AddPair('formName', LSnapshot.FormName);
    LJson.AddPair('formClassName', LSnapshot.FormClassName);
    LJson.AddPair(
      'createdAtUtc',
      DateToISO8601(LSnapshot.CreatedAtUtc, True)
    );
    LJson.AddPair(
      'componentCount',
      TJSONNumber.Create(Length(LSnapshot.Components))
    );
    LJson.AddPair('storage', 'memory');
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerVisualDiffTool.ExecuteClear: TRadIAToolResult;
begin
  FService.Clear;
  Result := TRadIAToolResult.Succeeded(
    '{"cleared":true,"storage":"memory"}'
  );
end;

function TRadIADesignerVisualDiffTool.ExecuteCompare(
  const AArgumentsJson: string
): TRadIAToolResult;
var
  LComparison: TRadIADesignerVisualComparison;
  LJson: TJSONObject;
  LRoot: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Designer visual comparison arguments must be a JSON object.'
    ));
  try
    LComparison := FService.PrepareComparison(
      GetRequiredString(LJson, 'beforeId'),
      GetRequiredString(LJson, 'afterId')
    );
    LRoot := TJSONObject.Create;
    try
      AddComparison(LRoot, LComparison);
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerVisualDiffTool.ExecuteDecide(
  const AArgumentsJson: string
): TRadIAToolResult;
var
  LComparison: TRadIADesignerVisualComparison;
  LDecision: string;
  LJson: TJSONObject;
  LRoot: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Designer visual decision arguments must be a JSON object.'
    ));
  try
    LDecision := GetRequiredString(LJson, 'decision');
    if not SameText(LDecision, 'accept') and
      not SameText(LDecision, 'reject') then
      Exit(TRadIAToolResult.Failed(
        'invalid_decision',
        'Designer visual decision must be accept or reject.'
      ));
    LComparison := FService.Decide(
      GetRequiredString(LJson, 'comparisonId'),
      SameText(LDecision, 'accept')
    );
    LRoot := TJSONObject.Create;
    try
      AddComparison(LRoot, LComparison);
      LRoot.AddPair('designerMutated', TJSONBool.Create(False));
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIADesignerVisualDiffTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    dvtCapture:
      Result := TRadIAToolDescriptor.Create(
        'CaptureDesignerVisualSnapshot',
        '1.0.0',
        'Captures a bounded in-memory snapshot of the active Form Designer.',
        CEmptyInputSchema,
        COutputSchema,
        trReadOnly
      );
    dvtCompare:
      Result := TRadIAToolDescriptor.Create(
        'CompareDesignerVisualSnapshots',
        '1.0.0',
        'Returns a timeline-ready before and after Designer comparison.',
        CCompareInputSchema,
        COutputSchema,
        trReadOnly
      );
    dvtDecide:
      Result := TRadIAToolDescriptor.Create(
        'DecideDesignerVisualDiff',
        '1.0.0',
        'Accepts or rejects a visual comparison without mutating the Designer.',
        CDecideInputSchema,
        COutputSchema,
        trReversibleWrite
      );
  else
    Result := TRadIAToolDescriptor.Create(
      'ClearDesignerVisualDiffArtifacts',
      '1.0.0',
      'Clears bounded in-memory Designer snapshots and comparisons.',
      CEmptyInputSchema,
      COutputSchema,
      trReversibleWrite
    );
  end;
end;

end.
