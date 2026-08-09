unit RadIA.Core.CredentialProtector;

interface

type
  TCredentialProtector = record
  public
    class function CleanApiKey(const AValue: string): string; static;
    class function Protect(const AValue: string): string; static;
    class function ProtectText(const AValue: string): string; static;
    class function Unprotect(const AValue: string): string; static;
    class function UnprotectText(const AValue: string): string; static;
  end;

implementation

uses
  Winapi.Windows, System.NetEncoding, RadIA.Core.Logger, System.SysUtils;

type
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDataBlob = ^TDataBlob;

function CryptProtectData(APDataIn: PDataBlob; ASzDataDescr: LPCWSTR;
  APOptionalEntropy: PDataBlob; APvReserved: Pointer;
  APPromptStruct: Pointer; ADwFlags: DWORD;
  APDataOut: PDataBlob): BOOL; stdcall; external 'crypt32.dll';

function CryptUnprotectData(APDataIn: PDataBlob; APpszDataDescr: Pointer;
  APOptionalEntropy: PDataBlob; APvReserved: Pointer;
  APPromptStruct: Pointer; ADwFlags: DWORD;
  APDataOut: PDataBlob): BOOL; stdcall; external 'crypt32.dll';

procedure LogDebug(const AMsg: string);
begin
  TLogger.Log(AMsg, 'Config');
end;

class function TCredentialProtector.CleanApiKey(const AValue: string): string;
var
  I: Integer;
  LChar: Char;
begin
  Result := '';
  for I := Low(AValue) to High(AValue) do
  begin
    LChar := AValue[I];
    if ((LChar >= 'a') and (LChar <= 'z')) or
       ((LChar >= 'A') and (LChar <= 'Z')) or
       ((LChar >= '0') and (LChar <= '9')) or
       (LChar = '.') or (LChar = '-') or (LChar = '_') or
       (LChar = '/') or (LChar = '+') or (LChar = '=') or
       (LChar = '@') or (LChar = ':') then
    begin
      Result := Result + LChar;
    end;
  end;
end;

class function TCredentialProtector.Protect(const AValue: string): string;
begin
  Result := ProtectText(AValue);
end;

class function TCredentialProtector.ProtectText(const AValue: string): string;
var
  LInBlob: TDataBlob;
  LOutBlob: TDataBlob;
  LBytes: TBytes;
begin
  Result := '';
  if AValue.IsEmpty then
    Exit;

  LBytes := TEncoding.UTF8.GetBytes(AValue);
  LInBlob.cbData := Length(LBytes);
  LInBlob.pbData := @LBytes[0];

  if CryptProtectData(@LInBlob, nil, nil, nil, nil, 0, @LOutBlob) then
  begin
    try
      Result := TNetEncoding.Base64.EncodeBytesToString(LOutBlob.pbData, LOutBlob.cbData);
      Result := Result.Replace(#13, '').Replace(#10, '');
    finally
      LocalFree(HLOCAL(LOutBlob.pbData));
    end;
  end;
end;

class function TCredentialProtector.Unprotect(const AValue: string): string;
begin
  Result := CleanApiKey(UnprotectText(AValue));
end;

class function TCredentialProtector.UnprotectText(const AValue: string): string;
var
  LInBlob: TDataBlob;
  LOutBlob: TDataBlob;
  LBytes: TBytes;
begin
  Result := '';
  if AValue.IsEmpty then
    Exit;

  LogDebug('TCredentialProtector.Unprotect: Input string length: ' + IntToStr(Length(AValue)));
  try
    LBytes := TNetEncoding.Base64.DecodeStringToBytes(AValue);
  except
    on E: Exception do
    begin
      LogDebug('TCredentialProtector.Unprotect: Base64 decode failed: ' + E.Message);
      Exit;
    end;
  end;

  if Length(LBytes) = 0 then
  begin
    LogDebug('TCredentialProtector.Unprotect: Base64 decoded bytes length is 0');
    Exit;
  end;

  LInBlob.cbData := Length(LBytes);
  LInBlob.pbData := @LBytes[0];

  if CryptUnprotectData(@LInBlob, nil, nil, nil, nil, 0, @LOutBlob) then
  begin
    try
      SetLength(LBytes, LOutBlob.cbData);
      Move(LOutBlob.pbData^, LBytes[0], LOutBlob.cbData);
      Result := TEncoding.UTF8.GetString(LBytes);
      LogDebug('TCredentialProtector.UnprotectText: Decrypted successfully.');
    finally
      LocalFree(HLOCAL(LOutBlob.pbData));
    end;
  end;
end;

end.
