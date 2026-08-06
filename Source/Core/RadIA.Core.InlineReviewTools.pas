unit RadIA.Core.InlineReviewTools;

interface

uses
  RadIA.Core.InlineReviews,
  RadIA.Core.Tools;

procedure RegisterRadIAInlineReviewTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAInlineReviewService
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Patches;

type
  TRadIAInlineReviewToolKind = (
    irtkPublish,
    irtkList,
    irtkPrepareFix,
    irtkApplyFix,
    irtkReject,
    irtkRemove,
    irtkClear
  );

  TRadIAInlineReviewTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIAInlineReviewToolKind;
    FService: IRadIAInlineReviewService;
    function ExecuteIdAction(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteList: TRadIAToolResult;
    function ExecutePublish(
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
    function ParseSeverity(
      const AValue: string
    ): TRadIAInlineReviewSeverity;
    function PatchToToolResult(
      const AResult: TRadIAPatchResult
    ): TRadIAToolResult;
    function ReviewToJson(
      const AReview: TRadIAInlineReview
    ): TJSONObject;
  public
    constructor Create(
      const AKind: TRadIAInlineReviewToolKind;
      const AService: IRadIAInlineReviewService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInput =
    '{"type":"object","additionalProperties":false}';
  CIdInput =
    '{"type":"object","required":["reviewId"],"properties":{' +
    '"reviewId":{"type":"string"}},"additionalProperties":false}';
  CPublishInput =
    '{"type":"object","required":["fileName","baseRevision","startLine",' +
    '"endLine","severity","message"],"properties":{' +
    '"fileName":{"type":"string"},"baseRevision":{"type":"string"},' +
    '"startLine":{"type":"integer","minimum":1},' +
    '"endLine":{"type":"integer","minimum":1},' +
    '"severity":{"type":"string","enum":["info","warning","error"]},' +
    '"message":{"type":"string","minLength":1,"maxLength":2000},' +
    '"originalText":{"type":"string"},' +
    '"replacementText":{"type":"string"}},"additionalProperties":false}';
  CObjectOutput = '{"type":"object"}';

procedure RegisterRadIAInlineReviewTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAInlineReviewService
);
var
  LKind: TRadIAInlineReviewToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  for LKind := Low(TRadIAInlineReviewToolKind) to
    High(TRadIAInlineReviewToolKind) do
    ARegistry.RegisterTool(
      TRadIAInlineReviewTool.Create(LKind, AService)
    );
end;

constructor TRadIAInlineReviewTool.Create(
  const AKind: TRadIAInlineReviewToolKind;
  const AService: IRadIAInlineReviewService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIAInlineReviewTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    irtkPublish:
      Result := ExecutePublish(ARequest);
    irtkList:
      Result := ExecuteList;
    irtkPrepareFix,
    irtkApplyFix,
    irtkReject,
    irtkRemove:
      Result := ExecuteIdAction(ARequest);
    irtkClear:
      begin
        FService.Clear;
        Result := TRadIAToolResult.Succeeded('{"success":true}');
      end;
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Inline review tool kind is not supported.'
    );
  end;
end;

function TRadIAInlineReviewTool.ExecuteIdAction(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LId: string;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Inline review arguments must be a JSON object.'
    ));
  try
    LId := GetRequiredString(LJson, 'reviewId');
    if FKind = irtkPrepareFix then
      Result := PatchToToolResult(FService.PrepareFix(LId))
    else if FKind = irtkApplyFix then
      Result := PatchToToolResult(FService.ApplyFix(LId))
    else if (
      ((FKind = irtkReject) and FService.Reject(LId)) or
      ((FKind = irtkRemove) and FService.Remove(LId))
    ) then
      Result := TRadIAToolResult.Succeeded('{"success":true}')
    else
      Result := TRadIAToolResult.Failed(
        'review_not_found',
        'Inline review was not found.'
      );
  finally
    LJson.Free;
  end;
end;

function TRadIAInlineReviewTool.ExecuteList:
  TRadIAToolResult;
var
  LArray: TJSONArray;
  LJson: TJSONObject;
  LReview: TRadIAInlineReview;
  LReviews: TArray<TRadIAInlineReview>;
begin
  LReviews := FService.ListCurrent;
  LJson := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LJson.AddPair('reviews', LArray);
    for LReview in LReviews do
      LArray.AddElement(ReviewToJson(LReview));
    LJson.AddPair('count', TJSONNumber.Create(LArray.Count));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAInlineReviewTool.ExecutePublish(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LResult: TRadIAInlineReviewResult;
  LReview: TRadIAInlineReview;
  LReviewJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Inline review arguments must be a JSON object.'
    ));
  try
    LReview := TRadIAInlineReview.Create(
      '',
      GetRequiredString(LJson, 'fileName'),
      GetRequiredString(LJson, 'baseRevision'),
      GetRequiredInteger(LJson, 'startLine'),
      GetRequiredInteger(LJson, 'endLine'),
      ParseSeverity(GetRequiredString(LJson, 'severity'))
    );
    LReview.SetContent(
      GetRequiredString(LJson, 'message'),
      LJson.GetValue<string>('originalText', ''),
      LJson.GetValue<string>('replacementText', '')
    );
    LResult := FService.Publish(LReview);
    if not LResult.Success then
      Exit(TRadIAToolResult.Failed(
        LResult.ErrorCode,
        LResult.ErrorMessage
      ));
    LReviewJson := ReviewToJson(LResult.Review);
    try
      Result := TRadIAToolResult.Succeeded(LReviewJson.ToJSON);
    finally
      LReviewJson.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIAInlineReviewTool.GetDescriptor:
  TRadIAToolDescriptor;
