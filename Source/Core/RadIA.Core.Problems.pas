unit RadIA.Core.Problems;

interface

uses
  System.Generics.Collections,
  System.JSON;

type
  TRadIAProblemSeverity = (
    psInformation,
    psWarning,
    psError,
    psCritical
  );

  TRadIAProblemCategory = (
    pcGeneral,
    pcBuild,
    pcTests,
    pcCoverage,
    pcMemory,
    pcDfmPas,
    pcThreading,
    pcReview
  );

  TRadIAProblem = record
  private
    FCategory: TRadIAProblemCategory;
    FSeverity: TRadIAProblemSeverity;
    FCode: string;
    FTitle: string;
    FMessage: string;
    FSourceTool: string;
    FFileName: string;
    FLine: Integer;
    FColumn: Integer;
    FRecommendedCommand: string;
    FFixId: string;
  public
    constructor Create(
      const ACategory: TRadIAProblemCategory;
      const ASeverity: TRadIAProblemSeverity;
      const ACode: string;
      const ATitle: string;
      const AMessage: string;
      const ASourceTool: string
    );
    function WithLocation(
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer
    ): TRadIAProblem;
    function WithRecommendedCommand(
      const ACommand: string
    ): TRadIAProblem;
    function WithFixId(const AId: string): TRadIAProblem;
    function ToJson: TJSONObject;
  end;

  TRadIAProblemExtractor = class
  private
    class procedure AppendCollection(
      const AToolName: string;
      const ACollectionName: string;
      const ARoot: TJSONObject;
      const AOutput: TJSONArray;
      const ASeen: TDictionary<string, Boolean>
    ); static;
    class procedure AppendCoverage(
      const AToolName: string;
      const ARoot: TJSONObject;
      const AOutput: TJSONArray
    ); static;
    class function CategoryFor(
      const AToolName: string;
      const ACollectionName: string
    ): TRadIAProblemCategory; static;
    class function CommandFor(
      const ACategory: TRadIAProblemCategory
    ): string; static;
    class function ExtractItem(
      const AToolName: string;
      const ACollectionName: string;
      const ARoot: TJSONObject;
      const AValue: TJSONValue;
      out AProblem: TRadIAProblem
    ): Boolean; static;
    class function IsActionableItem(
      const ACollectionName: string;
      const AItem: TJSONObject
    ): Boolean; static;
    class function MessageFor(
      const ACollectionName: string;
      const AItem: TJSONObject
    ): string; static;
    class procedure ResolveLocation(
      const ACollectionName: string;
      const ARoot: TJSONObject;
      const AItem: TJSONObject;
      const ACategory: TRadIAProblemCategory;
      out AFileName: string;
      out ALine: Integer
    ); static;
    class function SeverityFor(
      const ACollectionName: string;
      const AItem: TJSONObject;
      const AMessage: string
    ): TRadIAProblemSeverity; static;
  public
    class function Extract(
      const AToolName: string;
      const ARoot: TJSONObject
    ): TJSONArray; static;
  end;

implementation

uses
  System.Math,
  System.StrUtils,
  System.SysUtils;

const
  CMaxProblems = 200;
  CFnvOffset: UInt64 = $CBF29CE484222325;
  CFnvPrime: UInt64 = $100000001B3;
  CProblemCollections: array[0..8] of string = (
    'messages',
    'findings',
    'risks',
    'issues',
    'diagnostics',
    'testCases',
    'leaks',
    'events',
    'suggestedFixes'
  );

function CategoryName(
  const ACategory: TRadIAProblemCategory
): string;
begin
  case ACategory of
    pcBuild: Result := 'build';
    pcTests: Result := 'tests';
    pcCoverage: Result := 'coverage';
    pcMemory: Result := 'memory';
    pcDfmPas: Result := 'dfm-pas';
    pcThreading: Result := 'threading';
    pcReview: Result := 'review';
  else
    Result := 'general';
  end;
end;

function SeverityName(
  const ASeverity: TRadIAProblemSeverity
): string;
begin
  case ASeverity of
    psWarning: Result := 'warning';
    psError: Result := 'error';
    psCritical: Result := 'critical';
  else
    Result := 'information';
  end;
end;

function JsonInteger(
  const AObject: TJSONObject;
  const AName: string
): Integer;
var
  LValue: TJSONValue;
