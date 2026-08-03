unit RadIA.Tests.KnowledgeNotifier;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.KnowledgeScheduler;

type
  TRadIAFakeKnowledgeRefreshScheduler = class(
    TInterfacedObject,
    IRadIAKnowledgeRefreshScheduler
  )
  private
    FDirtyCount: Integer;
  public
    function IsRunning: Boolean;
    procedure MarkDirty;
    procedure Poll;
    procedure Stop;
    property DirtyCount: Integer read FDirtyCount;
  end;

  [TestFixture]
  TTestRadIAKnowledgeNotifier = class
  public
    [Test]
    procedure ModuleEventsMarkKnowledgeDirty;
    [Test]
    procedure SourceFilterAcceptsOnlyIndexableDelphiFiles;
  end;

implementation

uses
  System.SysUtils,
  ToolsAPI,
  RadIA.OTA.KnowledgeNotifier;

{ TRadIAFakeKnowledgeRefreshScheduler }

function TRadIAFakeKnowledgeRefreshScheduler.IsRunning: Boolean;
begin
  Result := False;
end;

procedure TRadIAFakeKnowledgeRefreshScheduler.MarkDirty;
begin
  Inc(FDirtyCount);
end;

procedure TRadIAFakeKnowledgeRefreshScheduler.Poll;
begin
  if True then ;
end;

procedure TRadIAFakeKnowledgeRefreshScheduler.Stop;
begin
  if True then ;
end;

{ TTestRadIAKnowledgeNotifier }

procedure TTestRadIAKnowledgeNotifier.ModuleEventsMarkKnowledgeDirty;
var
  LNotifier: IOTAModuleNotifier;
  LNotifierReference: IInterface;
  LScheduler: TRadIAFakeKnowledgeRefreshScheduler;
begin
  LScheduler := TRadIAFakeKnowledgeRefreshScheduler.Create;
  LNotifierReference := CreateRadIAKnowledgeModuleNotifier(
    LScheduler
  );
  Assert.IsTrue(
    Supports(LNotifierReference, IOTAModuleNotifier, LNotifier)
  );

  LNotifier.BeforeSave;
  Assert.IsTrue(LNotifier.CheckOverwrite);
  LNotifier.Modified;
  LNotifier.AfterSave;
  LNotifier.ModuleRenamed('Renamed.Unit.pas');
  LNotifier.Destroyed;

  Assert.AreEqual(4, LScheduler.DirtyCount);
end;

procedure TTestRadIAKnowledgeNotifier.SourceFilterAcceptsOnlyIndexableDelphiFiles;
begin
  Assert.IsTrue(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('Unit.One.pas')
  );
  Assert.IsTrue(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('ProjectOne.dpr')
  );
  Assert.IsTrue(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('PackageOne.dpk')
  );
  Assert.IsTrue(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('Shared.inc')
  );
  Assert.IsFalse(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('FormOne.dfm')
  );
  Assert.IsFalse(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('ProjectOne.dproj')
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAKnowledgeNotifier);

end.
