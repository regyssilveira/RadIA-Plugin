unit RadIA.OTA.Build;

interface

uses
  System.Classes,
  System.SyncObjs,
  RadIA.Core.Build,
  RadIA.Core.Workspace;

type
  IRadIACompileWaiter = interface
    ['{ACB8C694-0644-461F-8F62-657DE7D07E02}']
    function WaitFor(const ATimeoutMs: Cardinal): TWaitResult;
    function GetCompileResult: Integer;
  end;

  TRadIAOTABuildFacade = class(
    TInterfacedObject,
    IRadIABuildFacade
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FRunning: Integer;
    FStatus: Integer;
    function BuildOnMainThread(
      const ARequest: TRadIABuildRequest;
      out ANotifier: IRadIACompileWaiter;
      out ACompileResult: Integer;
      out ANotifierIndex: Integer
    ): Boolean;
    function CompileMode(
      const AMode: TRadIABuildMode
    ): Integer;
    procedure RemoveNotifier(
      const ANotifierIndex: Integer
    );
    procedure RunOnMainThread(const AAction: TThreadProcedure);
    procedure SetStatus(const AStatus: TRadIABuildStatus);
    function WaitForCompletion(
      const ANotifier: IRadIACompileWaiter;
      const ATimeoutMs: Cardinal
    ): TRadIABuildStatus;
  public
    constructor Create(const AWorkspace: IRadIAWorkspaceFacade);
    function Execute(
      const ARequest: TRadIABuildRequest
    ): TRadIABuildResult;
    function Cancel: Boolean;
    function GetStatus: TRadIABuildStatus;
  end;

implementation

uses
  System.Diagnostics,
  System.SysUtils,
  ToolsAPI,
  Winapi.Windows,
  RadIA.Core.Types;

const
  CBuildBusy = 'build_busy';
  CBuildTimeout = 'build_timeout';
  CNoActiveProject = 'no_active_project';
  CUnsupported = 'build_unsupported';

type
  TRadIACompileNotifier = class(
    TInterfacedObject,
    IOTACompileNotifier,
    IRadIACompileWaiter
  )
  private
    FEvent: TEvent;
    FResult: TOTACompileResult;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ProjectCompileStarted(
      const Project: IOTAProject;
      Mode: TOTACompileMode
    );
    procedure ProjectCompileFinished(
      const Project: IOTAProject;
      Result: TOTACompileResult
    );
    procedure ProjectGroupCompileStarted(Mode: TOTACompileMode);
    procedure ProjectGroupCompileFinished(
      Result: TOTACompileResult
    );
    function GetCompileResult: Integer;
    function WaitFor(const ATimeoutMs: Cardinal): TWaitResult;
  end;

{ TRadIACompileNotifier }

constructor TRadIACompileNotifier.Create;
begin
  inherited Create;
  FEvent := TEvent.Create(nil, True, False, '');
  FResult := crOTAFailed;
end;

destructor TRadIACompileNotifier.Destroy;
begin
  FEvent.Free;
  inherited;
end;

procedure TRadIACompileNotifier.ProjectCompileFinished(
  const Project: IOTAProject;
  Result: TOTACompileResult
);
begin
  FResult := Result;
  FEvent.SetEvent;
end;

procedure TRadIACompileNotifier.ProjectCompileStarted(
  const Project: IOTAProject;
  Mode: TOTACompileMode
);
begin
  FEvent.ResetEvent;
end;

procedure TRadIACompileNotifier.ProjectGroupCompileFinished(
  Result: TOTACompileResult
);
begin
  FResult := Result;
  FEvent.SetEvent;
end;

procedure TRadIACompileNotifier.ProjectGroupCompileStarted(
  Mode: TOTACompileMode
);
begin
  FEvent.ResetEvent;
end;

function TRadIACompileNotifier.GetCompileResult: Integer;
begin
  Result := Ord(FResult);
end;

function TRadIACompileNotifier.WaitFor(
  const ATimeoutMs: Cardinal
): TWaitResult;
begin
  Result := FEvent.WaitFor(ATimeoutMs);
end;

{ TRadIAOTABuildFacade }

function TRadIAOTABuildFacade.BuildOnMainThread(
  const ARequest: TRadIABuildRequest;
  out ANotifier: IRadIACompileWaiter;
  out ACompileResult: Integer;
  out ANotifierIndex: Integer
): Boolean;
var
  LCompileResult: TOTACompileResult;
  LNotifier: TRadIACompileNotifier;
  LNotifierInterface: IOTACompileNotifier;
  LNotifierIndex: Integer;
  LResult: Boolean;
  LWaiter: IRadIACompileWaiter;
begin
  ANotifier := nil;
  ACompileResult := Ord(crOTAFailed);
  ANotifierIndex := -1;
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LCompileServices: IOTACompileServices;
      LProject: IOTAProject;
      LModuleServices: IOTAModuleServices;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTACompileServices,
        LCompileServices
      ) then
        Exit;
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;

      LProject := LModuleServices.GetActiveProject;
      if not Assigned(LProject) then
        Exit;

      LNotifier := TRadIACompileNotifier.Create;
      LNotifierInterface := LNotifier;
      LNotifierIndex := LCompileServices.AddNotifier(
        LNotifierInterface
      );
      if LNotifierIndex < 0 then
        Exit;

      LCompileResult := LCompileServices.CompileProjects(
        [LProject],
        TOTACompileMode(CompileMode(ARequest.Mode)),
        False,
        ARequest.ClearMessages
      );
      LWaiter := LNotifier;
      LResult := True;
    end
  );
  if LResult then
  begin
    ANotifier := LWaiter;
    ACompileResult := Ord(LCompileResult);
    ANotifierIndex := LNotifierIndex;
  end;
  Result := LResult;
