unit RadIA.Tests.FastMM5;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAFastMM5 = class
  private
    FRootPath: string;
    procedure CreateFastMMTree(const AIncludeVersion: Boolean);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PersistsSettings;
    [Test]
    procedure DetectsReadyWin32Installation;
    [Test]
    procedure RequiresLicenseAcknowledgement;
    [Test]
    procedure RejectsMissingRuntimeLibrary;
    [Test]
    procedure DetectsReadyWin64Installation;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.FastMM5,
  RadIA.Core.MemoryDiagnostics,
  RadIA.Core.SettingsStorage;

procedure TTestRadIAFastMM5.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    TPath.GetRandomFileName
  );
  TDirectory.CreateDirectory(FRootPath);
end;

procedure TTestRadIAFastMM5.TearDown;
begin
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TTestRadIAFastMM5.CreateFastMMTree(
  const AIncludeVersion: Boolean
);
var
  LContent: string;
  LRuntimePath: string;
begin
  if AIncludeVersion then
    LContent := 'const CFastMM_Version = 507;'
  else
    LContent := 'unit FastMM5;';
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'FastMM5.pas'),
    LContent
  );
  LRuntimePath := TPath.Combine(
    FRootPath,
    'FullDebugMode DLL\Precompiled'
  );
  TDirectory.CreateDirectory(LRuntimePath);
  TFile.WriteAllText(
    TPath.Combine(LRuntimePath, 'FastMM_FullDebugMode.dll'),
    'test'
  );
  TFile.WriteAllText(
    TPath.Combine(LRuntimePath, 'FastMM_FullDebugMode64.dll'),
    'test'
  );
end;

procedure TTestRadIAFastMM5.PersistsSettings;
var
  LLoaded: TRadIAFastMM5Settings;
  LSettings: TRadIAFastMM5Settings;
  LStorage: IRadIASettingsStorage;
  LStore: TRadIAFastMM5SettingsStore;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LStore := TRadIAFastMM5SettingsStore.Create(
    LStorage,
    'Test\MemoryDiagnostics'
  );
  try
    LSettings := TRadIAFastMM5Settings.Create(
      FRootPath,
      True,
      TRadIAMemoryDiagnosticsLimits.Create(60000, 1048576, 3)
    );
    LStore.Save(LSettings);
    LLoaded := LStore.Load;
    Assert.AreEqual(FRootPath, LLoaded.RootPath);
    Assert.IsTrue(LLoaded.LicenseAcknowledged);
    Assert.AreEqual(60000, LLoaded.Limits.MaxDurationMs);
    Assert.AreEqual(Int64(1048576), LLoaded.Limits.MaxLogBytes);
    Assert.AreEqual(3, LLoaded.Limits.MaxRepetitions);
  finally
    LStore.Free;
  end;
end;

procedure TTestRadIAFastMM5.DetectsReadyWin32Installation;
var
  LDetector: TRadIAFastMM5Detector;
  LStatus: TRadIAMemoryBackendStatus;
begin
  CreateFastMMTree(True);
  LDetector := TRadIAFastMM5Detector.Create;
  try
    LStatus := LDetector.Detect(
      TRadIAFastMM5Settings.Create(
        FRootPath,
        True,
        TRadIAMemoryDiagnosticsLimits.Create(60000, 1048576, 3)
      ),
      'Win32'
    );
    Assert.IsTrue(LStatus.IsReady);
    Assert.AreEqual('5.07', LStatus.BackendVersion);
  finally
    LDetector.Free;
  end;
end;

procedure TTestRadIAFastMM5.RequiresLicenseAcknowledgement;
var
  LDetector: TRadIAFastMM5Detector;
  LStatus: TRadIAMemoryBackendStatus;
begin
  CreateFastMMTree(True);
  LDetector := TRadIAFastMM5Detector.Create;
  try
    LStatus := LDetector.Detect(
      TRadIAFastMM5Settings.Create(
        FRootPath,
        False,
        TRadIAMemoryDiagnosticsLimits.Create(60000, 1048576, 3)
      ),
      'Win32'
    );
    Assert.AreEqual(Ord(mbsInvalid), Ord(LStatus.State));
  finally
    LDetector.Free;
  end;
end;

procedure TTestRadIAFastMM5.RejectsMissingRuntimeLibrary;
var
  LDetector: TRadIAFastMM5Detector;
  LStatus: TRadIAMemoryBackendStatus;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'FastMM5.pas'),
    'const CFastMM_Version = 507;'
  );
  LDetector := TRadIAFastMM5Detector.Create;
  try
    LStatus := LDetector.Detect(
      TRadIAFastMM5Settings.Create(
        FRootPath,
        True,
        TRadIAMemoryDiagnosticsLimits.Create(60000, 1048576, 3)
      ),
      'Win32'
    );
    Assert.AreEqual(Ord(mbsInvalid), Ord(LStatus.State));
  finally
    LDetector.Free;
  end;
end;

procedure TTestRadIAFastMM5.DetectsReadyWin64Installation;
var
  LDetector: TRadIAFastMM5Detector;
  LStatus: TRadIAMemoryBackendStatus;
begin
  CreateFastMMTree(True);
  LDetector := TRadIAFastMM5Detector.Create;
  try
    LStatus := LDetector.Detect(
      TRadIAFastMM5Settings.Create(
        FRootPath,
        True,
        TRadIAMemoryDiagnosticsLimits.Create(60000, 1048576, 3)
      ),
      'Win64'
    );
    Assert.IsTrue(LStatus.IsReady);
    Assert.IsTrue(LStatus.DebugLibraryPath.EndsWith('64.dll'));
  finally
    LDetector.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAFastMM5);

end.
