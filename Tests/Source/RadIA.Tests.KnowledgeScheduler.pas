unit RadIA.Tests.KnowledgeScheduler;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Knowledge,
  RadIA.Core.KnowledgeScheduler;

type
  TRadIAFakeScheduledKnowledge = class(
    TInterfacedObject,
    IRadIAKnowledgeService
  )
  private
    FRefreshCount: Integer;
  public
    function GetCurrentProjectId: string;
    function GetStatus(
      const AProjectId: string
    ): TRadIAKnowledgeStatus;
    function GetDocument(
      const AProjectId: string;
      const AFileName: string;
      out ADocument: TRadIAIndexedKnowledgeDocument
    ): Boolean;
    function RefreshProject: TRadIAKnowledgeRefreshResult;
    function Search(
      const AProjectId: string;
      const AQuery: string;
      const AMaxResults: Integer
    ): TArray<TRadIAKnowledgeSearchHit>;
    procedure ClearProject(const AProjectId: string);
    procedure Clear;
    function GetRefreshCount: Integer;
  end;

  [TestFixture]
  TTestRadIAKnowledgeScheduler = class
  private
    FKnowledge: TRadIAFakeScheduledKnowledge;
    FScheduler: IRadIAKnowledgeRefreshScheduler;
    FTick: UInt64;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure DebouncesAndRefreshesInBackground;
    [Test]
    procedure StopPreventsPendingRefresh;
  end;

implementation

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  Winapi.Windows;

{ TRadIAFakeScheduledKnowledge }

procedure TRadIAFakeScheduledKnowledge.Clear;
begin
  if True then ;
end;

procedure TRadIAFakeScheduledKnowledge.ClearProject(
  const AProjectId: string
);
begin
  if True then ;
end;

function TRadIAFakeScheduledKnowledge.GetCurrentProjectId: string;
begin
  Result := 'scheduled-project';
end;

function TRadIAFakeScheduledKnowledge.GetDocument(
  const AProjectId: string;
  const AFileName: string;
  out ADocument: TRadIAIndexedKnowledgeDocument
): Boolean;
begin
  ADocument := Default(TRadIAIndexedKnowledgeDocument);
  Result := False;
end;

function TRadIAFakeScheduledKnowledge.GetRefreshCount: Integer;
begin
  Result := TInterlocked.CompareExchange(FRefreshCount, 0, 0);
end;

function TRadIAFakeScheduledKnowledge.GetStatus(
  const AProjectId: string
): TRadIAKnowledgeStatus;
begin
  Result := TRadIAKnowledgeStatus.Create(
    AProjectId,
    True,
    0,
    0
  );
end;

function TRadIAFakeScheduledKnowledge.RefreshProject:
  TRadIAKnowledgeRefreshResult;
begin
  TInterlocked.Increment(FRefreshCount);
  Result := TRadIAKnowledgeRefreshResult.Succeeded(
    'scheduled-project',
    1,
    1,
    0,
    0
  );
end;

function TRadIAFakeScheduledKnowledge.Search(
  const AProjectId: string;
  const AQuery: string;
  const AMaxResults: Integer
): TArray<TRadIAKnowledgeSearchHit>;
begin
  Result := nil;
end;

{ TTestRadIAKnowledgeScheduler }

procedure TTestRadIAKnowledgeScheduler.DebouncesAndRefreshesInBackground;
begin
  FScheduler.MarkDirty;
  FScheduler.Poll;
  Assert.AreEqual(0, FKnowledge.GetRefreshCount);

  Inc(FTick, 50);
  FScheduler.Poll;

  Assert.AreEqual(1, FKnowledge.GetRefreshCount);
end;

procedure TTestRadIAKnowledgeScheduler.Setup;
begin
  FKnowledge := TRadIAFakeScheduledKnowledge.Create;
  FTick := 1000;
  FScheduler := TRadIAKnowledgeRefreshScheduler.Create(
    FKnowledge,
    50,
    procedure(const AAction: TProc)
    begin
      AAction();
    end,
    function: UInt64
    begin
      Result := FTick;
    end
  );
end;

procedure TTestRadIAKnowledgeScheduler.StopPreventsPendingRefresh;
begin
  FScheduler.MarkDirty;
  FScheduler.Stop;
  Inc(FTick, 50);
  FScheduler.Poll;

  Assert.AreEqual(0, FKnowledge.GetRefreshCount);
end;

procedure TTestRadIAKnowledgeScheduler.TearDown;
var
  LTimeout: Integer;
begin
  FScheduler.Stop;
  LTimeout := 0;
  while FScheduler.IsRunning and (LTimeout < 2000) do
  begin
    Sleep(1);
    Inc(LTimeout);
  end;
  Assert.IsFalse(
    FScheduler.IsRunning,
    'Scheduled refresh did not stop in time.'
  );
  FScheduler := nil;
  FKnowledge := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAKnowledgeScheduler);

end.
