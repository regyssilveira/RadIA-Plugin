unit RadIA.Tests.HierarchicalSettings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAHierarchicalSettingsTests = class
  private
    FRootPath: string;
    FStore: IInterface;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
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
    [Test]
    procedure StorePersistsProjectAndSessionSeparately;
    [Test]
    procedure StorePreservesUnknownFieldsDuringMerge;
    [Test]
    procedure EmptyValuesRestoreInheritanceWithoutRemovingExtensions;
    [Test]
    procedure CorruptedFilesAreNeverOverwritten;
    [Test]
    procedure ScopeFileNamesAreHashedAndLeaveNoTemporaryFile;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.HierarchicalSettings,
  RadIA.Core.HierarchicalSettingsStore;

function StoreFrom(
  const AValue: IInterface
): IRadIAHierarchicalSettingsStore;
begin
  Result := AValue as IRadIAHierarchicalSettingsStore;
end;

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

procedure TRadIAHierarchicalSettingsTests.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-HierarchicalSettings-' +
      TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '')
  );
  FStore := TRadIAJsonHierarchicalSettingsStore.Create(FRootPath);
end;

procedure TRadIAHierarchicalSettingsTests.TearDown;
begin
  FStore := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
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

procedure TRadIAHierarchicalSettingsTests.
  StorePersistsProjectAndSessionSeparately;
var
  LProject: TRadIAExecutionSettings;
  LSession: TRadIAExecutionSettings;
  LStore: IRadIAHierarchicalSettingsStore;
begin
  LStore := StoreFrom(FStore);
  LStore.Save(
    rssProject,
    'C:\projects\alpha\alpha.dproj',
    Settings('openai', 'project-model', '', 2000)
  );
  LStore.Save(
    rssSession,
    'chat-1',
    Settings('', 'session-model', 'claude', -1, 45000)
  );

  LProject := LStore.Load(rssProject, 'C:\projects\alpha\alpha.dproj');
  LSession := LStore.Load(rssSession, 'chat-1');
  Assert.AreEqual('openai', LProject.ProviderId);
  Assert.AreEqual('project-model', LProject.ModelId);
  Assert.AreEqual(2000, LProject.MaxTokens);
  Assert.AreEqual('session-model', LSession.ModelId);
  Assert.AreEqual('claude', LSession.ExecutorId);
  Assert.AreEqual(45000, LSession.TimeoutMs);
end;

procedure TRadIAHierarchicalSettingsTests.StorePreservesUnknownFieldsDuringMerge;
var
  LFileName: string;
  LJson: TJSONObject;
  LSettings: TJSONObject;
  LStore: IRadIAHierarchicalSettingsStore;
  LText: string;
begin
  LStore := StoreFrom(FStore);
  LStore.Save(rssSession, 'chat-1', Settings('openai', 'first', 'native'));
  LFileName := LStore.GetScopeFileName(rssSession, 'chat-1');
  LJson := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(LFileName, TEncoding.UTF8)
  ) as TJSONObject;
  try
    LJson.AddPair('extensionMetadata', 'keep-me');
    LSettings := LJson.GetValue<TJSONObject>('settings');
    LSettings.AddPair('futureLimit', TJSONNumber.Create(42));
    TFile.WriteAllText(LFileName, LJson.Format(2), TEncoding.UTF8);
  finally
    LJson.Free;
  end;

  LStore.Save(rssSession, 'chat-1', Settings('claude', 'second', 'claude'));
  LText := TFile.ReadAllText(LFileName, TEncoding.UTF8);
  Assert.Contains(LText, '"extensionMetadata": "keep-me"');
  Assert.Contains(LText, '"futureLimit": 42');
  Assert.Contains(LText, '"provider": "claude"');
end;

procedure TRadIAHierarchicalSettingsTests.
  EmptyValuesRestoreInheritanceWithoutRemovingExtensions;
var
  LFileName: string;
  LJson: TJSONObject;
  LSettings: TJSONObject;
  LStore: IRadIAHierarchicalSettingsStore;
  LText: string;
begin
  LStore := StoreFrom(FStore);
  LStore.Save(rssProject, 'project-a', Settings('openai', 'model-a', 'native'));
  LFileName := LStore.GetScopeFileName(rssProject, 'project-a');
  LJson := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(LFileName, TEncoding.UTF8)
  ) as TJSONObject;
  try
    LSettings := LJson.GetValue<TJSONObject>('settings');
    LSettings.AddPair('extensionSetting', 'preserved');
    TFile.WriteAllText(LFileName, LJson.Format(2), TEncoding.UTF8);
  finally
    LJson.Free;
  end;

  LStore.Save(rssProject, 'project-a', TRadIAExecutionSettings.Empty);
  LText := TFile.ReadAllText(LFileName, TEncoding.UTF8);
  Assert.IsFalse(LText.Contains('"provider"'));
  Assert.IsFalse(LText.Contains('"model"'));
  Assert.Contains(LText, '"extensionSetting": "preserved"');
end;

procedure TRadIAHierarchicalSettingsTests.CorruptedFilesAreNeverOverwritten;
var
  LFileName: string;
  LStore: IRadIAHierarchicalSettingsStore;
begin
  LStore := StoreFrom(FStore);
  LFileName := LStore.GetScopeFileName(rssSession, 'chat-1');
  TDirectory.CreateDirectory(ExtractFilePath(LFileName));
  TFile.WriteAllText(LFileName, '{broken', TEncoding.UTF8);

  Assert.WillRaise(
    procedure
    begin
      LStore.Save(rssSession, 'chat-1', Settings('openai', 'model', 'native'));
    end,
    EConvertError
  );
  Assert.AreEqual('{broken', TFile.ReadAllText(LFileName, TEncoding.UTF8));
end;

procedure TRadIAHierarchicalSettingsTests.
  ScopeFileNamesAreHashedAndLeaveNoTemporaryFile;
var
  LFileName: string;
  LFiles: TArray<string>;
  LStore: IRadIAHierarchicalSettingsStore;
begin
  LStore := StoreFrom(FStore);
  LFileName := LStore.GetScopeFileName(
    rssProject,
    'C:\private\customer\secret.dproj'
  );
  Assert.IsFalse(LFileName.Contains('customer'));
  Assert.IsFalse(LFileName.Contains('secret'));

  LStore.Save(rssProject, 'C:\private\customer\secret.dproj', Settings(
    'openai',
    'model',
    'native'
  ));
  Assert.IsTrue(TFile.Exists(LFileName));
  LFiles := TDirectory.GetFiles(FRootPath, '*.tmp');
  Assert.AreEqual(NativeInt(0), Length(LFiles));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAHierarchicalSettingsTests);

end.
