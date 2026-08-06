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
    procedure DeactivatedModuleEventsDoNotScheduleRefresh;
    [Test]
    procedure ModuleEventsMarkKnowledgeDirty;
    [Test]
    procedure SourceFilterAcceptsIndexableKnowledgeFiles;
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

procedure TTestRadIAKnowledgeNotifier.DeactivatedModuleEventsDoNotScheduleRefresh;
var
  LControl: IRadIAKnowledgeModuleNotifierControl;
  LNotifier: IOTAModuleNotifier;
  LNotifierReference: IInterface;
  LSchedulerReference: IRadIAKnowledgeRefreshScheduler;
  LScheduler: TRadIAFakeKnowledgeRefreshScheduler;
begin
  LScheduler := TRadIAFakeKnowledgeRefreshScheduler.Create;
  LSchedulerReference := LScheduler;
  LNotifierReference := CreateRadIAKnowledgeModuleNotifier(
    LSchedulerReference
  );
  Assert.IsTrue(
    Supports(LNotifierReference, IOTAModuleNotifier, LNotifier)
  );
  Assert.IsTrue(
    Supports(
      LNotifierReference,
      IRadIAKnowledgeModuleNotifierControl,
      LControl
    )
  );

  LControl.Deactivate;
  LNotifier.Modified;
  LNotifier.AfterSave;
  LNotifier.ModuleRenamed('Renamed.Unit.pas');
  LNotifier.Destroyed;

  Assert.AreEqual(0, LScheduler.DirtyCount);
end;

procedure TTestRadIAKnowledgeNotifier.ModuleEventsMarkKnowledgeDirty;
var
  LNotifier: IOTAModuleNotifier;
  LNotifierReference: IInterface;
  LSchedulerReference: IRadIAKnowledgeRefreshScheduler;
  LScheduler: TRadIAFakeKnowledgeRefreshScheduler;
begin
  LScheduler := TRadIAFakeKnowledgeRefreshScheduler.Create;
  LSchedulerReference := LScheduler;
  LNotifierReference := CreateRadIAKnowledgeModuleNotifier(
    LSchedulerReference
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

procedure TTestRadIAKnowledgeNotifier.SourceFilterAcceptsIndexableKnowledgeFiles;
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
  Assert.IsTrue(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('FormOne.dfm')
  );
  Assert.IsTrue(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('ProjectOne.dproj')
  );
  Assert.IsTrue(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('Architecture.md')
  );
  Assert.IsFalse(
    TRadIAOTAKnowledgeNotifier.SupportsSourceFile('CompiledUnit.dcu')
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAKnowledgeNotifier);

end.
