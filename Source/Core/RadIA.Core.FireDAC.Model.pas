unit RadIA.Core.FireDAC.Model;

interface

uses
  System.Generics.Collections,
  System.JSON;

const
  CRadIAFireDACMaximumFiles = 2000;
  CRadIAFireDACMaximumFileBytes = 2 * 1024 * 1024;
  CRadIAFireDACMaximumComponents = 5000;
  CRadIAFireDACMaximumRelationships = 10000;
  CRadIAFireDACMaximumFindings = 2000;

type
  TRadIAFireDACComponentKind = (
    fckUnknown,
    fckManager,
    fckConnection,
    fckTransaction,
    fckQuery,
    fckCommand,
    fckTable,
    fckStoredProcedure,
    fckMemoryTable,
    fckLocalSql,
    fckUpdateSql,
    fckScript,
    fckBatchMove,
    fckDriverLink,
    fckWaitCursor,
    fckMonitorLink,
    fckDataSource
  );

  TRadIAFireDACFindingSeverity = (ffsCritical, ffsHigh, ffsMedium, ffsLow, ffsInfo);
  TRadIAFireDACFindingConfidence = (ffcProven, ffcStrong, ffcPossible, ffcInformational);

  TRadIAFireDACLocation = record
  private
    FFileName: string;
    FLine: Integer;
  public
    constructor Create(const AFileName: string; const ALine: Integer);
    property FileName: string read FFileName;
    property Line: Integer read FLine;
  end;

  TRadIAFireDACComponent = record
  private
    FClassName: string;
    FKind: TRadIAFireDACComponentKind;
    FLocation: TRadIAFireDACLocation;
    FName: string;
    FOwnerName: string;
  public
    constructor Create(
      const AName: string;
      const AClassName: string;
      const AKind: TRadIAFireDACComponentKind;
      const ALocation: TRadIAFireDACLocation;
      const AOwnerName: string
    );
    property ClassName: string read FClassName;
    property Kind: TRadIAFireDACComponentKind read FKind;
    property Location: TRadIAFireDACLocation read FLocation;
    property Name: string read FName;
    property OwnerName: string read FOwnerName;
  end;

  TRadIAFireDACRelationship = record
  private
    FKind: string;
    FLocation: TRadIAFireDACLocation;
    FSourceName: string;
    FTargetName: string;
  public
    constructor Create(
      const ASourceName: string;
      const ATargetName: string;
      const AKind: string;
      const ALocation: TRadIAFireDACLocation
    );
    property Kind: string read FKind;
    property Location: TRadIAFireDACLocation read FLocation;
    property SourceName: string read FSourceName;
    property TargetName: string read FTargetName;
  end;

  TRadIAFireDACFinding = record
  private
    FAutomaticFixAvailable: Boolean;
    FConfidence: TRadIAFireDACFindingConfidence;
    FId: string;
    FLocation: TRadIAFireDACLocation;
    FMessage: string;
    FRuleId: string;
    FSeverity: TRadIAFireDACFindingSeverity;
    FSuggestedAction: string;
    FTitle: string;
  public
    constructor Create(
      const ARuleId: string;
      const ASeverity: TRadIAFireDACFindingSeverity;
      const AConfidence: TRadIAFireDACFindingConfidence;
      const ATitle: string;
      const AMessage: string;
      const ALocation: TRadIAFireDACLocation;
      const ASuggestedAction: string;
      const AAutomaticFixAvailable: Boolean
    );
    property AutomaticFixAvailable: Boolean read FAutomaticFixAvailable;
    property Confidence: TRadIAFireDACFindingConfidence read FConfidence;
    property Id: string read FId;
    property Location: TRadIAFireDACLocation read FLocation;
    property Message: string read FMessage;
    property RuleId: string read FRuleId;
    property Severity: TRadIAFireDACFindingSeverity read FSeverity;
    property SuggestedAction: string read FSuggestedAction;
    property Title: string read FTitle;
  end;

  TRadIAFireDACInventory = class
  private
    FComponents: TList<TRadIAFireDACComponent>;
    FFindings: TList<TRadIAFireDACFinding>;
    FParameterReferenceCount: Integer;
    FPotentiallyMutableSqlFileCount: Integer;
    FProjectReferences: TList<string>;
    FRelationships: TList<TRadIAFireDACRelationship>;
    FScannedFileCount: Integer;
    FTruncated: Boolean;
    function ContainsComponent(const AComponent: TRadIAFireDACComponent): Boolean;
    function ContainsFinding(const AFinding: TRadIAFireDACFinding): Boolean;
    function ContainsRelationship(const ARelationship: TRadIAFireDACRelationship): Boolean;
    function ContainsProjectReference(const AReference: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddComponent(const AComponent: TRadIAFireDACComponent);
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    procedure AddRelationship(const ARelationship: TRadIAFireDACRelationship);
    procedure AddProjectReference(const AReference: string);
    function Components: TArray<TRadIAFireDACComponent>;
    function Findings: TArray<TRadIAFireDACFinding>;
    function Relationships: TArray<TRadIAFireDACRelationship>;
    function ProjectReferences: TArray<string>;
    function ToJson: string;
    property ScannedFileCount: Integer read FScannedFileCount write FScannedFileCount;
    property ParameterReferenceCount: Integer read FParameterReferenceCount write FParameterReferenceCount;
    property PotentiallyMutableSqlFileCount: Integer read FPotentiallyMutableSqlFileCount
      write FPotentiallyMutableSqlFileCount;
    property Truncated: Boolean read FTruncated write FTruncated;
  end;

function RadIAFireDACComponentKindName(const AKind: TRadIAFireDACComponentKind): string;
function RadIAFireDACConfidenceName(const AValue: TRadIAFireDACFindingConfidence): string;
function RadIAFireDACSeverityName(const AValue: TRadIAFireDACFindingSeverity): string;

implementation

uses
  System.Hash,
  System.SysUtils;

function RadIAFireDACComponentKindName(const AKind: TRadIAFireDACComponentKind): string;
const
  CNames: array[TRadIAFireDACComponentKind] of string = (
    'unknown', 'manager', 'connection', 'transaction', 'query', 'command', 'table',
    'stored-procedure', 'memory-table', 'local-sql', 'update-sql', 'script', 'batch-move',
    'driver-link', 'wait-cursor', 'monitor-link', 'data-source'
  );
begin
  Result := CNames[AKind];
end;

function RadIAFireDACConfidenceName(const AValue: TRadIAFireDACFindingConfidence): string;
const
  CNames: array[TRadIAFireDACFindingConfidence] of string = (
    'proven', 'strong', 'possible', 'informational'
  );
begin
  Result := CNames[AValue];
end;

function RadIAFireDACSeverityName(const AValue: TRadIAFireDACFindingSeverity): string;
const
  CNames: array[TRadIAFireDACFindingSeverity] of string = (
    'critical', 'high', 'medium', 'low', 'info'
  );
begin
  Result := CNames[AValue];
end;

constructor TRadIAFireDACLocation.Create(const AFileName: string; const ALine: Integer);
begin
  FFileName := AFileName;
  FLine := ALine;
end;

constructor TRadIAFireDACComponent.Create(
  const AName: string;
  const AClassName: string;
  const AKind: TRadIAFireDACComponentKind;
  const ALocation: TRadIAFireDACLocation;
  const AOwnerName: string
);
begin
  FName := AName;
  FClassName := AClassName;
  FKind := AKind;
  FLocation := ALocation;
  FOwnerName := AOwnerName;
end;

constructor TRadIAFireDACRelationship.Create(
  const ASourceName: string;
  const ATargetName: string;
  const AKind: string;
  const ALocation: TRadIAFireDACLocation
);
begin
  FSourceName := ASourceName;
  FTargetName := ATargetName;
  FKind := AKind;
  FLocation := ALocation;
end;

constructor TRadIAFireDACFinding.Create(
  const ARuleId: string;
  const ASeverity: TRadIAFireDACFindingSeverity;
  const AConfidence: TRadIAFireDACFindingConfidence;
  const ATitle: string;
  const AMessage: string;
  const ALocation: TRadIAFireDACLocation;
  const ASuggestedAction: string;
  const AAutomaticFixAvailable: Boolean
);
var
  LIdentity: string;
begin
  FRuleId := ARuleId;
  FSeverity := ASeverity;
  FConfidence := AConfidence;
  FTitle := ATitle;
  FMessage := AMessage;
  FLocation := ALocation;
  FSuggestedAction := ASuggestedAction;
  FAutomaticFixAvailable := AAutomaticFixAvailable and (AConfidence = ffcProven);
  LIdentity := LowerCase(ARuleId + '|' + ALocation.FileName + '|' + ALocation.Line.ToString);
  FId := LowerCase(THashSHA2.GetHashString(LIdentity)).Substring(0, 24);
end;

constructor TRadIAFireDACInventory.Create;
begin
  inherited Create;
  FComponents := TList<TRadIAFireDACComponent>.Create;
  FRelationships := TList<TRadIAFireDACRelationship>.Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
  FProjectReferences := TList<string>.Create;
end;

destructor TRadIAFireDACInventory.Destroy;
begin
  FProjectReferences.Free;
  FFindings.Free;
  FRelationships.Free;
  FComponents.Free;
  inherited;
end;

function TRadIAFireDACInventory.ContainsProjectReference(const AReference: string): Boolean;
var
  LItem: string;
begin
  Result := False;
  for LItem in FProjectReferences do
    if SameText(LItem, AReference) then
      Exit(True);
end;

function TRadIAFireDACInventory.ContainsComponent(
  const AComponent: TRadIAFireDACComponent
): Boolean;
var
  LItem: TRadIAFireDACComponent;
begin
  Result := False;
  for LItem in FComponents do
    if SameText(LItem.Name, AComponent.Name) and
      SameText(LItem.Location.FileName, AComponent.Location.FileName) then
      Exit(True);
end;

function TRadIAFireDACInventory.ContainsFinding(const AFinding: TRadIAFireDACFinding): Boolean;
var
  LItem: TRadIAFireDACFinding;
begin
  Result := False;
  for LItem in FFindings do
    if SameText(LItem.Id, AFinding.Id) then
      Exit(True);
end;

function TRadIAFireDACInventory.ContainsRelationship(
  const ARelationship: TRadIAFireDACRelationship
): Boolean;
var
  LItem: TRadIAFireDACRelationship;
begin
  Result := False;
  for LItem in FRelationships do
    if SameText(LItem.SourceName, ARelationship.SourceName) and
      SameText(LItem.TargetName, ARelationship.TargetName) and
      SameText(LItem.Kind, ARelationship.Kind) then
      Exit(True);
end;

procedure TRadIAFireDACInventory.AddComponent(const AComponent: TRadIAFireDACComponent);
begin
  if FComponents.Count >= CRadIAFireDACMaximumComponents then
  begin
    FTruncated := True;
    Exit;
  end;
  if not ContainsComponent(AComponent) then
    FComponents.Add(AComponent);
end;

procedure TRadIAFireDACInventory.AddFinding(const AFinding: TRadIAFireDACFinding);
begin
  if FFindings.Count >= CRadIAFireDACMaximumFindings then
  begin
    FTruncated := True;
    Exit;
  end;
  if not ContainsFinding(AFinding) then
    FFindings.Add(AFinding);
end;

procedure TRadIAFireDACInventory.AddRelationship(
  const ARelationship: TRadIAFireDACRelationship
);
begin
  if FRelationships.Count >= CRadIAFireDACMaximumRelationships then
  begin
    FTruncated := True;
    Exit;
  end;
  if not ContainsRelationship(ARelationship) then
    FRelationships.Add(ARelationship);
end;

procedure TRadIAFireDACInventory.AddProjectReference(const AReference: string);
begin
  if AReference.Trim.IsEmpty or ContainsProjectReference(AReference) then
    Exit;
  if FProjectReferences.Count >= CRadIAFireDACMaximumComponents then
  begin
    FTruncated := True;
    Exit;
  end;
  FProjectReferences.Add(AReference);
end;

function TRadIAFireDACInventory.Components: TArray<TRadIAFireDACComponent>;
begin
  Result := FComponents.ToArray;
end;

function TRadIAFireDACInventory.Findings: TArray<TRadIAFireDACFinding>;
begin
  Result := FFindings.ToArray;
end;

function TRadIAFireDACInventory.Relationships: TArray<TRadIAFireDACRelationship>;
begin
  Result := FRelationships.ToArray;
end;

function TRadIAFireDACInventory.ProjectReferences: TArray<string>;
begin
  Result := FProjectReferences.ToArray;
end;

function ComponentToJson(const AComponent: TRadIAFireDACComponent): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AComponent.Name);
  Result.AddPair('className', AComponent.ClassName);
  Result.AddPair('kind', RadIAFireDACComponentKindName(AComponent.Kind));
  Result.AddPair('file', AComponent.Location.FileName);
  Result.AddPair('line', TJSONNumber.Create(AComponent.Location.Line));
  Result.AddPair('owner', AComponent.OwnerName);
