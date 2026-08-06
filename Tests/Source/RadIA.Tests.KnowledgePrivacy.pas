unit RadIA.Tests.KnowledgePrivacy;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Interfaces,
  RadIA.Core.Knowledge,
  RadIA.Core.SettingsStorage;

type
  TRadIAKnowledgePrivacyTestSource = class(
    TInterfacedObject,
    IRadIAKnowledgeSource
  )
  public
    function GetProjectId: string;
    function ListSourceFiles: TArray<string>;
    function ReadSourceFile(
      const AFileName: string;
      out ADocument: TRadIAKnowledgeDocument
    ): Boolean;
  end;

  [TestFixture]
  TTestRadIAKnowledgePrivacy = class
  private
    FConfig: IRadIAConfig;
    FStorage: IRadIASettingsStorage;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ExclusionsBlockExistingAndFutureKnowledge;
    [Test]
    procedure ApprovedHistoryRequiresConsentAndStaysProjectScoped;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.AgentRuntime,
  RadIA.Core.Config,
  RadIA.Core.KnowledgeHistory,
  RadIA.Core.KnowledgePrivacy;

const
  CProjectId = 'C:\Projects\PrivacyDemo\PrivacyDemo.dproj';
  CPublicFile = 'C:\Projects\PrivacyDemo\PublicUnit.pas';
  CSecretFile = 'C:\Projects\PrivacyDemo\SecretUnit.pas';

function TRadIAKnowledgePrivacyTestSource.GetProjectId: string;
begin
  Result := CProjectId;
end;

function TRadIAKnowledgePrivacyTestSource.ListSourceFiles:
  TArray<string>;
begin
  Result := [CPublicFile, CSecretFile];
end;

function TRadIAKnowledgePrivacyTestSource.ReadSourceFile(
  const AFileName: string;
  out ADocument: TRadIAKnowledgeDocument
): Boolean;
var
  LContent: string;
begin
  Result := SameText(AFileName, CPublicFile) or
    SameText(AFileName, CSecretFile);
  if not Result then
    Exit;
  if SameText(AFileName, CSecretFile) then
    LContent := 'unit SecretUnit; interface const PrivateMarker = 42;'
  else
    LContent := 'unit PublicUnit; interface const PublicMarker = 7;';
  ADocument := TRadIAKnowledgeDocument.Create(
    AFileName,
    'revision-1',
    LContent
  );
end;

procedure TTestRadIAKnowledgePrivacy.ExclusionsBlockExistingAndFutureKnowledge;
var
  LCount: Integer;
  LDocument: TRadIAIndexedKnowledgeDocument;
  LHits: TArray<TRadIAKnowledgeSearchHit>;
  LService: IRadIAKnowledgeService;
  LSource: IRadIAKnowledgeSource;
  LStatus: TRadIAKnowledgeStatus;
begin
  LSource := TRadIAConfigurableKnowledgeSource.Create(
    FConfig,
    TRadIAKnowledgePrivacyTestSource.Create
  );
  LService := TRadIAConfigurableKnowledgeService.Create(
    FConfig,
    TRadIALocalKnowledgeService.Create(LSource)
  );
  Assert.IsTrue(LService.RefreshProject.Success);
  LHits := LService.Search(CProjectId, 'PrivateMarker', 10);
  LCount := Length(LHits);
  Assert.AreEqual(1, LCount);

  FConfig.KnowledgeExcludedFiles := 'generated; secretunit.pas';
  Assert.IsFalse(
    LService.GetDocument(CProjectId, CSecretFile, LDocument)
  );
  LHits := LService.Search(CProjectId, 'PrivateMarker', 10);
  LCount := Length(LHits);
  Assert.AreEqual(0, LCount);
  Assert.IsTrue(LService.RefreshProject.Success);
  LStatus := LService.GetStatus(CProjectId);
  Assert.AreEqual(1, LStatus.FileCount);

  FConfig.KnowledgeExcludedProjects := 'privacydemo';
  LCount := Length(LSource.ListSourceFiles);
  Assert.AreEqual(0, LCount);
  LHits := LService.Search(CProjectId, 'PublicMarker', 10);
  LCount := Length(LHits);
  Assert.AreEqual(0, LCount);
  Assert.IsTrue(LService.RefreshProject.Success);
  LStatus := LService.GetStatus(CProjectId);
  Assert.IsFalse(LStatus.Loaded);
  Assert.AreEqual(0, LStatus.FileCount);
