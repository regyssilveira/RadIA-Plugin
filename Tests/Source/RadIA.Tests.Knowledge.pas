unit RadIA.Tests.Knowledge;

interface

uses
  System.Generics.Collections,
  DUnitX.TestFramework,
  RadIA.Core.Knowledge,
  RadIA.Core.Tools;

type
  TRadIAFakeKnowledgeSource = class(
    TInterfacedObject,
    IRadIAKnowledgeSource
  )
  private
    FDocuments: TDictionary<string, TRadIAKnowledgeDocument>;
    FProjectId: string;
  public
    constructor Create;
    destructor Destroy; override;
    function GetProjectId: string;
    function ListSourceFiles: TArray<string>;
    function ReadSourceFile(
      const AFileName: string;
      out ADocument: TRadIAKnowledgeDocument
    ): Boolean;
    procedure AddDocument(
      const AFileName: string;
      const ARevision: string;
      const AContent: string
    );
    procedure RemoveDocument(const AFileName: string);
    property ProjectId: string read FProjectId write FProjectId;
  end;

  [TestFixture]
  TTestRadIALocalKnowledge = class
  private
    FExecutor: IRadIAToolExecutor;
    FRegistry: IRadIAToolRegistry;
    FService: IRadIAKnowledgeService;
    FSource: TRadIAFakeKnowledgeSource;
    function ExecuteTool(
      const AName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RefreshesAndSearchesStructuralChunks;
    [Test]
    procedure SkipsUnchangedRevisions;
    [Test]
    procedure ReplacesChangedDocuments;
    [Test]
    procedure RemovesDeletedDocuments;
    [Test]
    procedure ClearsProjectIndex;
    [Test]
    procedure RejectsMissingProject;
    [Test]
    procedure KnowledgeToolsIndexSearchAndClear;
    [Test]
    procedure KnowledgeToolsExposeExpectedRisks;
    [Test]
    procedure KnowledgeToolsExposeStatusAndDocument;
    [Test]
    procedure KnowledgeDocumentHonorsContentLimit;
    [Test]
    procedure PersistsAndReloadsIndex;
    [Test]
    procedure ClearProjectDeletesPersistedIndex;
    [Test]
    procedure RebuildsCorruptedPersistedIndex;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.KnowledgeStore,
  RadIA.Core.KnowledgeTools,
  RadIA.Core.ToolRegistry;

const
  CFirstFile = 'C:\Sample\Sample.Service.pas';
  CSecondFile = 'C:\Sample\Sample.Model.pas';
  CFirstContent =
    'unit Sample.Service;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TSampleService = class' + sLineBreak +
    '  public' + sLineBreak +
    '    function CalculateTotal: Currency;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'function TSampleService.CalculateTotal: Currency;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := 42;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  CSecondContent =
    'unit Sample.Model;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TInvoice = record' + sLineBreak +
    '    Number: string;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';

{ TRadIAFakeKnowledgeSource }

procedure TRadIAFakeKnowledgeSource.AddDocument(
  const AFileName: string;
  const ARevision: string;
  const AContent: string
);
begin
  FDocuments.AddOrSetValue(
    AFileName,
    TRadIAKnowledgeDocument.Create(
      AFileName,
      ARevision,
      AContent
    )
  );
end;

constructor TRadIAFakeKnowledgeSource.Create;
begin
  inherited;
  FDocuments := TDictionary<string, TRadIAKnowledgeDocument>.Create;
  FProjectId := 'C:\Sample\Sample.dproj';
end;

destructor TRadIAFakeKnowledgeSource.Destroy;
begin
  FDocuments.Free;
  inherited;
end;

function TRadIAFakeKnowledgeSource.GetProjectId: string;
begin
  Result := FProjectId;
end;

function TRadIAFakeKnowledgeSource.ListSourceFiles: TArray<string>;
begin
  Result := FDocuments.Keys.ToArray;
end;

function TRadIAFakeKnowledgeSource.ReadSourceFile(
  const AFileName: string;
  out ADocument: TRadIAKnowledgeDocument
): Boolean;
begin
  Result := FDocuments.TryGetValue(AFileName, ADocument);
end;

procedure TRadIAFakeKnowledgeSource.RemoveDocument(
  const AFileName: string
);
begin
  FDocuments.Remove(AFileName);
end;

{ TTestRadIALocalKnowledge }

function TTestRadIALocalKnowledge.ExecuteTool(
  const AName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      AArgumentsJson,
      'knowledge-test'
    )
  );
end;

procedure TTestRadIALocalKnowledge.ClearsProjectIndex;
var
  LHits: TArray<TRadIAKnowledgeSearchHit>;
begin
  FService.RefreshProject;
  FService.ClearProject(FSource.ProjectId);

  LHits := FService.Search(
    FSource.ProjectId,
    'CalculateTotal',
    10
  );
  Assert.AreEqual(0, Integer(Length(LHits)));