end;

function RelationshipToJson(const AValue: TRadIAFireDACRelationship): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('source', AValue.SourceName);
  Result.AddPair('target', AValue.TargetName);
  Result.AddPair('kind', AValue.Kind);
  Result.AddPair('file', AValue.Location.FileName);
  Result.AddPair('line', TJSONNumber.Create(AValue.Location.Line));
end;

function FindingToJson(const AValue: TRadIAFireDACFinding): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AValue.Id);
  Result.AddPair('ruleId', AValue.RuleId);
  Result.AddPair('severity', RadIAFireDACSeverityName(AValue.Severity));
  Result.AddPair('confidence', RadIAFireDACConfidenceName(AValue.Confidence));
  Result.AddPair('title', AValue.Title);
  Result.AddPair('message', AValue.Message);
  Result.AddPair('file', AValue.Location.FileName);
  Result.AddPair('line', TJSONNumber.Create(AValue.Location.Line));
  Result.AddPair('suggestedAction', AValue.SuggestedAction);
  Result.AddPair('automaticFixAvailable', TJSONBool.Create(AValue.AutomaticFixAvailable));
end;

function TRadIAFireDACInventory.ToJson: string;
var
  LArray: TJSONArray;
  LComponent: TRadIAFireDACComponent;
  LConnectionCount: Integer;
  LFinding: TRadIAFireDACFinding;
  LQueryCount: Integer;
  LRelationship: TRadIAFireDACRelationship;
  LRoot: TJSONObject;
  LProjectReference: string;
  LTransactionCount: Integer;
