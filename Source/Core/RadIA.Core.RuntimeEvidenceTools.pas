unit RadIA.Core.RuntimeEvidenceTools;

interface

uses
  RadIA.Core.RuntimeEvidence,
  RadIA.Core.Tools;

procedure RegisterRadIARuntimeEvidenceTools(
  const ARegistry: IRadIAToolRegistry;
  const AEvidence: IRadIARuntimeEvidenceCoordinator
);

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils;

type
  TRadIARuntimeEvidenceToolKind = (
    retkCapture,
    retkCompare
  );

  TRadIARuntimeEvidenceTool = class(TInterfacedObject, IRadIATool)
  private
    FEvidence: IRadIARuntimeEvidenceCoordinator;
    FKind: TRadIARuntimeEvidenceToolKind;
    function ExecuteCapture(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteCompare(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIARuntimeEvidenceToolKind;
      const AEvidence: IRadIARuntimeEvidenceCoordinator
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CCaptureInputSchema =
    '{"type":"object","required":["phase"],"properties":{' +
    '"phase":{"enum":["failure","verification"]},' +
    '"expressions":{"type":"array","maxItems":10,' +
    '"items":{"type":"string","minLength":1,"maxLength":256}}},' +
    '"additionalProperties":false}';
  CCompareInputSchema =
    '{"type":"object","required":["failureEvidenceId",' +
    '"verificationEvidenceId"],"properties":{' +
    '"failureEvidenceId":{"type":"string","minLength":32},' +
    '"verificationEvidenceId":{"type":"string","minLength":32}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

function ParseExpressions(
  const AJson: TJSONObject;
  out AExpressions: TArray<string>
): Boolean;
var
  LArray: TJSONArray;
  LExpression: string;
  LItem: TJSONValue;
  LItems: TList<string>;
begin
  Result := False;
  LArray := AJson.GetValue<TJSONArray>('expressions');
  if not Assigned(LArray) then
  begin
    AExpressions := [];
    Exit(True);
  end;
  if LArray.Count > 10 then
    Exit;
  LItems := TList<string>.Create;
  try
    for LItem in LArray do
    begin
      LExpression := Trim(LItem.Value);
      if (LExpression = '') or (Length(LExpression) > 256) then
        Exit;
      LItems.Add(LExpression);
    end;
    AExpressions := LItems.ToArray;
    Result := True;
  finally
    LItems.Free;
  end;
end;

{ TRadIARuntimeEvidenceTool }

constructor TRadIARuntimeEvidenceTool.Create(
  const AKind: TRadIARuntimeEvidenceToolKind;
  const AEvidence: IRadIARuntimeEvidenceCoordinator
);
begin
  inherited Create;
  if not Assigned(AEvidence) then
    raise EArgumentNilException.Create('AEvidence');
  FKind := AKind;
  FEvidence := AEvidence;
end;

function TRadIARuntimeEvidenceTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  try
    case FKind of
      retkCapture:
        Result := ExecuteCapture(ARequest);
      retkCompare:
        Result := ExecuteCompare(ARequest);
    else
      Result := TRadIAToolResult.Failed(
        'unsupported_tool',
        'Runtime evidence tool kind is unsupported.'
      );
    end;
  except
    on E: EArgumentException do
      Result := TRadIAToolResult.Failed(
        'invalid_runtime_evidence',
        E.Message
      );
    on E: EInvalidOp do
      Result := TRadIAToolResult.Failed(
        'runtime_evidence_unavailable',
        E.Message
      );
  end;
end;

function TRadIARuntimeEvidenceTool.ExecuteCapture(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LExpressions: TArray<string>;
  LJson: TJSONObject;
  LPhase: string;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime evidence arguments must be a JSON object.'
    ));
  try
    LPhase := LJson.GetValue<string>('phase', '');
    if not ParseExpressions(LJson, LExpressions) then
      Exit(TRadIAToolResult.Failed(
        'invalid_expressions',
        'Runtime evidence expressions are invalid.'
      ));
    Result := TRadIAToolResult.Succeeded(
      FEvidence.Capture(LPhase, LExpressions)
    );
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeEvidenceTool.ExecuteCompare(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LFailureEvidenceId: string;
  LJson: TJSONObject;
  LVerificationEvidenceId: string;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime evidence comparison arguments must be a JSON object.'
    ));
  try
    LFailureEvidenceId := LJson.GetValue<string>(
      'failureEvidenceId',
      ''
    );
    LVerificationEvidenceId := LJson.GetValue<string>(
      'verificationEvidenceId',
      ''
    );
    if (LFailureEvidenceId = '') or
      (LVerificationEvidenceId = '') then
      Exit(TRadIAToolResult.Failed(
        'invalid_evidence_ids',
        'Both runtime evidence ids are required.'
      ));
    Result := TRadIAToolResult.Succeeded(
      FEvidence.Compare(
        LFailureEvidenceId,
        LVerificationEvidenceId
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeEvidenceTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    retkCapture:
      Result := TRadIAToolDescriptor.Create(
        'CaptureRuntimeEvidence',
        '1.0.0',
        'Capture sanitized session, scenario, exception, stack, and values.',
        CCaptureInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    retkCompare:
      Result := TRadIAToolDescriptor.Create(
        'CompareRuntimeEvidence',
        '1.0.0',
        'Compare failure and verification evidence across rebuilt sessions.',
        CCompareInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  end;
end;

procedure RegisterRadIARuntimeEvidenceTools(
  const ARegistry: IRadIAToolRegistry;
  const AEvidence: IRadIARuntimeEvidenceCoordinator
);
var
  LKind: TRadIARuntimeEvidenceToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  for LKind := Low(TRadIARuntimeEvidenceToolKind) to
    High(TRadIARuntimeEvidenceToolKind) do
    ARegistry.RegisterTool(
      TRadIARuntimeEvidenceTool.Create(LKind, AEvidence)
    );
end;

end.