end;

procedure TTestRadIALocalKnowledge.ClearProjectDeletesPersistedIndex;
var
  LRootPath: string;
  LService: IRadIAKnowledgeService;
  LSnapshot: TRadIAKnowledgeIndexSnapshot;
  LStore: IRadIAKnowledgeStore;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'radia-knowledge-' + TGUID.NewGuid.ToString
  );
  try
    LStore := TRadIAJsonKnowledgeStore.Create(LRootPath);
    LService := TRadIALocalKnowledgeService.Create(FSource, LStore);
    Assert.IsTrue(LService.RefreshProject.Success);
    Assert.IsTrue(LStore.Load(FSource.ProjectId, LSnapshot));

    LService.ClearProject(FSource.ProjectId);

    Assert.IsFalse(LStore.Load(FSource.ProjectId, LSnapshot));
  finally
    LService := nil;
    LStore := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIALocalKnowledge.RefreshesAndSearchesStructuralChunks;
var
  LHits: TArray<TRadIAKnowledgeSearchHit>;
  LRefresh: TRadIAKnowledgeRefreshResult;
begin
  LRefresh := FService.RefreshProject;
  Assert.IsTrue(LRefresh.Success);
  Assert.AreEqual(2, LRefresh.IndexedFiles);
  Assert.AreEqual(2, LRefresh.UpdatedFiles);

  LHits := FService.Search(
    FSource.ProjectId,
    'calculate total',
    10
  );
  Assert.IsTrue(Length(LHits) > 0);
  Assert.AreEqual(CFirstFile, LHits[0].Chunk.FileName);
  Assert.IsTrue(LHits[0].Chunk.StartLine > 0);
  Assert.IsNotEmpty(LHits[0].Chunk.Revision);
end;

procedure TTestRadIALocalKnowledge.RebuildsCorruptedPersistedIndex;
var
  LFiles: TArray<string>;
  LRefresh: TRadIAKnowledgeRefreshResult;
  LRootPath: string;
  LService: IRadIAKnowledgeService;
  LSnapshot: TRadIAKnowledgeIndexSnapshot;
  LStore: IRadIAKnowledgeStore;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'radia-knowledge-' + TGUID.NewGuid.ToString
  );
  try
    LStore := TRadIAJsonKnowledgeStore.Create(LRootPath);
    LService := TRadIALocalKnowledgeService.Create(FSource, LStore);
    Assert.IsTrue(LService.RefreshProject.Success);
    LService := nil;
    LStore := nil;

    LFiles := TDirectory.GetFiles(
      LRootPath,
      '*.knowledge.json',
      TSearchOption.soTopDirectoryOnly
    );
    Assert.AreEqual(1, Integer(Length(LFiles)));
    TFile.WriteAllText(LFiles[0], '{invalid', TEncoding.UTF8);

    LStore := TRadIAJsonKnowledgeStore.Create(LRootPath);
    LService := TRadIALocalKnowledgeService.Create(FSource, LStore);
    LRefresh := LService.RefreshProject;

    Assert.IsTrue(LRefresh.Success);
    Assert.AreEqual(2, LRefresh.UpdatedFiles);
    Assert.IsTrue(LStore.Load(FSource.ProjectId, LSnapshot));
  finally
    LService := nil;
    LStore := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIALocalKnowledge.KnowledgeToolsExposeExpectedRisks;
begin
  Assert.AreEqual(5, FRegistry.Count);
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('IndexProjectKnowledge').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('SearchProjectKnowledge').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    FRegistry.Resolve('ClearProjectKnowledge').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('GetKnowledgeStatus').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('GetKnowledgeDocument').Descriptor.Risk
  );
end;

procedure TTestRadIALocalKnowledge.KnowledgeDocumentHonorsContentLimit;
var
  LResult: TRadIAToolResult;
