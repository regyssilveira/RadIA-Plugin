unit RadIA.OTA.RuntimePerformance;

interface

uses
  RadIA.Core.RuntimePerformance;

type
  TRadIAWindowsRuntimePerformanceSampler = class(
    TInterfacedObject,
    IRadIARuntimePerformanceSampler
  )
  private
    FWorker: TObject;
  public
    destructor Destroy; override;
    function BeginMeasurement(
      const AProcessId: LongWord;
      const AMaximumDurationMs: Cardinal;
      out AErrorMessage: string
    ): Boolean;
    function CompleteMeasurement(
      out ASummary: TRadIARuntimePerformanceSummary;
      out AErrorMessage: string
    ): Boolean;
    procedure CancelMeasurement;
  end;

implementation

uses
  System.Classes,
  Winapi.Messages,
  Winapi.PsAPI,
  Winapi.Windows;

const
  CSampleIntervalMs = 100;
  CResponsivenessTimeoutMs = 50;

type
  TRadIARuntimeWindowSearch = record
    ProcessId: LongWord;
    WindowHandle: HWND;
  end;
  PRadIARuntimeWindowSearch = ^TRadIARuntimeWindowSearch;

  TRadIARuntimePerformanceWorker = class(TThread)
  private
    FCpuStartMs: UInt64;
    FCpuTimeMs: UInt64;
    FDurationMs: UInt64;
    FErrorMessage: string;
    FMaximumDurationMs: Cardinal;
    FPeakPrivateBytes: UInt64;
    FPeakWorkingSetBytes: UInt64;
    FProcessHandle: THandle;
    FSampleCount: Integer;
    FStartedAt: UInt64;
    FUnresponsiveSamples: Integer;
    function CaptureCpuTimeMs: UInt64;
    function FindMainWindow: HWND;
    function IsWindowResponsive(const AWindow: HWND): Boolean;
    procedure Sample;
  protected
    procedure Execute; override;
  public
    constructor Create(
      const AProcessId: LongWord;
      const AMaximumDurationMs: Cardinal
    );
    destructor Destroy; override;
    function BuildSummary: TRadIARuntimePerformanceSummary;
    property ErrorMessage: string read FErrorMessage;
    property ProcessHandle: THandle read FProcessHandle;
  end;

function EnumerateRuntimeWindow(
  const AWindow: HWND;
  const AParameter: LPARAM
): BOOL; stdcall;
var
  LProcessId: LongWord;
  LSearch: PRadIARuntimeWindowSearch;
begin
  LSearch := PRadIARuntimeWindowSearch(AParameter);
  LProcessId := 0;
  GetWindowThreadProcessId(AWindow, @LProcessId);
  if (LProcessId = LSearch.ProcessId) and IsWindowVisible(AWindow) and
    (GetWindow(AWindow, GW_OWNER) = 0) then
  begin
    LSearch.WindowHandle := AWindow;
    Exit(False);
  end;
  Result := True;
end;

