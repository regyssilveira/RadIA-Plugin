unit RadIA.Tests.DelphiMentor;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADelphiMentorTests = class
  public
    [Test]
    procedure AdaptsExplanationToThreeProfiles;
    [Test]
    procedure DetectsOwnershipVclDfmAndPackageTopics;
    [Test]
    procedure RejectsEmptyAndOversizedSelections;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DelphiGuidance,
  RadIA.Core.DelphiMentor;

procedure TRadIADelphiMentorTests.AdaptsExplanationToThreeProfiles;
var
  LCatalog: IRadIADelphiGuidanceCatalog;
  LExperienced: TRadIADelphiMentorLesson;
  LMentor: TRadIADelphiMentor;
begin
  LCatalog := TRadIADelphiGuidanceCatalog.Create;
  LMentor := TRadIADelphiMentor.Create(LCatalog);
  try
    Assert.Contains(LMentor.BuildLesson(dmpBeginner, 'begin end.', 'Delphi 13').ExplanationTemplate,
      'syntax first');
    Assert.Contains(LMentor.BuildLesson(dmpCrossLanguage, 'begin end.', 'Delphi 13').ExplanationTemplate,
      'managed-language');
    LExperienced := LMentor.BuildLesson(dmpExperienced, 'begin end.', 'Delphi 13');
    Assert.Contains(LExperienced.ExplanationTemplate, 'compiler constraints');
    Assert.IsTrue(Length(LExperienced.Rules) > 0);
  finally
    LMentor.Free;
  end;
end;

procedure TRadIADelphiMentorTests.DetectsOwnershipVclDfmAndPackageTopics;
var
  LCatalog: IRadIADelphiGuidanceCatalog;
  LLesson: TRadIADelphiMentorLesson;
  LMentor: TRadIADelphiMentor;
  LTopics: string;
begin
  LCatalog := TRadIADelphiGuidanceCatalog.Create;
  LMentor := TRadIADelphiMentor.Create(LCatalog);
  try
    LLesson := LMentor.BuildLesson(
      dmpBeginner,
      'package Demo; requires rtl; contains Vcl.Forms; {$R *.dfm} TObject.Create.Free;',
      'Delphi 13'
    );
    LTopics := string.Join(',', LLesson.Topics);
    Assert.AreEqual('VCL', LLesson.Framework);
    Assert.Contains(LTopics, 'ownership');
    Assert.Contains(LTopics, 'form-resource');
    Assert.Contains(LTopics, 'package');
    Assert.Contains(LTopics, 'vcl');
  finally
    LMentor.Free;
  end;
end;

procedure TRadIADelphiMentorTests.RejectsEmptyAndOversizedSelections;
var
  LCatalog: IRadIADelphiGuidanceCatalog;
  LMentor: TRadIADelphiMentor;
begin
  LCatalog := TRadIADelphiGuidanceCatalog.Create;
  LMentor := TRadIADelphiMentor.Create(LCatalog);
  try
    Assert.WillRaise(
      procedure
      begin
        LMentor.BuildLesson(dmpBeginner, '', 'Delphi 13');
      end,
      EArgumentException
    );
    Assert.WillRaise(
      procedure
      begin
        LMentor.BuildLesson(dmpBeginner, StringOfChar('x', 12001), 'Delphi 13');
      end,
      EArgumentOutOfRangeException
    );
  finally
    LMentor.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADelphiMentorTests);

end.
