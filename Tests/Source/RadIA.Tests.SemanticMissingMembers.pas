unit RadIA.Tests.SemanticMissingMembers;

interface

implementation

uses
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Semantic.Index,
  RadIA.Semantic.MissingMembers;

type
  [TestFixture]
  TRadIASemanticMissingMemberTests = class
  public
    [Test]
    procedure GeneratesDeclarationsAndImplementations;
    [Test]
    procedure ProducesNoChangeAfterMembersExist;
  end;

const
  CContractSource =
    'unit Contracts; interface type IWorker = interface ' +
    'procedure Execute(const AValue: Integer); ' +
    'function Ready: Boolean; end; implementation end.';
  CWorkerSource =
    'unit Worker;' + sLineBreak +
    'interface' + sLineBreak +
    'uses Contracts;' + sLineBreak +
    'type' + sLineBreak +
    '  TWorker = class(TObject, IWorker)' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';

procedure IndexSources(
  const AIndex: TRadIASemanticIndex;
  const AWorkerSource: string
);
begin
  AIndex.IndexUnit(
    TRadIASemanticUnitDescriptor.Create('contracts', '', susGroup, 1),
    CContractSource,
    nil
  );
  AIndex.IndexUnit(
    TRadIASemanticUnitDescriptor.Create('worker', '', susProject, 1),
    AWorkerSource,
    nil
  );
end;

procedure TRadIASemanticMissingMemberTests.
  GeneratesDeclarationsAndImplementations;
var
  LIndex: TRadIASemanticIndex;
  LPreview: TRadIASemanticMissingMemberPreview;
begin
  LIndex := TRadIASemanticIndex.Create;
  try
    IndexSources(LIndex, CWorkerSource);
    LPreview := TRadIASemanticMissingMemberGenerator.Generate(
      CWorkerSource,
      'TWorker',
      LIndex.FindMissingMembers('TWorker'),
      nil
    );
    Assert.IsTrue(LPreview.Changed, LPreview.ErrorMessage);
    Assert.AreEqual(2, LPreview.MissingCount);
    Assert.Contains(
      LPreview.ProposedSource,
      'procedure Execute(const AValue: Integer);'
    );
    Assert.Contains(
      LPreview.ProposedSource,
      'procedure TWorker.Execute(const AValue: Integer);'
    );
    Assert.Contains(LPreview.ProposedSource, 'function TWorker.Ready: Boolean;');
  finally
    LIndex.Free;
  end;
end;

procedure TRadIASemanticMissingMemberTests.ProducesNoChangeAfterMembersExist;
var
  LIndex: TRadIASemanticIndex;
  LPreview: TRadIASemanticMissingMemberPreview;
begin
  LIndex := TRadIASemanticIndex.Create;
  try
    IndexSources(
      LIndex,
      StringReplace(
        CWorkerSource,
        '  end;',
        '    procedure Execute(const AValue: Integer);' + sLineBreak +
        '    function Ready: Boolean;' + sLineBreak +
        '  end;',
        []
      )
    );
    LPreview := TRadIASemanticMissingMemberGenerator.Generate(
      CWorkerSource,
      'TWorker',
      LIndex.FindMissingMembers('TWorker'),
      nil
    );
    Assert.IsFalse(LPreview.Changed);
    Assert.AreEqual(0, LPreview.MissingCount);
  finally
    LIndex.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticMissingMemberTests);

end.
