unit RadIA.Tests.CodeValidation;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Patches,
  RadIA.Core.Workspace;

type
  TRadIACodeValidationMutationStub = class(
    TInterfacedObject,
    IRadIAEditorMutationFacade
  )
  private
    FContent: string;
    FFileName: string;
  public
    constructor Create(const AFileName: string; const AContent: string);
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
    function ReadContent(
      const AFileName: string;
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
  end;

  TRadIACodeValidationPatchStub = class(TInterfacedObject, IRadIAPatchService)
  public
    function Apply(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
    function Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
  end;

  [TestFixture]
  TRadIACodeValidationTests = class
  public
    [Test]
    procedure ParsesDelphiLintIssues;
    [Test]
    procedure ParsesSonarIssuesAndComponentPaths;
    [Test]
    procedure NormalizesCompilerMessages;
    [Test]
    procedure RejectsInvalidExternalResponses;
    [Test]
    procedure DiscoversSonarConfiguration;
    [Test]
    procedure EncodesAndDecodesDelphiLintProtocol;
    [Test]
    procedure PreparesDelphiLintQuickFix;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.CodeValidation,
  RadIA.Core.CodeValidationFixes,
  RadIA.Core.DelphiLintAdapter;

constructor TRadIACodeValidationMutationStub.Create(
  const AFileName: string;
  const AContent: string
);
begin
  inherited Create;
  FFileName := AFileName;
  FContent := AContent;
end;

function TRadIACodeValidationMutationStub.ApplyContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
begin
  FContent := ANewContent;
  AAppliedRevision := 'applied';
  Result := SameText(AFileName, FFileName) and not AExpectedRevision.IsEmpty;
end;

function TRadIACodeValidationMutationStub.ReadContent(
  const AFileName: string;
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := TRadIAEditorContent.Create(
    'Main',
    AFileName,
    FContent,
    'revision-1',
    Length(FContent),
    Length(FContent) > AMaxCharacters
  );
end;

function TRadIACodeValidationPatchStub.Apply(
  const APreviewId: string
): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('not-used', APreviewId);
end;

procedure TRadIACodeValidationPatchStub.Clear;
begin
  // No retained previews are needed by this deterministic test double.
end;

function TRadIACodeValidationPatchStub.Prepare(
  const ASpec: TRadIAPatchSpec
): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    'preview-1',
    ASpec,
    ASpec.OriginalText,
    ASpec.ReplacementText,
    'revision-2',
    Now + 1
  ));
end;

function TRadIACodeValidationPatchStub.Revert(
  const APreviewId: string
): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('not-used', APreviewId);
end;

procedure TRadIACodeValidationTests.NormalizesCompilerMessages;
var
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  LFindings := TRadIACodeValidationParser.FromCompilerMessages([
    TRadIACompilerMessage.Create(
      cmsError,
      'E2003 Undeclared identifier',
      'Main.pas',
      14,
      3
    )
  ]);
  Assert.AreEqual(1, Length(LFindings));
  Assert.AreEqual('compiler', RadIAValidationSourceName(LFindings[0].Source));
  Assert.AreEqual('error', RadIAValidationSeverityName(LFindings[0].Severity));
  Assert.AreEqual(14, LFindings[0].Line);
end;

procedure TRadIACodeValidationTests.EncodesAndDecodesDelphiLintProtocol;
var
  LCategory: Byte;
  LHeader: TBytes;
  LId: Integer;
  LLength: Integer;
  LMessage: TBytes;
begin
  LMessage := TRadIADelphiLintProtocol.BuildMessage(30, 42, '{"unit":"Main"}');
  LHeader := Copy(LMessage, 0, 9);
  Assert.IsTrue(TRadIADelphiLintProtocol.DecodeHeader(
    LHeader,
    LCategory,
    LId,
    LLength
  ));
  Assert.AreEqual(30, Integer(LCategory));
  Assert.AreEqual(42, LId);
  Assert.AreEqual(Length(LMessage) - 9, LLength);
  Assert.AreEqual('{"unit":"Main"}', TEncoding.UTF8.GetString(
    Copy(LMessage, 9, LLength)
  ));
end;

procedure TRadIACodeValidationTests.DiscoversSonarConfiguration;
var
  LKey: string;
  LRootPath: string;
  LUrl: string;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIASonarConfiguration-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(TPath.Combine(LRootPath, '.scannerwork'));
  try
    TFile.WriteAllText(
      TPath.Combine(LRootPath, 'sonar-project.properties'),
      '# project' + sLineBreak + 'sonar.projectKey = sample-key',
      TEncoding.UTF8
    );
    TFile.WriteAllText(
      TPath.Combine(LRootPath, '.scannerwork\report-task.txt'),
      'serverUrl=http://localhost:9000',
      TEncoding.UTF8
    );
    TRadIASonarConfiguration.Resolve(
      LRootPath,
      'https://sonar.example.test/',
      '',
      LUrl,
      LKey
    );
    Assert.AreEqual('https://sonar.example.test', LUrl);
    Assert.AreEqual('sample-key', LKey);
  finally
    TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TRadIACodeValidationTests.ParsesDelphiLintIssues;
var
  LError: string;
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  Assert.IsTrue(TRadIACodeValidationParser.ParseDelphiLint(
    '{"issues":[{"ruleKey":"DelphiLint:LongRoutine",' +
    '"message":"Routine is too long","file":"Main.pas",' +
    '"range":{"startLine":12,"startOffset":4}}]}',
    LFindings,
    LError
  ), LError);
  Assert.AreEqual(1, Length(LFindings));
  Assert.AreEqual('DelphiLint:LongRoutine', LFindings[0].Rule);
  Assert.AreEqual(12, LFindings[0].Line);
  Assert.AreEqual(5, LFindings[0].Column);
end;

procedure TRadIACodeValidationTests.PreparesDelphiLintQuickFix;
var
  LContent: string;
  LFileName: string;
  LFixes: TJSONArray;
  LMutation: IRadIAEditorMutationFacade;
  LResult: TRadIAPatchResult;
  LRootPath: string;
  LService: IRadIACodeValidationFixService;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIADelphiLintFix-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LRootPath);
  LFileName := TPath.Combine(LRootPath, 'Main.pas');
  LContent := 'unit Main;' + sLineBreak + 'foo' + sLineBreak + 'end.';
  TFile.WriteAllText(LFileName, LContent);
  try
    LMutation := TRadIACodeValidationMutationStub.Create(LFileName, LContent);
    LService := CreateRadIACodeValidationFixService(
      LMutation,
      TRadIACodeValidationPatchStub.Create
    );
    LFixes := TJSONArray.Create;
    try
      LService.CaptureDelphiLintFixes(
        '{"issues":[{"file":"Main.pas","quickFixes":[{' +
          '"message":"Replace foo","textEdits":[{' +
          '"replacement":"bar","range":{"startLine":2,' +
          '"startOffset":0,"endLine":2,"endOffset":3}}]}]}]}',
        LRootPath,
        LFixes
      );
      Assert.AreEqual(1, LFixes.Count);
      LResult := LService.Prepare(
        TJSONObject(LFixes[0]).GetValue<string>('fixId')
      );
      Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
      Assert.Contains(LResult.Preview.ProposedContent, 'bar');
      Assert.DoesNotContain(LResult.Preview.ProposedContent, 'foo');
    finally
      LFixes.Free;
    end;
  finally
    TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TRadIACodeValidationTests.ParsesSonarIssuesAndComponentPaths;
