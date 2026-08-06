unit RadIA.Core.ExtensionSigning;

interface

uses
  RadIA.Core.AgentExecutors;

type
  TRadIAExtensionSigningCertificate = record
  private
    FDisplayName: string;
    FExpiresAt: string;
    FThumbprint: string;
  public
    property DisplayName: string read FDisplayName;
    property ExpiresAt: string read FExpiresAt;
    property Thumbprint: string read FThumbprint;
  end;

  TRadIAExtensionSigningRequest = record
  private
    FManifestPath: string;
    FOutputPath: string;
    FPackagerPath: string;
    FPublisherId: string;
    FPublisherName: string;
    FThumbprint: string;
  public
    constructor Create(
      const AManifestPath: string;
      const AOutputPath: string;
      const APackagerPath: string;
      const APublisherId: string;
      const APublisherName: string;
      const AThumbprint: string
    );
    property ManifestPath: string read FManifestPath;
    property OutputPath: string read FOutputPath;
    property PackagerPath: string read FPackagerPath;
    property PublisherId: string read FPublisherId;
    property PublisherName: string read FPublisherName;
    property Thumbprint: string read FThumbprint;
  end;

  TRadIAExtensionSigningService = class
  private
    class function CertificateQueryScript: string; static;
    class procedure ValidateRequest(
      const ARequest: TRadIAExtensionSigningRequest
    ); static;
  public
    class function BuildCertificateQueryInvocation:
      TRadIACliInvocation; static;
    class function BuildSigningInvocation(
      const ARequest: TRadIAExtensionSigningRequest
    ): TRadIACliInvocation; static;
    class function FindPackager: string; static;
    class function ParseCertificates(
      const AJson: string
    ): TArray<TRadIAExtensionSigningCertificate>; static;
    class function ValidateSignedPackage(
      const AFileName: string
    ): string; static;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.DeclarativeExtensionPackages;

{ TRadIAExtensionSigningRequest }

constructor TRadIAExtensionSigningRequest.Create(
  const AManifestPath: string;
  const AOutputPath: string;
  const APackagerPath: string;
  const APublisherId: string;
  const APublisherName: string;
  const AThumbprint: string
);
begin
  FManifestPath := Trim(AManifestPath);
  FOutputPath := Trim(AOutputPath);
  FPackagerPath := Trim(APackagerPath);
  FPublisherId := Trim(APublisherId);
  FPublisherName := Trim(APublisherName);
  FThumbprint := UpperCase(Trim(AThumbprint));
end;

{ TRadIAExtensionSigningService }

class function TRadIAExtensionSigningService.BuildCertificateQueryInvocation:
  TRadIACliInvocation;
begin
  Result := TRadIACliInvocation.Create(
    'powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      CertificateQueryScript
    ],
    TPath.GetTempPath,
    'json'
  );
end;

class function TRadIAExtensionSigningService.BuildSigningInvocation(
  const ARequest: TRadIAExtensionSigningRequest
): TRadIACliInvocation;
begin
  ValidateRequest(ARequest);
  Result := TRadIACliInvocation.Create(
    'powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      ARequest.PackagerPath,
      '-ManifestPath',
      ARequest.ManifestPath,
      '-OutputPath',
      ARequest.OutputPath,
      '-SigningCertificateThumbprint',
      ARequest.Thumbprint,
      '-PublisherId',
      ARequest.PublisherId,
      '-PublisherName',
      ARequest.PublisherName
    ],
    ExtractFilePath(ARequest.ManifestPath),
    'text'
  );
end;