begin
  Result := 0;
  LValue := AObject.GetValue(AName);
  if Assigned(LValue) then
    Result := StrToIntDef(LValue.Value, 0);
end;

function JsonText(
  const AObject: TJSONObject;
  const AName: string
): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  LValue := AObject.GetValue(AName);
  if Assigned(LValue) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function FirstText(
  const AObject: TJSONObject;
  const ANames: array of string
): string;
var
  LName: string;
begin
  Result := '';
  for LName in ANames do
  begin
    Result := JsonText(AObject, LName);
    if not Result.Trim.IsEmpty then
      Exit;
  end;
end;

function StableProblemId(const AText: string): string;
var
  LCharacter: Char;
  LHash: UInt64;
begin
  LHash := CFnvOffset;
  for LCharacter in AText do
  begin
    LHash := LHash xor Ord(LCharacter);
    LHash := LHash * CFnvPrime;
  end;
  Result := 'problem-' + LowerCase(IntToHex(LHash, 16));
end;

{ TRadIAProblem }

constructor TRadIAProblem.Create(
  const ACategory: TRadIAProblemCategory;
  const ASeverity: TRadIAProblemSeverity;
  const ACode: string;
  const ATitle: string;
  const AMessage: string;
  const ASourceTool: string
);
begin
  FCategory := ACategory;
  FSeverity := ASeverity;
  FCode := ACode;
  FTitle := ATitle;
  FMessage := AMessage;
  FSourceTool := ASourceTool;
  FFileName := '';
  FLine := 0;
  FColumn := 0;
  FRecommendedCommand := '';
  FFixId := '';
end;

function TRadIAProblem.ToJson: TJSONObject;
var
  LIdentity: string;
begin
  LIdentity := LowerCase(
    FSourceTool + '|' + FCode + '|' + FFileName + '|' +
    IntToStr(FLine) + '|' + FMessage
  );
  Result := TJSONObject.Create;
  Result.AddPair('id', StableProblemId(LIdentity));
  Result.AddPair('category', CategoryName(FCategory));
  Result.AddPair('severity', SeverityName(FSeverity));
  Result.AddPair('code', FCode);
  Result.AddPair('title', FTitle);
  Result.AddPair('message', FMessage);
  Result.AddPair('sourceTool', FSourceTool);
  Result.AddPair('fileName', FFileName);
  Result.AddPair('line', TJSONNumber.Create(FLine));
  Result.AddPair('column', TJSONNumber.Create(FColumn));
  Result.AddPair('recommendedCommand', FRecommendedCommand);
  Result.AddPair('fixId', FFixId);
end;

function TRadIAProblem.WithFixId(const AId: string): TRadIAProblem;
begin
  Result := Self;
  Result.FFixId := AId;
end;

function TRadIAProblem.WithLocation(
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer
): TRadIAProblem;
begin
  Result := Self;
  Result.FFileName := AFileName;
  Result.FLine := Max(0, ALine);
  Result.FColumn := Max(0, AColumn);
end;

function TRadIAProblem.WithRecommendedCommand(
  const ACommand: string
): TRadIAProblem;
begin
  Result := Self;
  Result.FRecommendedCommand := ACommand;
end;

{ TRadIAProblemExtractor }

class procedure TRadIAProblemExtractor.AppendCollection(
  const AToolName: string;
  const ACollectionName: string;
  const ARoot: TJSONObject;
  const AOutput: TJSONArray;
  const ASeen: TDictionary<string, Boolean>
);
var
  LIndex: Integer;
  LProblem: TRadIAProblem;
  LProblemId: string;
  LProblemJson: TJSONObject;
  LValue: TJSONValue;
  LValues: TJSONArray;
begin
  LValue := ARoot.GetValue(ACollectionName);
  if not (LValue is TJSONArray) then
    Exit;
  LValues := TJSONArray(LValue);
  for LIndex := 0 to LValues.Count - 1 do
  begin
    if AOutput.Count >= CMaxProblems then
      Exit;
    if not ExtractItem(
      AToolName,
      ACollectionName,
      ARoot,
      LValues[LIndex],
      LProblem
    ) then
      Continue;
    LProblemJson := LProblem.ToJson;
    LProblemId := JsonText(LProblemJson, 'id');
    if ASeen.ContainsKey(LProblemId) then
    begin
      LProblemJson.Free;
      Continue;
    end;
    ASeen.Add(LProblemId, True);
    AOutput.AddElement(LProblemJson);
  end;
