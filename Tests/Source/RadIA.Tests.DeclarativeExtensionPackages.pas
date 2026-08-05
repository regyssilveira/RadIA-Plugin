unit RadIA.Tests.DeclarativeExtensionPackages;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADeclarativeExtensionPackageTests = class
  private
    FDirectory: string;
    function CreatePackage(
      const AManifestContent: string;
      const ADeclaredManifestName: string;
      const ADeclaredHash: string;
      const AAddUnexpectedFile: Boolean
    ): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ReadsAndInstallsVerifiedPackage;
    [Test]
    procedure HashingMatchesStandardUtf8Sha256;
    [Test]
    procedure RejectsTamperedManifestHash;
    [Test]
    procedure RejectsUnsafeManifestPath;
    [Test]
    procedure RejectsUndeclaredArchiveEntry;
    [Test]
    procedure RejectsPackageIdentityMismatch;
    [Test]
    procedure RejectsCompressedOversizedEntry;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  System.Zip,
  RadIA.Core.DeclarativeExtensionPackages,
  RadIA.Core.DeclarativeExtensions;

const
  CPackageManifest =
    '{"schemaVersion":1,"id":"PackagedCommands","version":"1.2.0",' +
    '"enabled":true,"permissions":["chat.prompt"],"commands":[{' +
    '"name":"Package review","description":"Review from a verified package.",' +
    '"command":"/package-review","prompt":"Review package input: {code}"' +
    '}]}';

function TRadIADeclarativeExtensionPackageTests.CreatePackage(
  const AManifestContent: string;
  const ADeclaredManifestName: string;
  const ADeclaredHash: string;
  const AAddUnexpectedFile: Boolean
): string;
var
  LArchive: TZipFile;
  LFile: TJSONObject;
  LFiles: TJSONArray;
  LHash: string;
  LManifestBytes: TArray<Byte>;
  LManifestFileName: string;
  LMetadata: TJSONObject;
  LMetadataFileName: string;
  LUnexpectedFileName: string;
begin
  LManifestBytes := TEncoding.UTF8.GetBytes(AManifestContent);
  if ADeclaredHash = '' then
    LHash := THashSHA2.GetHashString(AManifestContent)
  else
    LHash := ADeclaredHash;
  LMetadata := TJSONObject.Create;
  try
    LMetadata.AddPair(
      'schemaVersion',
      TJSONNumber.Create(
        CRadIADeclarativeExtensionPackageSchemaVersion
      )
    );
    LMetadata.AddPair('id', 'PackagedCommands');
    LMetadata.AddPair('version', '1.2.0');
    LMetadata.AddPair('manifest', ADeclaredManifestName);
    LFiles := TJSONArray.Create;
    LFile := TJSONObject.Create;
    LFile.AddPair('path', ADeclaredManifestName);
    LFile.AddPair(
      'size',
      TJSONNumber.Create(Length(LManifestBytes))
    );
    LFile.AddPair('sha256', LowerCase(LHash));
    LFiles.AddElement(LFile);
    LMetadata.AddPair('files', LFiles);
    LMetadataFileName := TPath.Combine(FDirectory, 'package.json');
    TFile.WriteAllText(
      LMetadataFileName,
      LMetadata.ToJSON,
      TEncoding.UTF8
    );
  finally
    LMetadata.Free;
  end;
  LManifestFileName := TPath.Combine(
    FDirectory,
    'PackagedCommands.radia.json'
  );
  TFile.WriteAllBytes(LManifestFileName, LManifestBytes);
  Result := TPath.Combine(
    FDirectory,
    TGUID.NewGuid.ToString + '.radiaext'
  );
  LArchive := TZipFile.Create;
  try
    LArchive.Open(Result, zmWrite);
    LArchive.Add(LMetadataFileName, 'package.json');
    LArchive.Add(
      LManifestFileName,
      'PackagedCommands.radia.json'
    );
    if AAddUnexpectedFile then
    begin
      LUnexpectedFileName := TPath.Combine(
        FDirectory,
        'unexpected.txt'
      );
      TFile.WriteAllText(
        LUnexpectedFileName,
        'unexpected',
        TEncoding.UTF8
      );
      LArchive.Add(LUnexpectedFileName, 'unexpected.txt');
    end;
  finally
    LArchive.Free;
  end;
