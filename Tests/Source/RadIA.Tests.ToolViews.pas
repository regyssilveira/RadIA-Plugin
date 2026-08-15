unit RadIA.Tests.ToolViews;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAToolViewTests = class
  public
    [Test]
    procedure ResolvesEveryViewCategory;
    [Test]
    procedure AttachesViewToSuccessfulObject;
    [Test]
    procedure PreservesExistingViewContract;
    [Test]
    procedure LeavesFailuresAndNonObjectsUnchanged;
  end;

implementation

uses
  RadIA.Core.Tools,
  RadIA.Core.ToolViews;

procedure TRadIAToolViewTests.AttachesViewToSuccessfulObject;
var
  LResolver: IRadIAToolViewResolver;
  LResult: TRadIAToolResult;
begin
  LResolver := TRadIAToolViewResolver.Create;
  LResult := LResolver.Attach(
    'PreparePatch',
    TRadIAToolResult.Succeeded('{"previewId":"123"}', True)
  );
  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(LResult.Truncated);
  Assert.Contains(LResult.ContentJson, '"_radiaView"');
  Assert.Contains(LResult.ContentJson, '"_radiaProblems":[]');
  Assert.Contains(LResult.ContentJson, '"kind":"diff"');
  Assert.Contains(LResult.ContentJson, '"sourceTool":"PreparePatch"');
end;

procedure TRadIAToolViewTests.LeavesFailuresAndNonObjectsUnchanged;
var
  LResolver: IRadIAToolViewResolver;
  LResult: TRadIAToolResult;
begin
  LResolver := TRadIAToolViewResolver.Create;
  LResult := LResolver.Attach(
    'SampleTool',
    TRadIAToolResult.Failed('failed', 'Failure.')
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('failed', LResult.ErrorCode);

  LResult := LResolver.Attach(
    'SampleTool',
    TRadIAToolResult.Succeeded('[]')
  );
  Assert.AreEqual('[]', LResult.ContentJson);
end;

procedure TRadIAToolViewTests.PreservesExistingViewContract;
var
  LResolver: IRadIAToolViewResolver;
  LResult: TRadIAToolResult;
begin
  LResolver := TRadIAToolViewResolver.Create;
  LResult := LResolver.Attach(
    'SampleTool',
    TRadIAToolResult.Succeeded(
      '{"_radiaView":{"version":2,"kind":"custom"},' +
      '"_radiaProblems":[{"id":"untrusted"}]}'
    )
  );
  Assert.Contains(LResult.ContentJson, '"version":2');
  Assert.Contains(LResult.ContentJson, '"kind":"custom"');
  Assert.Contains(LResult.ContentJson, '"_radiaProblems":[]');
  Assert.DoesNotContain(LResult.ContentJson, 'untrusted');
end;

procedure TRadIAToolViewTests.ResolvesEveryViewCategory;
var
  LResolver: IRadIAToolViewResolver;
begin
  LResolver := TRadIAToolViewResolver.Create;
  Assert.AreEqual(
    tvkEditorNavigation,
    LResolver.Resolve('NavigateToFile').Kind
  );
  Assert.AreEqual(tvkDiff, LResolver.Resolve('PreparePatch').Kind);
  Assert.AreEqual(
    tvkActivity,
    LResolver.Resolve('RunDUnitXTests').Kind
  );
  Assert.AreEqual(
    tvkExplorer,
    LResolver.Resolve('GetProjectDependencies').Kind
  );
  Assert.AreEqual(tvkDetails, LResolver.Resolve('GetGitStatus').Kind);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAToolViewTests);

end.
