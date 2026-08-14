unit RadIA.Tests.SemanticIndex;

interface

implementation

uses
  System.Diagnostics,
  System.IOUtils,
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Semantic.Index;

type
  [TestFixture]
  TRadIASemanticIndexTests = class
  private
    FIndex: TRadIASemanticIndex;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure IndexesAndQueriesSymbolsAndMembers;
    [Test]
    procedure ReplacesOnlyNewerUnitRevisions;
    [Test]
    procedure RemovesUnitFromEveryLookup;
    [Test]
    procedure PersistsAndRestoresIndexCache;
    [Test]
    procedure DiscardsCorruptedIndexCache;
    [Test]
    procedure WarmQueriesMeetLatencyBudget;
    [Test]
    procedure ResolvesInheritedAndInterfaceMembersAcrossUnits;
    [Test]
    procedure FindsOnlyUnimplementedInterfaceMembers;
    [Test]
    procedure CompletesResolvedMembersByPrefixWithoutDuplicates;
    [Test]
    procedure ListsOnlyDeterministicPublicProjectApi;
  end;

procedure TRadIASemanticIndexTests.Setup;
begin
  FIndex := TRadIASemanticIndex.Create;
end;

procedure TRadIASemanticIndexTests.TearDown;
begin
  FIndex.Free;
end;

procedure TRadIASemanticIndexTests.IndexesAndQueriesSymbolsAndMembers;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.main',
    'Sample.Main.pas',
    susProject,
    1
  );
  Assert.IsTrue(FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Main; interface type TWorker = class' +
    ' public procedure Execute; end; implementation end.',
    nil
  ));
  Assert.AreEqual(1, FIndex.UnitCount);
  Assert.AreEqual(1, Length(FIndex.FindSymbols('TWorker')));
  Assert.AreEqual(1, Length(FIndex.FindMembers('TWorker')));
  Assert.AreEqual(susProject, FIndex.FindSymbols('TWorker')[0].Scope);
end;

procedure TRadIASemanticIndexTests.ReplacesOnlyNewerUnitRevisions;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create('sample', '', susGroup, 2);
  Assert.IsTrue(FIndex.IndexUnit(
    LDescriptor,
    'unit Sample; interface type TOld = class end; implementation end.',
    nil
  ));
  LDescriptor := TRadIASemanticUnitDescriptor.Create('sample', '', susGroup, 1);
  Assert.IsFalse(FIndex.IndexUnit(
    LDescriptor,
    'unit Sample; interface type TStale = class end; implementation end.',
    nil
  ));
  Assert.AreEqual(0, Length(FIndex.FindSymbols('TStale')));
  LDescriptor := TRadIASemanticUnitDescriptor.Create('sample', '', susGroup, 3);
  Assert.IsTrue(FIndex.IndexUnit(
    LDescriptor,
    'unit Sample; interface type TNew = class end; implementation end.',
    nil
  ));
  Assert.AreEqual(0, Length(FIndex.FindSymbols('TOld')));
  Assert.AreEqual(1, Length(FIndex.FindSymbols('TNew')));
end;

procedure TRadIASemanticIndexTests.RemovesUnitFromEveryLookup;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create('sample', '', susRTL, 1);
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample; interface type TWorker = class' +
    ' procedure Execute; end; implementation end.',
    nil
  );
  Assert.IsTrue(FIndex.RemoveUnit('SAMPLE'));
  Assert.IsFalse(FIndex.HasUnit('sample'));
  Assert.AreEqual(0, FIndex.SymbolCount);
  Assert.AreEqual(0, Length(FIndex.FindSymbols('TWorker')));
  Assert.AreEqual(0, Length(FIndex.FindMembers('TWorker')));
end;

procedure TRadIASemanticIndexTests.PersistsAndRestoresIndexCache;
var
  LCacheFile: string;
  LDescriptor: TRadIASemanticUnitDescriptor;
  LError: string;
  LRestored: TRadIASemanticIndex;
begin
  LCacheFile := TPath.GetTempFileName;
  try
    LDescriptor := TRadIASemanticUnitDescriptor.Create(
      'sample',
      'Sample.pas',
      susVCL,
      4
    );
    FIndex.IndexUnit(
      LDescriptor,
      'unit Sample; interface type TWorker = class ' +
      'procedure Execute; end; implementation end.',
      nil
    );
    FIndex.SaveCache(LCacheFile);
    LRestored := TRadIASemanticIndex.Create;
    try
      Assert.IsTrue(LRestored.LoadCache(LCacheFile, LError), LError);
      Assert.AreEqual(1, LRestored.UnitCount);
      Assert.AreEqual(1, Length(LRestored.FindSymbols('TWorker')));
      Assert.AreEqual(susVCL, LRestored.FindSymbols('TWorker')[0].Scope);
      Assert.AreEqual(1, Length(LRestored.FindMembers('TWorker')));
    finally
      LRestored.Free;
    end;
  finally
    if TFile.Exists(LCacheFile) then
      TFile.Delete(LCacheFile);
  end;
end;

procedure TRadIASemanticIndexTests.DiscardsCorruptedIndexCache;
var
  LCacheFile: string;
  LError: string;
