unit RadIA.Tests.ExtensionCatalog;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.ExtensionCatalog;

type
  TRadIAMockExtensionCatalogTransport = class(
    TInterfacedObject,
    IRadIAExtensionCatalogTransport
  )
  private
    FBytes: TArray<Byte>;
    FLastUrl: string;
    FText: string;
  public
    function GetBytes(
      const AUrl: string;
      const AMaximumBytes: Integer
    ): TArray<Byte>;
    function GetText(
      const AUrl: string;
      const AMaximumBytes: Integer
    ): string;
    property Bytes: TArray<Byte> read FBytes write FBytes;
    property LastUrl: string read FLastUrl;
    property Text: string read FText write FText;
  end;

  [TestFixture]
  TRadIAExtensionCatalogTests = class
  private
    FClient: TRadIAExtensionCatalogClient;
    FDirectory: string;
    FTransport: TRadIAMockExtensionCatalogTransport;
    function BuildCatalog(
      const APackageBytes: TArray<Byte>;
      const AHash: string;
      const AFingerprint: string;
      const ADuplicate: Boolean = False
    ): string;
    function CreateSignedPackage: TArray<Byte>;
    function HashBytes(const ABytes: TArray<Byte>): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ParsesAndLoadsHttpsCatalog;
    [Test]
    procedure RejectsInsecureCatalogPackageUrl;
    [Test]
    procedure RejectsDuplicateExtensionIds;
    [Test]
    procedure DownloadsAndVerifiesSignedPackage;
    [Test]
    procedure RejectsDownloadedPackageHashMismatch;
    [Test]
    procedure RejectsPublisherMismatch;
    [Test]
    procedure PersistsValidatedCatalogUrl;
    [Test]
    procedure AcceptsPackageSizeUpToTwentyMiB;
    [Test]
    procedure RejectsPackageSizeAboveTwentyMiB;
  end;

implementation

uses
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  System.Zip,
  RadIA.Core.RsaSignature;

const
  CPackageManifest =
    '{"schemaVersion":1,"id":"PackagedCommands","version":"1.2.0",' +
    '"enabled":true,"permissions":["chat.prompt"],"commands":[{' +
    '"name":"Package review","description":"Review from a verified package.",' +
    '"command":"/package-review","prompt":"Review package input: {code}"' +
    '}]}';
  CPackageHash =
    'faf3f943e51dffd182a724dc242ca2a99b6f5393dd8f58a532d2768d5a600784';
  CPackageModulus =
    'v5VOxP9Xq6j1tPMAaUmB715skgQwVBSfOAOEZlxeCMA4qXMOZ7c/LljGQlX/' +
    'LQ+vEUmiMVMOeUMwYsFa2wqRz1Hyv2W+aFLX1+3XuxJA/O8V1c5JvOoPfa' +
    'FWJLK+7ut36L41hbQJka8Dk05PYkIh54jdeMkQB0xY6jGZ2VoRrTVxziMa' +
    'Gvmv2I0NHjMbPetbvJAHXNA8sbt6KAuvZLW+gFUUNfq0dmut3TzHD6xLgk' +
    'rF3wayYd4Jvkch1qSWSxSapFkwWmGpBN5XetBPARcVX3F5vt9XNczRNIm1' +
    'HYYuFndGguVWg3zoJWaGEE5rgD5/MLpzQnPeubQblxxq7BHBIQ==';
  CPackageSignature =
    'fPKw/3Pt79tW8rrGlJ54zSo9jWroc1eUwTe5idHT/l2hKkat79D7w3IHo9' +
    '6+cEd4z7y41wW4AWfA9T7tG6h0yeUWWw6ECKO0/tH7vwQOTgszToxk+nT' +
    'pLYAWu07IW79CSzsiP5RCNVEUCemEEPNmjkvZ2zRTP0x/50SQRkdhf/iTW' +
    '7bgAR3fxh2QheD491kCwJK+YXoQMgIhphQGBzZkHu5vftuWGO/kTprhQBl' +
    '23wrQXVT8YuFItlMEVU3cnHpE1yezzwoKxUEIkuZMXGFRzXAZsetufPSgx' +
    '8gaYutTgVnViUcfoLdFSG+vjpQUZt27ItYn/m2WuNXQc57MdAL2vw==';

