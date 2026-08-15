unit RadIA.Tests.IntentTelemetry;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAIntentTelemetry = class
  private
    FDirectory: string;
    FFileName: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure StoresOnlySanitizedRoutingEvents;
    [Test]
    procedure ResetsStorageAtTheDocumentedBound;
    [Test]
    procedure MissingOrInvalidStorageDoesNotBreakStatus;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.IntentTelemetry;

procedure TTestRadIAIntentTelemetry.Setup;
begin
  FDirectory := TPath.Combine(TPath.GetTempPath, TGUID.NewGuid.ToString);
  FFileName := TPath.Combine(FDirectory, 'intent-routing.jsonl');
end;

procedure TTestRadIAIntentTelemetry.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TTestRadIAIntentTelemetry.StoresOnlySanitizedRoutingEvents;
const
  CSensitivePrompt = 'SECRET PROMPT CONTENT MUST NEVER BE STORED';
var
  LContent: string;
  LSummary: string;
begin
  TRadIAIntentTelemetry.TryRecordTo(
    FFileName,
    riteRecommended,
    CSensitivePrompt,
    'high'
  );
  TRadIAIntentTelemetry.TryRecordTo(
    FFileName,
    riteAccepted,
    'Create project',
    CSensitivePrompt
  );
  TRadIAIntentTelemetry.TryRecordTo(FFileName, riteReviewed, 'Fix build', 'high');
  TRadIAIntentTelemetry.TryRecordTo(FFileName, riteChatFallback, 'Run tests', 'high');
  TRadIAIntentTelemetry.TryRecordTo(FFileName, riteSuperseded, 'Diagnose problem', 'medium');

  LContent := TFile.ReadAllText(FFileName, TEncoding.UTF8);
  Assert.DoesNotContain(LContent, CSensitivePrompt);
  Assert.DoesNotContain(LowerCase(LContent), 'prompt');
  Assert.Contains(LContent, '"intent":"Unknown"');
  Assert.Contains(LContent, '"confidence":"unknown"');
  LSummary := TRadIAIntentTelemetry.SummaryJsonFrom(FFileName);
  Assert.Contains(LSummary, '"eventCount":5');
  Assert.Contains(LSummary, '"recommended":1');
  Assert.Contains(LSummary, '"accepted":1');
  Assert.Contains(LSummary, '"reviewed":1');
  Assert.Contains(LSummary, '"chatFallback":1');
  Assert.Contains(LSummary, '"superseded":1');
  Assert.Contains(LSummary, '"promptContentStored":false');
end;

procedure TTestRadIAIntentTelemetry.MissingOrInvalidStorageDoesNotBreakStatus;
var
  LSummary: string;
begin
  LSummary := TRadIAIntentTelemetry.SummaryJsonFrom(FFileName);
  Assert.Contains(LSummary, '"eventCount":0');
  TRadIAIntentTelemetry.TryRecordTo('', riteRecommended, 'Create project', 'high');
  Assert.IsFalse(TFile.Exists(FFileName));
end;

procedure TTestRadIAIntentTelemetry.ResetsStorageAtTheDocumentedBound;
var
  LContent: string;
begin
  TDirectory.CreateDirectory(FDirectory);
  TFile.WriteAllText(FFileName, StringOfChar('x', 1024 * 1024), TEncoding.UTF8);

  TRadIAIntentTelemetry.TryRecordTo(
    FFileName,
    riteRecommended,
    'Create project',
    'high'
  );

  LContent := TFile.ReadAllText(FFileName, TEncoding.UTF8);
  Assert.IsTrue(Length(LContent) < 1024);
  Assert.Contains(LContent, '"event":"recommended"');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAIntentTelemetry);

end.