begin
  LConnectionCount := 0;
  LQueryCount := 0;
  LTransactionCount := 0;
  for LComponent in FComponents do
    case LComponent.Kind of
      fckConnection:
        Inc(LConnectionCount);
      fckQuery, fckCommand, fckStoredProcedure:
        Inc(LQueryCount);
      fckTransaction:
        Inc(LTransactionCount);
    end;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('scannedFileCount', TJSONNumber.Create(FScannedFileCount));
    LRoot.AddPair('truncated', TJSONBool.Create(FTruncated));
    LRoot.AddPair('connectionCount', TJSONNumber.Create(LConnectionCount));
    LRoot.AddPair('queryCount', TJSONNumber.Create(LQueryCount));
    LRoot.AddPair('parameterReferenceCount', TJSONNumber.Create(FParameterReferenceCount));
    LRoot.AddPair('transactionCount', TJSONNumber.Create(LTransactionCount));
    LRoot.AddPair(
      'filesWithPotentiallyMutableSql',
      TJSONNumber.Create(FPotentiallyMutableSqlFileCount)
    );
    LArray := TJSONArray.Create;
    for LComponent in FComponents do
      LArray.AddElement(ComponentToJson(LComponent));
    LRoot.AddPair('components', LArray);
    LArray := TJSONArray.Create;
    for LRelationship in FRelationships do
      LArray.AddElement(RelationshipToJson(LRelationship));
    LRoot.AddPair('relationships', LArray);
    LArray := TJSONArray.Create;
    for LProjectReference in FProjectReferences do
      LArray.Add(LProjectReference);
    LRoot.AddPair('projectReferences', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(FindingToJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    LRoot.AddPair('credentialsCollected', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

end.
