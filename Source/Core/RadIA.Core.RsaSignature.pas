unit RadIA.Core.RsaSignature;

interface

type
  TRadIARsaSignature = class
  public
    class function Fingerprint(
      const AModulusBase64: string;
      const AExponentBase64: string
    ): string; static;
    class function VerifySha256(
      const AContent: string;
      const AModulusBase64: string;
      const AExponentBase64: string;
      const ASignatureBase64: string
    ): Boolean; static;
  end;

implementation

uses
  System.Hash,
  System.NetEncoding,
  System.SysUtils;

type
  NTSTATUS = LongInt;
  BCRYPT_ALG_HANDLE = Pointer;
  BCRYPT_KEY_HANDLE = Pointer;
  ULONG = Cardinal;

  TBcryptRsaKeyBlob = packed record
    Magic: ULONG;
    BitLength: ULONG;
    PublicExponentSize: ULONG;
    ModulusSize: ULONG;
    Prime1Size: ULONG;
    Prime2Size: ULONG;
  end;

  TBcryptPkcs1PaddingInfo = record
    AlgorithmId: PWideChar;
  end;

const
  BCRYPT_PAD_PKCS1 = $00000002;
  BCRYPT_RSAPUBLIC_MAGIC = $31415352;
  STATUS_SUCCESS = 0;

function BCryptCloseAlgorithmProvider(
  AAlgorithm: BCRYPT_ALG_HANDLE;
  AFlags: ULONG
): NTSTATUS; stdcall; external 'bcrypt.dll';

function BCryptDestroyKey(
  AKey: BCRYPT_KEY_HANDLE
): NTSTATUS; stdcall; external 'bcrypt.dll';

function BCryptImportKeyPair(
  AAlgorithm: BCRYPT_ALG_HANDLE;
  AImportKey: BCRYPT_KEY_HANDLE;
  ABlobType: PWideChar;
  out AKey: BCRYPT_KEY_HANDLE;
  AInput: PByte;
  AInputSize: ULONG;
  AFlags: ULONG
): NTSTATUS; stdcall; external 'bcrypt.dll';

function BCryptOpenAlgorithmProvider(
  out AAlgorithm: BCRYPT_ALG_HANDLE;
  AAlgorithmId: PWideChar;
  AImplementation: PWideChar;
  AFlags: ULONG
): NTSTATUS; stdcall; external 'bcrypt.dll';

function BCryptVerifySignature(
  AKey: BCRYPT_KEY_HANDLE;
  APaddingInfo: Pointer;
  AHash: PByte;
  AHashSize: ULONG;
  ASignature: PByte;
  ASignatureSize: ULONG;
  AFlags: ULONG
): NTSTATUS; stdcall; external 'bcrypt.dll';

function FirstByte(const ABytes: TArray<Byte>): PByte;
begin
  if Length(ABytes) = 0 then
    Result := nil
  else
    Result := @ABytes[0];
end;

function BuildPublicKeyBlob(
  const AModulus: TArray<Byte>;
  const AExponent: TArray<Byte>
): TArray<Byte>;
var
  LHeader: TBcryptRsaKeyBlob;
  LOffset: Integer;
begin
  if (Length(AModulus) < 256) or (Length(AExponent) = 0) then
    raise EArgumentException.Create(
      'RSA public key must use at least 2048 bits.'
    );
  LHeader.Magic := BCRYPT_RSAPUBLIC_MAGIC;
  LHeader.BitLength := Length(AModulus) * 8;
  LHeader.PublicExponentSize := Length(AExponent);
  LHeader.ModulusSize := Length(AModulus);
  LHeader.Prime1Size := 0;
  LHeader.Prime2Size := 0;
  SetLength(
    Result,
    SizeOf(LHeader) + Length(AExponent) + Length(AModulus)
  );
  Move(LHeader, Result[0], SizeOf(LHeader));
  LOffset := SizeOf(LHeader);
  Move(AExponent[0], Result[LOffset], Length(AExponent));
  Inc(LOffset, Length(AExponent));
  Move(AModulus[0], Result[LOffset], Length(AModulus));
end;

class function TRadIARsaSignature.Fingerprint(
  const AModulusBase64: string;
  const AExponentBase64: string
): string;
var
  LExponent: TArray<Byte>;
  LModulus: TArray<Byte>;
  LMaterial: string;
begin
  LModulus := TNetEncoding.Base64.DecodeStringToBytes(
    AModulusBase64
  );
  LExponent := TNetEncoding.Base64.DecodeStringToBytes(
    AExponentBase64
  );
  if (Length(LModulus) < 256) or (Length(LExponent) = 0) then
    raise EArgumentException.Create(
      'RSA public key must use at least 2048 bits.'
    );
  LMaterial := TNetEncoding.Base64.EncodeBytesToString(LModulus) +
    ':' + TNetEncoding.Base64.EncodeBytesToString(LExponent);
  Result := LowerCase(THashSHA2.GetHashString(LMaterial));
end;

class function TRadIARsaSignature.VerifySha256(
  const AContent: string;
  const AModulusBase64: string;
  const AExponentBase64: string;
  const ASignatureBase64: string
): Boolean;
const
  CAlgorithmId: PWideChar = 'RSA';
  CBlobType: PWideChar = 'RSAPUBLICBLOB';
  CHashAlgorithmId: PWideChar = 'SHA256';
var
  LAlgorithm: BCRYPT_ALG_HANDLE;
  LBlob: TArray<Byte>;
  LExponent: TArray<Byte>;
  LHash: TArray<Byte>;
  LKey: BCRYPT_KEY_HANDLE;
  LModulus: TArray<Byte>;
  LPadding: TBcryptPkcs1PaddingInfo;
  LSignature: TArray<Byte>;
  LStatus: NTSTATUS;
begin
  LAlgorithm := nil;
  LKey := nil;
  LModulus := TNetEncoding.Base64.DecodeStringToBytes(
    AModulusBase64
  );
  LExponent := TNetEncoding.Base64.DecodeStringToBytes(
    AExponentBase64
  );
  LSignature := TNetEncoding.Base64.DecodeStringToBytes(
    ASignatureBase64
  );
  LBlob := BuildPublicKeyBlob(LModulus, LExponent);
  LHash := THashSHA2.GetHashBytes(AContent);
  LStatus := BCryptOpenAlgorithmProvider(
    LAlgorithm,
    CAlgorithmId,
    nil,
    0
  );
  if LStatus <> STATUS_SUCCESS then
    raise EInvalidOpException.Create(
      'Windows could not initialize the RSA verifier.'
    );
  try
    LStatus := BCryptImportKeyPair(
      LAlgorithm,
      nil,
      CBlobType,
      LKey,
      FirstByte(LBlob),
      Length(LBlob),
      0
    );
    if LStatus <> STATUS_SUCCESS then
      raise EArgumentException.Create('RSA public key is invalid.');
    try
      LPadding.AlgorithmId := CHashAlgorithmId;
      LStatus := BCryptVerifySignature(
        LKey,
        @LPadding,
        FirstByte(LHash),
        Length(LHash),
        FirstByte(LSignature),
        Length(LSignature),
        BCRYPT_PAD_PKCS1
      );
      Result := LStatus = STATUS_SUCCESS;
    finally
      BCryptDestroyKey(LKey);
    end;
  finally
    BCryptCloseAlgorithmProvider(LAlgorithm, 0);
  end;
end;

end.
