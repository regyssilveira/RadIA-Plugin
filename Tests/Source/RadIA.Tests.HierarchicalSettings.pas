unit RadIA.Tests.HierarchicalSettings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAHierarchicalSettingsTests = class
  public
    [Test]
    procedure RequestOverridesEveryBroaderScope;
    [Test]
    procedure MissingValuesInheritIndependently;
    [Test]
    procedure SeparateProjectsResolveWithoutCrossContamination;
    [Test]
    procedure EmptyScopeDoesNotReplaceExplicitZeroLimits;
    [Test]
    procedure OriginNamesAreStableForStatusAndUi;
  end;

implementation

uses
  RadIA.Core.HierarchicalSettings;

function Settings(
  const AProvider: string;
  const AModel: string;
  const AExecutor: string;
  const AMaxTokens: Integer = -1;
  const ATimeoutMs: Integer = -1;
  const ATokenBudget: Int64 = -1
): TRadIAExecutionSettings;
begin
  Result := TRadIAExecutionSettings.Create(
    AProvider,
    AModel,
    AExecutor,
    AMaxTokens,
    ATimeoutMs,
    ATokenBudget
  );
end;

procedure TRadIAHierarchicalSettingsTests.RequestOverridesEveryBroaderScope;
var
  LResolved: TRadIAResolvedExecutionSettings;
begin
  LResolved := TRadIAExecutionSettingsResolver.Resolve(
    Settings('default', 'default-model', 'native'),
    Settings('global', 'global-model', 'codex'),
    Settings('project', 'project-model', 'claude'),
    Settings('session', 'session-model', 'gemini'),
    Settings('request', 'request-model', 'copilot')
  );

  Assert.AreEqual('request', LResolved.Values.ProviderId);
  Assert.AreEqual('request-model', LResolved.Values.ModelId);
  Assert.AreEqual('copilot', LResolved.Values.ExecutorId);
  Assert.AreEqual(rsoRequest, LResolved.ProviderOrigin);
  Assert.AreEqual(rsoRequest, LResolved.ModelOrigin);
  Assert.AreEqual(rsoRequest, LResolved.ExecutorOrigin);
end;

procedure TRadIAHierarchicalSettingsTests.MissingValuesInheritIndependently;
var
  LResolved: TRadIAResolvedExecutionSettings;
begin
  LResolved := TRadIAExecutionSettingsResolver.Resolve(
    Settings('default', 'default-model', 'native', 1024, 30000, 0),
    Settings('global', '', '', 2048),
    Settings('', 'project-model', ''),
    Settings('', '', 'claude', -1, 45000),
    Settings('', '', '', -1, -1, 9000)
  );

  Assert.AreEqual('global', LResolved.Values.ProviderId);
  Assert.AreEqual('project-model', LResolved.Values.ModelId);
  Assert.AreEqual('claude', LResolved.Values.ExecutorId);
  Assert.AreEqual(2048, LResolved.Values.MaxTokens);
  Assert.AreEqual(45000, LResolved.Values.TimeoutMs);
  Assert.AreEqual(Int64(9000), LResolved.Values.TokenBudget);
  Assert.AreEqual(rsoGlobal, LResolved.ProviderOrigin);
  Assert.AreEqual(rsoProject, LResolved.ModelOrigin);
  Assert.AreEqual(rsoSession, LResolved.ExecutorOrigin);
  Assert.AreEqual(rsoSession, LResolved.TimeoutOrigin);
  Assert.AreEqual(rsoRequest, LResolved.TokenBudgetOrigin);
end;

procedure TRadIAHierarchicalSettingsTests.
  SeparateProjectsResolveWithoutCrossContamination;
var
  LProjectA: TRadIAResolvedExecutionSettings;
  LProjectB: TRadIAResolvedExecutionSettings;
begin
  LProjectA := TRadIAExecutionSettingsResolver.Resolve(
    Settings('default', 'default-model', 'native'),
    TRadIAExecutionSettings.Empty,
    Settings('openai', 'model-a', ''),
    TRadIAExecutionSettings.Empty,
    TRadIAExecutionSettings.Empty
  );
  LProjectB := TRadIAExecutionSettingsResolver.Resolve(
    Settings('default', 'default-model', 'native'),
    TRadIAExecutionSettings.Empty,
    Settings('claude', 'model-b', ''),
    TRadIAExecutionSettings.Empty,
    TRadIAExecutionSettings.Empty
  );

  Assert.AreEqual('openai', LProjectA.Values.ProviderId);
  Assert.AreEqual('model-a', LProjectA.Values.ModelId);
  Assert.AreEqual('claude', LProjectB.Values.ProviderId);
  Assert.AreEqual('model-b', LProjectB.Values.ModelId);
end;

procedure TRadIAHierarchicalSettingsTests.
  EmptyScopeDoesNotReplaceExplicitZeroLimits;
var
  LResolved: TRadIAResolvedExecutionSettings;
begin
  LResolved := TRadIAExecutionSettingsResolver.Resolve(
    Settings('default', 'model', 'native', 1000, 30000, 1000),
    Settings('', '', '', 0, 0, 0),
    TRadIAExecutionSettings.Empty,
    TRadIAExecutionSettings.Empty,
    TRadIAExecutionSettings.Empty
  );

  Assert.AreEqual(0, LResolved.Values.MaxTokens);
  Assert.AreEqual(0, LResolved.Values.TimeoutMs);
  Assert.AreEqual(Int64(0), LResolved.Values.TokenBudget);
  Assert.AreEqual(rsoGlobal, LResolved.MaxTokensOrigin);
end;

procedure TRadIAHierarchicalSettingsTests.OriginNamesAreStableForStatusAndUi;
begin
  Assert.AreEqual('default', TRadIAExecutionSettingsResolver.OriginName(rsoDefault));
  Assert.AreEqual('global', TRadIAExecutionSettingsResolver.OriginName(rsoGlobal));
  Assert.AreEqual('project', TRadIAExecutionSettingsResolver.OriginName(rsoProject));
  Assert.AreEqual('session', TRadIAExecutionSettingsResolver.OriginName(rsoSession));
  Assert.AreEqual('request', TRadIAExecutionSettingsResolver.OriginName(rsoRequest));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAHierarchicalSettingsTests);

end.
