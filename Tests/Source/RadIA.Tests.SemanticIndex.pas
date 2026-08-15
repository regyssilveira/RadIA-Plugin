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
    [Test]
    procedure ListsProjectTypesWithAncestorMetadata;
    [Test]
    procedure KeepsStableSymbolIdentityAcrossOffsetChanges;
    [Test]
    procedure DistinguishesOverloadsAndUnitsByIdentity;
    [Test]
    procedure ResolvesRoutineFamilyByCanonicalSignature;
    [Test]
    procedure FindsOnlyActiveCodeReferencesForUniqueSymbol;
    [Test]
    procedure SeparatesExactAndCandidateReferencesForHomonyms;
    [Test]
    procedure RestoresReferencesFromCache;
    [Test]
    procedure FindsDfmClassAndEventReferences;
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
  Assert.AreEqual(NativeInt(1), FIndex.UnitCount);
  Assert.AreEqual(NativeInt(1), Length(FIndex.FindSymbols('TWorker')));
  Assert.AreEqual(NativeInt(1), Length(FIndex.FindMembers('TWorker')));
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
  Assert.AreEqual(NativeInt(0), Length(FIndex.FindSymbols('TStale')));
  LDescriptor := TRadIASemanticUnitDescriptor.Create('sample', '', susGroup, 3);
  Assert.IsTrue(FIndex.IndexUnit(
    LDescriptor,
    'unit Sample; interface type TNew = class end; implementation end.',
    nil
  ));
  Assert.AreEqual(NativeInt(0), Length(FIndex.FindSymbols('TOld')));
  Assert.AreEqual(NativeInt(1), Length(FIndex.FindSymbols('TNew')));
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
  Assert.AreEqual(NativeInt(0), Length(FIndex.FindSymbols('TWorker')));
  Assert.AreEqual(NativeInt(0), Length(FIndex.FindMembers('TWorker')));
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
      Assert.AreEqual(NativeInt(1), LRestored.UnitCount);
      Assert.AreEqual(NativeInt(1), Length(LRestored.FindSymbols('TWorker')));
      Assert.AreEqual(susVCL, LRestored.FindSymbols('TWorker')[0].Scope);
      Assert.AreEqual(NativeInt(1), Length(LRestored.FindMembers('TWorker')));
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
    Assert.AreEqual(NativeInt(0), FIndex.UnitCount);
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
  Assert.AreEqual(NativeInt(1), Length(FIndex.FindSymbols('TIndexed1000')));
  Assert.AreEqual(NativeInt(1), Length(FIndex.FindMembers('TIndexed1000')));
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
  Assert.AreEqual(NativeInt(3), Length(FIndex.FindResolvedMembers('TWorker')));
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
  Assert.AreEqual(NativeInt(1), Length(LMissing));
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
  Assert.AreEqual(NativeInt(1), Length(LMatches));
  Assert.AreEqual('Save', LMatches[0].Name);
  LMatches := FIndex.CompleteResolvedMembers('TChild', 'S', 1);
  Assert.AreEqual(NativeInt(1), Length(LMatches));
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
  Assert.AreEqual(NativeInt(3), Length(LSymbols));
  Assert.AreEqual('Sample.Api', LSymbols[0].Name);
  Assert.AreEqual('TApi', LSymbols[1].Name);
  Assert.AreEqual('Execute', LSymbols[2].Name);
end;

procedure TRadIASemanticIndexTests.ResolvesRoutineFamilyByCanonicalSignature;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'worker',
    'Worker.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Worker; interface type TWorker = class ' +
    'procedure Execute(const AValue: Integer); overload; ' +
    'procedure Execute(const AValue: string); overload; end; ' +
    'implementation procedure TWorker.Execute(const AValue: Integer); ' +
    'begin end; procedure TWorker.Execute(const AValue: string); ' +
    'begin end; end.',
    nil
  );
  LSymbols := FIndex.FindRoutineSymbols(
    'Execute',
    'worker',
    'TWorker',
    'procedure Execute(const AValue: Integer);'
  );
  Assert.AreEqual(NativeInt(2), Length(LSymbols));
  Assert.AreEqual(LSymbols[0].SymbolId, LSymbols[1].SymbolId);
  Assert.AreNotEqual(
    Integer(LSymbols[0].DeclarationSection),
    Integer(LSymbols[1].DeclarationSection)
  );
end;