{ TRadIAMockExtensionCatalogTransport }

function TRadIAMockExtensionCatalogTransport.GetBytes(
  const AUrl: string;
  const AMaximumBytes: Integer
): TArray<Byte>;
begin
  FLastUrl := AUrl;
  if Length(FBytes) > AMaximumBytes then
    raise EArgumentException.Create('Mock content exceeds the limit.');
  Result := Copy(FBytes);
end;

function TRadIAMockExtensionCatalogTransport.GetText(
  const AUrl: string;
  const AMaximumBytes: Integer
): string;
begin
  FLastUrl := AUrl;
  if TEncoding.UTF8.GetByteCount(FText) > AMaximumBytes then
    raise EArgumentException.Create('Mock content exceeds the limit.');
  Result := FText;
end;

{ TRadIAExtensionCatalogTests }

procedure TRadIAExtensionCatalogTests.AcceptsPackageSizeUpToTwentyMiB;
var
  LCatalog: TRadIAExtensionCatalog;
  LCatalogJson: string;
  LFingerprint: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  LFingerprint := TRadIARsaSignature.Fingerprint(
    CPackageModulus,
    'AQAB'
  );
  LCatalogJson := BuildCatalog(
    LPackageBytes,
    HashBytes(LPackageBytes),
    LFingerprint
  ).Replace(
    '"size":' + Length(LPackageBytes).ToString,
    '"size":' + (20 * 1024 * 1024).ToString
  );
  LCatalog := TRadIAExtensionCatalogClient.Parse(LCatalogJson);
  Assert.AreEqual(20 * 1024 * 1024, LCatalog.Entries[0].PackageSize);
end;

function TRadIAExtensionCatalogTests.BuildCatalog(
  const APackageBytes: TArray<Byte>;
  const AHash: string;
  const AFingerprint: string;
  const ADuplicate: Boolean
): string;
var
  LEntry: string;
begin
  LEntry :=
    '{"id":"PackagedCommands","name":"Package commands",' +
    '"description":"Verified commands from a remote catalog.",' +
    '"version":"1.2.0","package":{' +
    '"url":"https://extensions.example.test/PackagedCommands.radiaext",' +
    '"size":' + Length(APackageBytes).ToString + ',"sha256":"' +
    AHash + '"},"publisher":{"id":"radia.test",' +
    '"name":"Rad IA Test Publisher","fingerprint":"' +
    AFingerprint + '"}}';
  Result := '{"schemaVersion":1,"name":"Test catalog","extensions":[' +
    LEntry;
  if ADuplicate then
    Result := Result + ',' + LEntry;
  Result := Result + ']}';
end;

function TRadIAExtensionCatalogTests.CreateSignedPackage: TArray<Byte>;
var
  LArchive: TZipFile;
  LManifestFileName: string;
  LMetadata: string;
  LMetadataFileName: string;
  LPackageFileName: string;
begin
  LManifestFileName := TPath.Combine(
    FDirectory,
    'PackagedCommands.radia.json'
  );
  LMetadataFileName := TPath.Combine(FDirectory, 'package.json');
  LPackageFileName := TPath.Combine(FDirectory, 'catalog-package.zip');
  TFile.WriteAllBytes(
    LManifestFileName,
    TEncoding.UTF8.GetBytes(CPackageManifest)
  );
  LMetadata :=
    '{"schemaVersion":2,"id":"PackagedCommands","version":"1.2.0",' +
    '"manifest":"PackagedCommands.radia.json","files":[{' +
    '"path":"PackagedCommands.radia.json","size":261,"sha256":"' +
    CPackageHash + '"}],"publisher":{"algorithm":"RSA-SHA256",' +
    '"id":"radia.test","name":"Rad IA Test Publisher","modulus":"' +
    CPackageModulus + '","exponent":"AQAB","signature":"' +
    CPackageSignature + '"}}';
  TFile.WriteAllText(LMetadataFileName, LMetadata, TEncoding.UTF8);
  LArchive := TZipFile.Create;
  try
    LArchive.Open(LPackageFileName, zmWrite);
    LArchive.Add(LMetadataFileName, 'package.json');
    LArchive.Add(
      LManifestFileName,
      'PackagedCommands.radia.json'
    );
  finally
    LArchive.Free;
  end;
  Result := TFile.ReadAllBytes(LPackageFileName);
