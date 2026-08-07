unit RadIA.OTA.Build;

interface

uses
  RadIA.Core.Build,
  RadIA.Core.Workspace;

type
  TRadIAOTABuildFacade = class(
    TInterfacedObject,
    IRadIABuildFacade
  )
  private
    FCancelRequested: Integer;
    FProcessHandle: Pointer;
    FRunning: Integer;
    FStatus: Integer;
    FWorkspace: IRadIAWorkspaceFacade;
    function CaptureBuildContext(
      out AProjectFile: string;
      out AConfiguration: string;
      out APlatform: string;
      out AIDERoot: string
    ): Boolean;
    procedure CaptureIDEContext(
      out AProjectFile: string;
      out AConfiguration: string;
      out APlatform: string;
      out AIDERoot: string
    );
    function ExecuteBuildProcess(
      const ACommandLine: string;
      const AWorkingDirectory: string;
      const AOutputPath: string;
      const ATimeoutMs: Cardinal;
      out AExitCode: Cardinal
    ): TRadIABuildStatus;
    function ParseBuildMessages(
      const AOutputPath: string
    ): TArray<TRadIACompilerMessage>;
    function ReadBuildFailureMessage(
      const AOutputPath: string
    ): string;
    function TargetName(const AMode: TRadIABuildMode): string;
    procedure SetStatus(const AStatus: TRadIABuildStatus);
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
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils,
  System.SyncObjs,
  ToolsAPI,
  Winapi.Windows;

const
  CBuildBusy = 'build_busy';
  CNoActiveProject = 'no_active_project';
  CUnsupported = 'build_unsupported';

function ResolveBuildConfiguration(
  const AConfigurations: IOTAProjectOptionsConfigurations
): string;
var
  LConfiguration: IOTABuildConfiguration;
  LIndex: Integer;
begin
  Result := Trim(AConfigurations.ActiveConfigurationName);
  if (Result <> '') and not SameText(Result, 'Base') then
    Exit;

  Result := '';
  for LIndex := 0 to AConfigurations.ConfigurationCount - 1 do
  begin
    LConfiguration := AConfigurations.Configurations[LIndex];
    if not Assigned(LConfiguration) or
      not Assigned(LConfiguration.Parent) then
      Continue;
    if SameText(LConfiguration.Name, 'Debug') then
      Exit(LConfiguration.Name);
    if Result = '' then
      Result := LConfiguration.Name;
  end;
end;

function ResolveBuildPlatform(
  const AConfigurations: IOTAProjectOptionsConfigurations;
  const AProjectPlatform: string
): string;
var
  LActiveConfiguration: IOTABuildConfiguration;
  LCandidate: string;
  LPlatform: string;
  LPlatforms: TArray<string>;
begin
  Result := '';
  LActiveConfiguration := AConfigurations.ActiveConfiguration;
  if not Assigned(LActiveConfiguration) then
    Exit;

  LPlatforms := LActiveConfiguration.Platforms;
  LCandidate := Trim(AProjectPlatform);
  if LCandidate = '' then
    LCandidate := Trim(AConfigurations.ActivePlatformName);
  for LPlatform in LPlatforms do
    if SameText(LPlatform, LCandidate) then
      Exit(LPlatform);

  for LPlatform in LPlatforms do
    if SameText(LPlatform, 'Win32') then
      Exit(LPlatform);
  if Length(LPlatforms) > 0 then
    Result := LPlatforms[0];
end;

{ TRadIAOTABuildFacade }

function TRadIAOTABuildFacade.Cancel: Boolean;
var
  LProcessHandle: THandle;
begin
  Result := GetStatus = bsRunning;
  if not Result then
    Exit;
  TInterlocked.Exchange(FCancelRequested, 1);
  LProcessHandle := THandle(
    TInterlocked.CompareExchange(FProcessHandle, nil, nil)
  );
  if LProcessHandle <> 0 then
    TerminateProcess(LProcessHandle, 2);
end;

function TRadIAOTABuildFacade.CaptureBuildContext(
  out AProjectFile: string;
  out AConfiguration: string;
  out APlatform: string;
  out AIDERoot: string
): Boolean;
var
  LAction: TThreadProcedure;
  LConfiguration: string;
  LIDERoot: string;
  LPlatform: string;
  LProjectFile: string;
begin
  AProjectFile := '';
  AConfiguration := '';
  APlatform := '';
  AIDERoot := '';
  LAction :=
    procedure
    begin
      CaptureIDEContext(
        LProjectFile,
        LConfiguration,
        LPlatform,
        LIDERoot
      );
    end;
  TThread.Synchronize(nil, LAction);
  AProjectFile := LProjectFile;
  AConfiguration := LConfiguration;
  APlatform := LPlatform;
  AIDERoot := LIDERoot;
  Result := (AProjectFile <> '') and TFile.Exists(AProjectFile) and
    (AIDERoot <> '');
end;

