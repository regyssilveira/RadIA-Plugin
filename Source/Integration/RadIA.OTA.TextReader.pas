unit RadIA.OTA.TextReader;

interface

uses
  ToolsAPI;

function ReadRadIAEditReaderText(
  const AEditReader: IOTAEditReader
): string;

implementation

uses
  System.SysUtils;

const
  CEditReaderChunkSize = 8192;

function ReadRadIAEditReaderText(
  const AEditReader: IOTAEditReader
): string;
var
  LBuffer: TBytes;
  LBytesRead: Integer;
  LOffset: Integer;
  LTextBytes: TBytes;
begin
  Result := '';
  if not Assigned(AEditReader) then
    Exit;

  SetLength(LBuffer, CEditReaderChunkSize);
  LOffset := 0;
  repeat
    LBytesRead := AEditReader.GetText(
      LOffset,
      PAnsiChar(@LBuffer[0]),
      CEditReaderChunkSize
    );
    if LBytesRead > 0 then
    begin
      SetLength(LTextBytes, Length(LTextBytes) + LBytesRead);
      Move(
        LBuffer[0],
        LTextBytes[Length(LTextBytes) - LBytesRead],
        LBytesRead
      );
      Inc(LOffset, LBytesRead);
    end;
  until LBytesRead < CEditReaderChunkSize;

  if Length(LTextBytes) = 0 then
    Exit;
  Result := TEncoding.UTF8.GetString(LTextBytes);
  if (Length(Result) > 0) and
    (Result[High(Result)] = #0) then
    SetLength(Result, Length(Result) - 1);
end;

end.
