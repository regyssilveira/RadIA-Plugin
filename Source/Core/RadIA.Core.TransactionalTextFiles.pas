unit RadIA.Core.TransactionalTextFiles;

interface

type
  TRadIATransactionalTextFile = class sealed
  public
    class function Apply(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean; static;
    class function Read(
      const AFileName: string;
      out AContent: string
    ): Boolean; static;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows;

function IsBinaryForm(const AFileName: string; const ABytes: TBytes): Boolean;
begin
  Result := SameText(ExtractFileExt(AFileName), '.dfm') and
    (Length(ABytes) >= 4) and (ABytes[0] = Ord('T')) and
    (ABytes[1] = Ord('P')) and (ABytes[2] = Ord('F')) and
    (ABytes[3] = Ord('0'));
end;

function DecodeText(
  const AFileName: string;
  out AContent: string;
  out AHasUtf8Preamble: Boolean
): Boolean;
var
  LBytes: TBytes;
begin
  Result := False;
  AContent := '';
  AHasUtf8Preamble := False;
  if not TFile.Exists(AFileName) then
    Exit;
  LBytes := TFile.ReadAllBytes(AFileName);
  if IsBinaryForm(AFileName, LBytes) then
    Exit;
  AHasUtf8Preamble := (Length(LBytes) >= 3) and
    (LBytes[0] = $EF) and (LBytes[1] = $BB) and (LBytes[2] = $BF);
  if AHasUtf8Preamble then
    AContent := TEncoding.UTF8.GetString(LBytes, 3, Length(LBytes) - 3)
  else
    AContent := TEncoding.UTF8.GetString(LBytes);
  Result := True;
end;

function EncodeText(
  const AContent: string;
  const AHasUtf8Preamble: Boolean
): TBytes;
var
  LContentBytes: TBytes;
begin
  LContentBytes := TEncoding.UTF8.GetBytes(AContent);
  if AHasUtf8Preamble then
    Result := TEncoding.UTF8.GetPreamble + LContentBytes
  else
    Result := LContentBytes;
end;

class function TRadIATransactionalTextFile.Apply(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
var
  LCurrentContent: string;
  LHasUtf8Preamble: Boolean;
  LTemporaryFile: string;
begin
  Result := False;
  AAppliedRevision := '';
  if not DecodeText(AFileName, LCurrentContent, LHasUtf8Preamble) then
    Exit;
  AAppliedRevision := THashSHA2.GetHashString(LCurrentContent);
  if not SameText(AAppliedRevision, AExpectedRevision) then
    Exit;
  LTemporaryFile := AFileName + '.radia-' + TGUID.NewGuid.ToString + '.tmp';
  try
    TFile.WriteAllBytes(
      LTemporaryFile,
      EncodeText(ANewContent, LHasUtf8Preamble)
    );
    Result := MoveFileEx(
      PChar(LTemporaryFile),
      PChar(AFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    );
    if Result then
      AAppliedRevision := THashSHA2.GetHashString(ANewContent);
  finally
    if TFile.Exists(LTemporaryFile) then
      TFile.Delete(LTemporaryFile);
  end;
end;

class function TRadIATransactionalTextFile.Read(
  const AFileName: string;
  out AContent: string
): Boolean;
var
  LHasUtf8Preamble: Boolean;
begin
  Result := DecodeText(AFileName, AContent, LHasUtf8Preamble);
end;

end.