end;

class procedure TRadIAProblemExtractor.AppendCoverage(
  const AToolName: string;
  const ARoot: TJSONObject;
  const AOutput: TJSONArray
);
var
  LPercent: Integer;
  LProblem: TRadIAProblem;
  LSummary: TJSONObject;
  LValue: TJSONValue;
begin
  if not ContainsText(AToolName, 'Coverage') then
    Exit;
  LValue := ARoot.GetValue('summary');
  if not (LValue is TJSONObject) then
    Exit;
  LSummary := TJSONObject(LValue);
  LPercent := JsonInteger(LSummary, 'coveredPercent');
  if (LPercent < 0) or (LPercent >= 80) then
    Exit;
  LProblem := TRadIAProblem.Create(
    pcCoverage,
    psWarning,
    'coverage-below-recommended',
    'Coverage below recommended level',
    Format('Current line coverage is %d%%; the recommended level is 80%%.', [LPercent]),
    AToolName
  ).WithLocation(
    JsonText(ARoot, 'reportPath'),
    0,
    0
  ).WithRecommendedCommand('/journey tests');
  AOutput.AddElement(LProblem.ToJson);
end;

class function TRadIAProblemExtractor.CategoryFor(
  const AToolName: string;
  const ACollectionName: string
): TRadIAProblemCategory;
begin
  if SameText(ACollectionName, 'testCases') or
    ContainsText(AToolName, 'DUnitX') or
    ContainsText(AToolName, 'Test') then
    Exit(pcTests);
  if ContainsText(AToolName, 'Coverage') then
    Exit(pcCoverage);
  if SameText(ACollectionName, 'leaks') or
    SameText(ACollectionName, 'events') or
    ContainsText(AToolName, 'Memory') or
    ContainsText(AToolName, 'FastMM') then
    Exit(pcMemory);
  if ContainsText(AToolName, 'DfmPas') or
    ContainsText(AToolName, 'FormConsistency') then
    Exit(pcDfmPas);
  if ContainsText(AToolName, 'Thread') then
    Exit(pcThreading);
  if ContainsText(AToolName, 'Build') or
    SameText(ACollectionName, 'messages') then
    Exit(pcBuild);
  if ContainsText(AToolName, 'Review') or
    ContainsText(AToolName, 'Analyze') or
    ContainsText(AToolName, 'Validate') then
    Exit(pcReview);
  Result := pcGeneral;
end;

class function TRadIAProblemExtractor.CommandFor(
  const ACategory: TRadIAProblemCategory
): string;
begin
  case ACategory of
    pcBuild: Result := '/journey fix-build';
    pcTests, pcCoverage: Result := '/journey tests';
    pcMemory, pcThreading: Result := '/journey debug';
    pcDfmPas, pcReview: Result := '/review';
  else
    Result := '/status';
  end;
end;

class function TRadIAProblemExtractor.Extract(
  const AToolName: string;
  const ARoot: TJSONObject
): TJSONArray;
var
  LCollection: string;
  LProblems: TDictionary<string, Boolean>;
begin
  Result := TJSONArray.Create;
  LProblems := TDictionary<string, Boolean>.Create;
  try
    for LCollection in CProblemCollections do
      AppendCollection(AToolName, LCollection, ARoot, Result, LProblems);
    if Result.Count < CMaxProblems then
      AppendCoverage(AToolName, ARoot, Result);
  finally
    LProblems.Free;
  end;
end;

class function TRadIAProblemExtractor.ExtractItem(
  const AToolName: string;
  const ACollectionName: string;
  const ARoot: TJSONObject;
  const AValue: TJSONValue;
  out AProblem: TRadIAProblem
): Boolean;
var
  LCategory: TRadIAProblemCategory;
  LCode: string;
  LCommand: string;
  LFileName: string;
  LItem: TJSONObject;
  LLine: Integer;
  LMessage: string;
  LTitle: string;
