unit RadIA.Tests.AgentExecutionContract;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAAgentExecutionContract = class
  public
    [Test]
    procedure PersistsContractAndPeriodicSummary;
    [Test]
    procedure PausesBeforeOperationLimitIsExceeded;
    [Test]
    procedure PausesBeforeFileLimitIsExceeded;
    [Test]
    procedure PausesOnAmbiguousToolResult;
    [Test]
    procedure CompletedRunIncludesFinalEvidenceReport;
    [Test]
    procedure RequiredTestGateRejectsEarlyCompletion;
  end;

implementation

uses
  RadIA.Core.AgentRuntime,
  RadIA.Core.Tools,
  RadIA.Tests.AgentRuntime;

function NewRuntime(
  const AExecutor: IRadIAToolExecutor;
  const AProvider: IRadIAAgentDecisionProvider;
  const AStore: IRadIAAgentCheckpointStore
): TRadIAAgentRuntime;
begin
  Result := TRadIAAgentRuntime.Create(
    AExecutor,
    AProvider,
    AStore,
    nil
  );
end;

function TestContract(
  const AMaxOperations: Integer;
  const ASummaryEverySteps: Integer;
  const ARequireTests: Boolean
): TRadIAAgentExecutionContract;
begin
  Result := TRadIAAgentExecutionContract.Create(
    2,
    AMaxOperations,
    ASummaryEverySteps,
    True,
    ARequireTests,
    'Apply the reviewed change and provide build and test evidence.'
  );
end;

procedure TTestRadIAAgentExecutionContract.CompletedRunIncludesFinalEvidenceReport;
var
  LProvider: IRadIAAgentDecisionProvider;
  LRuntime: TRadIAAgentRuntime;
  LStore: IRadIAAgentCheckpointStore;
begin
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan('Review.', '[{"step":"inspect"}]'),
    TRadIAAgentDecision.Complete('Done.')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(
    TRadIAMockAgentToolExecutor.Create(TRadIAToolResult.Succeeded('{}')),
    LProvider,
    LStore
  );
  try
    LRuntime.Start(
      'Complete with evidence.',
      'contract-final-report',
      'project',
      TRadIAAgentLimits.Default,
      TestContract(2, 1, False)
    );
    LRuntime.Resume('contract-final-report');
    Assert.Contains(LRuntime.SnapshotJson, '"finalReport"');
    Assert.Contains(LRuntime.SnapshotJson, '"pendingItems":[]');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentExecutionContract.PausesBeforeOperationLimitIsExceeded;
var
  LExecutor: IRadIAToolExecutor;
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LStore: IRadIAAgentCheckpointStore;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{"fileName":"Main.pas"}')
  );
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan('Review.', '[{"step":"change"}]'),
    TRadIAAgentDecision.CallTool('ApplyPatch', '{}'),
    TRadIAAgentDecision.CallTool('ApplyPatch', '{"next":true}')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LExecutor := LExecutorObject;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LRuntime.Start(
      'Respect operation contract.',
      'contract-operation-limit',
      'project',
      TRadIAAgentLimits.Default,
      TestContract(1, 1, False)
    );
    LResult := LRuntime.Resume('contract-operation-limit');
    Assert.AreEqual(asPaused, LResult.Status);
    Assert.AreEqual(1, LExecutorObject.CallCount);
    Assert.Contains(LResult.Message, 'before exceeding');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentExecutionContract.PausesBeforeFileLimitIsExceeded;
var
  LExecutor: IRadIAToolExecutor;
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LStore: IRadIAAgentCheckpointStore;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan('Review.', '[{"step":"change"}]'),
    TRadIAAgentDecision.CallTool(
      'ApplyPatch',
      '{"targetFile":"First.pas"}'
    ),
    TRadIAAgentDecision.CallTool(
      'ApplyPatch',
      '{"targetFile":"Second.pas"}'
    )
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LExecutor := LExecutorObject;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LRuntime.Start(
      'Respect file contract.',
      'contract-file-limit',
      'project',
      TRadIAAgentLimits.Default,
      TRadIAAgentExecutionContract.Create(
        1,
        5,
        1,
        True,
        False,
        'Apply only changes within the approved file boundary.'
      )
    );
    LResult := LRuntime.Resume('contract-file-limit');
    Assert.AreEqual(asPaused, LResult.Status);
    Assert.AreEqual(1, LExecutorObject.CallCount);
    Assert.Contains(LResult.Message, 'file limit');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentExecutionContract.PausesOnAmbiguousToolResult;
