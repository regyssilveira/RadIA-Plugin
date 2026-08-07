unit RadIA.Tests.FastMM5LogParser;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAFastMM5LogParser = class
  private
    function LeakBlock(const ASize: Integer): string;
    function FreedObjectBlock(const AVirtualMethod: string): string;
  public
    [Test]
    procedure ParsesLeakWithSourceFrame;
    [Test]
    procedure ClassifiesDoubleFree;
    [Test]
    procedure ClassifiesUseAfterFree;
    [Test]
    procedure AggregatesMultipleEvents;
    [Test]
    procedure EnforcesByteLimit;
    [Test]
    procedure ParsesExternalRealLogWhenProvided;
    [Test]
    procedure CollectsOutputDebugStringChunks;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.FastMM5LogParser;

function TTestRadIAFastMM5LogParser.LeakBlock(
  const ASize: Integer
): string;
begin
  Result :=
    '--------------------------------2026-08-07--------------------------------' + sLineBreak +
    'A memory block has been leaked. The size is: ' + ASize.ToString + sLineBreak +
    'The stack trace (return addresses) at the time was:' + sLineBreak +
    '01043163 [D:\Demo\Main.pas][Main][RunLeak$qqrv][31]' + sLineBreak +
    'The block is currently used for an object of class: TStringList' + sLineBreak +
    'The allocation number is: 9' + sLineBreak;
end;

function TTestRadIAFastMM5LogParser.FreedObjectBlock(
  const AVirtualMethod: string
): string;
begin
  Result :=
    '--------------------------------2026-08-07--------------------------------' + sLineBreak +
    'A virtual method was called on a freed object.' + sLineBreak +
    'Freed object class: System.Classes.TStringList' + sLineBreak +
    'Virtual method: ' + AVirtualMethod + sLineBreak +
    'The block size is 76.' + sLineBreak +
    '01043163 [D:\Demo\Main.pas][Main][ReleaseTwice$qqrv][42]' + sLineBreak +
    'The allocation number is: 5' + sLineBreak;
end;

procedure TTestRadIAFastMM5LogParser.ParsesLeakWithSourceFrame;
var
  LEvents: TJSONArray;
  LParser: TRadIAFastMM5LogParser;
  LResult: TRadIAMemoryLogParseResult;
  LRoot: TJSONObject;
begin
  LParser := TRadIAFastMM5LogParser.Create;
  try
    LResult := LParser.Parse(LeakBlock(50), 4096);
  finally
    LParser.Free;
  end;
  Assert.AreEqual(1, LResult.EventCount);
  Assert.AreEqual(Int64(50), LResult.TotalBytes);
  LRoot := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    LEvents := LRoot.GetValue<TJSONArray>('events');
    Assert.AreEqual('leak', LEvents[0].GetValue<string>('kind'));
    Assert.AreEqual(
      'TStringList',
      LEvents[0].GetValue<string>('className')
    );
    Assert.AreEqual(
      31,
      LEvents[0].GetValue<TJSONArray>('frames')[0]
        .GetValue<Integer>('lineNumber')
    );
  finally
    LRoot.Free;
  end;
end;

procedure TTestRadIAFastMM5LogParser.ClassifiesDoubleFree;
var
  LParser: TRadIAFastMM5LogParser;
  LResult: TRadIAMemoryLogParseResult;
begin
  LParser := TRadIAFastMM5LogParser.Create;
  try
    LResult := LParser.Parse(FreedObjectBlock('BeforeDestruction'), 4096);
  finally
    LParser.Free;
  end;
  Assert.Contains(LResult.ContentJson, '"kind":"doubleFree"');
  Assert.AreEqual(Int64(76), LResult.TotalBytes);
end;

procedure TTestRadIAFastMM5LogParser.ClassifiesUseAfterFree;
var
  LParser: TRadIAFastMM5LogParser;
  LResult: TRadIAMemoryLogParseResult;
begin
  LParser := TRadIAFastMM5LogParser.Create;
  try
    LResult := LParser.Parse(FreedObjectBlock('#15'), 4096);
  finally
    LParser.Free;
  end;
  Assert.Contains(LResult.ContentJson, '"kind":"useAfterFree"');
end;

procedure TTestRadIAFastMM5LogParser.AggregatesMultipleEvents;
var
  LParser: TRadIAFastMM5LogParser;
  LResult: TRadIAMemoryLogParseResult;
begin
  LParser := TRadIAFastMM5LogParser.Create;
  try
    LResult := LParser.Parse(LeakBlock(50) + LeakBlock(40), 8192);
  finally
    LParser.Free;
  end;
  Assert.AreEqual(2, LResult.EventCount);
  Assert.AreEqual(Int64(90), LResult.TotalBytes);
end;

procedure TTestRadIAFastMM5LogParser.EnforcesByteLimit;
var
  LParser: TRadIAFastMM5LogParser;
  LResult: TRadIAMemoryLogParseResult;
begin
  LParser := TRadIAFastMM5LogParser.Create;
  try
    LResult := LParser.Parse(
      LeakBlock(50) + StringOfChar('x', 5000),
      1024
    );
  finally
    LParser.Free;
  end;
  Assert.IsTrue(LResult.Truncated);
  Assert.IsTrue(Length(LResult.ContentJson) < 4096);
end;

procedure TTestRadIAFastMM5LogParser.ParsesExternalRealLogWhenProvided;
var
  LFixturePath: string;
  LParser: TRadIAFastMM5LogParser;
  LResult: TRadIAMemoryLogParseResult;
begin
  LFixturePath := GetEnvironmentVariable('RADIA_FASTMM5_LOG_FIXTURE');
  if LFixturePath.IsEmpty then
    Exit;
  Assert.IsTrue(TFile.Exists(LFixturePath));
  LParser := TRadIAFastMM5LogParser.Create;
  try
    LResult := LParser.Parse(
      TFile.ReadAllText(LFixturePath, TEncoding.UTF8),
      52428800
    );
  finally
    LParser.Free;
  end;
  Assert.IsTrue(LResult.EventCount > 0);
  Assert.IsTrue(LResult.TotalBytes > 0);
  Assert.Contains(LResult.ContentJson, 'RunLeakCase');
end;

procedure TTestRadIAFastMM5LogParser.CollectsOutputDebugStringChunks;
var
  LCollector: TRadIAMemoryLogCollector;
  LResult: TRadIAMemoryLogParseResult;
begin
  LCollector := TRadIAMemoryLogCollector.Create(4096);
  try
    LCollector.AppendOutputDebugString(LeakBlock(64));
    LResult := LCollector.Complete;
  finally
    LCollector.Free;
  end;
  Assert.AreEqual(1, LResult.EventCount);
  Assert.AreEqual(Int64(64), LResult.TotalBytes);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAFastMM5LogParser);

end.