class function TRadIAExtensionSigningService.CertificateQueryScript: string;
begin
  Result :=
    '$items = @(Get-ChildItem Cert:\CurrentUser\My | Where-Object { ' +
    '$_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) -and ' +
    '$_.PublicKey.Oid.Value -eq ''1.2.840.113549.1.1.1'' } | ' +
    'Sort-Object NotAfter -Descending | ForEach-Object { ' +
    '[pscustomobject]@{ displayName = $_.GetNameInfo(' +
    '[System.Security.Cryptography.X509Certificates.X509NameType]' +
    '::SimpleName, $false); expiresAt = $_.NotAfter.ToString(' +
    '''yyyy-MM-dd HH:mm:ss''); thumbprint = $_.Thumbprint } }); ' +
    'ConvertTo-Json -InputObject $items -Compress';
end;

class function TRadIAExtensionSigningService.FindPackager: string;
var
  LCandidates: TArray<string>;
  LCandidate: string;
begin
  LCandidates := [
    TPath.Combine(
      ExtractFilePath(GetModuleName(HInstance)),
      'New-RadIA.DeclarativeExtensionPackage.ps1'
    ),
    TPath.Combine(
      TDirectory.GetCurrentDirectory,
      'scripts\New-RadIA.DeclarativeExtensionPackage.ps1'
    )
  ];
  for LCandidate in LCandidates do
    if TFile.Exists(LCandidate) then
      Exit(LCandidate);
  Result := '';
end;

class function TRadIAExtensionSigningService.ParseCertificates(
  const AJson: string
): TArray<TRadIAExtensionSigningCertificate>;
var
  LArray: TJSONArray;
  LIndex: Integer;
  LObject: TJSONObject;
  LValue: TJSONValue;
begin
  Result := [];
  LValue := TJSONObject.ParseJSONValue(Trim(AJson));
  if not Assigned(LValue) then
    raise EConvertError.Create('The certificate catalog response is invalid.');
  try
    if not (LValue is TJSONArray) then
      raise EConvertError.Create('The certificate catalog must be a JSON array.');
    LArray := TJSONArray(LValue);
    SetLength(Result, LArray.Count);
    for LIndex := 0 to LArray.Count - 1 do
    begin
      if not (LArray[LIndex] is TJSONObject) then
        raise EConvertError.Create('The certificate catalog entry is invalid.');
      LObject := TJSONObject(LArray[LIndex]);
      Result[LIndex].FDisplayName := Trim(
        LObject.GetValue<string>('displayName')
      );
      Result[LIndex].FExpiresAt := Trim(
        LObject.GetValue<string>('expiresAt')
      );
      Result[LIndex].FThumbprint := UpperCase(Trim(
        LObject.GetValue<string>('thumbprint')
      ));
      if Result[LIndex].Thumbprint = '' then
        raise EConvertError.Create('The certificate thumbprint is required.');
    end;
  finally
    LValue.Free;
  end;
end;

class procedure TRadIAExtensionSigningService.ValidateRequest(
  const ARequest: TRadIAExtensionSigningRequest
);
begin
  if not TFile.Exists(ARequest.ManifestPath) then
    raise EFileNotFoundException.Create('The extension manifest was not found.');
  if not TFile.Exists(ARequest.PackagerPath) then
    raise EFileNotFoundException.Create('The signed package builder was not found.');
  if ARequest.OutputPath = '' then
    raise EArgumentException.Create('The signed package output path is required.');
  if ARequest.PublisherId = '' then
    raise EArgumentException.Create('The publisher ID is required.');
  if ARequest.PublisherName = '' then
    raise EArgumentException.Create('The publisher name is required.');
  if ARequest.Thumbprint = '' then
    raise EArgumentException.Create('A signing certificate is required.');
end;

class function TRadIAExtensionSigningService.ValidateSignedPackage(
  const AFileName: string
): string;
var
  LPackage: TRadIADeclarativeExtensionPackage;
begin
  LPackage := TRadIADeclarativeExtensionPackageReader.Read(AFileName);
  if not LPackage.IsSigned then
    raise EInvalidOpException.Create('The generated extension package is not signed.');
  Result := LPackage.Publisher.Fingerprint;
end;

end.