end;

procedure TRadIAExtensionCatalogTests.
  DownloadsAndVerifiesSignedPackage;
var
  LCatalog: TRadIAExtensionCatalog;
  LFingerprint: string;
  LOutputFileName: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  LFingerprint := TRadIARsaSignature.Fingerprint(
    CPackageModulus,
    'AQAB'
  );
  FTransport.Bytes := LPackageBytes;
  FTransport.Text := BuildCatalog(
    LPackageBytes,
    HashBytes(LPackageBytes),
    LFingerprint
  );
  LCatalog := FClient.Load('https://catalog.example.test/catalog.json');
  LOutputFileName := TPath.Combine(FDirectory, 'downloaded.radiaext');
  Assert.AreEqual(
    'PackagedCommands',
    FClient.DownloadAndVerify(
      LCatalog.Entries[0],
      LOutputFileName
    ).ExtensionId
  );
  Assert.IsTrue(TFile.Exists(LOutputFileName));
  Assert.AreEqual(
    'https://extensions.example.test/PackagedCommands.radiaext',
    FTransport.LastUrl
  );
end;

function TRadIAExtensionCatalogTests.HashBytes(
  const ABytes: TArray<Byte>
): string;
var
  LStream: TBytesStream;
begin
  LStream := TBytesStream.Create(ABytes);
  try
    Result := LowerCase(THashSHA2.GetHashString(LStream));
  finally
    LStream.Free;
  end;
end;

procedure TRadIAExtensionCatalogTests.ParsesAndLoadsHttpsCatalog;
var
  LCatalog: TRadIAExtensionCatalog;
  LFingerprint: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  LFingerprint := TRadIARsaSignature.Fingerprint(
    CPackageModulus,
    'AQAB'
  );
  FTransport.Text := BuildCatalog(
    LPackageBytes,
    HashBytes(LPackageBytes),
    LFingerprint
  );
  LCatalog := FClient.Load('https://catalog.example.test/catalog.json');
  Assert.AreEqual('Test catalog', LCatalog.Name);
  Assert.AreEqual<Integer>(1, Length(LCatalog.Entries));
  Assert.AreEqual('PackagedCommands', LCatalog.Entries[0].ExtensionId);
  Assert.AreEqual('Package commands', LCatalog.Entries[0].Name);
  Assert.AreEqual(
    'Verified commands from a remote catalog.',
    LCatalog.Entries[0].Description
  );
  Assert.AreEqual(
    'https://catalog.example.test/catalog.json',
    FTransport.LastUrl
  );
end;

procedure TRadIAExtensionCatalogTests.PersistsValidatedCatalogUrl;
var
  LFileName: string;
  LPreferences: TRadIAExtensionCatalogPreferences;
begin
  LFileName := TPath.Combine(FDirectory, 'catalog-preferences.json');
  LPreferences := TRadIAExtensionCatalogPreferences.Create(LFileName);
  try
    Assert.AreEqual('', LPreferences.LoadUrl);
    LPreferences.SaveUrl('https://catalog.example.test/catalog.json');
    Assert.AreEqual(
      'https://catalog.example.test/catalog.json',
      LPreferences.LoadUrl
    );
    Assert.WillRaise(
      procedure
      begin
        LPreferences.SaveUrl('http://catalog.example.test/catalog.json');
      end,
      EArgumentException
    );
  finally
    LPreferences.Free;
  end;
end;

procedure TRadIAExtensionCatalogTests.
  RejectsDownloadedPackageHashMismatch;