procedure TRadIASemanticIndexTests.ListsProjectTypesWithAncestorMetadata;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.types',
    'Sample.Types.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Types; interface type TBase = class end; ' +
    'TChild = class(TBase) public procedure Execute; end; ' +
    'implementation end.',
    nil
  );
  LSymbols := FIndex.ListTypeSymbols(100);
  Assert.AreEqual(NativeInt(2), Length(LSymbols));
  Assert.AreEqual('TBase', LSymbols[0].Name);
  Assert.AreEqual('TChild', LSymbols[1].Name);
  Assert.AreEqual(NativeInt(1), Length(LSymbols[1].AncestorNames));
  Assert.AreEqual('TBase', LSymbols[1].AncestorNames[0]);
end;

procedure TRadIASemanticIndexTests.KeepsStableSymbolIdentityAcrossOffsetChanges;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LFirstId: string;
  LFirstOffset: Integer;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.identity',
    'Sample.Identity.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Identity; interface type TWorker = class end; ' +
    'implementation end.',
    nil
  );
  LSymbols := FIndex.FindSymbols('TWorker');
  Assert.AreEqual(NativeInt(1), Length(LSymbols));
  LFirstId := LSymbols[0].SymbolId;
  LFirstOffset := LSymbols[0].StartOffset;

  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.identity',
    'Sample.Identity.pas',
    susProject,
    2
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Identity; interface const CShift = 1; ' +
    'type TWorker = class end; implementation end.',
    nil
  );
  LSymbols := FIndex.FindSymbols('TWorker');
  Assert.AreEqual(LFirstId, LSymbols[0].SymbolId);
  Assert.AreNotEqual(LFirstOffset, LSymbols[0].StartOffset);
  Assert.AreEqual(
    NativeInt(1),
    Length(FIndex.FindSymbolsById(LFirstId))
  );
end;

procedure TRadIASemanticIndexTests.DistinguishesOverloadsAndUnitsByIdentity;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LFirstUnitTypeId: string;
  LMethods: TArray<TRadIASemanticIndexedSymbol>;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.first',
    'Sample.First.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.First; interface type TWorker = class ' +
    'procedure Execute(const AValue: Integer); overload; ' +
    'procedure Execute(const AValue: string); overload; end; ' +
    'implementation end.',
    nil
  );
  LFirstUnitTypeId := FIndex.FindSymbols('TWorker')[0].SymbolId;
  LMethods := FIndex.FindSymbols('Execute');
  Assert.AreEqual(NativeInt(2), Length(LMethods));
  Assert.AreNotEqual(LMethods[0].SymbolId, LMethods[1].SymbolId);

  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.second',
    'Sample.Second.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Second; interface type TWorker = class end; ' +
    'implementation end.',
    nil
  );
  Assert.AreEqual(NativeInt(2), Length(FIndex.FindSymbols('TWorker')));
  Assert.AreNotEqual(
    LFirstUnitTypeId,
    FIndex.FindSymbols('TWorker')[1].SymbolId
  );
end;

procedure TRadIASemanticIndexTests.
  FindsOnlyActiveCodeReferencesForUniqueSymbol;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LReferences: TArray<TRadIASemanticReference>;
  LSymbolId: string;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.references',
    'Sample.References.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.References; interface type TWorker = class end; ' +
    'implementation procedure Use; var LWorker: TWorker; begin ' +
    '// TWorker' + sLineBreak +
    'Writeln(''TWorker''); {$IFDEF NEVER} LWorker := TWorker.Create; ' +
    '{$ENDIF} end; end.',
    nil
  );
  LSymbolId := FIndex.FindSymbols('TWorker')[0].SymbolId;
  LReferences := FIndex.FindReferences(LSymbolId, False, 100);
  Assert.AreEqual(NativeInt(2), Length(LReferences));
  Assert.AreEqual(srkDeclaration, LReferences[0].Kind);
  Assert.AreEqual(srkExact, LReferences[1].Kind);
end;

procedure TRadIASemanticIndexTests.
  SeparatesExactAndCandidateReferencesForHomonyms;
