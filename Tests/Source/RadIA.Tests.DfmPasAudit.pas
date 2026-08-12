unit RadIA.Tests.DfmPasAudit;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.DfmPasAudit;

type
  [TestFixture]
  TTestRadIADfmPasAudit = class
  private
    FAuditor: IRadIADfmPasAuditor;
    function Audit(
      const ADfm: string;
      const APas: string
    ): TRadIADfmPasAuditResult;
    function ContainsCode(
      const AResult: TRadIADfmPasAuditResult;
      const ACode: string
    ): Boolean;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure AcceptsConsistentForm;
    [Test]
    procedure DetectsMissingAndIncompatibleHandlers;
    [Test]
    procedure DetectsComponentAndRootMismatches;
    [Test]
    procedure DetectsOrphanComponentField;
    [Test]
    procedure DetectsOrphanEventHandler;
    [Test]
    procedure ReportsStableLocations;
  end;

implementation

uses
  System.SysUtils;

const
  CValidDfm =
    'object MainForm: TMainForm' + sLineBreak +
    '  object SaveButton: TButton' + sLineBreak +
    '    OnClick = SaveButtonClick' + sLineBreak +
    '  end' + sLineBreak +
    'end';
  CValidPas =
    'unit Main;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TMainForm = class(TForm)' + sLineBreak +
    '    SaveButton: TButton;' + sLineBreak +
    '    procedure SaveButtonClick(Sender: TObject);' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TMainForm.SaveButtonClick(Sender: TObject);' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'end.';

function TTestRadIADfmPasAudit.Audit(
  const ADfm: string;
  const APas: string
): TRadIADfmPasAuditResult;
begin
  Result := FAuditor.Audit(
    TRadIADfmPasAuditInput.Create(
      'Main.dfm',
      ADfm,
      'Main.pas',
      APas
    )
  );
end;

procedure TTestRadIADfmPasAudit.AcceptsConsistentForm;
var
  LResult: TRadIADfmPasAuditResult;
begin
  LResult := Audit(CValidDfm, CValidPas);
  Assert.AreEqual<Integer>(0, Length(LResult.Findings));
end;

function TTestRadIADfmPasAudit.ContainsCode(
  const AResult: TRadIADfmPasAuditResult;
  const ACode: string
): Boolean;
var
  LFinding: TRadIADfmPasFinding;
begin
  for LFinding in AResult.Findings do
    if SameText(LFinding.Code, ACode) then
      Exit(True);
  Result := False;
end;

procedure TTestRadIADfmPasAudit.DetectsComponentAndRootMismatches;
var
  LDfm: string;
  LPas: string;
  LResult: TRadIADfmPasAuditResult;
begin
  LDfm := StringReplace(CValidDfm, 'TMainForm', 'TOtherForm', []);
  LPas := StringReplace(CValidPas, 'SaveButton: TButton',
    'SaveButton: TEdit', []);
  LResult := Audit(LDfm, LPas);
  Assert.IsTrue(ContainsCode(LResult, 'root_class_mismatch'));
  Assert.IsTrue(ContainsCode(LResult, 'component_class_mismatch'));
end;

procedure TTestRadIADfmPasAudit.DetectsMissingAndIncompatibleHandlers;
var
  LPas: string;
  LResult: TRadIADfmPasAuditResult;
begin
  LPas := StringReplace(CValidPas, 'SaveButtonClick(Sender: TObject)',
    'SaveButtonClick', [rfReplaceAll]);
  LResult := Audit(CValidDfm, LPas);
  Assert.IsTrue(ContainsCode(LResult, 'missing_event_handler'));

  LPas := StringReplace(CValidPas, 'Sender: TObject',
    'Sender: TComponent', [rfReplaceAll]);
  LResult := Audit(CValidDfm, LPas);
  Assert.IsTrue(ContainsCode(LResult, 'incompatible_event_handler'));
end;

procedure TTestRadIADfmPasAudit.DetectsOrphanComponentField;
var
  LPas: string;
  LResult: TRadIADfmPasAuditResult;
begin
  LPas := StringReplace(CValidPas, 'SaveButton: TButton;',
    'SaveButton: TButton;' + sLineBreak + '    OldLabel: TLabel;', []);
  LResult := Audit(CValidDfm, LPas);
  Assert.IsTrue(ContainsCode(LResult, 'orphan_component_field'));
end;

procedure TTestRadIADfmPasAudit.DetectsOrphanEventHandler;
var
  LDfm: string;
  LResult: TRadIADfmPasAuditResult;
begin
  LDfm := StringReplace(
    CValidDfm,
    '    OnClick = SaveButtonClick' + sLineBreak,
    '',
    []
  );
  LResult := Audit(LDfm, CValidPas);
  Assert.IsTrue(ContainsCode(LResult, 'orphan_event_handler'));
end;

procedure TTestRadIADfmPasAudit.ReportsStableLocations;
var
  LFinding: TRadIADfmPasFinding;
  LResult: TRadIADfmPasAuditResult;
begin
  LResult := Audit(
    StringReplace(CValidDfm, 'SaveButton: TButton',
      'MissingButton: TButton', []),
    CValidPas
  );
  for LFinding in LResult.Findings do
    if LFinding.Code = 'missing_component_field' then
    begin
      Assert.AreEqual(2, LFinding.Line);
      Assert.AreEqual('dfm', LFinding.FileKind);
      Exit;
    end;
  Assert.Fail('Expected missing_component_field finding.');
end;

procedure TTestRadIADfmPasAudit.Setup;
begin
  FAuditor := TRadIADfmPasAuditor.Create;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADfmPasAudit);

end.