var
  LCatalog: TRadIAExtensionCatalog;
  LFingerprint: string;
  LOutputFileName: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  LFingerprint := TRadIARsaSignature.Fingerprint(
    CPackageModulus,
    'AQAB'
  );
  FTransport.Bytes := LPackageBytes;
  FTransport.Text := BuildCatalog(
    LPackageBytes,
    StringOfChar('0', 64),
    LFingerprint
  );
  LCatalog := FClient.Load('https://catalog.example.test/catalog.json');
  LOutputFileName := TPath.Combine(FDirectory, 'tampered.radiaext');
  TFile.WriteAllText(
    LOutputFileName,
    'existing package',
    TEncoding.UTF8
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FClient.DownloadAndVerify(
        LCatalog.Entries[0],
        LOutputFileName
      );
    end,
    EArgumentException,
    'Downloaded extension package SHA-256 does not match the catalog.'
  );
  Assert.IsTrue(TFile.Exists(LOutputFileName));
  Assert.AreEqual(
    'existing package',
    TFile.ReadAllText(LOutputFileName, TEncoding.UTF8)
  );
end;

procedure TRadIAExtensionCatalogTests.RejectsDuplicateExtensionIds;
var
  LFingerprint: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  LFingerprint := TRadIARsaSignature.Fingerprint(
    CPackageModulus,
    'AQAB'
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIAExtensionCatalogClient.Parse(
        BuildCatalog(
          LPackageBytes,
          HashBytes(LPackageBytes),
          LFingerprint,
          True
        )
      );
    end,
    EArgumentException,
    'Extension catalog contains duplicate IDs.'
  );
end;

procedure TRadIAExtensionCatalogTests.
  RejectsInsecureCatalogPackageUrl;
var
  LCatalogJson: string;
  LFingerprint: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  LFingerprint := TRadIARsaSignature.Fingerprint(
    CPackageModulus,
    'AQAB'
  );
  LCatalogJson := BuildCatalog(
    LPackageBytes,
    HashBytes(LPackageBytes),
    LFingerprint
  ).Replace(
    'https://extensions.example.test',
    'http://extensions.example.test'
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIAExtensionCatalogClient.Parse(LCatalogJson);
    end,
    EArgumentException,
    'Extension catalog URLs must use HTTPS without credentials or fragments.'
  );
end;

procedure TRadIAExtensionCatalogTests.RejectsPublisherMismatch;
var
  LCatalog: TRadIAExtensionCatalog;
  LOutputFileName: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  FTransport.Bytes := LPackageBytes;
  FTransport.Text := BuildCatalog(
    LPackageBytes,
    HashBytes(LPackageBytes),
    StringOfChar('1', 64)
  );
  LCatalog := FClient.Load('https://catalog.example.test/catalog.json');
  LOutputFileName := TPath.Combine(
    FDirectory,
    'publisher-mismatch.radiaext'
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FClient.DownloadAndVerify(
        LCatalog.Entries[0],
        LOutputFileName
      );
    end,
    EArgumentException,
    'Downloaded package publisher does not match the catalog.'
  );
  Assert.IsFalse(TFile.Exists(LOutputFileName));
end;

procedure TRadIAExtensionCatalogTests.RejectsPackageSizeAboveTwentyMiB;
var
  LCatalogJson: string;
  LFingerprint: string;
  LPackageBytes: TArray<Byte>;
begin
  LPackageBytes := CreateSignedPackage;
  LFingerprint := TRadIARsaSignature.Fingerprint(
    CPackageModulus,
    'AQAB'
  );
  LCatalogJson := BuildCatalog(
    LPackageBytes,
    HashBytes(LPackageBytes),
    LFingerprint
  ).Replace(
    '"size":' + Length(LPackageBytes).ToString,
    '"size":' + (20 * 1024 * 1024 + 1).ToString
  );
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TRadIAExtensionCatalogClient.Parse(LCatalogJson);
    end,
    EArgumentException,
    'Catalog package size is invalid.'
  );
end;

procedure TRadIAExtensionCatalogTests.Setup;
begin
  FDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExtensionCatalog-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FDirectory);
  FTransport := TRadIAMockExtensionCatalogTransport.Create;
  FClient := TRadIAExtensionCatalogClient.Create(FTransport);
end;

procedure TRadIAExtensionCatalogTests.TearDown;
begin
  FClient.Free;
  FTransport := nil;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExtensionCatalogTests);

end.
