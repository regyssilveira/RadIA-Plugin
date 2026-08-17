unit RadIA.Core.FireDAC.Fixes;

interface

uses
  RadIA.Core.Patches,
  RadIA.Core.Tools;

procedure RegisterRadIAFireDACFixTools(
  const ARegistry: IRadIAToolRegistry;
  const APatches: IRadIAPatchService
);

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.JSON,
  System.RegularExpressions,
  System.SysUtils;

type
  TRadIAFireDACFixState = (
    ffsPrepared,
    ffsApplying,
    ffsApplied,
    ffsReverting
  );

  IRadIAFireDACFixService = interface
    ['{17065C7F-59A6-48E5-99E5-DAB10BE35BC2}']
    function PrepareParameterFix(const AInput: TJSONObject): TRadIAPatchResult;
    function PrepareTransactionFix(const AInput: TJSONObject): TRadIAPatchResult;
    function Apply(const APreviewId: string): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
  end;

  TRadIAFireDACFixService = class(TInterfacedObject, IRadIAFireDACFixService)
  private
    FPatches: IRadIAPatchService;
    FStates: TDictionary<string, TRadIAFireDACFixState>;
    function PrepareSpec(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function ValidateCommon(
      const AInput: TJSONObject;
      const ARuleId: string;
      out ATargetFile: string;
      out ABaseRevision: string
    ): TRadIAPatchResult;
  public
    constructor Create(const APatches: IRadIAPatchService);
    destructor Destroy; override;
    function PrepareParameterFix(const AInput: TJSONObject): TRadIAPatchResult;
    function PrepareTransactionFix(const AInput: TJSONObject): TRadIAPatchResult;
    function Apply(const APreviewId: string): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
  end;

  TRadIAFireDACFixToolKind = (
    fftPrepareParameter,
    fftPrepareTransaction,
    fftPrepareGeneric,
    fftApply,
    fftRevert
  );

  TRadIAFireDACFixTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIAFireDACFixToolKind;
    FService: IRadIAFireDACFixService;
    function PatchResult(
      const AResult: TRadIAPatchResult;
      const AMutationApplied: Boolean
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIAFireDACFixToolKind;
      const AService: IRadIAFireDACFixService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CParameterRuleId = 'firedac.parameter.accessor-mismatch';
  CTransactionRuleId = 'firedac.transaction.rollback-missing';
  CParameterInputSchema =
    '{"type":"object","additionalProperties":false,' +
    '"required":["findingId","confidence","targetFile","baseRevision",' +
    '"queryVariable","parameterName","fromAccessor","toAccessor"],"properties":{' +
    '"findingId":{"type":"string","minLength":1,"maxLength":128},' +
    '"confidence":{"const":"proven"},"targetFile":{"type":"string","minLength":1},' +
    '"baseRevision":{"type":"string","minLength":1},' +
    '"queryVariable":{"type":"string","minLength":1,"maxLength":64},' +
    '"parameterName":{"type":"string","minLength":1,"maxLength":64},' +
    '"fromAccessor":{"type":"string"},"toAccessor":{"type":"string"}}}';
  CTransactionInputSchema =
    '{"type":"object","additionalProperties":false,' +
    '"required":["findingId","confidence","targetFile","baseRevision",' +
    '"transactionVariable"],"properties":{' +
    '"findingId":{"type":"string","minLength":1,"maxLength":128},' +
    '"confidence":{"const":"proven"},"targetFile":{"type":"string","minLength":1},' +
    '"baseRevision":{"type":"string","minLength":1},' +
    '"transactionVariable":{"type":"string","minLength":1,"maxLength":64},' +
    '"indentLevel":{"type":"integer","minimum":0,"maximum":20}}}';
  CGenericInputSchema =
    '{"type":"object","required":["ruleId"],"properties":{' +
    '"ruleId":{"type":"string","enum":["firedac.parameter.accessor-mismatch",' +
    '"firedac.transaction.rollback-missing"]}},"additionalProperties":true}';
  CPreviewInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string","minLength":1}},"additionalProperties":false}';
  CFixOutputSchema =
    '{"type":"object","required":["previewId","targetFile","baseRevision",' +
    '"proposedRevision","mutationApplied"]}';

function IsIdentifier(const AValue: string): Boolean;
begin
  Result := TRegEx.IsMatch(AValue, '^[A-Za-z_][A-Za-z0-9_]*$');
end;

function IsAccessor(const AValue: string): Boolean;
begin
  Result := SameText(AValue, 'Value') or
    SameText(AValue, 'AsString') or
    SameText(AValue, 'AsInteger') or
    SameText(AValue, 'AsLargeInt') or
    SameText(AValue, 'AsBoolean') or
    SameText(AValue, 'AsDateTime') or
    SameText(AValue, 'AsFloat') or
    SameText(AValue, 'AsCurrency');
end;

constructor TRadIAFireDACFixService.Create(
  const APatches: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FPatches := APatches;
  FStates := TDictionary<string, TRadIAFireDACFixState>.Create;
end;

destructor TRadIAFireDACFixService.Destroy;
begin
  FStates.Free;
  inherited;
end;

function TRadIAFireDACFixService.ValidateCommon(
  const AInput: TJSONObject;
  const ARuleId: string;
  out ATargetFile: string;
  out ABaseRevision: string
): TRadIAPatchResult;
var
  LFindingId: string;
begin
  ATargetFile := AInput.GetValue<string>('targetFile', '').Trim;
  ABaseRevision := AInput.GetValue<string>('baseRevision', '').Trim;
  LFindingId := AInput.GetValue<string>('findingId', '').Trim;
  if not SameText(AInput.GetValue<string>('confidence', ''), 'proven') then
    Exit(TRadIAPatchResult.Failed(
      'fix_not_proven',
      'Only proven FireDAC findings can prepare an automatic fix.'
    ));
  if LFindingId.IsEmpty or not LFindingId.StartsWith(ARuleId + ':', True) then
    Exit(TRadIAPatchResult.Failed(
      'finding_mismatch',
      'The finding identifier does not match the requested FireDAC rule.'
    ));
  if ATargetFile.IsEmpty or ABaseRevision.IsEmpty then
    Exit(TRadIAPatchResult.Failed(
      'snapshot_required',
      'A target file and base revision are required.'
    ));
  Result := TRadIAPatchResult.Succeeded(Default(TRadIAPatchPreview));
end;

function TRadIAFireDACFixService.PrepareSpec(
  const ASpec: TRadIAPatchSpec
): TRadIAPatchResult;
begin
  Result := FPatches.Prepare(ASpec);
  if Result.Success then
  begin
    TMonitor.Enter(FStates);
    try
      FStates.Add(Result.Preview.Id, ffsPrepared);
    finally
      TMonitor.Exit(FStates);
    end;
  end;
end;

function TRadIAFireDACFixService.PrepareParameterFix(
  const AInput: TJSONObject
): TRadIAPatchResult;
var
  LBaseRevision: string;
  LFromAccessor: string;
  LOriginalText: string;
  LParameterName: string;
  LQueryVariable: string;
  LReplacementText: string;
  LTargetFile: string;
  LToAccessor: string;
begin
  Result := ValidateCommon(
    AInput,
    CParameterRuleId,
    LTargetFile,
    LBaseRevision
  );
  if not Result.Success then
    Exit;
  LQueryVariable := AInput.GetValue<string>('queryVariable', '').Trim;
  LParameterName := AInput.GetValue<string>('parameterName', '').Trim;
  LFromAccessor := AInput.GetValue<string>('fromAccessor', '').Trim;
  LToAccessor := AInput.GetValue<string>('toAccessor', '').Trim;
  if not IsIdentifier(LQueryVariable) or not IsIdentifier(LParameterName) then
    Exit(TRadIAPatchResult.Failed(
      'invalid_identifier',
      'Query and parameter names must be simple Pascal identifiers.'
    ));
  if not IsAccessor(LFromAccessor) or not IsAccessor(LToAccessor) or
    SameText(LFromAccessor, LToAccessor) then
    Exit(TRadIAPatchResult.Failed(
      'invalid_accessor',
      'Distinct supported FireDAC parameter accessors are required.'
    ));
  LOriginalText := LQueryVariable + '.ParamByName(' +
    QuotedStr(LParameterName) + ').' + LFromAccessor;
  LReplacementText := LQueryVariable + '.ParamByName(' +
    QuotedStr(LParameterName) + ').' + LToAccessor;
  Result := PrepareSpec(TRadIAPatchSpec.Create(
    LTargetFile,
    LBaseRevision,
    LOriginalText,
    LReplacementText
  ));
end;

function TRadIAFireDACFixService.PrepareTransactionFix(
  const AInput: TJSONObject
): TRadIAPatchResult;
var
  LBaseRevision: string;
  LIndent: string;
  LIndentLevel: Integer;
  LOriginalText: string;
  LReplacementText: string;
  LTargetFile: string;
  LTransactionVariable: string;
begin
  Result := ValidateCommon(
    AInput,
    CTransactionRuleId,
    LTargetFile,
    LBaseRevision
  );
  if not Result.Success then
    Exit;
  LTransactionVariable := AInput.GetValue<string>('transactionVariable', '').Trim;
  LIndentLevel := AInput.GetValue<Integer>('indentLevel', 0);
  if not IsIdentifier(LTransactionVariable) then
    Exit(TRadIAPatchResult.Failed(
      'invalid_identifier',
      'Transaction name must be a simple Pascal identifier.'
    ));
  if (LIndentLevel < 0) or (LIndentLevel > 20) then
    Exit(TRadIAPatchResult.Failed('invalid_indent', 'Indent level must be between 0 and 20.'));
  LIndent := StringOfChar(' ', LIndentLevel * 2);
  LOriginalText := LIndent + 'except';
  LReplacementText := LOriginalText + sLineBreak + LIndent + '  ' +
    LTransactionVariable + '.Rollback;';
  Result := PrepareSpec(TRadIAPatchSpec.Create(
    LTargetFile,
    LBaseRevision,
    LOriginalText,
    LReplacementText
  ));
end;

function TRadIAFireDACFixService.Apply(
  const APreviewId: string
): TRadIAPatchResult;
var
  LState: TRadIAFireDACFixState;
begin
  TMonitor.Enter(FStates);
  try
    if not FStates.TryGetValue(APreviewId, LState) then
      Exit(TRadIAPatchResult.Failed(
        'foreign_preview',
        'The preview was not prepared by the FireDAC Advisor.'
      ));
    if LState <> ffsPrepared then
      Exit(TRadIAPatchResult.Failed('invalid_state', 'The FireDAC fix is not awaiting application.'));
    FStates[APreviewId] := ffsApplying;
  finally
    TMonitor.Exit(FStates);
  end;
  Result := FPatches.Apply(APreviewId);
  TMonitor.Enter(FStates);
  try
    if Result.Success then
      FStates[APreviewId] := ffsApplied
    else
      FStates[APreviewId] := ffsPrepared;
  finally
    TMonitor.Exit(FStates);
  end;
end;

function TRadIAFireDACFixService.Revert(
  const APreviewId: string
): TRadIAPatchResult;
var
  LState: TRadIAFireDACFixState;
begin
  TMonitor.Enter(FStates);
  try
    if not FStates.TryGetValue(APreviewId, LState) then
      Exit(TRadIAPatchResult.Failed(
        'foreign_preview',
        'The preview was not prepared by the FireDAC Advisor.'
      ));
    if LState <> ffsApplied then
      Exit(TRadIAPatchResult.Failed('invalid_state', 'Only an applied FireDAC fix can be reverted.'));
    FStates[APreviewId] := ffsReverting;
  finally
    TMonitor.Exit(FStates);
  end;
  Result := FPatches.Revert(APreviewId);
  TMonitor.Enter(FStates);
  try
    if Result.Success then
      FStates.Remove(APreviewId)
    else
      FStates[APreviewId] := ffsApplied;
  finally
    TMonitor.Exit(FStates);
  end;
end;

constructor TRadIAFireDACFixTool.Create(
  const AKind: TRadIAFireDACFixToolKind;
  const AService: IRadIAFireDACFixService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIAFireDACFixTool.PatchResult(
  const AResult: TRadIAPatchResult;
  const AMutationApplied: Boolean
): TRadIAToolResult;
var
  LRoot: TJSONObject;
begin
  if not AResult.Success then
    Exit(TRadIAToolResult.Failed(AResult.ErrorCode, AResult.ErrorMessage));
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('previewId', AResult.Preview.Id);
    LRoot.AddPair('targetFile', AResult.Preview.Spec.TargetFile);
    LRoot.AddPair('baseRevision', AResult.Preview.Spec.BaseRevision);
    LRoot.AddPair('proposedRevision', AResult.Preview.ProposedRevision);
    LRoot.AddPair('originalText', AResult.Preview.Spec.OriginalText);
    LRoot.AddPair('replacementText', AResult.Preview.Spec.ReplacementText);
    LRoot.AddPair('mutationApplied', TJSONBool.Create(AMutationApplied));
    LRoot.AddPair('expiresAtUtc', DateToISO8601(AResult.Preview.ExpiresAtUtc, True));
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACFixTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LInput: TJSONObject;
  LPreviewId: string;
  LRuleId: string;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LInput) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
  try
    case FKind of
      fftPrepareParameter:
        Result := PatchResult(FService.PrepareParameterFix(LInput), False);
      fftPrepareTransaction:
        Result := PatchResult(FService.PrepareTransactionFix(LInput), False);
      fftPrepareGeneric:
        begin
          LRuleId := LInput.GetValue<string>('ruleId', '');
          if SameText(LRuleId, CParameterRuleId) then
            Result := PatchResult(FService.PrepareParameterFix(LInput), False)
          else if SameText(LRuleId, CTransactionRuleId) then
            Result := PatchResult(FService.PrepareTransactionFix(LInput), False)
          else
            Result := TRadIAToolResult.Failed('unsupported_rule', 'The FireDAC rule has no safe fix.');
        end;
      fftApply, fftRevert:
        begin
          LPreviewId := LInput.GetValue<string>('previewId', '').Trim;
          if LPreviewId.IsEmpty then
            Exit(TRadIAToolResult.Failed('preview_required', 'A preview identifier is required.'));
          if FKind = fftApply then
            Result := PatchResult(FService.Apply(LPreviewId), True)
          else
            Result := PatchResult(FService.Revert(LPreviewId), False);
        end;
    end;
  finally
    LInput.Free;
  end;
end;

function TRadIAFireDACFixTool.GetDescriptor: TRadIAToolDescriptor;
begin
  case FKind of
    fftPrepareParameter:
      Result := TRadIAToolDescriptor.Create(
        'PrepareFireDACParameterFix',
        '1.0.0',
        'Prepares a proven FireDAC parameter accessor fix without changing the editor.',
        CParameterInputSchema,
        CFixOutputSchema,
        trReadOnly
      );
    fftPrepareTransaction:
      Result := TRadIAToolDescriptor.Create(
        'PrepareFireDACTransactionFix',
        '1.0.0',
        'Prepares a proven missing FireDAC rollback fix without changing the editor.',
        CTransactionInputSchema,
        CFixOutputSchema,
        trReadOnly
      );
    fftPrepareGeneric:
      Result := TRadIAToolDescriptor.Create(
        'PrepareFireDACFix',
        '1.0.0',
        'Routes a proven supported FireDAC finding to a deterministic patch preview.',
        CGenericInputSchema,
        CFixOutputSchema,
        trReadOnly
      );
    fftApply:
      Result := TRadIAToolDescriptor.Create(
        'ApplyFireDACFix',
        '1.0.0',
        'Applies a reviewed FireDAC-owned fix when its editor fingerprint still matches.',
        CPreviewInputSchema,
        CFixOutputSchema,
        trReversibleWrite
      );
    fftRevert:
      Result := TRadIAToolDescriptor.Create(
        'RevertFireDACFix',
        '1.0.0',
        'Reverts an applied FireDAC-owned fix when its proposed fingerprint still matches.',
        CPreviewInputSchema,
        CFixOutputSchema,
        trReversibleWrite
      );
  end;
end;

procedure RegisterRadIAFireDACFixTools(
  const ARegistry: IRadIAToolRegistry;
  const APatches: IRadIAPatchService
);
var
  LKind: TRadIAFireDACFixToolKind;
  LService: IRadIAFireDACFixService;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  LService := TRadIAFireDACFixService.Create(APatches);
  for LKind := Low(TRadIAFireDACFixToolKind) to High(TRadIAFireDACFixToolKind) do
    ARegistry.RegisterTool(TRadIAFireDACFixTool.Create(LKind, LService));
end;

end.