var
  LDescription: string;
  LInput: string;
  LName: string;
  LRisk: TRadIAToolRisk;
begin
  LInput := CEmptyInput;
  LRisk := trStructuralWrite;
  case FKind of
    irtkPublish:
      begin
        LName := 'PublishInlineReview';
        LDescription := 'Publishes a revision-anchored review in the active editor.';
        LInput := CPublishInput;
      end;
    irtkList:
      begin
        LName := 'ListInlineReviews';
        LDescription := 'Lists reviews that match the active editor revision.';
        LRisk := trReadOnly;
      end;
    irtkPrepareFix:
      begin
        LName := 'PrepareInlineReviewFix';
        LDescription := 'Creates a reversible patch preview from a review suggestion.';
        LInput := CIdInput;
        LRisk := trReadOnly;
      end;
    irtkApplyFix:
      begin
        LName := 'ApplyInlineReviewFix';
        LDescription := 'Applies one revision-anchored inline review suggestion.';
        LInput := CIdInput;
      end;
    irtkReject:
      begin
        LName := 'RejectInlineReview';
        LDescription := 'Rejects one inline review without changing the buffer.';
        LInput := CIdInput;
      end;
    irtkRemove:
      begin
        LName := 'RemoveInlineReview';
        LDescription := 'Removes one inline review decoration.';
        LInput := CIdInput;
      end;
    irtkClear:
      begin
        LName := 'ClearInlineReviews';
        LDescription := 'Clears all RadIA inline review decorations.';
      end;
  else
    Exit(Default(TRadIAToolDescriptor));
  end;
  Result := TRadIAToolDescriptor.Create(
    LName,
    '1.0',
    LDescription,
    LInput,
    CObjectOutput,
    LRisk
  );
end;

function TRadIAInlineReviewTool.GetRequiredInteger(
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

function TRadIAInlineReviewTool.GetRequiredString(
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

function TRadIAInlineReviewTool.ParseSeverity(
  const AValue: string
): TRadIAInlineReviewSeverity;
begin
  if SameText(AValue, 'info') then
    Exit(irsInfo);
  if SameText(AValue, 'warning') then
    Exit(irsWarning);
  if SameText(AValue, 'error') then
    Exit(irsError);
  raise EArgumentException.Create(
    'severity must be info, warning or error.'
  );
end;

function TRadIAInlineReviewTool.PatchToToolResult(
  const AResult: TRadIAPatchResult
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
    LJson.AddPair('targetFile', AResult.Preview.Spec.TargetFile);
    LJson.AddPair('baseRevision', AResult.Preview.Spec.BaseRevision);
    LJson.AddPair(
      'proposedRevision',
      AResult.Preview.ProposedRevision
    );
    LJson.AddPair('originalContent', AResult.Preview.OriginalContent);
    LJson.AddPair('proposedContent', AResult.Preview.ProposedContent);
    LJson.AddPair(
      'expiresAtUtc',
      DateToISO8601(AResult.Preview.ExpiresAtUtc, True)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAInlineReviewTool.ReviewToJson(
  const AReview: TRadIAInlineReview
): TJSONObject;
const
  CSeverityNames: array[TRadIAInlineReviewSeverity] of string = (
    'info',
    'warning',
    'error'
  );
begin
  Result := TJSONObject.Create;
  Result.AddPair('reviewId', AReview.Id);
  Result.AddPair('fileName', AReview.FileName);
  Result.AddPair('baseRevision', AReview.BaseRevision);
  Result.AddPair('startLine', TJSONNumber.Create(AReview.StartLine));
  Result.AddPair('endLine', TJSONNumber.Create(AReview.EndLine));
  Result.AddPair('severity', CSeverityNames[AReview.Severity]);
  Result.AddPair('message', AReview.Message);
  Result.AddPair(
    'hasSuggestion',
    TJSONBool.Create(AReview.HasSuggestion)
  );
end;

end.