var
  LError: string;
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  Assert.IsTrue(TRadIACodeValidationParser.ParseSonar(
    '{"issues":[{"rule":"community-delphi:EmptyRoutine",' +
    '"severity":"CRITICAL","component":"radia:Main.pas",' +
    '"line":22,"message":"Remove this empty routine.",' +
    '"textRange":{"startOffset":2}}],"components":[' +
    '{"key":"radia:Main.pas","path":"Source/Main.pas"}]}',
    LFindings,
    LError
  ), LError);
  Assert.AreEqual(1, Length(LFindings));
  Assert.AreEqual('Source/Main.pas', LFindings[0].FileName);
  Assert.AreEqual('error', RadIAValidationSeverityName(LFindings[0].Severity));
  Assert.AreEqual(3, LFindings[0].Column);
end;

procedure TRadIACodeValidationTests.RejectsInvalidExternalResponses;
var
  LError: string;
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  Assert.IsFalse(TRadIACodeValidationParser.ParseDelphiLint(
    '{}',
    LFindings,
    LError
  ));
  Assert.Contains(LError, 'issues');
  Assert.IsFalse(TRadIACodeValidationParser.ParseSonar(
    '[]',
    LFindings,
    LError
  ));
  Assert.Contains(LError, 'object');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIACodeValidationTests);

end.