begin
  Result := False;
  if not (AValue is TJSONObject) then
    Exit;
  LItem := TJSONObject(AValue);
  if not IsActionableItem(ACollectionName, LItem) then
    Exit;
  LMessage := MessageFor(ACollectionName, LItem);
  if LMessage.Trim.IsEmpty then
    Exit;
  LCategory := CategoryFor(AToolName, ACollectionName);
  LCode := FirstText(LItem, ['code', 'id', 'kind', 'name']);
  if LCode.Trim.IsEmpty then
    LCode := ACollectionName;
  LTitle := FirstText(LItem, ['title', 'name', 'code']);
  if LTitle.Trim.IsEmpty then
    LTitle := LCode;
  ResolveLocation(
    ACollectionName,
    ARoot,
    LItem,
    LCategory,
    LFileName,
    LLine
  );
  LCommand := FirstText(LItem, ['recommendedCommand', 'action']);
  if LCommand.Trim.IsEmpty and
    not SameText(ACollectionName, 'suggestedFixes') then
    LCommand := CommandFor(LCategory);
  AProblem := TRadIAProblem.Create(
    LCategory,
    SeverityFor(ACollectionName, LItem, LMessage),
    LCode,
    LTitle,
    LMessage,
    AToolName
  ).WithLocation(
    LFileName,
    LLine,
    JsonInteger(LItem, 'column')
  ).WithRecommendedCommand(LCommand);
  if SameText(ACollectionName, 'suggestedFixes') then
    AProblem := AProblem.WithFixId(JsonText(LItem, 'fixId'));
  Result := True;
end;

class function TRadIAProblemExtractor.IsActionableItem(
  const ACollectionName: string;
  const AItem: TJSONObject
): Boolean;
var
  LStatus: string;
begin
  if not SameText(ACollectionName, 'testCases') then
    Exit(True);
  LStatus := LowerCase(FirstText(AItem, ['status', 'result']));
  Result := (LStatus = 'failed') or (LStatus = 'error');
end;

class function TRadIAProblemExtractor.MessageFor(
  const ACollectionName: string;
  const AItem: TJSONObject
): string;
begin
  Result := FirstText(AItem, ['message', 'text', 'description', 'stackTrace']);
  if Result.Trim.IsEmpty and SameText(ACollectionName, 'events') then
    Result := Format(
      '%s: %s (%s bytes).',
      [
        FirstText(AItem, ['kind']),
        FirstText(AItem, ['className']),
        FirstText(AItem, ['totalBytes', 'blockSize'])
      ]
    );
end;

class procedure TRadIAProblemExtractor.ResolveLocation(
  const ACollectionName: string;
  const ARoot: TJSONObject;
  const AItem: TJSONObject;
  const ACategory: TRadIAProblemCategory;
  out AFileName: string;
  out ALine: Integer
);
var
  LFrame: TJSONObject;
  LFrames: TJSONArray;
  LValue: TJSONValue;
begin
  LFrame := nil;
  AFileName := FirstText(AItem, ['fileName', 'file', 'path']);
  LValue := AItem.GetValue('frames');
  if AFileName.Trim.IsEmpty and SameText(ACollectionName, 'events') and
    (LValue is TJSONArray) then
  begin
    LFrames := TJSONArray(LValue);
    if (LFrames.Count > 0) and (LFrames[0] is TJSONObject) then
    begin
      LFrame := TJSONObject(LFrames[0]);
      AFileName := JsonText(LFrame, 'fileName');
    end;
  end;
  if AFileName.Trim.IsEmpty and (ACategory = pcDfmPas) then
  begin
    if SameText(JsonText(AItem, 'fileKind'), 'dfm') then
      AFileName := JsonText(ARoot, 'dfmFile')
    else
      AFileName := JsonText(ARoot, 'pasFile');
  end;
  ALine := JsonInteger(AItem, 'line');
  if (ALine <= 0) and Assigned(LFrame) then
    ALine := JsonInteger(LFrame, 'lineNumber');
end;

class function TRadIAProblemExtractor.SeverityFor(
  const ACollectionName: string;
  const AItem: TJSONObject;
  const AMessage: string
): TRadIAProblemSeverity;
var
  LSeverity: string;
  LText: string;
begin
  LSeverity := LowerCase(FirstText(AItem, ['severity', 'status', 'result']));
  LText := LowerCase(LSeverity + ' ' + AMessage);
  if ContainsText(LText, 'critical') or ContainsText(LText, 'fatal') then
    Exit(psCritical);
  if ContainsText(LText, 'error') or ContainsText(LText, 'failed') or
    SameText(ACollectionName, 'leaks') or
    SameText(ACollectionName, 'events') then
    Exit(psError);
  if ContainsText(LText, 'warning') or ContainsText(LText, 'medium') or
    ContainsText(LText, 'high') then
    Exit(psWarning);
  Result := psInformation;
end;

end.