constructor TRadIARuntimePerformanceWorker.Create(
  const AProcessId: LongWord;
  const AMaximumDurationMs: Cardinal
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMaximumDurationMs := AMaximumDurationMs;
  FProcessHandle := OpenProcess(
    PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,
    False,
    AProcessId
  );
  if FProcessHandle <> 0 then
  begin
    FStartedAt := GetTickCount64;
    FCpuStartMs := CaptureCpuTimeMs;
  end;
end;

destructor TRadIARuntimePerformanceWorker.Destroy;
begin
  if FProcessHandle <> 0 then
    CloseHandle(FProcessHandle);
  inherited Destroy;
end;

function FileTimeToUInt64(const AValue: TFileTime): UInt64;
begin
  Result := (UInt64(AValue.dwHighDateTime) shl 32) or AValue.dwLowDateTime;
end;

function TRadIARuntimePerformanceWorker.CaptureCpuTimeMs: UInt64;
var
  LCreationTime: TFileTime;
  LExitTime: TFileTime;
  LKernelTime: TFileTime;
  LUserTime: TFileTime;
begin
  Result := 0;
  if GetProcessTimes(
    FProcessHandle,
    LCreationTime,
    LExitTime,
    LKernelTime,
    LUserTime
  ) then
    Result := (
      FileTimeToUInt64(LKernelTime) + FileTimeToUInt64(LUserTime)
    ) div 10000;
end;

function TRadIARuntimePerformanceWorker.FindMainWindow: HWND;
var
  LProcessId: LongWord;
  LSearch: TRadIARuntimeWindowSearch;
begin
  LProcessId := GetProcessId(FProcessHandle);
  LSearch.ProcessId := LProcessId;
  LSearch.WindowHandle := 0;
  EnumWindows(@EnumerateRuntimeWindow, LPARAM(@LSearch));
  Result := LSearch.WindowHandle;
end;

function TRadIARuntimePerformanceWorker.IsWindowResponsive(
  const AWindow: HWND
): Boolean;
var
  LResult: DWORD_PTR;
begin
  if AWindow = 0 then
    Exit(True);
  LResult := 0;
  Result := SendMessageTimeout(
    AWindow,
    WM_NULL,
    0,
    0,
    SMTO_ABORTIFHUNG or SMTO_BLOCK,
    CResponsivenessTimeoutMs,
    @LResult
  ) <> 0;
end;

procedure TRadIARuntimePerformanceWorker.Sample;
var
  LCounters: TProcessMemoryCountersEx;
  LWindow: HWND;
begin
  ZeroMemory(@LCounters, SizeOf(LCounters));
  LCounters.cb := SizeOf(LCounters);
  if GetProcessMemoryInfo(
    FProcessHandle,
    @LCounters,
    SizeOf(LCounters)
  ) then
  begin
    if LCounters.WorkingSetSize > FPeakWorkingSetBytes then
      FPeakWorkingSetBytes := LCounters.WorkingSetSize;
    if LCounters.PrivateUsage > FPeakPrivateBytes then
      FPeakPrivateBytes := LCounters.PrivateUsage;
  end;
  LWindow := FindMainWindow;
  if not IsWindowResponsive(LWindow) then
    Inc(FUnresponsiveSamples);
  Inc(FSampleCount);
end;

procedure TRadIARuntimePerformanceWorker.Execute;
var
  LCpuEndMs: UInt64;
  LElapsed: UInt64;
begin
  while not Terminated do
  begin
    if WaitForSingleObject(FProcessHandle, 0) = WAIT_OBJECT_0 then
      Break;
    LElapsed := GetTickCount64 - FStartedAt;
    if LElapsed >= FMaximumDurationMs then
    begin
      FErrorMessage := 'Runtime performance measurement reached its maximum duration.';
      Break;
    end;
    Sample;
    Sleep(CSampleIntervalMs);
  end;
  FDurationMs := GetTickCount64 - FStartedAt;
  LCpuEndMs := CaptureCpuTimeMs;
  if LCpuEndMs >= FCpuStartMs then
    FCpuTimeMs := LCpuEndMs - FCpuStartMs
  else
    FCpuTimeMs := 0;
end;

function TRadIARuntimePerformanceWorker.BuildSummary:
  TRadIARuntimePerformanceSummary;
begin
  Result := TRadIARuntimePerformanceSummary.Create(
    FDurationMs,
    FCpuTimeMs,
    FPeakWorkingSetBytes,
    FPeakPrivateBytes,
    FSampleCount,
    FUnresponsiveSamples
  );
end;

destructor TRadIAWindowsRuntimePerformanceSampler.Destroy;
begin
  CancelMeasurement;
  inherited Destroy;
end;

function TRadIAWindowsRuntimePerformanceSampler.BeginMeasurement(
  const AProcessId: LongWord;
  const AMaximumDurationMs: Cardinal;
  out AErrorMessage: string
): Boolean;
var
  LWorker: TRadIARuntimePerformanceWorker;
begin
  AErrorMessage := '';
  if Assigned(FWorker) then
  begin
    AErrorMessage := 'A runtime performance measurement is already active.';
    Exit(False);
  end;
  LWorker := TRadIARuntimePerformanceWorker.Create(
    AProcessId,
    AMaximumDurationMs
  );
  if LWorker.ProcessHandle = 0 then
  begin
    LWorker.Free;
    AErrorMessage := 'The runtime process could not be opened for bounded sampling.';
    Exit(False);
  end;
  FWorker := LWorker;
  LWorker.Start;
  Result := True;
end;

function TRadIAWindowsRuntimePerformanceSampler.CompleteMeasurement(
  out ASummary: TRadIARuntimePerformanceSummary;
  out AErrorMessage: string
): Boolean;
var
  LWorker: TRadIARuntimePerformanceWorker;
begin
  ASummary := Default(TRadIARuntimePerformanceSummary);
  AErrorMessage := '';
  if not Assigned(FWorker) then
  begin
    AErrorMessage := 'No runtime performance measurement is active.';
    Exit(False);
  end;
  LWorker := TRadIARuntimePerformanceWorker(FWorker);
  LWorker.Terminate;
  LWorker.WaitFor;
  AErrorMessage := LWorker.ErrorMessage;
  ASummary := LWorker.BuildSummary;
  LWorker.Free;
  FWorker := nil;
  Result := AErrorMessage = '';
end;

procedure TRadIAWindowsRuntimePerformanceSampler.CancelMeasurement;
var
  LWorker: TRadIARuntimePerformanceWorker;
begin
  if not Assigned(FWorker) then
    Exit;
  LWorker := TRadIARuntimePerformanceWorker(FWorker);
  LWorker.Terminate;
  LWorker.WaitFor;
  LWorker.Free;
  FWorker := nil;
end;

end.
