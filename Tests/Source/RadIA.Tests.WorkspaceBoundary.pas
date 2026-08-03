unit RadIA.Tests.WorkspaceBoundary;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.WorkspaceBoundary;

type
  [TestFixture]
  TTestRadIAWorkspaceBoundary = class
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FWorkspaceRoot: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure RelativePathInsideWorkspaceIsAccepted;
    [Test]
    procedure ParentTraversalIsRejected;
    [Test]
    procedure AbsolutePathOutsideWorkspaceIsRejected;
    [Test]
    procedure VolumeRootIsRejected;
    [Test]
    procedure EmptyCandidateIsRejected;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils;

procedure TTestRadIAWorkspaceBoundary.AbsolutePathOutsideWorkspaceIsRejected;
var
  LResult: TRadIAPathValidation;
begin
  LResult := FBoundary.ValidatePath(
    FWorkspaceRoot,
    TPath.Combine(TPath.GetTempPath, 'outside.pas')
  );

  Assert.IsFalse(LResult.Allowed);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
end;

procedure TTestRadIAWorkspaceBoundary.EmptyCandidateIsRejected;
var
  LResult: TRadIAPathValidation;
begin
  LResult := FBoundary.ValidatePath(FWorkspaceRoot, '');

  Assert.IsFalse(LResult.Allowed);
  Assert.AreEqual('invalid_path', LResult.ErrorCode);
end;

procedure TTestRadIAWorkspaceBoundary.ParentTraversalIsRejected;
var
  LResult: TRadIAPathValidation;
begin
  LResult := FBoundary.ValidatePath(
    FWorkspaceRoot,
    '..\outside.pas'
  );

  Assert.IsFalse(LResult.Allowed);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
end;

procedure TTestRadIAWorkspaceBoundary.RelativePathInsideWorkspaceIsAccepted;
var
  LExpectedPath: string;
  LResult: TRadIAPathValidation;
begin
  LExpectedPath := TPath.GetFullPath(
    TPath.Combine(FWorkspaceRoot, 'Source\UnitOne.pas')
  );
  LResult := FBoundary.ValidatePath(
    FWorkspaceRoot,
    'Source\UnitOne.pas'
  );

  Assert.IsTrue(LResult.Allowed);
  Assert.AreEqual(LExpectedPath, LResult.ResolvedPath);
end;

procedure TTestRadIAWorkspaceBoundary.Setup;
begin
  FWorkspaceRoot := TPath.Combine(
    TPath.GetTempPath,
    'RadIAWorkspaceBoundary-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FWorkspaceRoot);
  FBoundary := TRadIAWorkspaceBoundary.Create;
end;

procedure TTestRadIAWorkspaceBoundary.TearDown;
begin
  FBoundary := nil;
  if TDirectory.Exists(FWorkspaceRoot) then
    TDirectory.Delete(FWorkspaceRoot, True);
end;

procedure TTestRadIAWorkspaceBoundary.VolumeRootIsRejected;
var
  LResult: TRadIAPathValidation;
  LVolumeRoot: string;
begin
  LVolumeRoot := TPath.GetPathRoot(FWorkspaceRoot);
  LResult := FBoundary.ValidatePath(LVolumeRoot, 'Windows');

  Assert.IsFalse(LResult.Allowed);
  Assert.AreEqual('invalid_workspace_root', LResult.ErrorCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAWorkspaceBoundary);

end.
