unit RadIA.Core.MemoryDiagnostics;

interface

type
  TRadIAMemoryBackendKind = (
    mbkNone,
    mbkFastMM5
  );

  TRadIAMemoryBackendState = (
    mbsUnavailable,
    mbsInvalid,
    mbsIncompatible,
    mbsReady
  );

  TRadIAMemoryEventKind = (
    mekLeak,
    mekDoubleFree,
    mekUseAfterFree,
    mekHeaderCorruption,
    mekFooterCorruption,
    mekSnapshotGrowth
  );

  TRadIAMemoryComparisonOutcome = (
    mcoIncomparable,
    mcoFixed,
    mcoImproved,
    mcoUnchanged,
    mcoRegressed
  );

  TRadIAMemoryDiagnosticsLimits = record
  private
    FMaxDurationMs: Integer;
    FMaxLogBytes: Int64;
    FMaxRepetitions: Integer;
  public
    constructor Create(
      const AMaxDurationMs: Integer;
      const AMaxLogBytes: Int64;
      const AMaxRepetitions: Integer
    );
    function IsValid: Boolean;
    property MaxDurationMs: Integer read FMaxDurationMs;
    property MaxLogBytes: Int64 read FMaxLogBytes;
    property MaxRepetitions: Integer read FMaxRepetitions;
  end;

  TRadIAMemoryBackendStatus = record
  private
    FBackend: TRadIAMemoryBackendKind;
    FBackendVersion: string;
    FDebugLibraryPath: string;
    FMessage: string;
    FRootPath: string;
    FState: TRadIAMemoryBackendState;
    FTargetPlatform: string;
  public
    constructor Create(
      const ABackend: TRadIAMemoryBackendKind;
      const AState: TRadIAMemoryBackendState;
      const ABackendVersion: string;
      const ARootPath: string;
      const ADebugLibraryPath: string;
      const ATargetPlatform: string;
      const AMessage: string
    );
    function IsReady: Boolean;
    property Backend: TRadIAMemoryBackendKind read FBackend;
    property BackendVersion: string read FBackendVersion;
    property DebugLibraryPath: string read FDebugLibraryPath;
    property Message: string read FMessage;
    property RootPath: string read FRootPath;
    property State: TRadIAMemoryBackendState read FState;
    property TargetPlatform: string read FTargetPlatform;
  end;

function RadIAMemoryEventKindToString(
  const AValue: TRadIAMemoryEventKind
): string;
function RadIAMemoryComparisonOutcomeToString(
  const AValue: TRadIAMemoryComparisonOutcome
): string;

implementation

uses
  System.SysUtils;

constructor TRadIAMemoryDiagnosticsLimits.Create(
  const AMaxDurationMs: Integer;
  const AMaxLogBytes: Int64;
  const AMaxRepetitions: Integer
);
begin
  FMaxDurationMs := AMaxDurationMs;
  FMaxLogBytes := AMaxLogBytes;
  FMaxRepetitions := AMaxRepetitions;
end;

function TRadIAMemoryDiagnosticsLimits.IsValid: Boolean;
begin
  Result :=
    (MaxDurationMs >= 1000) and
    (MaxDurationMs <= 1800000) and
    (MaxLogBytes >= 1024) and
    (MaxLogBytes <= 1073741824) and
    (MaxRepetitions >= 1) and
    (MaxRepetitions <= 50);
end;

constructor TRadIAMemoryBackendStatus.Create(
  const ABackend: TRadIAMemoryBackendKind;
  const AState: TRadIAMemoryBackendState;
  const ABackendVersion: string;
  const ARootPath: string;
  const ADebugLibraryPath: string;
  const ATargetPlatform: string;
  const AMessage: string
);
begin
  FBackend := ABackend;
  FState := AState;
  FBackendVersion := ABackendVersion;
  FRootPath := ARootPath;
  FDebugLibraryPath := ADebugLibraryPath;
  FTargetPlatform := ATargetPlatform;
  FMessage := AMessage;
end;

function TRadIAMemoryBackendStatus.IsReady: Boolean;
begin
  Result :=
    (Backend <> mbkNone) and
    (State = mbsReady) and
    (Trim(BackendVersion) <> '') and
    (Trim(RootPath) <> '') and
    (Trim(DebugLibraryPath) <> '') and
    (Trim(TargetPlatform) <> '') and
    (Trim(Message) <> '');
end;

function RadIAMemoryEventKindToString(
  const AValue: TRadIAMemoryEventKind
): string;
const
  CNames: array[TRadIAMemoryEventKind] of string = (
    'leak',
    'doubleFree',
    'useAfterFree',
    'headerCorruption',
    'footerCorruption',
    'snapshotGrowth'
  );
begin
  Result := CNames[AValue];
end;

function RadIAMemoryComparisonOutcomeToString(
  const AValue: TRadIAMemoryComparisonOutcome
): string;
const
  CNames: array[TRadIAMemoryComparisonOutcome] of string = (
    'incomparable',
    'fixed',
    'improved',
    'unchanged',
    'regressed'
  );
begin
  Result := CNames[AValue];
end;

end.