procedure TRadIAOTABuildFacade.CaptureIDEContext(
  out AProjectFile: string;
  out AConfiguration: string;
  out APlatform: string;
  out AIDERoot: string
);
var
  LIndex: Integer;
  LModule: IOTAModule;
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
  LProjectConfigurations: IOTAProjectOptionsConfigurations;
  LServices: IOTAServices;
begin
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    for LIndex := 0 to LModuleServices.ModuleCount - 1 do
    begin
      LModule := LModuleServices.Modules[LIndex];
      if Assigned(LModule) and
        (Trim(LModule.FileName) <> '') and
        TFile.Exists(LModule.FileName) then
        LModule.Save(False, False);
    end;
    LProject := LModuleServices.GetActiveProject;
    if Assigned(LProject) then
    begin
      AProjectFile := LProject.FileName;
      if Supports(
        LProject.ProjectOptions,
        IOTAProjectOptionsConfigurations,
        LProjectConfigurations
      ) then
      begin
        AConfiguration := ResolveBuildConfiguration(
          LProjectConfigurations
        );
        APlatform := ResolveBuildPlatform(
          LProjectConfigurations,
          LProject.CurrentPlatform
        );
      end
      else
      begin
        AConfiguration := LProject.CurrentConfiguration;
        APlatform := LProject.CurrentPlatform;
      end;
    end;
  end;
  if Supports(BorlandIDEServices, IOTAServices, LServices) then
    AIDERoot := LServices.GetRootDirectory;
end;