var
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LStore: IRadIAAgentCheckpointStore;
begin
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan('Review.', '[{"step":"inspect"}]'),
    TRadIAAgentDecision.CallTool('ReadFile', '{}')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(
    TRadIAMockAgentToolExecutor.Create(
      TRadIAToolResult.Failed(
        'ambiguous_original',
        'More than one match requires clarification.'
      )
    ),
    LProvider,
    LStore
  );
  try
    LRuntime.Start(
      'Pause on ambiguity.',
      'contract-ambiguity',
      'project',
      TRadIAAgentLimits.Default,
      TestContract(2, 1, False)
    );
    LResult := LRuntime.Resume('contract-ambiguity');
    Assert.AreEqual(asPaused, LResult.Status);
    Assert.Contains(LResult.Message, 'requires clarification');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentExecutionContract.PersistsContractAndPeriodicSummary;
var
  LProvider: IRadIAAgentDecisionProvider;
  LRuntime: TRadIAAgentRuntime;
  LStoreObject: TRadIAMemoryAgentCheckpointStore;
  LStore: IRadIAAgentCheckpointStore;
begin
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan('Review.', '[{"step":"inspect"}]'),
    TRadIAAgentDecision.CallTool('ReadFile', '{}'),
    TRadIAAgentDecision.Fail('Stop after summary.')
  ]);
  LStoreObject := TRadIAMemoryAgentCheckpointStore.Create;
  LStore := LStoreObject;
  LRuntime := NewRuntime(
    TRadIAMockAgentToolExecutor.Create(TRadIAToolResult.Succeeded('{}')),
    LProvider,
    LStore
  );
  try
    LRuntime.Start(
      'Persist execution contract.',
      'contract-persistence',
      'project',
      TRadIAAgentLimits.Default,
      TestContract(2, 1, True)
    );
    LRuntime.Resume('contract-persistence');
    Assert.Contains(LStoreObject.SnapshotJson, '"maxFiles":2');
    Assert.Contains(LStoreObject.SnapshotJson, '"requireTests":true');
    Assert.Contains(LStoreObject.SnapshotJson, '"periodicSummary":"1 steps');
    Assert.Contains(
      LStoreObject.SnapshotJson,
      'Apply the reviewed change and provide build and test evidence.'
    );
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentExecutionContract.RequiredTestGateRejectsEarlyCompletion;
var
  LExecutor: IRadIAToolExecutor;
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LStore: IRadIAAgentCheckpointStore;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LExecutorObject.OnExecute :=
    procedure
    begin
      case LExecutorObject.CallCount of
        2:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"status":"succeeded"}'
          );
        3:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"status":"succeeded","report":{"total":2,' +
            '"passed":2,"failed":0,"errors":0,"ignored":0}}'
          );
      end;
    end;
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan('Review.', '[{"step":"validate"}]'),
    TRadIAAgentDecision.CallTool(
      'ApplyPatch',
      '{"targetFile":"Main.pas"}'
    ),
    TRadIAAgentDecision.CallTool('BuildProject', '{}'),
    TRadIAAgentDecision.Complete('Tests are still missing.'),
    TRadIAAgentDecision.CallTool('RunDUnitXTests', '{}'),
    TRadIAAgentDecision.Complete('Validated.')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LExecutor := LExecutorObject;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LRuntime.Start(
      'Require tests.',
      'contract-required-tests',
      'project',
      TRadIAAgentLimits.Default,
      TestContract(5, 1, True)
    );
    LResult := LRuntime.Resume('contract-required-tests');
    Assert.AreEqual(asCompleted, LResult.Status);
    Assert.AreEqual('Validated.', LResult.Message);
    Assert.AreEqual(3, LExecutorObject.CallCount);
  finally
    LRuntime.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAAgentExecutionContract);

end.
