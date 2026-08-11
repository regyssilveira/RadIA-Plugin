unit RadIA.Core.BlockReviewTools;

interface

uses
  RadIA.Core.BlockReviewSessions,
  RadIA.Core.Tools;

procedure RegisterRadIABlockReviewTools(
  const ARegistry: IRadIAToolRegistry;
  const ASession: IRadIABlockReviewSession
);

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.BlockReviews;

type
  TRadIABlockReviewToolBase = class abstract(
    TInterfacedObject,
    IRadIATool
  )
  protected
    FSession: IRadIABlockReviewSession;
    function ResultToToolResult(
      const AResult: TRadIABlockReviewSessionResult
    ): TRadIAToolResult;
  public
    constructor Create(const ASession: IRadIABlockReviewSession);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; virtual; abstract;
    function GetDescriptor: TRadIAToolDescriptor; virtual; abstract;
  end;

  TRadIAListBlockReviewsTool = class(TRadIABlockReviewToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIADecideBlockReviewTool = class(TRadIABlockReviewToolBase)
  private
    function ParseDecision(
      const AValue: string;
      out ADecision: TRadIABlockReviewDecision
    ): Boolean;
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAApplyBlockReviewsTool = class(TRadIABlockReviewToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

  TRadIAClearBlockReviewsTool = class(TRadIABlockReviewToolBase)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult; override;
    function GetDescriptor: TRadIAToolDescriptor; override;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","properties":{},"additionalProperties":false}';
  CDecisionInputSchema =
    '{"type":"object","required":["blockId","decision"],' +
    '"properties":{"blockId":{"type":"string"},"decision":{' +
    '"type":"string","enum":["accept","reject","edit","request-changes"]},' +
    '"editedText":{"type":"string"},"comment":{"type":"string",' +
    '"maxLength":8192}},"additionalProperties":false}';
  CResultSchema =
    '{"type":"object","required":["success"],"properties":{' +
    '"success":{"type":"boolean"},"transactionId":{"type":"string"}}}';

function DecisionName(const ADecision: TRadIABlockReviewDecision): string;
begin
  case ADecision of
    brdAccepted: Result := 'accepted';
    brdRejected: Result := 'rejected';
    brdEdited: Result := 'edited';
    brdChangesRequested: Result := 'changes-requested';
  else
    Result := 'pending';
  end;
end;

{ TRadIABlockReviewToolBase }

constructor TRadIABlockReviewToolBase.Create(
  const ASession: IRadIABlockReviewSession
);
begin
  inherited Create;
  if not Assigned(ASession) then
    raise EArgumentNilException.Create('ASession');
  FSession := ASession;
end;

function TRadIABlockReviewToolBase.ResultToToolResult(
  const AResult: TRadIABlockReviewSessionResult
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
    LJson.AddPair('success', TJSONBool.Create(True));
    LJson.AddPair('transactionId', AResult.TransactionId);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

{ TRadIAListBlockReviewsTool }

function TRadIAListBlockReviewsTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LBlock: TRadIABlockReview;
  LItem: TJSONObject;
  LRoot: TJSONObject;
  LStatus: TRadIABlockReviewSessionStatus;
begin
  LRoot := TJSONObject.Create;
  try
    LStatus := FSession.GetStatus;
    LRoot.AddPair('fileCount', TJSONNumber.Create(LStatus.FileCount));
    LRoot.AddPair('blockCount', TJSONNumber.Create(LStatus.BlockCount));
    LRoot.AddPair('pendingCount', TJSONNumber.Create(LStatus.PendingCount));
    LArray := TJSONArray.Create;
    LRoot.AddPair('blocks', LArray);
    for LBlock in FSession.ListBlocks do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('id', LBlock.Id);
      LItem.AddPair('targetFile', LBlock.TargetFile);
      LItem.AddPair('baseRevision', LBlock.BaseRevision);
      LItem.AddPair(
        'startLine',
        TJSONNumber.Create(LBlock.OriginalStartLine)
      );
      LItem.AddPair(
        'originalLineCount',
        TJSONNumber.Create(LBlock.OriginalLineCount)
      );
      LItem.AddPair(
        'proposedLineCount',
        TJSONNumber.Create(LBlock.ProposedLineCount)
      );
      LItem.AddPair('decision', DecisionName(LBlock.Decision));
      LItem.AddPair('comment', LBlock.Comment);
      LItem.AddPair('originalText', LBlock.OriginalText);
      LItem.AddPair('proposedText', LBlock.ProposedText);
      LArray.AddElement(LItem);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAListBlockReviewsTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ListBlockReviews',
    '1.0.0',
    'Lists revision-bound patch blocks and their pending review decisions.',
    CEmptyInputSchema,
    '{"type":"object","required":["blocks","pendingCount"]}',
    trReadOnly
  );
end;

{ TRadIADecideBlockReviewTool }

function TRadIADecideBlockReviewTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LBlockId: string;
  LComment: string;
  LDecision: TRadIABlockReviewDecision;
  LDecisionText: string;
  LEditedText: string;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Block review arguments must be a valid JSON object.'
    ));
  try
    LBlockId := LJson.GetValue<string>('blockId', '');
    LDecisionText := LJson.GetValue<string>('decision', '');
    LEditedText := LJson.GetValue<string>('editedText', '');
    LComment := LJson.GetValue<string>('comment', '');
    if (LBlockId = '') or not ParseDecision(LDecisionText, LDecision) then
      Exit(TRadIAToolResult.Failed(
        'invalid_request',
        'Block id and a valid review decision are required.'
      ));
    Result := ResultToToolResult(
      FSession.Decide(LBlockId, LDecision, LEditedText, LComment)
    );
  finally
    LJson.Free;
  end;
