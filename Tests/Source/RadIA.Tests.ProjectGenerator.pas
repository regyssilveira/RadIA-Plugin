unit RadIA.Tests.ProjectGenerator;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces;

type
  [TestFixture]
  TTestRadIAProjectGenerator = class
  private
    FTempDir: string;
    FGenerator: IRadIAProjectGenerator;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestGenerateProjectSuccess;
    [Test]
    procedure TestGenerateProjectEmptyJSON;
    [Test]
    procedure TestGenerateProjectRollbackOnError;
    [Test]
    procedure TestRejectsPathTraversal;
    [Test]
    procedure TestRejectsDuplicatePaths;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, RadIA.Core.ProjectGenerator;

{ TTestRadIAProjectGenerator }

procedure TTestRadIAProjectGenerator.Setup;
begin
  // Create a unique temporary directory for each test execution
  FTempDir := TPath.Combine(TPath.GetTempPath, 'RadIATests_ProjGen_' + TGUID.NewGuid.ToString);
  FGenerator := TRadIAProjectGenerator.Create;
end;

procedure TTestRadIAProjectGenerator.TearDown;
begin
  FGenerator := nil;
  // Recursively clean up the temporary directory if it exists
  if TDirectory.Exists(FTempDir) then
  begin
    try
      TDirectory.Delete(FTempDir, True);
    except
      // Suppress deletion errors on teardown to prevent blocking other tests
    end;
  end;
end;

procedure TTestRadIAProjectGenerator.TestGenerateProjectSuccess;
var
  LJson: TJSONArray;
  LFile1, LFile2: TJSONObject;
  LJsonStr: string;
  LErrorMsg: string;
  LSuccess: Boolean;
  LWrittenFile1: string;
  LWrittenFile2: string;
begin
  LJson := TJSONArray.Create;
  try
    LFile1 := TJSONObject.Create;
    LFile1.AddPair('path', 'MyProject.dpr');
    LFile1.AddPair('content', 'program MyProject;' + sLineBreak + 'begin' + sLineBreak + 'end.');
    LJson.AddElement(LFile1);

    LFile2 := TJSONObject.Create;
    LFile2.AddPair('path', 'src\uMain.pas');
    LFile2.AddPair('content', 'unit uMain;' + sLineBreak + 'interface' + sLineBreak + 'implementatio' +
        'n' + sLineBreak + 'end.');
    LJson.AddElement(LFile2);

    LJsonStr := LJson.ToJSON;
  finally
    LJson.Free;
  end;

  LSuccess := FGenerator.GenerateFromJSON(LJsonStr, LErrorMsg, FTempDir);

  Assert.IsTrue(LSuccess, 'Project generation should succeed. Error: ' + LErrorMsg);
  Assert.IsEmpty(LErrorMsg, 'Error message should be empty on success');

  LWrittenFile1 := TPath.Combine(FTempDir, 'MyProject.dpr');
  LWrittenFile2 := TPath.Combine(TPath.Combine(FTempDir, 'src'), 'uMain.pas');

  Assert.IsTrue(TFile.Exists(LWrittenFile1), 'MyProject.dpr was not physically created');
  Assert.IsTrue(TFile.Exists(LWrittenFile2), 'uMain.pas was not physically created');

  Assert.AreEqual('program MyProject;' + sLineBreak + 'begin' + sLineBreak + 'end.', TFile.ReadAllText(LWrittenFile1),
      'Content mismatch in file 1');
  Assert.AreEqual('unit uMain;' + sLineBreak + 'interface' + sLineBreak + 'implementation' + sLineBreak + 'end.',
      TFile.ReadAllText(LWrittenFile2), 'Content mismatch in file 2');
end;

procedure TTestRadIAProjectGenerator.TestGenerateProjectEmptyJSON;
var
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  LSuccess := FGenerator.GenerateFromJSON('', LErrorMsg, FTempDir);
  Assert.IsFalse(LSuccess, 'Generation should fail for empty JSON string');
  Assert.IsNotEmpty(LErrorMsg, 'Error message should be provided for empty JSON');

  LSuccess := FGenerator.GenerateFromJSON('   ', LErrorMsg, FTempDir);
  Assert.IsFalse(LSuccess, 'Generation should fail for whitespace JSON string');

  LSuccess := FGenerator.GenerateFromJSON('[]', LErrorMsg, FTempDir);
  Assert.IsFalse(LSuccess, 'Generation should fail for empty JSON array');
end;

procedure TTestRadIAProjectGenerator.TestGenerateProjectRollbackOnError;
var
  LJson: TJSONArray;
  LFile1, LFile2: TJSONObject;
  LJsonStr: string;
  LErrorMsg: string;
  LSuccess: Boolean;
  LWrittenFile1: string;
begin
  LJson := TJSONArray.Create;
  try
    // File 1 is valid and should be written first
    LFile1 := TJSONObject.Create;
    LFile1.AddPair('path', 'FirstValidFile.pas');
    LFile1.AddPair('content', 'unit FirstValidFile;');
    LJson.AddElement(LFile1);

    // File 2 is invalid (contains invalid character '|' on Windows path) to trigger an exception
    LFile2 := TJSONObject.Create;
    LFile2.AddPair('path', 'Invalid|File.pas');
    LFile2.AddPair('content', 'unit InvalidFile;');
    LJson.AddElement(LFile2);

    LJsonStr := LJson.ToJSON;
  finally
    LJson.Free;
  end;

  LSuccess := FGenerator.GenerateFromJSON(LJsonStr, LErrorMsg, FTempDir);

  Assert.IsFalse(LSuccess, 'Project generation should fail due to invalid file path');
  Assert.IsNotEmpty(LErrorMsg, 'Error message should be captured during exception');

  LWrittenFile1 := TPath.Combine(FTempDir, 'FirstValidFile.pas');
  Assert.IsFalse(TFile.Exists(LWrittenFile1), 'Rollback failed: FirstValidFile.pas should have been ' +
      'cleaned up and deleted');
end;

procedure TTestRadIAProjectGenerator.TestRejectsDuplicatePaths;
var
  LErrorMsg: string;
  LJson: string;
begin
  LJson :=
    '[{"path":"UnitOne.pas","content":"unit UnitOne; end."},' +
    '{"path":"UnitOne.pas","content":"unit UnitOne; end."}]';

  Assert.IsFalse(
    FGenerator.GenerateFromJSON(LJson, LErrorMsg, FTempDir)
  );
  Assert.Contains(LErrorMsg, 'duplicate file path');
  Assert.IsFalse(TFile.Exists(TPath.Combine(FTempDir, 'UnitOne.pas')));
end;

procedure TTestRadIAProjectGenerator.TestRejectsPathTraversal;
var
  LErrorMsg: string;
  LEscapedFile: string;
  LJson: string;
begin
  LEscapedFile := TPath.GetFullPath(
    TPath.Combine(FTempDir, '..\escaped-radia-test.pas')
  );
  if TFile.Exists(LEscapedFile) then
    TFile.Delete(LEscapedFile);
  LJson :=
    '[{"path":"..\\escaped-radia-test.pas",' +
    '"content":"unit Escaped; end."}]';

  Assert.IsFalse(
    FGenerator.GenerateFromJSON(LJson, LErrorMsg, FTempDir)
  );
  Assert.Contains(LErrorMsg, 'escapes the destination folder');
  Assert.IsFalse(TFile.Exists(LEscapedFile));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAProjectGenerator);

end.