begin
  LCacheFile := TPath.GetTempFileName;
  try
    TFile.WriteAllText(LCacheFile, '{broken', TEncoding.UTF8);
    Assert.IsFalse(FIndex.LoadCache(LCacheFile, LError));
    Assert.IsFalse(TFile.Exists(LCacheFile));
    Assert.IsTrue(LError <> '');
    Assert.AreEqual(0, FIndex.UnitCount);
  finally
    if TFile.Exists(LCacheFile) then
      TFile.Delete(LCacheFile);
  end;
end;

procedure TRadIASemanticIndexTests.WarmQueriesMeetLatencyBudget;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LIndex: Integer;
  LName: string;
  LStopwatch: TStopwatch;
begin
  for LIndex := 1 to 1000 do
  begin
    LName := 'TIndexed' + LIndex.ToString;
    LDescriptor := TRadIASemanticUnitDescriptor.Create(
      'unit.' + LIndex.ToString,
      '',
      susRTL,
      1
    );
    FIndex.IndexUnit(
      LDescriptor,
      'unit Unit' + LIndex.ToString + '; interface type ' + LName +
      ' = class procedure Execute; end; implementation end.',
      nil
    );
  end;
  FIndex.FindSymbols('TIndexed1000');
  FIndex.FindMembers('TIndexed1000');
  LStopwatch := TStopwatch.StartNew;
  Assert.AreEqual(1, Length(FIndex.FindSymbols('TIndexed1000')));
  Assert.AreEqual(1, Length(FIndex.FindMembers('TIndexed1000')));
  LStopwatch.Stop;
  Assert.IsTrue(
    LStopwatch.ElapsedMilliseconds < 50,
    'Warm semantic queries exceeded 50 ms.'
  );
end;

procedure TRadIASemanticIndexTests.ResolvesInheritedAndInterfaceMembersAcrossUnits;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create('contracts', '', susGroup, 1);
  FIndex.IndexUnit(
    LDescriptor,
    'unit Contracts; interface type IWorker = interface ' +
    'procedure Work; end; TBase = class procedure Reset; end; ' +
    'implementation end.',
    nil
  );
  LDescriptor := TRadIASemanticUnitDescriptor.Create('worker', '', susProject, 1);
  FIndex.IndexUnit(
    LDescriptor,
    'unit Worker; interface type TWorker = class(TBase, IWorker) ' +
    'procedure Execute; end; implementation end.',
    nil
  );
  Assert.AreEqual(3, Length(FIndex.FindResolvedMembers('TWorker')));
  Assert.AreEqual('Reset', FIndex.FindResolvedMembers('TWorker')[0].Name);
  Assert.AreEqual('Work', FIndex.FindResolvedMembers('TWorker')[1].Name);
  Assert.AreEqual('Execute', FIndex.FindResolvedMembers('TWorker')[2].Name);
end;

procedure TRadIASemanticIndexTests.FindsOnlyUnimplementedInterfaceMembers;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LMissing: TArray<TRadIASemanticIndexedSymbol>;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'contracts',
    '',
    susGroup,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Contracts; interface type IWorker = interface ' +
    'procedure Work(const AValue: Integer); ' +
    'procedure Work(const AValue: string); ' +
    'function Ready: Boolean; end; implementation end.',
    nil
  );
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'worker',
    '',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Worker; interface uses Contracts; type TWorker = class(IWorker) ' +
    'procedure Work(const AValue: Integer); function Ready: Boolean; ' +
    'end; implementation end.',
    nil
  );
  LMissing := FIndex.FindMissingMembers('TWorker');
  Assert.AreEqual(1, Length(LMissing));
  Assert.AreEqual('Work', LMissing[0].Name);
  Assert.Contains(LMissing[0].Signature, 'string');
end;

procedure TRadIASemanticIndexTests.
  CompletesResolvedMembersByPrefixWithoutDuplicates;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LMatches: TArray<TRadIASemanticIndexedSymbol>;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create('base', '', susVCL, 1);
  FIndex.IndexUnit(
    LDescriptor,
    'unit Base; interface type TBase = class procedure Save; ' +
    'procedure Search; procedure Reset; end; implementation end.',
    nil
  );
  LDescriptor := TRadIASemanticUnitDescriptor.Create('child', '', susProject, 1);
  FIndex.IndexUnit(
    LDescriptor,
    'unit Child; interface type TChild = class(TBase) ' +
    'procedure Save; end; implementation end.',
    nil
  );
  LMatches := FIndex.CompleteResolvedMembers('TChild', 'Sa', 10);
  Assert.AreEqual(1, Length(LMatches));
  Assert.AreEqual('Save', LMatches[0].Name);
  LMatches := FIndex.CompleteResolvedMembers('TChild', 'S', 1);
  Assert.AreEqual(1, Length(LMatches));
end;

procedure TRadIASemanticIndexTests.ListsOnlyDeterministicPublicProjectApi;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.api',
    'Sample.Api.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Api; interface type TApi = class ' +
    'private procedure Hidden; public procedure Execute; end; ' +
    'implementation end.',
    nil
  );
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'system.external',
    'System.External.pas',
    susRTL,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit System.External; interface type TExternal = class ' +
    'public procedure Execute; end; implementation end.',
    nil
  );
  LSymbols := FIndex.ListPublicApiSymbols(100);
  Assert.AreEqual(3, Length(LSymbols));
  Assert.AreEqual('Sample.Api', LSymbols[0].Name);
  Assert.AreEqual('TApi', LSymbols[1].Name);
  Assert.AreEqual('Execute', LSymbols[2].Name);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticIndexTests);

end.