end;

function TRadIAOTABuildFacade.Cancel: Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  if GIsShuttingDown then
    Exit(False);

  RunOnMainThread(
    procedure
    var
      LCompileServices: IOTACompileServices;
    begin
      if Supports(
        BorlandIDEServices,
        IOTACompileServices,
        LCompileServices
      ) and LCompileServices.IsBackgroundCompileActive then
        LResult := LCompileServices.CancelBackgroundCompile(False);
    end
  );
  if LResult then
    SetStatus(bsCancelled);
  Result := LResult;
end;

function TRadIAOTABuildFacade.CompileMode(
  const AMode: TRadIABuildMode
): Integer;
begin
  case AMode of
    bmMake: Result := Ord(cmOTAMake);
    bmCheck: Result := Ord(cmOTACheck);
    bmClean: Result := Ord(cmOTAClean);
  else
    Result := Ord(cmOTABuild);
  end;
end;

constructor TRadIAOTABuildFacade.Create(
  const AWorkspace: IRadIAWorkspaceFacade
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  FWorkspace := AWorkspace;
  FRunning := 0;
  FStatus := Ord(bsIdle);
end;

function TRadIAOTABuildFacade.Execute(
  const ARequest: TRadIABuildRequest
): TRadIABuildResult;
var
  LCompileResult: Integer;
  LNotifier: IRadIACompileWaiter;
  LNotifierIndex: Integer;
  LProject: TRadIAProjectSnapshot;
  LStatus: TRadIABuildStatus;
  LStopwatch: TStopwatch;
begin
  if GetCurrentThreadId = MainThreadID then
    Exit(TRadIABuildResult.Failed(
      bsUnsupported,
      CUnsupported,
      'Build tools must execute outside the IDE main thread.'
    ));
  if TInterlocked.CompareExchange(FRunning, 1, 0) <> 0 then
    Exit(TRadIABuildResult.Failed(
      GetStatus,
      CBuildBusy,
      'Another build request is already active.'
    ));

  LStopwatch := TStopwatch.StartNew;
  LNotifierIndex := -1;
  SetStatus(bsRunning);
  try
    LProject := FWorkspace.GetActiveProject;
    if LProject.FileName = '' then
      Exit(TRadIABuildResult.Failed(
        bsFailed,
        CNoActiveProject,
        'No active project is available.'
      ));
    if not BuildOnMainThread(
      ARequest,
      LNotifier,
      LCompileResult,
      LNotifierIndex
    ) then
      Exit(TRadIABuildResult.Failed(
        bsUnsupported,
        CUnsupported,
        'The IDE compile service is not available.'
      ));

    LStatus := bsFailed;
    if TOTACompileResult(LCompileResult) = crOTABackground then
    begin
      LStatus := WaitForCompletion(
        LNotifier,
        ARequest.TimeoutMs
      );
    end
    else if TOTACompileResult(LCompileResult) = crOTASucceeded then
      LStatus := bsSucceeded;

    RemoveNotifier(LNotifierIndex);
    LNotifierIndex := -1;
    LStopwatch.Stop;
    Result := TRadIABuildResult.Completed(
      LStatus,
      LProject,
      LStopwatch.ElapsedMilliseconds,
      FWorkspace.GetCompilerMessages(200)
    );
    if LStatus = bsTimedOut then
      Result := TRadIABuildResult.Failed(
        bsTimedOut,
        CBuildTimeout,
        'Build timed out and cancellation was requested.'
      )
    else if LStatus = bsFailed then
      Result := TRadIABuildResult.Completed(
        bsFailed,
        LProject,
        LStopwatch.ElapsedMilliseconds,
        FWorkspace.GetCompilerMessages(200)
      );
    SetStatus(LStatus);
  finally
    if LNotifierIndex >= 0 then
      RemoveNotifier(LNotifierIndex);
    if GetStatus = bsRunning then
      SetStatus(bsFailed);
    TInterlocked.Exchange(FRunning, 0);
  end;
end;

function TRadIAOTABuildFacade.GetStatus: TRadIABuildStatus;
begin
  Result := TRadIABuildStatus(
    TInterlocked.CompareExchange(FStatus, 0, 0)
  );
end;

procedure TRadIAOTABuildFacade.RemoveNotifier(
  const ANotifierIndex: Integer
);
begin
  if (ANotifierIndex < 0) or GIsShuttingDown then
    Exit;
  RunOnMainThread(
    procedure
    var
      LCompileServices: IOTACompileServices;
    begin
      if Supports(
        BorlandIDEServices,
        IOTACompileServices,
        LCompileServices
      ) then
        LCompileServices.RemoveNotifier(ANotifierIndex);
    end
  );
end;

procedure TRadIAOTABuildFacade.RunOnMainThread(
  const AAction: TThreadProcedure
);
begin
  if GIsShuttingDown then
    raise EInvalidOperation.Create(
      'The IDE workspace is shutting down.'
    );
  if GetCurrentThreadId = MainThreadID then
    AAction()
  else
    TThread.Synchronize(nil, AAction);
end;

procedure TRadIAOTABuildFacade.SetStatus(
  const AStatus: TRadIABuildStatus
);
begin
  TInterlocked.Exchange(FStatus, Ord(AStatus));
end;

function TRadIAOTABuildFacade.WaitForCompletion(
  const ANotifier: IRadIACompileWaiter;
  const ATimeoutMs: Cardinal
): TRadIABuildStatus;
var
  LElapsedMs: UInt64;
  LStartedAt: UInt64;
  LWaitMs: Cardinal;
begin
  LStartedAt := GetTickCount64;
  repeat
    if GIsShuttingDown then
      Exit(bsCancelled);

    LElapsedMs := GetTickCount64 - LStartedAt;
    if LElapsedMs >= ATimeoutMs then
    begin
      Cancel;
      Exit(bsTimedOut);
    end;

    LWaitMs := Cardinal(ATimeoutMs - LElapsedMs);
    if LWaitMs > 250 then
      LWaitMs := 250;
    if ANotifier.WaitFor(LWaitMs) = wrSignaled then
    begin
      if TOTACompileResult(
        ANotifier.GetCompileResult
      ) = crOTASucceeded then
        Exit(bsSucceeded);
      Exit(bsFailed);
    end;
  until False;
end;

end.
