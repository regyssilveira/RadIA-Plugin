unit RadIA.Tests.AgentResultStore;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAAgentResultStoreTests = class
  private
    FDirectory: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure StoresAndReadsBoundedRange;
    [Test]
    procedure RejectsUnsafeIdentifiers;
    [Test]
    procedure RetrievalToolsRespectSessionBoundary;
    [Test]
    procedure EnforcesSessionQuotas;
    [Test]
    procedure CleansExpiredArtifacts;
    [Test]
    procedure SupportsConcurrentWritesAndReopen;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  System.Threading,
  RadIA.Core.AgentResultStore,
  RadIA.Core.AgentResultTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

procedure TRadIAAgentResultStoreTests.SupportsConcurrentWritesAndReopen;
var
  LArtifacts: TList<string>;
  LIndex: Integer;
  LLock: TObject;
  LStore: IRadIAAgentResultStore;
  LSummary: TRadIAAgentResultArtifact;
  LTasks: TArray<ITask>;
begin
  LArtifacts := TList<string>.Create;
  LLock := TObject.Create;
  try
    LStore := TRadIAAgentFileResultStore.Create(FDirectory);
    SetLength(LTasks, 8);
    for LIndex := Low(LTasks) to High(LTasks) do
      LTasks[LIndex] := TTask.Run(
        procedure
        var
          LArtifact: TRadIAAgentResultArtifact;
          LStep: Integer;
        begin
          LStep := TThread.CurrentThread.ThreadID mod 100000 + 1;
          LArtifact := LStore.Store(
            'session-concurrent',
            LStep,
            'content-' + IntToStr(LStep)
          );
          TMonitor.Enter(LLock);
          try
            LArtifacts.Add(LArtifact.ArtifactId);
          finally
            TMonitor.Exit(LLock);
          end;
        end
      );
    TTask.WaitForAll(LTasks);
    Assert.AreEqual<Integer>(8, LArtifacts.Count);
    LStore := nil;
    LStore := TRadIAAgentFileResultStore.Create(FDirectory);
    for LIndex := 0 to LArtifacts.Count - 1 do
      Assert.IsTrue(
        LStore.TryGetSummary(
          'session-concurrent',
          LArtifacts[LIndex],
          LSummary
        )
      );
  finally
    LLock.Free;
    LArtifacts.Free;
  end;
end;

procedure TRadIAAgentResultStoreTests.CleansExpiredArtifacts;
var
  LArtifact: TRadIAAgentResultArtifact;
  LOptions: TRadIAAgentResultStoreOptions;
  LPath: string;
  LStore: IRadIAAgentResultStore;
begin
  LOptions := TRadIAAgentResultStoreOptions.Create(100, 10, 500, 1);
  LStore := TRadIAAgentFileResultStore.Create(FDirectory, LOptions);
  LArtifact := LStore.Store('session-1', 1, 'expired');
  LPath := TPath.Combine(
    TPath.Combine(FDirectory, 'session-1'),
    LArtifact.ArtifactId + '.json'
  );
  TFile.SetLastWriteTime(LPath, Now - 2);
  Assert.AreEqual(1, LStore.CleanupExpired);
  Assert.IsFalse(TFile.Exists(LPath));
end;

procedure TRadIAAgentResultStoreTests.EnforcesSessionQuotas;
var
  LOptions: TRadIAAgentResultStoreOptions;
  LStore: IRadIAAgentResultStore;
begin
  LOptions := TRadIAAgentResultStoreOptions.Create(10, 2, 12, 1);
  LStore := TRadIAAgentFileResultStore.Create(FDirectory, LOptions);
  LStore.Store('session-1', 1, '123456');
  LStore.Store('session-1', 2, '123456');
  Assert.WillRaise(
    procedure
    begin
      LStore.Store('session-1', 3, 'x');
    end,
    EInvalidOpException
  );
end;

procedure TRadIAAgentResultStoreTests.Setup;
begin
  FDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ResultStore-' + TGUID.NewGuid.ToString
  );
end;

procedure TRadIAAgentResultStoreTests.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TRadIAAgentResultStoreTests.StoresAndReadsBoundedRange;
var
  LArtifact: TRadIAAgentResultArtifact;
  LContent: string;
  LStore: IRadIAAgentResultStore;
  LSummary: TRadIAAgentResultArtifact;
  LTotal: Integer;
begin
  LStore := TRadIAAgentFileResultStore.Create(FDirectory);
  LArtifact := LStore.Store('session-1', 2, '0123456789');
  Assert.IsTrue(
    LStore.TryGetSummary('session-1', LArtifact.ArtifactId, LSummary)
  );
  Assert.AreEqual(10, LSummary.CharacterCount);
  Assert.AreEqual(2, LSummary.StepIndex);
  Assert.IsTrue(
    LStore.TryReadRange(
      'session-1',
      LArtifact.ArtifactId,
      3,
      4,
      LContent,
      LTotal
    )
  );
  Assert.AreEqual('3456', LContent);
  Assert.AreEqual(10, LTotal);
end;

procedure TRadIAAgentResultStoreTests.RejectsUnsafeIdentifiers;
var
  LStore: IRadIAAgentResultStore;
begin
  LStore := TRadIAAgentFileResultStore.Create(FDirectory);
  Assert.WillRaise(
    procedure
    begin
      LStore.Store('..\outside', 1, '{}');
    end,
    EArgumentException
  );
end;

procedure TRadIAAgentResultStoreTests.RetrievalToolsRespectSessionBoundary;
var
  LArtifact: TRadIAAgentResultArtifact;
  LRangeTool: IRadIATool;
  LRegistry: IRadIAToolRegistry;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
  LStore: IRadIAAgentResultStore;
begin
  LStore := TRadIAAgentFileResultStore.Create(FDirectory);
  LArtifact := LStore.Store('session-1', 1, 'complete-result');
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAAgentResultTools(LRegistry, LStore);
  LRangeTool := LRegistry.Resolve('GetToolResultRange');
  LRequest := TRadIAToolRequest.Create(
    'GetToolResultRange',
    '{"artifactId":"' + LArtifact.ArtifactId + '",' +
      '"startCharacter":0,"maxCharacters":8}',
    'correlation',
    'test',
    'session-1',
    'project',
    'workspace'
  );
  LResult := LRangeTool.Execute(LRequest);
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'complete');
  LRequest := TRadIAToolRequest.Create(
    'GetToolResultRange',
    '{"artifactId":"' + LArtifact.ArtifactId + '",' +
      '"startCharacter":0,"maxCharacters":8}',
    'correlation',
    'test',
    'session-2',
    'project',
    'workspace'
  );
  LResult := LRangeTool.Execute(LRequest);
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('result_artifact_not_found', LResult.ErrorCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAAgentResultStoreTests);

end.