end;

procedure TRadIADeclarativeExtensionPackageTests.
  HashingMatchesStandardUtf8Sha256;
begin
  Assert.AreEqual(
    'faf3f943e51dffd182a724dc242ca2a99b6f5393dd8f58a532d2768d5a600784',
    LowerCase(THashSHA2.GetHashString(CPackageManifest))
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  ReadsAndInstallsVerifiedPackage;
var
  LExtensionId: string;
  LInstallDirectory: string;
  LManager: TRadIADeclarativeExtensionManager;
  LMessage: string;
  LPackage: TRadIADeclarativeExtensionPackage;
  LPackageFileName: string;
begin
  LPackageFileName := CreatePackage(
    CPackageManifest,
    'PackagedCommands.radia.json',
    '',
    False
  );
  LPackage := TRadIADeclarativeExtensionPackageReader.Read(
    LPackageFileName
  );
  Assert.AreEqual('PackagedCommands', LPackage.ExtensionId);
  Assert.AreEqual('1.2.0', LPackage.Version);
  LInstallDirectory := TPath.Combine(FDirectory, 'installed');
  LManager := TRadIADeclarativeExtensionManager.Create(
    LInstallDirectory
  );
  try
    Assert.IsTrue(
      TRadIADeclarativeExtensionPackageInstaller.Install(
        LPackageFileName,
        LManager,
        [],
        LExtensionId,
        LMessage
      ),
      LMessage
    );
    Assert.AreEqual('PackagedCommands', LExtensionId);
    Assert.AreEqual<Integer>(1, Length(LManager.GetCommands));
  finally
    LManager.Free;
  end;
end;

procedure TRadIADeclarativeExtensionPackageTests.
  RejectsCompressedOversizedEntry;
var
  LPackageFileName: string;
begin
  LPackageFileName := CreatePackage(
    StringOfChar('x', 1048577),
    'PackagedCommands.radia.json',
    '',
    False
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIADeclarativeExtensionPackageReader.Read(LPackageFileName);
    end,
    EArgumentException,
    'Package entry exceeds the 1 MiB size limit.'
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  RejectsPackageIdentityMismatch;
var
  LPackageFileName: string;
begin
  LPackageFileName := CreatePackage(
    CPackageManifest.Replace(
      '"id":"PackagedCommands"',
      '"id":"DifferentCommands"'
    ),
    'PackagedCommands.radia.json',
    '',
    False
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIADeclarativeExtensionPackageReader.Read(LPackageFileName);
    end,
    EArgumentException,
    'Package ID does not match the embedded manifest.'
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  RejectsTamperedManifestHash;
var
  LPackageFileName: string;
begin
  LPackageFileName := CreatePackage(
    CPackageManifest,
    'PackagedCommands.radia.json',
    StringOfChar('0', 64),
    False
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIADeclarativeExtensionPackageReader.Read(LPackageFileName);
    end,
    EArgumentException,
    'Manifest SHA-256 does not match package metadata.'
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  RejectsUndeclaredArchiveEntry;
var
  LPackageFileName: string;
begin
  LPackageFileName := CreatePackage(
    CPackageManifest,
    'PackagedCommands.radia.json',
    '',
    True
  );
  Assert.WillRaise(
    procedure
    begin
      TRadIADeclarativeExtensionPackageReader.Read(LPackageFileName);
    end,
    EArgumentException
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  RejectsUnsafeManifestPath;
var
  LPackageFileName: string;
begin
  LPackageFileName := CreatePackage(
    CPackageManifest,
    '..\PackagedCommands.radia.json',
    '',
    False
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIADeclarativeExtensionPackageReader.Read(LPackageFileName);
    end,
    EArgumentException,
    'Package manifest name is invalid.'
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.Setup;
begin
  FDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExtensionPackages-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FDirectory);
end;

procedure TRadIADeclarativeExtensionPackageTests.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

initialization
  TDUnitX.RegisterTestFixture(
    TRadIADeclarativeExtensionPackageTests
  );

end.
