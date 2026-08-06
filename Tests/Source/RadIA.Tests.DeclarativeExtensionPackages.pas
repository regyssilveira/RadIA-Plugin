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
    function CreatePackageCore(
      const AManifestContent: string;
      const ADeclaredManifestName: string;
      const ADeclaredHash: string;
      const AAddUnexpectedFile: Boolean;
      const ASigned: Boolean;
      const ATamperedSignature: Boolean
    ): string;
    function CreateSignedPackage(
      const ATamperedSignature: Boolean = False
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
    procedure VerifiesRsaSha256PublisherSignature;
    [Test]
    procedure ReadsSignedPackageAndPublisherIdentity;
    [Test]
    procedure RejectsInvalidPublisherSignature;
    [Test]
    procedure TrustStoreRoundTripsAndRevokesPublisher;
    [Test]
    procedure TrustedInstallerRequiresConsentOrTrustedPublisher;
    [Test]
    procedure TrustedInstallerRejectsUnsignedPackageChangedAfterConsent;
    [Test]
    procedure RejectsInvalidTrustStoreEntries;
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
    [Test]
    procedure ReadsSchemaTwoTemplatePackage;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  System.Zip,
  RadIA.Core.DeclarativeExtensionPackages,
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.ExtensionPublisherTrust,
  RadIA.Core.RsaSignature;

const
  CPackageManifest =
    '{"schemaVersion":1,"id":"PackagedCommands","version":"1.2.0",' +
    '"enabled":true,"permissions":["chat.prompt"],"commands":[{' +
    '"name":"Package review","description":"Review from a verified package.",' +
    '"command":"/package-review","prompt":"Review package input: {code}"' +
    '}]}';
  CSchemaTwoPackageManifest =
    '{"schemaVersion":2,"id":"PackagedCommands","version":"1.2.0",' +
    '"enabled":true,"permissions":["chat.prompt"],"templates":[{' +
    '"name":"Package plan","description":"Plan from a verified package.",' +
    '"command":"/package-plan","prompt":"Plan package input: {argument}"' +
    '}]}';
  CRsaModulus =
    'teUwBI7/eDWLlI0bCfZ72J6Rn+PjH1KcLuRE7Lbjuetb6WHPGgdjgYJWWx8I' +
    'PsI9Y+DhYmUclupV3/8zIft3VuanrmgXCUKE5NhoIHCKIquv8uzog347ln' +
    'OI5qHMvYz48n8DF+modyXs3aZW1/1XPiHdnjEEg7jK5vw1E2mnpk5QxZkz' +
    'RNxVQ8lJpBc1QAgk9s6p9gfaSeGEcIN3uzIkzTcdyJBjz40uR7E5Q00rP4' +
    'sBdkVopJbJrKk79p9PyadF7DIDKA4AnTj70gKvjPQcC+ALPppr/w5Xyq/s' +
    'ylFB5/H87U7y+mfjImHDpRY6+tvRJewu4gZulzzK4cZzriiIpQ==';
  CRsaSignature =
    'DRdJtz3vZX1i39cFsvVcgFuzXF3hxJUn52/1FKUT0kZRcIlPH7rdPo2dWA' +
    'BE9hYrS3K/IXiVgb9uCV9zjtXiHt1pTlSHJ+pd1gGTMOLXDT7afzRnaBqh' +
    'AIMWk+EzhXdvdLuu+Kdp+52jtzQuGvpuvB01DDGVDOpib8gKBsFaGuCo8x' +
    'k7NqyQebRvoOshpB9TtzLVsFE0PqenaKdlZz+GDC9HQGmxmfhFM2mHIOqO' +
    'k/nDUGTefJTmEpV+CiApH4CaMnNPYecvgBd70cZtQJYTcxxigUTp9qZdJe' +
    'I4J9NPjxwjjpgRAwLs+m6VXNzIhDsF2gIuBqngfwybN84vQYT5Jg==';
  CSignedPackageModulus =
    'v5VOxP9Xq6j1tPMAaUmB715skgQwVBSfOAOEZlxeCMA4qXMOZ7c/LljGQlX/' +
    'LQ+vEUmiMVMOeUMwYsFa2wqRz1Hyv2W+aFLX1+3XuxJA/O8V1c5JvOoPfa' +
    'FWJLK+7ut36L41hbQJka8Dk05PYkIh54jdeMkQB0xY6jGZ2VoRrTVxziMa' +
    'Gvmv2I0NHjMbPetbvJAHXNA8sbt6KAuvZLW+gFUUNfq0dmut3TzHD6xLgk' +
    'rF3wayYd4Jvkch1qSWSxSapFkwWmGpBN5XetBPARcVX3F5vt9XNczRNIm1' +
    'HYYuFndGguVWg3zoJWaGEE5rgD5/MLpzQnPeubQblxxq7BHBIQ==';
  CSignedPackageSignature =
    'fPKw/3Pt79tW8rrGlJ54zSo9jWroc1eUwTe5idHT/l2hKkat79D7w3IHo9' +
    '6+cEd4z7y41wW4AWfA9T7tG6h0yeUWWw6ECKO0/tH7vwQOTgszToxk+nT' +
    'pLYAWu07IW79CSzsiP5RCNVEUCemEEPNmjkvZ2zRTP0x/50SQRkdhf/iTW' +
    '7bgAR3fxh2QheD491kCwJK+YXoQMgIhphQGBzZkHu5vftuWGO/kTprhQBl' +
    '23wrQXVT8YuFItlMEVU3cnHpE1yezzwoKxUEIkuZMXGFRzXAZsetufPSgx' +
    '8gaYutTgVnViUcfoLdFSG+vjpQUZt27ItYn/m2WuNXQc57MdAL2vw==';

function TRadIADeclarativeExtensionPackageTests.CreatePackage(
  const AManifestContent: string;
  const ADeclaredManifestName: string;
  const ADeclaredHash: string;
  const AAddUnexpectedFile: Boolean
): string;
begin
  Result := CreatePackageCore(
    AManifestContent,
    ADeclaredManifestName,
    ADeclaredHash,
    AAddUnexpectedFile,
    False,
    False
  );
end;

function TRadIADeclarativeExtensionPackageTests.CreatePackageCore(
  const AManifestContent: string;
  const ADeclaredManifestName: string;
  const ADeclaredHash: string;
  const AAddUnexpectedFile: Boolean;
  const ASigned: Boolean;
  const ATamperedSignature: Boolean
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
  LPublisher: TJSONObject;
  LSignature: string;
  LUnexpectedFileName: string;
begin
  LManifestBytes := TEncoding.UTF8.GetBytes(AManifestContent);
  if ADeclaredHash = '' then
    LHash := THashSHA2.GetHashString(AManifestContent)
  else
    LHash := ADeclaredHash;
  LMetadata := TJSONObject.Create;
  try
    if ASigned then
      LMetadata.AddPair('schemaVersion', TJSONNumber.Create(2))
    else
      LMetadata.AddPair('schemaVersion', TJSONNumber.Create(1));
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
    if ASigned then
    begin
      LSignature := CSignedPackageSignature;
      if ATamperedSignature then
        LSignature[1] := 'A';
      LPublisher := TJSONObject.Create;
      LPublisher.AddPair('algorithm', 'RSA-SHA256');
      LPublisher.AddPair('id', 'radia.test');
      LPublisher.AddPair('name', 'Rad IA Test Publisher');
      LPublisher.AddPair('modulus', CSignedPackageModulus);
      LPublisher.AddPair('exponent', 'AQAB');
      LPublisher.AddPair('signature', LSignature);
      LMetadata.AddPair('publisher', LPublisher);
    end;
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

function TRadIADeclarativeExtensionPackageTests.CreateSignedPackage(
  const ATamperedSignature: Boolean
): string;
begin
  Result := CreatePackageCore(
    CPackageManifest,
    'PackagedCommands.radia.json',
    '',
    False,
    True,
    ATamperedSignature
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  VerifiesRsaSha256PublisherSignature;
begin
  Assert.IsTrue(
    TRadIARsaSignature.VerifySha256(
      'RadIA signed package test',
      CRsaModulus,
      'AQAB',
      CRsaSignature
    )
  );
  Assert.IsFalse(
    TRadIARsaSignature.VerifySha256(
      'tampered package test',
      CRsaModulus,
      'AQAB',
      CRsaSignature
    )
  );
  Assert.AreEqual<Integer>(
    64,
    Length(TRadIARsaSignature.Fingerprint(CRsaModulus, 'AQAB'))
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  ReadsSignedPackageAndPublisherIdentity;
var
  LPackage: TRadIADeclarativeExtensionPackage;
begin
  LPackage := TRadIADeclarativeExtensionPackageReader.Read(
    CreateSignedPackage
  );
  Assert.IsTrue(LPackage.IsSigned);
  Assert.AreEqual<Integer>(2, LPackage.SchemaVersion);
  Assert.AreEqual('radia.test', LPackage.Publisher.Id);
  Assert.AreEqual('Rad IA Test Publisher', LPackage.Publisher.Name);
  Assert.AreEqual<Integer>(64, Length(LPackage.Publisher.Fingerprint));
end;

procedure TRadIADeclarativeExtensionPackageTests.
  ReadsSchemaTwoTemplatePackage;
var
  LManager: TRadIADeclarativeExtensionManager;
  LPackage: TRadIADeclarativeExtensionPackage;
  LTemplate: TRadIADeclarativeCommand;
begin
  LPackage := TRadIADeclarativeExtensionPackageReader.Read(
    CreatePackage(
      CSchemaTwoPackageManifest,
      'PackagedCommands.radia.json',
      '',
      False
    )
  );
  LManager := TRadIADeclarativeExtensionManager.Create(FDirectory);
  try
    TFile.WriteAllBytes(
      TPath.Combine(FDirectory, 'PackagedCommands.radia.json'),
      LPackage.ManifestContent
    );
    LManager.Reload([]);
    Assert.IsTrue(LManager.TryResolve('/package-plan', LTemplate));
    Assert.AreEqual('template', LTemplate.Kind);
  finally
    LManager.Free;
  end;
end;

procedure TRadIADeclarativeExtensionPackageTests.
  RejectsInvalidPublisherSignature;
var
  LPackageFileName: string;
begin
  LPackageFileName := CreateSignedPackage(True);
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIADeclarativeExtensionPackageReader.Read(LPackageFileName);
    end,
    EArgumentException,
    'Package publisher signature is invalid.'
  );
end;

procedure TRadIADeclarativeExtensionPackageTests.
  RejectsInvalidTrustStoreEntries;
var
  LStore: TRadIAExtensionPublisherTrustStore;
  LStoreFileName: string;
begin
  LStoreFileName := TPath.Combine(FDirectory, 'invalid-trust.json');
  TFile.WriteAllText(
    LStoreFileName,
    '{"schemaVersion":1,"publishers":[{"id":"radia.test",' +
    '"name":"Test","fingerprint":"invalid"}]}',
    TEncoding.UTF8
  );
  LStore := TRadIAExtensionPublisherTrustStore.Create(LStoreFileName);
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        LStore.Load;
      end,
      EArgumentException,
      'Trusted publisher fingerprint is invalid.'
    );
  finally
    LStore.Free;
  end;
end;

procedure TRadIADeclarativeExtensionPackageTests.
  TrustedInstallerRequiresConsentOrTrustedPublisher;
var
  LExtensionId: string;
  LManager: TRadIADeclarativeExtensionManager;
  LMessage: string;
  LPackage: TRadIADeclarativeExtensionPackage;
  LSignedFileName: string;
  LStore: TRadIAExtensionPublisherTrustStore;
  LUnsignedDecision: TRadIAExtensionPackageTrustDecision;
  LUnsignedFileName: string;
begin
  LUnsignedFileName := CreatePackage(
    CPackageManifest,
    'PackagedCommands.radia.json',
    '',
    False
  );
  LSignedFileName := CreateSignedPackage;
  LUnsignedDecision := TRadIAExtensionPackageTrustDecision.Create(
    True,
    LowerCase(
      THashSHA2.GetHashStringFromFile(LUnsignedFileName)
    )
  );
  LStore := TRadIAExtensionPublisherTrustStore.Create(
    TPath.Combine(FDirectory, 'trusted.json')
  );
  LManager := TRadIADeclarativeExtensionManager.Create(
    TPath.Combine(FDirectory, 'trusted-installed')
  );
  try
    Assert.IsFalse(
      TRadIATrustedExtensionPackageInstaller.Install(
        LUnsignedFileName,
        LManager,
        [],
        LStore,
        Default(TRadIAExtensionPackageTrustDecision),
        LExtensionId,
        LMessage
      )
    );
    Assert.AreEqual(
      'Unsigned integrity-only package requires confirmation.',
      LMessage
    );
    Assert.IsTrue(
      TRadIATrustedExtensionPackageInstaller.Install(
        LUnsignedFileName,
        LManager,
        [],
        LStore,
        LUnsignedDecision,
        LExtensionId,
        LMessage
      ),
      LMessage
    );
    Assert.IsFalse(
      TRadIATrustedExtensionPackageInstaller.Install(
        LSignedFileName,
        LManager,
        [],
        LStore,
        Default(TRadIAExtensionPackageTrustDecision),
        LExtensionId,
        LMessage
      )
    );
    Assert.AreEqual('Package publisher is not trusted.', LMessage);
    LPackage := TRadIADeclarativeExtensionPackageReader.Read(
      LSignedFileName
    );
    LStore.Trust(LPackage.Publisher);
    Assert.IsTrue(
      TRadIATrustedExtensionPackageInstaller.Install(
        LSignedFileName,
        LManager,
        [],
        LStore,
        Default(TRadIAExtensionPackageTrustDecision),
        LExtensionId,
        LMessage
      ),
      LMessage
    );
  finally
    LManager.Free;
    LStore.Free;
  end;
end;

procedure TRadIADeclarativeExtensionPackageTests.
  TrustedInstallerRejectsUnsignedPackageChangedAfterConsent;
var
  LDecision: TRadIAExtensionPackageTrustDecision;
  LExtensionId: string;
  LManager: TRadIADeclarativeExtensionManager;
  LMessage: string;
  LPackageFileName: string;
  LStore: TRadIAExtensionPublisherTrustStore;
begin
  LPackageFileName := CreatePackage(
    CPackageManifest,
    'PackagedCommands.radia.json',
    '',
    False
  );
  LDecision := TRadIAExtensionPackageTrustDecision.Create(
    True,
    LowerCase(
      THashSHA2.GetHashStringFromFile(LPackageFileName)
    )
  );
  TFile.AppendAllText(LPackageFileName, 'changed');
  LStore := TRadIAExtensionPublisherTrustStore.Create(
    TPath.Combine(FDirectory, 'changed-trust.json')
  );
  LManager := TRadIADeclarativeExtensionManager.Create(
    TPath.Combine(FDirectory, 'changed-installed')
  );
  try
    Assert.IsFalse(
      TRadIATrustedExtensionPackageInstaller.Install(
        LPackageFileName,
        LManager,
        [],
        LStore,
        LDecision,
        LExtensionId,
        LMessage
      )
    );
    Assert.AreEqual(
      'Unsigned package changed after confirmation.',
      LMessage
    );
  finally
    LManager.Free;
    LStore.Free;
  end;
end;

procedure TRadIADeclarativeExtensionPackageTests.
  TrustStoreRoundTripsAndRevokesPublisher;
var
  LChangedPublisher: TRadIADeclarativeExtensionPublisher;
  LPackage: TRadIADeclarativeExtensionPackage;
  LStore: TRadIAExtensionPublisherTrustStore;
  LStoreFileName: string;
begin
  LPackage := TRadIADeclarativeExtensionPackageReader.Read(
    CreateSignedPackage
  );
  LStoreFileName := TPath.Combine(FDirectory, 'publisher-trust.json');
  LStore := TRadIAExtensionPublisherTrustStore.Create(LStoreFileName);
  try
    LStore.Trust(LPackage.Publisher);
  finally
    LStore.Free;
  end;
  LStore := TRadIAExtensionPublisherTrustStore.Create(LStoreFileName);
  try
    LStore.Load;
    Assert.IsTrue(LStore.IsTrusted(LPackage.Publisher));
    LChangedPublisher := TRadIADeclarativeExtensionPublisher.Create(
      LPackage.Publisher.Id,
      LPackage.Publisher.Name,
      CRsaModulus,
      'AQAB',
      CRsaSignature
    );
    Assert.IsFalse(LStore.IsTrusted(LChangedPublisher));
    Assert.IsTrue(LStore.Revoke(LPackage.Publisher.Id));
    Assert.IsFalse(LStore.IsTrusted(LPackage.Publisher));
    Assert.IsFalse(LStore.Revoke(LPackage.Publisher.Id));
  finally
    LStore.Free;
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