var
  LCandidates: Integer;
  LDeclarations: Integer;
  LDescriptor: TRadIASemanticUnitDescriptor;
  LExact: TArray<TRadIASemanticReference>;
  LExactMatches: Integer;
  LReference: TRadIASemanticReference;
  LWithCandidates: TArray<TRadIASemanticReference>;
  LSymbolId: string;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.first',
    'Sample.First.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.First; interface type TWorker = class end; ' +
    'implementation end.',
    nil
  );
  LSymbolId := FIndex.FindSymbols('TWorker')[0].SymbolId;
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.second',
    'Sample.Second.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Second; interface type TWorker = class end; ' +
    'implementation end.',
    nil
  );
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'sample.consumer',
    'Sample.Consumer.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Sample.Consumer; interface uses Sample.First, Sample.Second; ' +
    'type TConsumer = class procedure Use; end; implementation ' +
    'procedure TConsumer.Use; var LExact: Sample.First.TWorker; ' +
    'LAmbiguous: TWorker; begin end; end.',
    nil
  );
  LExact := FIndex.FindReferences(LSymbolId, False, 100);
  Assert.AreEqual(NativeInt(2), Length(LExact));
  LDeclarations := 0;
  LExactMatches := 0;
  for LReference in LExact do
    if LReference.Kind = srkDeclaration then
      Inc(LDeclarations)
    else if (LReference.Kind = srkExact) and
      (LReference.Reason = 'qualified-symbol') then
      Inc(LExactMatches);
  Assert.AreEqual(1, LDeclarations);
  Assert.AreEqual(1, LExactMatches);
  LWithCandidates := FIndex.FindReferences(LSymbolId, True, 100);
  Assert.AreEqual(NativeInt(3), Length(LWithCandidates));
  LCandidates := 0;
  for LReference in LWithCandidates do
    if (LReference.Kind = srkCandidate) and
      (LReference.Reason = 'ambiguous-short-name') then
      Inc(LCandidates);
  Assert.AreEqual(1, LCandidates);
end;

procedure TRadIASemanticIndexTests.RestoresReferencesFromCache;
var
  LCacheFile: string;
  LDescriptor: TRadIASemanticUnitDescriptor;
  LError: string;
  LRestored: TRadIASemanticIndex;
  LSymbolId: string;
begin
  LCacheFile := TPath.GetTempFileName;
  try
    LDescriptor := TRadIASemanticUnitDescriptor.Create(
      'sample.cache',
      'Sample.Cache.pas',
      susProject,
      1
    );
    FIndex.IndexUnit(
      LDescriptor,
      'unit Sample.Cache; interface type TWorker = class end; ' +
      'implementation procedure Use(AWorker: TWorker); begin end; end.',
      nil
    );
    LSymbolId := FIndex.FindSymbols('TWorker')[0].SymbolId;
    FIndex.SaveCache(LCacheFile);
    LRestored := TRadIASemanticIndex.Create;
    try
      Assert.IsTrue(LRestored.LoadCache(LCacheFile, LError), LError);
      Assert.AreEqual(
        NativeInt(2),
        Length(LRestored.FindReferences(LSymbolId, False, 100))
      );
    finally
      LRestored.Free;
    end;
  finally
    if TFile.Exists(LCacheFile) then
      TFile.Delete(LCacheFile);
  end;
end;

procedure TRadIASemanticIndexTests.FindsDfmClassAndEventReferences;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LEventId: string;
  LReference: TRadIASemanticReference;
  LReferences: TArray<TRadIASemanticReference>;
  LTypeId: string;
  LFoundEvent: Boolean;
  LFoundType: Boolean;
begin
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'main.pas',
    'Main.pas',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'unit Main; interface type TMainForm = class ' +
    'procedure SaveButtonClick(Sender: TObject); end; implementation ' +
    'procedure TMainForm.SaveButtonClick(Sender: TObject); begin end; end.',
    nil
  );
  LTypeId := FIndex.FindSymbols('TMainForm')[0].SymbolId;
  LEventId := FIndex.FindSymbols('SaveButtonClick')[0].SymbolId;
  LDescriptor := TRadIASemanticUnitDescriptor.Create(
    'main.dfm',
    'Main.dfm',
    susProject,
    1
  );
  FIndex.IndexUnit(
    LDescriptor,
    'object MainForm: TMainForm' + sLineBreak +
    '  object SaveButton: TButton' + sLineBreak +
    '    OnClick = SaveButtonClick' + sLineBreak +
    '  end' + sLineBreak + 'end',
    nil
  );
  LFoundType := False;
  LReferences := FIndex.FindReferences(LTypeId, False, 100);
  for LReference in LReferences do
    if SameText(LReference.FileName, 'Main.dfm') and
      (LReference.Kind = srkExact) then
      LFoundType := True;
  LFoundEvent := False;
  LReferences := FIndex.FindReferences(LEventId, False, 100);
  for LReference in LReferences do
    if SameText(LReference.FileName, 'Main.dfm') and
      (LReference.Line = 3) and (LReference.Column = 15) and
      (LReference.Kind = srkExact) then
      LFoundEvent := True;
  Assert.IsTrue(LFoundType, 'The DFM class reference was not resolved.');
  Assert.IsTrue(LFoundEvent, 'The DFM event reference was not resolved.');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticIndexTests);

end.
