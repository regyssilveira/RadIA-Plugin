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
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.Config,
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
