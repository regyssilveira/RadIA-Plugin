unit RadIA.Core.DUnitX;

interface

type
  TRadIADUnitXRunStatus = (
    drsIdle,
    drsRunning,
    drsSucceeded,
    drsFailed,
    drsCancelled,
    drsTimedOut
  );

  TRadIADUnitXRunRequest = record
  private
    FExecutablePath: string;
    FTimeoutMs: Cardinal;
    FTests: TArray<string>;
  public
    constructor Create(
      const AExecutablePath: string;
      const ATimeoutMs: Cardinal;
      const ATests: TArray<string>
    );
    property ExecutablePath: string read FExecutablePath;
    property TimeoutMs: Cardinal read FTimeoutMs;
    property Tests: TArray<string> read FTests;
  end;

  TRadIADUnitXTestStatus = (
    dtsPassed,
    dtsFailed,
    dtsError,
    dtsIgnored,
    dtsInconclusive
  );

  TRadIADUnitXTestCase = record
  private
    FFixtureName: string;
    FName: string;
    FStatus: TRadIADUnitXTestStatus;
    FDurationMs: Int64;
    FMessage: string;
    FStackTrace: string;
  public
    property FixtureName: string read FFixtureName;
    property Name: string read FName;
    property Status: TRadIADUnitXTestStatus read FStatus;
    property DurationMs: Int64 read FDurationMs;
    property Message: string read FMessage;
    property StackTrace: string read FStackTrace;
  end;

  TRadIADUnitXReport = record
  private
    FName: string;
    FTotal: Integer;
    FPassed: Integer;
    FFailed: Integer;
    FErrors: Integer;
    FIgnored: Integer;
    FDurationMs: Int64;
    FTestCases: TArray<TRadIADUnitXTestCase>;
  public
    function AllPassed: Boolean;
    function ToJson: string;
    property Name: string read FName;
    property Total: Integer read FTotal;
    property Passed: Integer read FPassed;
    property Failed: Integer read FFailed;
    property Errors: Integer read FErrors;
    property Ignored: Integer read FIgnored;
    property DurationMs: Int64 read FDurationMs;
    property TestCases: TArray<TRadIADUnitXTestCase> read FTestCases;
  end;

  TRadIADUnitXReportParser = class
  public
    function Parse(const AXml: string): TRadIADUnitXReport;
  end;

  TRadIADUnitXRunResult = record
  private
    FStatus: TRadIADUnitXRunStatus;
    FExitCode: Cardinal;
    FDurationMs: Int64;
    FReport: TRadIADUnitXReport;
    FOutput: string;
    FErrorCode: string;
    FErrorMessage: string;
  public
    class function Completed(
      const AStatus: TRadIADUnitXRunStatus;
      const AExitCode: Cardinal;
      const ADurationMs: Int64;
      const AReport: TRadIADUnitXReport;
      const AOutput: string
    ): TRadIADUnitXRunResult; static;
    class function Failed(
      const AStatus: TRadIADUnitXRunStatus;
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIADUnitXRunResult; static;
    property Status: TRadIADUnitXRunStatus read FStatus;
    property ExitCode: Cardinal read FExitCode;
    property DurationMs: Int64 read FDurationMs;
    property Report: TRadIADUnitXReport read FReport;
    property Output: string read FOutput;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
  end;

  IRadIADUnitXRunner = interface
    ['{7E4C579F-0BF2-4CAD-A095-47128428F205}']
    function Execute(
      const ARequest: TRadIADUnitXRunRequest
    ): TRadIADUnitXRunResult;
    function Cancel: Boolean;
    function GetStatus: TRadIADUnitXRunStatus;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  System.Variants,
  Xml.XMLDoc,
  Xml.XMLIntf;

type
  TRadIADUnitXReportAccess = record helper for TRadIADUnitXReport
    procedure AddTestCase(const ATestCase: TRadIADUnitXTestCase);
    procedure SetSummary(
      const AName: string;
      const ATotal: Integer;
      const AFailed: Integer;
      const AErrors: Integer;
      const AIgnored: Integer
    );
  end;

  TRadIADUnitXTestCaseAccess = record helper for TRadIADUnitXTestCase
    procedure Initialize(
      const AFixtureName: string;
      const ANode: IXMLNode
    );
  end;

function AttributeText(
  const ANode: IXMLNode;
  const AName: string
): string;
var
  LValue: OleVariant;
begin
  Result := '';
  if not ANode.HasAttribute(AName) then
    Exit;
  LValue := ANode.Attributes[AName];
  Result := VarToStr(LValue);
end;

function ChildText(
  const ANode: IXMLNode;
  const AName: string
): string;
var
  LChild: IXMLNode;
begin
  Result := '';
  LChild := ANode.ChildNodes.FindNode(AName);
  if Assigned(LChild) then
    Result := LChild.Text;
end;

function ParseDurationMs(const ANode: IXMLNode): Int64;
var
  LSeconds: Double;
begin
  LSeconds := StrToFloatDef(
    AttributeText(ANode, 'time'),
    0,
    TFormatSettings.Invariant
  );
  Result := Round(LSeconds * 1000);
end;

function StatusFromNode(
  const ANode: IXMLNode
): TRadIADUnitXTestStatus;
var
  LResult: string;
begin
  LResult := LowerCase(AttributeText(ANode, 'result'));
  if SameText(LResult, 'success') then
    Exit(dtsPassed);
  if SameText(LResult, 'failure') then
    Exit(dtsFailed);
  if SameText(LResult, 'error') then
    Exit(dtsError);
  if SameText(LResult, 'ignored') or
    SameText(LResult, 'skipped') then
    Exit(dtsIgnored);
  Result := dtsInconclusive;
end;

function StatusName(
  const AStatus: TRadIADUnitXTestStatus
): string;
begin
  case AStatus of
    dtsPassed: Result := 'passed';
    dtsFailed: Result := 'failed';
    dtsError: Result := 'error';
    dtsIgnored: Result := 'ignored';
  else
    Result := 'inconclusive';
  end;
end;

procedure ParseNodes(
  const ANode: IXMLNode;
  const AFixtureName: string;
  var AReport: TRadIADUnitXReport
);
var
  LCase: TRadIADUnitXTestCase;
  LChild: IXMLNode;
  LFixtureName: string;
  LIndex: Integer;
begin
  LFixtureName := AFixtureName;
  if SameText(ANode.NodeName, 'test-suite') and
    SameText(AttributeText(ANode, 'type'), 'Fixture') then
    LFixtureName := AttributeText(ANode, 'name');

  if SameText(ANode.NodeName, 'test-case') then
  begin
    LCase.Initialize(LFixtureName, ANode);
    AReport.AddTestCase(LCase);
    Exit;
  end;

  for LIndex := 0 to ANode.ChildNodes.Count - 1 do
  begin
    LChild := ANode.ChildNodes[LIndex];
    ParseNodes(LChild, LFixtureName, AReport);
  end;
end;

{ TRadIADUnitXReportAccess }

{ TRadIADUnitXRunRequest }

constructor TRadIADUnitXRunRequest.Create(
  const AExecutablePath: string;
  const ATimeoutMs: Cardinal;
  const ATests: TArray<string>
);
begin
  FExecutablePath := AExecutablePath;
  FTimeoutMs := ATimeoutMs;
  FTests := Copy(ATests);
end;

procedure TRadIADUnitXReportAccess.AddTestCase(
  const ATestCase: TRadIADUnitXTestCase
);
var
  LLength: Integer;
begin
  LLength := Length(FTestCases);
  SetLength(FTestCases, LLength + 1);
  FTestCases[LLength] := ATestCase;
  Inc(FDurationMs, ATestCase.DurationMs);
end;

procedure TRadIADUnitXReportAccess.SetSummary(
  const AName: string;
  const ATotal: Integer;
  const AFailed: Integer;
  const AErrors: Integer;
  const AIgnored: Integer
);
begin
  FName := AName;
  FTotal := ATotal;
  FFailed := AFailed;
  FErrors := AErrors;
  FIgnored := AIgnored;
  FPassed := ATotal - AFailed - AErrors - AIgnored;
end;

{ TRadIADUnitXTestCaseAccess }

procedure TRadIADUnitXTestCaseAccess.Initialize(
  const AFixtureName: string;
  const ANode: IXMLNode
);
var
  LFailure: IXMLNode;
begin
  FFixtureName := AFixtureName;
  FName := AttributeText(ANode, 'name');
  FStatus := StatusFromNode(ANode);
  FDurationMs := ParseDurationMs(ANode);
  FMessage := '';
  FStackTrace := '';

  LFailure := ANode.ChildNodes.FindNode('failure');
  if not Assigned(LFailure) then
    LFailure := ANode.ChildNodes.FindNode('reason');
  if Assigned(LFailure) then
  begin
    FMessage := ChildText(LFailure, 'message');
    FStackTrace := ChildText(LFailure, 'stack-trace');
  end;
end;

{ TRadIADUnitXReport }

function TRadIADUnitXReport.AllPassed: Boolean;
begin
  Result := (FFailed = 0) and (FErrors = 0);
end;

function TRadIADUnitXReport.ToJson: string;
var
  LCase: TRadIADUnitXTestCase;
  LCaseJson: TJSONObject;
  LCases: TJSONArray;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('name', FName);
    LRoot.AddPair('total', TJSONNumber.Create(FTotal));
    LRoot.AddPair('passed', TJSONNumber.Create(FPassed));
    LRoot.AddPair('failed', TJSONNumber.Create(FFailed));
    LRoot.AddPair('errors', TJSONNumber.Create(FErrors));
    LRoot.AddPair('ignored', TJSONNumber.Create(FIgnored));
    LRoot.AddPair('durationMs', TJSONNumber.Create(FDurationMs));
    LRoot.AddPair('allPassed', TJSONBool.Create(AllPassed));
    LCases := TJSONArray.Create;
    for LCase in FTestCases do
    begin
      LCaseJson := TJSONObject.Create;
      LCaseJson.AddPair('fixture', LCase.FixtureName);
      LCaseJson.AddPair('name', LCase.Name);
      LCaseJson.AddPair('status', StatusName(LCase.Status));
      LCaseJson.AddPair(
        'durationMs',
        TJSONNumber.Create(LCase.DurationMs)
      );
      LCaseJson.AddPair('message', LCase.Message);
      LCaseJson.AddPair('stackTrace', LCase.StackTrace);
      LCases.AddElement(LCaseJson);
    end;
    LRoot.AddPair('testCases', LCases);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

{ TRadIADUnitXReportParser }

function TRadIADUnitXReportParser.Parse(
  const AXml: string
): TRadIADUnitXReport;
var
  LDocument: IXMLDocument;
  LRoot: IXMLNode;
begin
  Result := Default(TRadIADUnitXReport);
  if Trim(AXml) = '' then
    raise EArgumentException.Create('DUnitX XML report cannot be empty.');

  LDocument := LoadXMLData(AXml);
  LRoot := LDocument.DocumentElement;
  if not Assigned(LRoot) or
    not SameText(LRoot.NodeName, 'test-results') then
    raise EArgumentException.Create(
      'Expected a DUnitX NUnit test-results document.'
    );

  Result.SetSummary(
    AttributeText(LRoot, 'name'),
    StrToIntDef(AttributeText(LRoot, 'total'), 0),
    StrToIntDef(AttributeText(LRoot, 'failures'), 0),
    StrToIntDef(AttributeText(LRoot, 'errors'), 0),
    StrToIntDef(AttributeText(LRoot, 'ignored'), 0)
  );
  ParseNodes(LRoot, '', Result);
end;

{ TRadIADUnitXRunResult }

class function TRadIADUnitXRunResult.Completed(
  const AStatus: TRadIADUnitXRunStatus;
  const AExitCode: Cardinal;
  const ADurationMs: Int64;
  const AReport: TRadIADUnitXReport;
  const AOutput: string
): TRadIADUnitXRunResult;
begin
  Result.FStatus := AStatus;
  Result.FExitCode := AExitCode;
  Result.FDurationMs := ADurationMs;
  Result.FReport := AReport;
  Result.FOutput := AOutput;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
end;

class function TRadIADUnitXRunResult.Failed(
  const AStatus: TRadIADUnitXRunStatus;
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIADUnitXRunResult;
begin
  Result.FStatus := AStatus;
  Result.FExitCode := Cardinal(-1);
  Result.FDurationMs := 0;
  Result.FReport := Default(TRadIADUnitXReport);
  Result.FOutput := '';
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

end.
