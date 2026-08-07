program RadIAMemoryLab;

{$APPTYPE CONSOLE}

uses
  FastMM5,
  System.Classes,
  System.Generics.Collections,
  System.SysUtils;

var
  GLeakedObject: TObject;

procedure RunCleanCase;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.Add('clean');
  finally
    LList.Free;
  end;
end;

procedure RunLeakCase;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  LList.Add('deterministic leak');
  GLeakedObject := LList;
end;

procedure RunTransientGrowthCase;
var
  I: Integer;
  LItems: TObjectList<TStringList>;
  LList: TStringList;
begin
  LItems := TObjectList<TStringList>.Create(True);
  try
    for I := 1 to 1000 do
    begin
      LList := TStringList.Create;
      LList.Add('transient allocation');
      LItems.Add(LList);
    end;
  finally
    LItems.Free;
  end;
end;

procedure RunDoubleFreeCase;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  LList.Free;
  LList.Free;
end;

procedure RunUseAfterFreeCase;
var
  LList: TStringList;
begin
  LList := TStringList.Create;
  LList.Add('released');
  LList.Free;
  LList.Add('invalid');
end;

procedure RunMemoryLabCase(const AMode: string);
begin
  if SameText(AMode, 'clean') then
    RunCleanCase
  else if SameText(AMode, 'leak') then
    RunLeakCase
  else if SameText(AMode, 'transient') then
    RunTransientGrowthCase
  else if SameText(AMode, 'double-free') then
    RunDoubleFreeCase
  else if SameText(AMode, 'use-after-free') then
    RunUseAfterFreeCase
  else
    raise EArgumentException.CreateFmt(
      'Unsupported memory laboratory mode: %s',
      [AMode]
    );
end;

function ReadOptionValue(
  const AName: string;
  const ADefaultValue: string
): string;
var
  I: Integer;
begin
  Result := ADefaultValue;
  for I := 1 to ParamCount - 1 do
    if SameText(ParamStr(I), AName) then
      Exit(ParamStr(I + 1));
end;

procedure ConfigureDiagnostics;
var
  LLogPath: string;
begin
  LLogPath := ReadOptionValue(
    '--log',
    ChangeFileExt(ParamStr(0), '.memory.log')
  );
  FastMM_SetEventLogFilename(PWideChar(LLogPath));
  FastMM_LogToFileEvents := [
    mmetUnexpectedMemoryLeakDetail,
    mmetUnexpectedMemoryLeakSummary,
    mmetDebugBlockDoubleFree,
    mmetDebugBlockReallocOfFreedBlock,
    mmetDebugBlockHeaderCorruption,
    mmetDebugBlockFooterCorruption,
    mmetDebugBlockModifiedAfterFree,
    mmetVirtualMethodCallOnFreedObject
  ];
  FastMM_MessageBoxEvents := [];
  FastMM_OutputDebugStringEvents := FastMM_LogToFileEvents;
  FastMM_EnterDebugMode;
end;

var
  LMode: string;
begin
  GLeakedObject := nil;
  ConfigureDiagnostics;
  LMode := ReadOptionValue('--mode', 'clean');
  RunMemoryLabCase(LMode);
end.