begin
  Assert.IsTrue(FService.RefreshProject.Success);

  LResult := ExecuteTool(
    'GetKnowledgeDocument',
    '{"fileName":"C:\\Sample\\Sample.Service.pas",' +
      '"maxCharacters":20}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(LResult.Truncated);
  Assert.Contains(LResult.ContentJson, '"truncated":true');
  Assert.Contains(LResult.ContentJson, '"revision":"revision-1"');
end;

procedure TTestRadIALocalKnowledge.KnowledgeToolsExposeStatusAndDocument;
var
  LResult: TRadIAToolResult;
begin
  Assert.IsTrue(FService.RefreshProject.Success);

  LResult := ExecuteTool('GetKnowledgeStatus', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"fileCount":2');
  Assert.Contains(LResult.ContentJson, '"chunkCount":');

  LResult := ExecuteTool(
    'GetKnowledgeDocument',
    '{"fileName":"C:\\Sample\\Sample.Service.pas"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"fileName":');
  Assert.Contains(LResult.ContentJson, 'CalculateTotal');
  Assert.Contains(LResult.ContentJson, '"startLine":');
end;

procedure TTestRadIALocalKnowledge.KnowledgeToolsIndexSearchAndClear;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('IndexProjectKnowledge', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"indexedFiles":2');

  LResult := ExecuteTool(
    'SearchProjectKnowledge',
    '{"query":"CalculateTotal","maxResults":5}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'Sample.Service.pas');
  Assert.Contains(LResult.ContentJson, '"startLine":');

  LResult := ExecuteTool('ClearProjectKnowledge', '{}');
  Assert.IsTrue(LResult.Success);
  LResult := ExecuteTool(
    'SearchProjectKnowledge',
    '{"query":"CalculateTotal"}'
  );
  Assert.Contains(LResult.ContentJson, '"count":0');
end;

procedure TTestRadIALocalKnowledge.PersistsAndReloadsIndex;
var
  LHits: TArray<TRadIAKnowledgeSearchHit>;
  LRootPath: string;
  LService: IRadIAKnowledgeService;
  LStore: IRadIAKnowledgeStore;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'radia-knowledge-' + TGUID.NewGuid.ToString
  );
  try
    LStore := TRadIAJsonKnowledgeStore.Create(LRootPath);
    LService := TRadIALocalKnowledgeService.Create(FSource, LStore);
    Assert.IsTrue(LService.RefreshProject.Success);
    LService := nil;
    LStore := nil;

    LStore := TRadIAJsonKnowledgeStore.Create(LRootPath);
    LService := TRadIALocalKnowledgeService.Create(FSource, LStore);
    LHits := LService.Search(
      FSource.ProjectId,
      'CalculateTotal',
      10
    );

    Assert.IsTrue(Length(LHits) > 0);
    Assert.AreEqual(CFirstFile, LHits[0].Chunk.FileName);
    Assert.AreEqual('revision-1', LHits[0].Chunk.Revision);
  finally
    LService := nil;
    LStore := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIALocalKnowledge.RejectsMissingProject;
var
  LRefresh: TRadIAKnowledgeRefreshResult;
begin
  FSource.ProjectId := '';

  LRefresh := FService.RefreshProject;

  Assert.IsFalse(LRefresh.Success);
  Assert.AreEqual('invalid_project', LRefresh.ErrorCode);
end;

procedure TTestRadIALocalKnowledge.RemovesDeletedDocuments;
var
  LHits: TArray<TRadIAKnowledgeSearchHit>;
  LRefresh: TRadIAKnowledgeRefreshResult;
begin
  FService.RefreshProject;
  FSource.RemoveDocument(CSecondFile);

  LRefresh := FService.RefreshProject;

  Assert.AreEqual(1, LRefresh.RemovedFiles);
  Assert.AreEqual(1, LRefresh.IndexedFiles);
  LHits := FService.Search(FSource.ProjectId, 'invoice', 10);
  Assert.AreEqual(0, Integer(Length(LHits)));
end;

procedure TTestRadIALocalKnowledge.ReplacesChangedDocuments;
var
  LHits: TArray<TRadIAKnowledgeSearchHit>;
  LRefresh: TRadIAKnowledgeRefreshResult;
begin
  FService.RefreshProject;
  FSource.AddDocument(
    CFirstFile,
    'revision-2',
    StringReplace(
      CFirstContent,
      'CalculateTotal',
      'CalculateBalance',
      [rfReplaceAll]
    )
  );

  LRefresh := FService.RefreshProject;

  Assert.AreEqual(1, LRefresh.UpdatedFiles);
  LHits := FService.Search(
    FSource.ProjectId,
    'CalculateBalance',
    10
  );
  Assert.IsTrue(Length(LHits) > 0);
  Assert.AreEqual('revision-2', LHits[0].Chunk.Revision);
end;

procedure TTestRadIALocalKnowledge.Setup;
begin
  FSource := TRadIAFakeKnowledgeSource.Create;
  FSource.AddDocument(CFirstFile, 'revision-1', CFirstContent);
  FSource.AddDocument(CSecondFile, 'revision-1', CSecondContent);
  FService := TRadIALocalKnowledgeService.Create(FSource);
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAKnowledgeTools(FRegistry, FService);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

procedure TTestRadIALocalKnowledge.SkipsUnchangedRevisions;
var
  LRefresh: TRadIAKnowledgeRefreshResult;
begin
  FService.RefreshProject;

  LRefresh := FService.RefreshProject;

  Assert.AreEqual(0, LRefresh.UpdatedFiles);
  Assert.AreEqual(2, LRefresh.SkippedFiles);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIALocalKnowledge);

end.