end;

procedure TTestRadIAKnowledgePrivacy.
  ApprovedHistoryRequiresConsentAndStaysProjectScoped;
var
  LCheckpointDirectory: string;
  LCount: Integer;
  LDocument: TRadIAKnowledgeDocument;
  LFileName: string;
  LFiles: TArray<string>;
  LHits: TArray<TRadIAKnowledgeSearchHit>;
  LService: IRadIAKnowledgeService;
  LSource: IRadIAKnowledgeSource;
  LStore: TRadIAAgentFileCheckpointStore;
begin
  LCheckpointDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIAKnowledgeHistory-' + TGUID.NewGuid.ToString
  );
  LStore := TRadIAAgentFileCheckpointStore.Create(
    LCheckpointDirectory
  );
  try
    LStore.Save(
      'approved-session',
      '{"sessionId":"approved-session","objective":' +
      '"Refactor UniqueHistoryMarker","status":"completed",' +
      '"projectId":"' + CProjectId.Replace('\', '\\') + '",' +
      '"planApproved":true,"steps":[{"arguments":"SecretPayload"}]}'
    );
    LStore.Save(
      'other-project',
      '{"sessionId":"other-project","objective":"OtherProjectMarker",' +
      '"status":"completed","projectId":"C:\\Other\\Other.dproj",' +
      '"planApproved":true,"steps":[]}'
    );
  finally
    LStore.Free;
  end;
  try
    LSource := TRadIAApprovedHistoryKnowledgeSource.Create(
      FConfig,
      TRadIAKnowledgePrivacyTestSource.Create,
      LCheckpointDirectory
    );
    LCount := Length(LSource.ListSourceFiles);
    Assert.AreEqual(2, LCount);
    LService := TRadIAConfigurableKnowledgeService.Create(
      FConfig,
      TRadIALocalKnowledgeService.Create(LSource)
    );
    Assert.IsTrue(LService.RefreshProject.Success);
    LCount := Length(
      LService.Search(CProjectId, 'UniqueHistoryMarker', 10)
    );
    Assert.AreEqual(0, LCount);

    FConfig.KnowledgeApprovedHistoryEnabled := True;
    LFiles := LSource.ListSourceFiles;
    LCount := Length(LFiles);
    Assert.AreEqual(3, LCount);
    LFileName := LFiles[2];
    Assert.IsTrue(
      TRadIAApprovedHistoryKnowledgeSource.IsHistoryDocument(LFileName)
    );
    Assert.IsTrue(LSource.ReadSourceFile(LFileName, LDocument));
    Assert.Contains(LDocument.Content, 'UniqueHistoryMarker');
    Assert.DoesNotContain(LDocument.Content, 'SecretPayload');
    Assert.DoesNotContain(LDocument.Content, 'OtherProjectMarker');
    Assert.IsTrue(LService.RefreshProject.Success);
    LHits := LService.Search(CProjectId, 'UniqueHistoryMarker', 10);
    LCount := Length(LHits);
    Assert.AreEqual(1, LCount);

    FConfig.KnowledgeApprovedHistoryEnabled := False;
    LCount := Length(
      LService.Search(CProjectId, 'UniqueHistoryMarker', 10)
    );
    Assert.AreEqual(0, LCount);
  finally
    LSource := nil;
    LService := nil;
    if TDirectory.Exists(LCheckpointDirectory) then
      TDirectory.Delete(LCheckpointDirectory, True);
  end;
end;

procedure TTestRadIAKnowledgePrivacy.Setup;
begin
  TRadIAConfig.SetBaseRegistryPath('Software\TestRadIAKnowledgePrivacy');
  FStorage := TRadIAMemorySettingsStorage.Create;
  TRadIAConfig.SetStorage(FStorage);
  FConfig := TRadIAConfig.Create;
end;

procedure TTestRadIAKnowledgePrivacy.TearDown;
begin
  FConfig := nil;
  FStorage := nil;
  TRadIAConfig.SetStorage(nil);
  TRadIAConfig.SetBaseRegistryPath('');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAKnowledgePrivacy);

end.
