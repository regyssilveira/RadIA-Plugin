unit RadIA.OTA.DUnitX;

interface

uses
  RadIA.Core.DUnitX,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAOTADUnitXRunner = class(
    TInterfacedObject,
    IRadIADUnitXRunner
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    FCancelRequested: Integer;
    FRunning: Integer;
    FStatus: Integer;
    function BuildCommandLine(
      const AExecutablePath: string;
      const AReportPath: string;
      const ATests: TArray<string>
    ): string;
    function CreateArtifactPath(
      const ARootPath: string;
      const AExtension: string
    ): string;
    function ExecuteProcess(
      const ACommandLine: string;
      const AWorkingDirectory: string;
      const AOutputPath: string;
      const ATimeoutMs: Cardinal;
      out AExitCode: Cardinal;
      out ADurationMs: Int64
    ): TRadIADUnitXRunStatus;
    function ResolveExecutable(
      const ARequest: TRadIADUnitXRunRequest;
      out ARootPath: string;
      out AExecutablePath: string;
      out AError: TRadIADUnitXRunResult
    ): Boolean;
    procedure SetStatus(const AStatus: TRadIADUnitXRunStatus);
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function Execute(
      const ARequest: TRadIADUnitXRunRequest
    ): TRadIADUnitXRunResult;
    function Cancel: Boolean;
    function GetStatus: TRadIADUnitXRunStatus;
  end;

implementation

uses
  System.Diagnostics,
  System.IOUtils,
  System.SyncObjs,
  System.SysUtils,
  Winapi.Windows;

const
  CTestArtifactsDirectory = '.radia\test-results';

function QuoteArgument(const AValue: string): string;
begin
  Result := '"' + StringReplace(
    AValue,
    '"',
    '\"',
    [rfReplaceAll]
  ) + '"';
end;

{ TRadIAOTADUnitXRunner }

function TRadIAOTADUnitXRunner.BuildCommandLine(
  const AExecutablePath: string;
  const AReportPath: string;
  const ATests: TArray<string>
): string;
var
  LTest: string;
begin
  Result := QuoteArgument(AExecutablePath) +
    ' --hidebanner --consolemode:Off --loglevel:Error ' +
    '--xmlfile:' + QuoteArgument(AReportPath);
  for LTest in ATests do
    Result := Result + ' --run:' + QuoteArgument(LTest);
end;

function TRadIAOTADUnitXRunner.Cancel: Boolean;
begin
  Result := TInterlocked.CompareExchange(FRunning, 0, 0) <> 0;
  if Result then
    TInterlocked.Exchange(FCancelRequested, 1);
end;

constructor TRadIAOTADUnitXRunner.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FStatus := Ord(drsIdle);
end;

function TRadIAOTADUnitXRunner.CreateArtifactPath(
  const ARootPath: string;
  const AExtension: string
): string;
var
  LDirectory: string;
  LId: string;
begin
  LDirectory := TPath.Combine(
    ARootPath,
    CTestArtifactsDirectory
  );
  TDirectory.CreateDirectory(LDirectory);
  LId := TGUID.NewGuid.ToString;
  LId := LId.Replace('{', '').Replace('}', '');
  Result := TPath.Combine(
    LDirectory,
    'dunitx-' + LowerCase(LId) + AExtension
  );
end;

function TRadIAOTADUnitXRunner.Execute(
  const ARequest: TRadIADUnitXRunRequest
): TRadIADUnitXRunResult;
var
  LCommandLine: string;
  LDurationMs: Int64;
  LError: TRadIADUnitXRunResult;
  LExecutablePath: string;
  LExitCode: Cardinal;
  LOutput: string;
  LOutputPath: string;
  LParser: TRadIADUnitXReportParser;
  LReport: TRadIADUnitXReport;
  LReportPath: string;
  LRootPath: string;
  LStatus: TRadIADUnitXRunStatus;
begin
  if TInterlocked.CompareExchange(FRunning, 1, 0) <> 0 then
    Exit(TRadIADUnitXRunResult.Failed(
      drsFailed,
      'test_runner_busy',
      'Another DUnitX run is already active.'
    ));
  try
    try
      TInterlocked.Exchange(FCancelRequested, 0);
      SetStatus(drsRunning);
      if not ResolveExecutable(
      ARequest,
      LRootPath,
      LExecutablePath,
      LError
    ) then
      Exit(LError);

    LReportPath := CreateArtifactPath(LRootPath, '.xml');
    LOutputPath := CreateArtifactPath(LRootPath, '.log');
    LCommandLine := BuildCommandLine(
      LExecutablePath,
      LReportPath,
      ARequest.Tests
    );
    LStatus := ExecuteProcess(
      LCommandLine,
      ExtractFilePath(LExecutablePath),
      LOutputPath,
      ARequest.TimeoutMs,
      LExitCode,
      LDurationMs
    );
    SetStatus(LStatus);
    if LStatus = drsCancelled then
      Exit(TRadIADUnitXRunResult.Failed(
        LStatus,
        'test_run_cancelled',
        'DUnitX execution was cancelled.'
      ));
    if LStatus = drsTimedOut then
      Exit(TRadIADUnitXRunResult.Failed(
        LStatus,
        'test_run_timeout',
        'DUnitX execution exceeded its timeout.'
      ));
    if not TFile.Exists(LReportPath) then
      Exit(TRadIADUnitXRunResult.Failed(
        drsFailed,
        'test_report_missing',
        'The DUnitX process did not produce an NUnit XML report.'
      ));

    LOutput := '';
    if TFile.Exists(LOutputPath) then
      LOutput := TFile.ReadAllText(LOutputPath, TEncoding.UTF8);
    LParser := TRadIADUnitXReportParser.Create;
    try
      LReport := LParser.Parse(
        TFile.ReadAllText(LReportPath, TEncoding.UTF8)
      );
    finally
      LParser.Free;
    end;
    if LReport.AllPassed and (LExitCode = 0) then
      LStatus := drsSucceeded
    else
      LStatus := drsFailed;
    SetStatus(LStatus);
      Result := TRadIADUnitXRunResult.Completed(
        LStatus,
        LExitCode,
        LDurationMs,
        LReport,
        LOutput
      );
    except
      on E: Exception do
      begin
        SetStatus(drsFailed);
        Result := TRadIADUnitXRunResult.Failed(
          drsFailed,
          'test_runner_error',
          E.Message
        );
      end;
    end;
  finally
    TInterlocked.Exchange(FRunning, 0);
  end;
end;

function TRadIAOTADUnitXRunner.ExecuteProcess(
  const ACommandLine: string;
  const AWorkingDirectory: string;
  const AOutputPath: string;
  const ATimeoutMs: Cardinal;
  out AExitCode: Cardinal;
  out ADurationMs: Int64
): TRadIADUnitXRunStatus;
var
  LCommandLine: string;
  LOutputHandle: THandle;
  LProcessInfo: TProcessInformation;
  LSecurityAttributes: TSecurityAttributes;
  LStartupInfo: TStartupInfo;
  LStopwatch: System.Diagnostics.TStopwatch;
  LWaitResult: Cardinal;
begin
  AExitCode := Cardinal(-1);
  ADurationMs := 0;
  ZeroMemory(
    @LSecurityAttributes,
    SizeOf(LSecurityAttributes)
  );
  LSecurityAttributes.nLength := SizeOf(LSecurityAttributes);
  LSecurityAttributes.bInheritHandle := True;
  LOutputHandle := CreateFile(
    PChar(AOutputPath),
    GENERIC_WRITE,
    FILE_SHARE_READ,
    @LSecurityAttributes,
    CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL,
    0
  );
  if LOutputHandle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
    LStartupInfo.cb := SizeOf(LStartupInfo);
    LStartupInfo.dwFlags := STARTF_USESTDHANDLES;
    LStartupInfo.hStdOutput := LOutputHandle;
    LStartupInfo.hStdError := LOutputHandle;
    LStartupInfo.hStdInput := 0;
    ZeroMemory(@LProcessInfo, SizeOf(LProcessInfo));
    LCommandLine := ACommandLine;
    if not CreateProcess(
      nil,
      PChar(LCommandLine),
      nil,
      nil,
      True,
      CREATE_NO_WINDOW,
      nil,
      PChar(AWorkingDirectory),
      LStartupInfo,
      LProcessInfo
    ) then
      RaiseLastOSError;
    try
      LStopwatch := System.Diagnostics.TStopwatch.StartNew;
      repeat
        LWaitResult := WaitForSingleObject(LProcessInfo.hProcess, 25);
        if TInterlocked.CompareExchange(
          FCancelRequested,
          0,
          0
        ) <> 0 then
        begin
          TerminateProcess(LProcessInfo.hProcess, 2);
          Exit(drsCancelled);
        end;
        if LStopwatch.ElapsedMilliseconds >= ATimeoutMs then
        begin
          TerminateProcess(LProcessInfo.hProcess, 3);
          Exit(drsTimedOut);
        end;
      until LWaitResult <> WAIT_TIMEOUT;
      if LWaitResult <> WAIT_OBJECT_0 then
        RaiseLastOSError;
      GetExitCodeProcess(LProcessInfo.hProcess, AExitCode);
      Result := drsSucceeded;
    finally
      ADurationMs := LStopwatch.ElapsedMilliseconds;
      CloseHandle(LProcessInfo.hThread);
      CloseHandle(LProcessInfo.hProcess);
    end;
  finally
    CloseHandle(LOutputHandle);
  end;
end;

function TRadIAOTADUnitXRunner.GetStatus: TRadIADUnitXRunStatus;
begin
  Result := TRadIADUnitXRunStatus(
    TInterlocked.CompareExchange(FStatus, 0, 0)
  );
end;

function TRadIAOTADUnitXRunner.ResolveExecutable(
  const ARequest: TRadIADUnitXRunRequest;
  out ARootPath: string;
  out AExecutablePath: string;
  out AError: TRadIADUnitXRunResult
): Boolean;
var
  LProject: TRadIAProjectSnapshot;
  LValidation: TRadIAPathValidation;
begin
  Result := False;
  LProject := FWorkspace.GetActiveProject;
  ARootPath := LProject.RootPath;
  if Trim(ARootPath) = '' then
  begin
    AError := TRadIADUnitXRunResult.Failed(
      drsFailed,
      'no_active_project',
      'An active Delphi project is required to run tests.'
    );
    Exit;
  end;
  LValidation := FBoundary.ValidatePath(
    ARootPath,
    ARequest.ExecutablePath
  );
  if not LValidation.Allowed then
  begin
    AError := TRadIADUnitXRunResult.Failed(
      drsFailed,
      LValidation.ErrorCode,
      LValidation.ErrorMessage
    );
    Exit;
  end;
  AExecutablePath := LValidation.ResolvedPath;
  if not SameText(ExtractFileExt(AExecutablePath), '.exe') then
  begin
    AError := TRadIADUnitXRunResult.Failed(
      drsFailed,
      'invalid_test_executable',
      'Only Windows .exe test runners are allowed.'
    );
    Exit;
  end;
  if not TFile.Exists(AExecutablePath) then
  begin
    AError := TRadIADUnitXRunResult.Failed(
      drsFailed,
      'test_executable_not_found',
      'The DUnitX test executable does not exist.'
    );
    Exit;
  end;
  Result := True;
end;

procedure TRadIAOTADUnitXRunner.SetStatus(
  const AStatus: TRadIADUnitXRunStatus
);
begin
  TInterlocked.Exchange(FStatus, Ord(AStatus));
end;

end.
