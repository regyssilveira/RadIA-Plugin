unit RadIA.Tests.ProblemProjection;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAProblemProjection = class
  public
    [Test]
    procedure ParsesBoundedProblemSnapshot;
    [Test]
    procedure RejectsNonArrayPayload;
    [Test]
    procedure SkipsEntriesWithoutMessages;
    [Test]
    procedure NormalizesUnknownSeverity;
    [Test]
    procedure LimitsSnapshotToTwoHundredEntries;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.ProblemProjection;

procedure TTestRadIAProblemProjection.LimitsSnapshotToTwoHundredEntries;
var
  LArray: TJSONArray;
  LError: string;
  LIndex: Integer;
  LProblems: TArray<TRadIAProjectedProblem>;
begin
  LArray := TJSONArray.Create;
  try
    for LIndex := 1 to 250 do
      LArray.AddElement(
        TJSONObject.Create.AddPair('message', 'Finding ' + LIndex.ToString)
      );

    Assert.IsTrue(TRadIAProblemProjectionParser.Parse(
      LArray.ToJSON,
      LProblems,
      LError
    ));
    Assert.AreEqual(200, Length(LProblems));
  finally
    LArray.Free;
  end;
end;

procedure TTestRadIAProblemProjection.NormalizesUnknownSeverity;
var
  LError: string;
  LProblems: TArray<TRadIAProjectedProblem>;
begin
  Assert.IsTrue(TRadIAProblemProjectionParser.Parse(
    '[{"message":"Review this","severity":"unexpected"}]',
    LProblems,
    LError
  ));

  Assert.AreEqual(1, Length(LProblems));
  Assert.AreEqual('information', LProblems[0].Severity);
end;

procedure TTestRadIAProblemProjection.ParsesBoundedProblemSnapshot;
var
  LError: string;
  LProblems: TArray<TRadIAProjectedProblem>;
begin
  Assert.IsTrue(TRadIAProblemProjectionParser.Parse(
    '[{"title":"Compile error","message":"Unknown identifier",' +
    '"severity":"error","fileName":"Unit1.pas","line":12,' +
    '"column":4}]',
    LProblems,
    LError
  ));

  Assert.AreEqual('', LError);
  Assert.AreEqual(1, Length(LProblems));
  Assert.AreEqual('Compile error', LProblems[0].Title);
  Assert.AreEqual('Unknown identifier', LProblems[0].Message);
  Assert.AreEqual('error', LProblems[0].Severity);
  Assert.AreEqual('Unit1.pas', LProblems[0].FileName);
  Assert.AreEqual(12, LProblems[0].Line);
  Assert.AreEqual(4, LProblems[0].Column);
end;

procedure TTestRadIAProblemProjection.RejectsNonArrayPayload;
var
  LError: string;
  LProblems: TArray<TRadIAProjectedProblem>;
begin
  Assert.IsFalse(TRadIAProblemProjectionParser.Parse(
    '{"message":"not an array"}',
    LProblems,
    LError
  ));
  Assert.Contains(LError, 'JSON array');
end;

procedure TTestRadIAProblemProjection.SkipsEntriesWithoutMessages;
var
  LError: string;
  LProblems: TArray<TRadIAProjectedProblem>;
begin
  Assert.IsTrue(TRadIAProblemProjectionParser.Parse(
    '[{"title":"No message"},{"message":"Available"}]',
    LProblems,
    LError
  ));

  Assert.AreEqual(1, Length(LProblems));
  Assert.AreEqual('Available', LProblems[0].Message);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAProblemProjection);

end.