end;

function TRadIADecideBlockReviewTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'DecideBlockReview',
    '1.0.0',
    'Records accept, reject, edit, or commented change requests without buffer mutation.',
    CDecisionInputSchema,
    CResultSchema,
    trReadOnly
  );
end;

function TRadIADecideBlockReviewTool.ParseDecision(
  const AValue: string;
  out ADecision: TRadIABlockReviewDecision
): Boolean;
begin
  Result := True;
  if SameText(AValue, 'accept') then
    ADecision := brdAccepted
  else if SameText(AValue, 'reject') then
    ADecision := brdRejected
  else if SameText(AValue, 'edit') then
    ADecision := brdEdited
  else if SameText(AValue, 'request-changes') then
    ADecision := brdChangesRequested
  else
    Result := False;
end;

{ TRadIAApplyBlockReviewsTool }

function TRadIAApplyBlockReviewsTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := ResultToToolResult(FSession.Apply);
end;

function TRadIAApplyBlockReviewsTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ApplyBlockReviews',
    '1.0.0',
    'Applies all resolved block decisions as one preconditioned multi-file transaction.',
    CEmptyInputSchema,
    CResultSchema,
    trReversibleWrite
  );
end;

{ TRadIAClearBlockReviewsTool }

function TRadIAClearBlockReviewsTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  FSession.Clear;
  Result := ResultToToolResult(
    TRadIABlockReviewSessionResult.Succeeded('')
  );
end;

function TRadIAClearBlockReviewsTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ClearBlockReviews',
    '1.0.0',
    'Discards the active review session without changing editor buffers.',
    CEmptyInputSchema,
    CResultSchema,
    trReadOnly
  );
end;

procedure RegisterRadIABlockReviewTools(
  const ARegistry: IRadIAToolRegistry;
  const ASession: IRadIABlockReviewSession
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ASession) then
    raise EArgumentNilException.Create('ASession');
  ARegistry.RegisterTool(TRadIAListBlockReviewsTool.Create(ASession));
  ARegistry.RegisterTool(TRadIADecideBlockReviewTool.Create(ASession));
  ARegistry.RegisterTool(TRadIAApplyBlockReviewsTool.Create(ASession));
  ARegistry.RegisterTool(TRadIAClearBlockReviewsTool.Create(ASession));
end;

end.
