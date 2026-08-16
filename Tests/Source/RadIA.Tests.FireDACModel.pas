unit RadIA.Tests.FireDACModel;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACModelTests = class
  public
    [Test]
    procedure SerializesStructuredInventoryWithoutSensitiveValues;
    [Test]
    procedure DeduplicatesComponentsRelationshipsAndFindings;
    [Test]
    procedure AutomaticFixRequiresProvenConfidence;
    [Test]
    procedure ProducesStableFindingIdentifiers;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.FireDAC.Model;

function TestLocation: TRadIAFireDACLocation;
begin
  Result := TRadIAFireDACLocation.Create('Source/Data/MainData.pas', 42);
end;

function TestFinding(
  const AConfidence: TRadIAFireDACFindingConfidence
): TRadIAFireDACFinding;
begin
  Result := TRadIAFireDACFinding.Create(
    'firedac.parameter.missing',
    ffsHigh,
    AConfidence,
    'SQL parameter is not assigned',
    'Parameter customer_id has no matching assignment.',
    TestLocation,
    'Assign the parameter before opening the query.',
    True
  );
end;

procedure TRadIAFireDACModelTests.SerializesStructuredInventoryWithoutSensitiveValues;
var
  LInventory: TRadIAFireDACInventory;
  LJson: string;
begin
  LInventory := TRadIAFireDACInventory.Create;
  try
    LInventory.ScannedFileCount := 2;
    LInventory.AddComponent(TRadIAFireDACComponent.Create(
      'CustomerQuery',
      'TFDQuery',
      fckQuery,
      TestLocation,
      'MainData'
    ));
    LInventory.AddRelationship(TRadIAFireDACRelationship.Create(
      'CustomerQuery',
      'MainConnection',
      'connection',
      TestLocation
    ));
    LInventory.AddFinding(TestFinding(ffcProven));
    LJson := LInventory.ToJson;
    Assert.Contains(LJson, 'CustomerQuery');
    Assert.Contains(LJson, 'MainConnection');
    Assert.Contains(LJson, 'firedac.parameter.missing');
    Assert.Contains(LJson, '"sqlExecuted":false');
    Assert.Contains(LJson, '"credentialsCollected":false');
    Assert.DoesNotContain(LJson, 'secret-value');
  finally
    LInventory.Free;
  end;
end;

procedure TRadIAFireDACModelTests.DeduplicatesComponentsRelationshipsAndFindings;
var
  LComponent: TRadIAFireDACComponent;
  LFinding: TRadIAFireDACFinding;
  LInventory: TRadIAFireDACInventory;
  LRelationship: TRadIAFireDACRelationship;
begin
  LInventory := TRadIAFireDACInventory.Create;
  try
    LComponent := TRadIAFireDACComponent.Create(
      'CustomerQuery', 'TFDQuery', fckQuery, TestLocation, 'MainData'
    );
    LRelationship := TRadIAFireDACRelationship.Create(
      'CustomerQuery', 'MainConnection', 'connection', TestLocation
    );
    LFinding := TestFinding(ffcProven);
    LInventory.AddComponent(LComponent);
    LInventory.AddComponent(LComponent);
    LInventory.AddRelationship(LRelationship);
    LInventory.AddRelationship(LRelationship);
    LInventory.AddFinding(LFinding);
    LInventory.AddFinding(LFinding);
    Assert.AreEqual(1, Length(LInventory.Components));
    Assert.AreEqual(1, Length(LInventory.Relationships));
    Assert.AreEqual(1, Length(LInventory.Findings));
  finally
    LInventory.Free;
  end;
end;

procedure TRadIAFireDACModelTests.AutomaticFixRequiresProvenConfidence;
begin
  Assert.IsTrue(TestFinding(ffcProven).AutomaticFixAvailable);
  Assert.IsFalse(TestFinding(ffcStrong).AutomaticFixAvailable);
  Assert.IsFalse(TestFinding(ffcPossible).AutomaticFixAvailable);
  Assert.IsFalse(TestFinding(ffcInformational).AutomaticFixAvailable);
end;

procedure TRadIAFireDACModelTests.ProducesStableFindingIdentifiers;
var
  LFirst: TRadIAFireDACFinding;
  LSecond: TRadIAFireDACFinding;
begin
  LFirst := TestFinding(ffcProven);
  LSecond := TestFinding(ffcProven);
  Assert.AreEqual(LFirst.Id, LSecond.Id);
  Assert.AreEqual(24, LFirst.Id.Length);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACModelTests);

end.
