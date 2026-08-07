unit RadIA.OTA.RuntimeProcess;

interface

function TryGetRadIARuntimeProcessIdentity(
  const AProcessId: LongWord;
  out AExecutablePath: string;
  out ACreatedAtUtc: TDateTime
): Boolean;

function GetRadIARuntimeBuildId(
  const AExecutablePath: string
): string;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows;

const
  CRadIAProcessQueryLimitedInformation = $1000;

function QueryFullProcessImageNameW(
  AProcess: THandle;
  AFlags: DWORD;
  AExecutableName: PWideChar;
  var ASize: DWORD
): BOOL; stdcall;
  external kernel32 name 'QueryFullProcessImageNameW';

function FileTimeToDateTimeUtc(
  const AFileTime: TFileTime;
  out ADateTime: TDateTime
): Boolean;
var
  LSystemTime: TSystemTime;
begin
  Result := FileTimeToSystemTime(AFileTime, LSystemTime);
  if Result then
    ADateTime := SystemTimeToDateTime(LSystemTime)
  else
    ADateTime := 0;
end;

function QueryExecutablePath(
  const AProcessHandle: THandle;
  out AExecutablePath: string
): Boolean;
var
  LBuffer: TArray<Char>;
  LLength: DWORD;
begin
  SetLength(LBuffer, 32768);
  LLength := Length(LBuffer);
  Result := QueryFullProcessImageNameW(
    AProcessHandle,
    0,
    PChar(LBuffer),
    LLength
  );
  if Result then
    SetString(AExecutablePath, PChar(LBuffer), LLength)
  else
    AExecutablePath := '';
end;

function TryGetRadIARuntimeProcessIdentity(
  const AProcessId: LongWord;
  out AExecutablePath: string;
  out ACreatedAtUtc: TDateTime
): Boolean;
var
  LCreationTime: TFileTime;
  LExitTime: TFileTime;
  LKernelTime: TFileTime;
  LProcessHandle: THandle;
  LUserTime: TFileTime;
begin
  AExecutablePath := '';
  ACreatedAtUtc := 0;
  LProcessHandle := OpenProcess(
    CRadIAProcessQueryLimitedInformation,
    False,
    AProcessId
  );
  if LProcessHandle = 0 then
    Exit(False);
  try
    Result :=
      QueryExecutablePath(LProcessHandle, AExecutablePath) and
      GetProcessTimes(
        LProcessHandle,
        LCreationTime,
        LExitTime,
        LKernelTime,
        LUserTime
      ) and
      FileTimeToDateTimeUtc(LCreationTime, ACreatedAtUtc);
  finally
    CloseHandle(LProcessHandle);
  end;
end;

function GetRadIARuntimeBuildId(
  const AExecutablePath: string
): string;
var
  LModifiedUtc: TDateTime;
  LSize: Int64;
begin
  Result := '';
  if not FileExists(AExecutablePath) then
    Exit;
  LSize := TFile.GetSize(AExecutablePath);
  LModifiedUtc := TFile.GetLastWriteTimeUtc(AExecutablePath);
  Result := Format(
    '%d:%s',
    [LSize, DateToISO8601(LModifiedUtc, True)]
  );
end;

end.