constructor TRadIAOTABuildFacade.Create(
  const AWorkspace: IRadIAWorkspaceFacade
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  FWorkspace := AWorkspace;
  FCancelRequested := 0;
  FProcessHandle := nil;
  FRunning := 0;
  FStatus := Ord(bsIdle);
end;

function TRadIAOTABuildFacade.Execute(
  const ARequest: TRadIABuildRequest
): TRadIABuildResult;
var
  LCommandLine: string;
  LCommandProcessor: string;
  LConfiguration: string;
  LExitCode: Cardinal;
  LIDERoot: string;
  LMessages: TArray<TRadIACompilerMessage>;
  LOutputPath: string;
  LPlatform: string;
  LProject: TRadIAProjectSnapshot;
  LProjectFile: string;
  LStatus: TRadIABuildStatus;
  LStopwatch: TStopwatch;
  LWorkingDirectory: string;
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
  TInterlocked.Exchange(FCancelRequested, 0);
  SetStatus(bsRunning);
  try
    if not CaptureBuildContext(
      LProjectFile,
      LConfiguration,
      LPlatform,
      LIDERoot
    ) then
      Exit(TRadIABuildResult.Failed(
        bsFailed,
        CNoActiveProject,
        'No active buildable project is available.'
      ));
    if LConfiguration = '' then
      LConfiguration := 'Debug';
    if LPlatform = '' then
      LPlatform := 'Win32';

    LProject := FWorkspace.GetActiveProject;
    LWorkingDirectory := TPath.GetDirectoryName(LProjectFile);
    LOutputPath := TPath.Combine(
      LWorkingDirectory,
      '.radia-build-output.log'
    );
    LCommandProcessor := GetEnvironmentVariable('ComSpec');
    if LCommandProcessor = '' then
      LCommandProcessor := 'cmd.exe';
    LCommandLine := Format(
      '"%s" /S /C ""%s" && msbuild "%s" /t:%s ' +
      '/p:Config="%s" /p:Platform="%s" /p:DCC_ForceExecute=true ' +
      '/nologo /verbosity:minimal"',
      [
        LCommandProcessor,
        TPath.Combine(LIDERoot, 'bin\rsvars.bat'),
        LProjectFile,
        TargetName(ARequest.Mode),
        LConfiguration,
        LPlatform
      ]
    );
    LStatus := ExecuteBuildProcess(
      LCommandLine,
      LWorkingDirectory,
      LOutputPath,
      ARequest.TimeoutMs,
      LExitCode
    );
    if (LStatus = bsSucceeded) and (LExitCode <> 0) then
      LStatus := bsFailed;
    LMessages := ParseBuildMessages(LOutputPath);
    if (LStatus = bsFailed) and (Length(LMessages) = 0) then
    begin
      LCommandLine := ReadBuildFailureMessage(LOutputPath);
      if LCommandLine <> '' then
      begin
        SetLength(LMessages, 1);
        LMessages[0] := TRadIACompilerMessage.Create(
          cmsError,
          LCommandLine,
          LProjectFile,
          0,
          0
        );
      end;
    end;
    System.SysUtils.DeleteFile(LOutputPath);
    if Length(LMessages) = 0 then
      LMessages := FWorkspace.GetCompilerMessages(200);
    LStopwatch.Stop;
    SetStatus(LStatus);
    Result := TRadIABuildResult.Completed(
      LStatus,
      LProject,
      LStopwatch.ElapsedMilliseconds,
      LMessages
    );
  finally
    TInterlocked.Exchange(FProcessHandle, nil);
    if GetStatus = bsRunning then
      SetStatus(bsFailed);
    TInterlocked.Exchange(FRunning, 0);
  end;
end;

function TRadIAOTABuildFacade.ExecuteBuildProcess(
  const ACommandLine: string;
  const AWorkingDirectory: string;
  const AOutputPath: string;
  const ATimeoutMs: Cardinal;
  out AExitCode: Cardinal
): TRadIABuildStatus;
var
  LCommandLine: string;
  LOutputHandle: THandle;
  LProcessInfo: TProcessInformation;
  LSecurityAttributes: TSecurityAttributes;
  LStartupInfo: TStartupInfo;
  LStopwatch: TStopwatch;
  LWaitResult: Cardinal;
begin
  AExitCode := Cardinal(-1);
  ZeroMemory(@LSecurityAttributes, SizeOf(LSecurityAttributes));
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
      TInterlocked.Exchange(FProcessHandle, Pointer(LProcessInfo.hProcess));
      LStopwatch := TStopwatch.StartNew;
      repeat
        LWaitResult := WaitForSingleObject(LProcessInfo.hProcess, 25);
        if TInterlocked.CompareExchange(FCancelRequested, 0, 0) <> 0 then
        begin
          TerminateProcess(LProcessInfo.hProcess, 2);
          Exit(bsCancelled);
        end;
        if LStopwatch.ElapsedMilliseconds >= ATimeoutMs then
        begin
          TerminateProcess(LProcessInfo.hProcess, 3);
          Exit(bsTimedOut);
        end;
      until LWaitResult <> WAIT_TIMEOUT;
      if LWaitResult <> WAIT_OBJECT_0 then
        RaiseLastOSError;
      GetExitCodeProcess(LProcessInfo.hProcess, AExitCode);
      Result := bsSucceeded;
    finally
      TInterlocked.Exchange(FProcessHandle, nil);
      CloseHandle(LProcessInfo.hThread);
      CloseHandle(LProcessInfo.hProcess);
    end;
  finally
    CloseHandle(LOutputHandle);
  end;
end;

function TRadIAOTABuildFacade.GetStatus: TRadIABuildStatus;
begin
  Result := TRadIABuildStatus(
    TInterlocked.CompareExchange(FStatus, 0, 0)
  );
end;

function TRadIAOTABuildFacade.ParseBuildMessages(
  const AOutputPath: string
): TArray<TRadIACompilerMessage>;
const
  CDiagnosticPattern =
    '^(.+?)\((\d+)(?:,(\d+))?\)\s*:\s*' +
    '(fatal error|error|warning|hint)\s+([A-Za-z]?\d+)\s*:\s*(.*?)(?:\s+\[.*\])?$';
var
  LColumn: Integer;
  LFileName: string;
  LLine: string;
  LLineNumber: Integer;
  LList: TList<TRadIACompilerMessage>;
  LMatch: TMatch;
  LRegex: TRegEx;
  LSeverity: TRadIACompilerMessageSeverity;
  LText: string;
begin
  SetLength(Result, 0);
  if not TFile.Exists(AOutputPath) then
    Exit;
  LRegex := TRegEx.Create(CDiagnosticPattern, [roIgnoreCase]);
  LList := TList<TRadIACompilerMessage>.Create;
  try
    for LLine in TFile.ReadAllLines(AOutputPath) do
    begin
      LMatch := LRegex.Match(Trim(LLine));
      if not LMatch.Success then
        Continue;
      LFileName := LMatch.Groups[1].Value;
      LLineNumber := StrToIntDef(LMatch.Groups[2].Value, 0);
      LColumn := StrToIntDef(LMatch.Groups[3].Value, 0);
      if Pos('error', LowerCase(LMatch.Groups[4].Value)) > 0 then
        LSeverity := cmsError
      else if SameText(LMatch.Groups[4].Value, 'warning') then
        LSeverity := cmsWarning
      else
        LSeverity := cmsInfo;
      LText := LMatch.Groups[5].Value + ': ' +
        LMatch.Groups[6].Value;
      LList.Add(TRadIACompilerMessage.Create(
        LSeverity,
        LText,
        LFileName,
        LLineNumber,
        LColumn
      ));
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TRadIAOTABuildFacade.ReadBuildFailureMessage(
  const AOutputPath: string
): string;
const
  CMaximumFailureCharacters = 4096;
var
  LOutput: string;
begin
  Result := '';
  if not TFile.Exists(AOutputPath) then
    Exit;
  LOutput := Trim(TFile.ReadAllText(AOutputPath));
  if Length(LOutput) > CMaximumFailureCharacters then
    Delete(LOutput, 1, Length(LOutput) - CMaximumFailureCharacters);
  Result := LOutput;
end;

procedure TRadIAOTABuildFacade.SetStatus(
  const AStatus: TRadIABuildStatus
);
begin
  TInterlocked.Exchange(FStatus, Ord(AStatus));
end;

function TRadIAOTABuildFacade.TargetName(
  const AMode: TRadIABuildMode
): string;
begin
  case AMode of
    bmMake: Result := 'Make';
    bmCheck: Result := 'Build';
    bmClean: Result := 'Clean';
  else
    Result := 'Build';
  end;
end;

end.
