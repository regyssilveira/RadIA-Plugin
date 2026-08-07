unit RadIA.Core.MemoryEvidence;

interface

uses
  RadIA.Core.Tools;

type
  IRadIAMemoryEvidenceService = interface
    ['{2B977E5B-324C-42F5-AD52-E26A160985B1}']
    function Compare(
      const ABaselineEvidence: string;
      const AVerificationEvidence: string
    ): TRadIAToolResult;
    function PrepareFix(
      const AEvidence: string;
      const AGroupFingerprint: string
    ): TRadIAToolResult;
  end;

  TRadIAMemoryEvidenceService = class(
    TInterfacedObject,
    IRadIAMemoryEvidenceService
  )
  public
    function Compare(
      const ABaselineEvidence: string;
      const AVerificationEvidence: string
    ): TRadIAToolResult;
    function PrepareFix(
      const AEvidence: string;
      const AGroupFingerprint: string
    ): TRadIAToolResult;
  end;

procedure RegisterRadIAMemoryEvidenceTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAMemoryEvidenceService
);

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.MemoryDiagnostics;

type
  TRadIAMemoryEvidenceSummary = record
  private
    FBuildId: string;
    FEvidenceId: string;
    FGroupBytes: TDictionary<string, Int64>;
    FScenarioFingerprint: string;
    FTotalBytes: Int64;
  public
    procedure Clear;
    function GroupCount: Integer;
    function HasNewGroupComparedWith(
      const AOther: TRadIAMemoryEvidenceSummary
    ): Boolean;
    function IsComparableWith(
      const AOther: TRadIAMemoryEvidenceSummary
    ): Boolean;
    property EvidenceId: string read FEvidenceId;
    property TotalBytes: Int64 read FTotalBytes;
  end;

  TRadIAMemoryEvidenceToolKind = (
    metCompare,
    metPrepareFix
  );

  TRadIAMemoryEvidenceTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIAMemoryEvidenceToolKind;
    FService: IRadIAMemoryEvidenceService;
  public
    constructor Create(
      const AKind: TRadIAMemoryEvidenceToolKind;
      const AService: IRadIAMemoryEvidenceService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CCompareInputSchema =
    '{"type":"object","required":["baselineEvidence","verificationEvidence"],' +
    '"properties":{"baselineEvidence":{"type":"object"},' +
    '"verificationEvidence":{"type":"object"}},"additionalProperties":false}';
  CPrepareFixInputSchema =
    '{"type":"object","required":["evidence","groupFingerprint"],' +
    '"properties":{"evidence":{"type":"object"},' +
    '"groupFingerprint":{"type":"string","minLength":64,"maxLength":64}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

function IsProjectFrame(const AFrame: TJSONObject): Boolean;
var
  LFileName: string;
begin
  LFileName := AFrame.GetValue<string>('fileName', '');
  Result :=
    not LFileName.IsEmpty and
    not StartsText('System.', LFileName) and
    not StartsText('Vcl.', LFileName) and
    not SameText(LFileName, 'FastMM5.pas') and
    (AFrame.GetValue<Integer>('lineNumber', 0) > 0);
end;

function FindEvidenceGroup(
  const ARoot: TJSONObject;
  const AGroupFingerprint: string;
  out AInvalidGroup: Boolean
): TJSONObject;
var
  LGroup: TJSONValue;
  LGroups: TJSONArray;
begin
  Result := nil;
  AInvalidGroup := False;
  LGroups := ARoot.GetValue<TJSONArray>('groups');
  if not Assigned(LGroups) then
    Exit;
  for LGroup in LGroups do
  begin
    if not (LGroup is TJSONObject) then
    begin
      AInvalidGroup := True;
      Exit;
    end;
    if SameText(
      (LGroup as TJSONObject).GetValue<string>('fingerprint', ''),
      AGroupFingerprint
    ) then
      Exit(LGroup as TJSONObject);
  end;
end;

function FindProjectFrame(const AGroup: TJSONObject): TJSONObject;
var
  LFrame: TJSONValue;
  LFrames: TJSONArray;
begin
  Result := nil;
  LFrames := AGroup.GetValue<TJSONArray>('frames');
  if not Assigned(LFrames) then
    Exit;
  for LFrame in LFrames do
    if (LFrame is TJSONObject) and
      IsProjectFrame(LFrame as TJSONObject) then
      Exit(LFrame as TJSONObject);
end;

function BuildPreparedFix(
  const AGroupFingerprint: string;
  const AGroup: TJSONObject;
  const AFrame: TJSONObject
): TRadIAToolResult;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('groupFingerprint', AGroupFingerprint);
    LRoot.AddPair(
      'allocationNumber',
      TJSONNumber.Create(AGroup.GetValue<Int64>('allocationNumber', 0))
    );
    LRoot.AddPair('targetFile', AFrame.GetValue<string>('fileName', ''));
    LRoot.AddPair('lineNumber', AFrame.GetValue<Integer>('lineNumber', 0));
    LRoot.AddPair('routineName', AFrame.GetValue<string>('routineName', ''));
    LRoot.AddPair('nextTool', 'PreparePatch');
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TryReadSummary(
  const AEvidence: string;
  out ASummary: TRadIAMemoryEvidenceSummary
): Boolean;
var
  LFingerprint: string;
  LGroup: TJSONValue;
  LGroupObject: TJSONObject;
  LGroups: TJSONArray;
  LRoot: TJSONObject;
  LSession: TJSONObject;
  LTotalBytes: Int64;
begin
  Result := False;
  ASummary := Default(TRadIAMemoryEvidenceSummary);
  LRoot := TJSONObject.ParseJSONValue(AEvidence) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
      Exit;
    LSession := LRoot.GetValue<TJSONObject>('session');
    LGroups := LRoot.GetValue<TJSONArray>('groups');
    if not Assigned(LSession) or not Assigned(LGroups) then
      Exit;
    ASummary.FEvidenceId := LRoot.GetValue<string>('evidenceId', '');
    ASummary.FBuildId := LSession.GetValue<string>('buildId', '');
    ASummary.FScenarioFingerprint :=
      LSession.GetValue<string>('scenarioFingerprint', '');
    ASummary.FGroupBytes := TDictionary<string, Int64>.Create;
    for LGroup in LGroups do
    begin
      if not (LGroup is TJSONObject) then
        Exit;
      LGroupObject := LGroup as TJSONObject;
      LFingerprint := LGroupObject.GetValue<string>(
        'fingerprint',
        ''
      );
      LTotalBytes := LGroupObject.GetValue<Int64>(
        'totalBytes',
        0
      );
      if LFingerprint.IsEmpty or (LTotalBytes < 0) then
        Exit;
      ASummary.FGroupBytes.AddOrSetValue(LFingerprint, LTotalBytes);
      Inc(ASummary.FTotalBytes, LTotalBytes);
    end;
    Result :=
      not ASummary.FEvidenceId.IsEmpty and
      not ASummary.FBuildId.IsEmpty and
      not ASummary.FScenarioFingerprint.IsEmpty;
  finally
    LRoot.Free;
    if not Result then
      ASummary.Clear;
  end;
end;

function ComparisonOutcome(
  const ABaseline: TRadIAMemoryEvidenceSummary;
  const AVerification: TRadIAMemoryEvidenceSummary
): TRadIAMemoryComparisonOutcome;
begin
  if not ABaseline.IsComparableWith(AVerification) then
    Exit(mcoIncomparable);
  if (ABaseline.GroupCount > 0) and (AVerification.GroupCount = 0) then
    Exit(mcoFixed);
  if AVerification.HasNewGroupComparedWith(ABaseline) or
    (AVerification.TotalBytes > ABaseline.TotalBytes) then
    Exit(mcoRegressed);
  if (AVerification.GroupCount < ABaseline.GroupCount) or
    (AVerification.TotalBytes < ABaseline.TotalBytes) then
    Exit(mcoImproved);
  Result := mcoUnchanged;
end;

{ TRadIAMemoryEvidenceSummary }

procedure TRadIAMemoryEvidenceSummary.Clear;
begin
  FGroupBytes.Free;
  FGroupBytes := nil;
end;

function TRadIAMemoryEvidenceSummary.GroupCount: Integer;
begin
  if Assigned(FGroupBytes) then
    Result := FGroupBytes.Count
  else
    Result := 0;
end;

function TRadIAMemoryEvidenceSummary.HasNewGroupComparedWith(
  const AOther: TRadIAMemoryEvidenceSummary
): Boolean;
var
  LFingerprint: string;
begin
  Result := False;
  for LFingerprint in FGroupBytes.Keys do
    if not AOther.FGroupBytes.ContainsKey(LFingerprint) then
      Exit(True);
end;

function TRadIAMemoryEvidenceSummary.IsComparableWith(
  const AOther: TRadIAMemoryEvidenceSummary
): Boolean;
begin
  Result :=
    not SameText(FBuildId, AOther.FBuildId) and
    SameText(FScenarioFingerprint, AOther.FScenarioFingerprint);
end;

{ TRadIAMemoryEvidenceService }

function TRadIAMemoryEvidenceService.Compare(
  const ABaselineEvidence: string;
  const AVerificationEvidence: string
): TRadIAToolResult;
var
  LBaseline: TRadIAMemoryEvidenceSummary;
  LOutcome: TRadIAMemoryComparisonOutcome;
  LRoot: TJSONObject;
  LVerification: TRadIAMemoryEvidenceSummary;
begin
  if not TryReadSummary(ABaselineEvidence, LBaseline) then
    Exit(TRadIAToolResult.Failed(
      'invalid_baseline_evidence',
      'Baseline memory evidence is invalid.'
    ));
  try
    if not TryReadSummary(AVerificationEvidence, LVerification) then
      Exit(TRadIAToolResult.Failed(
        'invalid_verification_evidence',
        'Verification memory evidence is invalid.'
      ));
    try
      LOutcome := ComparisonOutcome(LBaseline, LVerification);
      LRoot := TJSONObject.Create;
      try
        LRoot.AddPair(
          'outcome',
          RadIAMemoryComparisonOutcomeToString(LOutcome)
        );
        LRoot.AddPair('baselineEvidenceId', LBaseline.EvidenceId);
        LRoot.AddPair('verificationEvidenceId', LVerification.EvidenceId);
        LRoot.AddPair('baselineGroups', LBaseline.GroupCount);
        LRoot.AddPair('verificationGroups', LVerification.GroupCount);
        LRoot.AddPair(
          'baselineBytes',
          TJSONNumber.Create(LBaseline.TotalBytes)
        );
        LRoot.AddPair(
          'verificationBytes',
          TJSONNumber.Create(LVerification.TotalBytes)
        );
        Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
      finally
        LRoot.Free;
      end;
    finally
      LVerification.Clear;
    end;
  finally
    LBaseline.Clear;
  end;
end;

function TRadIAMemoryEvidenceService.PrepareFix(
  const AEvidence: string;
  const AGroupFingerprint: string
): TRadIAToolResult;
var
  LInvalidGroup: Boolean;
  LRoot: TJSONObject;
  LSelected: TJSONObject;
  LTargetFrame: TJSONObject;
begin
  LRoot := TJSONObject.ParseJSONValue(AEvidence) as TJSONObject;
  if not Assigned(LRoot) then
    Exit(TRadIAToolResult.Failed(
      'invalid_memory_evidence',
      'Memory evidence is invalid.'
    ));
  try
    LSelected := FindEvidenceGroup(
      LRoot,
      AGroupFingerprint,
      LInvalidGroup
    );
    if LInvalidGroup then
      Exit(TRadIAToolResult.Failed(
        'invalid_memory_evidence',
        'Memory evidence contains an invalid group.'
      ));
    if not Assigned(LSelected) then
      Exit(TRadIAToolResult.Failed(
        'memory_group_not_found',
        'The requested memory group was not found.'
      ));
    LTargetFrame := FindProjectFrame(LSelected);
    if not Assigned(LTargetFrame) then
      Exit(TRadIAToolResult.Failed(
        'memory_fix_target_unavailable',
        'No project source frame was found for this memory group.'
      ));
    Result := BuildPreparedFix(
      AGroupFingerprint,
      LSelected,
      LTargetFrame
    );
  finally
    LRoot.Free;
  end;
end;

{ TRadIAMemoryEvidenceTool }

constructor TRadIAMemoryEvidenceTool.Create(
  const AKind: TRadIAMemoryEvidenceToolKind;
  const AService: IRadIAMemoryEvidenceService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FKind := AKind;
  FService := AService;
end;

function TRadIAMemoryEvidenceTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LBaseline: TJSONValue;
  LVerification: TJSONValue;
  LValue: TJSONValue;
begin
  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Arguments must be a JSON object.'
    ));
  try
    if FKind = metCompare then
    begin
      LBaseline := LJson.GetValue('baselineEvidence');
      LVerification := LJson.GetValue('verificationEvidence');
      if not Assigned(LBaseline) or not Assigned(LVerification) then
        Exit(TRadIAToolResult.Failed(
          'invalid_request',
          'Baseline and verification evidence are required.'
        ));
      Result := FService.Compare(LBaseline.ToJSON, LVerification.ToJSON);
    end
    else
    begin
      LValue := LJson.GetValue('evidence');
      if not Assigned(LValue) then
        Exit(TRadIAToolResult.Failed(
          'invalid_request',
          'Memory evidence is required.'
        ));
      Result := FService.PrepareFix(
        LValue.ToJSON,
        LJson.GetValue<string>('groupFingerprint', '')
      );
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIAMemoryEvidenceTool.GetDescriptor: TRadIAToolDescriptor;
begin
  if FKind = metCompare then
    Result := TRadIAToolDescriptor.Create(
      'CompareMemoryDiagnosticEvidence',
      '1.0.0',
      'Compares two independent memory sessions and classifies the result.',
      CCompareInputSchema,
      CObjectOutputSchema,
      trReadOnly
    )
  else
    Result := TRadIAToolDescriptor.Create(
      'PrepareMemoryDiagnosticFix',
      '1.0.0',
      'Selects the first project allocation frame for a reviewable patch.',
      CPrepareFixInputSchema,
      CObjectOutputSchema,
      trReadOnly
    );
end;

procedure RegisterRadIAMemoryEvidenceTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIAMemoryEvidenceService
);
var
  LKind: TRadIAMemoryEvidenceToolKind;
begin
  if not Assigned(ARegistry) or not Assigned(AService) then
    raise EArgumentNilException.Create('Memory evidence tool dependencies');
  for LKind := Low(TRadIAMemoryEvidenceToolKind) to
    High(TRadIAMemoryEvidenceToolKind) do
    ARegistry.RegisterTool(TRadIAMemoryEvidenceTool.Create(LKind, AService));
end;

end.
