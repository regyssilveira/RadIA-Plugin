unit RadIA.OTA.Git;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Git,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAGitCommitPreview = class
  private
    FPreviewId: string;
    FRootPath: string;
    FPaths: TArray<string>;
    FMessage: string;
    FFingerprint: string;
  public
    constructor Create(
      const APreviewId: string;
      const ARootPath: string;
      const APaths: TArray<string>;
      const AMessage: string;
      const AFingerprint: string
    );
    property RootPath: string read FRootPath;
    property Paths: TArray<string> read FPaths;
    property Message: string read FMessage;
    property Fingerprint: string read FFingerprint;
  end;

  TRadIAOTAGitFacade = class(
    TInterfacedObject,
    IRadIAGitFacade
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    FPreviews: TObjectDictionary<string, TRadIAGitCommitPreview>;
    FOperationLock: TObject;
    function ActiveRoot(
      out ARootPath: string;
      out AError: TRadIAGitResult
    ): Boolean;
    function BuildFingerprint(
      const ARootPath: string;
      const APaths: TArray<string>
    ): string;
    function CommitPreview(
      const APreview: TRadIAGitCommitPreview
    ): TRadIAGitResult;
    function ExecuteGit(
      const ARootPath: string;
      const AArguments: TArray<string>;
      out AOutput: string
    ): Cardinal;
    function HasStagedChanges(
      const ARootPath: string
    ): Boolean;
    function NormalizePaths(
      const ARootPath: string;
      const APaths: TArray<string>;
      out ANormalizedPaths: TArray<string>;
      out AError: TRadIAGitResult
    ): Boolean;
    function RunDiff(
      const ARootPath: string;
      const APaths: TArray<string>;
      out ADiff: string
    ): Cardinal;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    destructor Destroy; override;
    function GetStatus: TRadIAGitResult;
    function GetDiff(
      const APaths: TArray<string>
    ): TRadIAGitResult;
    function PreviewCommit(
      const APaths: TArray<string>;
      const AMessage: string
    ): TRadIAGitResult;
    function Commit(
      const APreviewId: string
    ): TRadIAGitResult;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows;

function AddPaths(
  const AArguments: TArray<string>;
  const APaths: TArray<string>
): TArray<string>;
var
  LArgument: string;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    LList.AddRange(AArguments);
    LList.Add('--');
    for LArgument in APaths do
      LList.Add(LArgument);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function QuoteArgument(const AValue: string): string;
begin
  if AValue.Contains('"') or
    AValue.Contains(#13) or
    AValue.Contains(#10) then
    raise EArgumentException.Create(
      'Git arguments cannot contain quotes or line breaks.'
    );
  Result := '"' + AValue + '"';
end;

function JsonString(const AValue: string): string;
var
  LValue: TJSONString;
begin
  LValue := TJSONString.Create(AValue);
  try
    Result := LValue.ToJSON;
  finally
    LValue.Free;
  end;
end;

constructor TRadIAGitCommitPreview.Create(
  const APreviewId: string;
  const ARootPath: string;
  const APaths: TArray<string>;
  const AMessage: string;
  const AFingerprint: string
);
begin
  inherited Create;
  FPreviewId := APreviewId;
  FRootPath := ARootPath;
  FPaths := Copy(APaths);
  FMessage := AMessage;
  FFingerprint := AFingerprint;
end;

function TRadIAOTAGitFacade.ActiveRoot(
  out ARootPath: string;
  out AError: TRadIAGitResult
): Boolean;
var
  LOutput: string;
  LProject: TRadIAProjectSnapshot;
begin
  Result := False;
  ARootPath := '';
  LProject := FWorkspace.GetActiveProject;
  if Trim(LProject.RootPath) = '' then
  begin
    AError := TRadIAGitResult.Failed(
      'no_active_project',
      'An active Delphi project is required for Git operations.'
    );
    Exit;
  end;
  ARootPath := ExcludeTrailingPathDelimiter(
    TPath.GetFullPath(LProject.RootPath)
  );
  if ExecuteGit(
    ARootPath,
    ['rev-parse', '--is-inside-work-tree'],
    LOutput
  ) <> 0 then
  begin
    AError := TRadIAGitResult.Failed(
      'git_repository_not_found',
      'The active project is not inside a Git work tree. ' +
      Trim(LOutput)
    );
    Exit;
  end;
  Result := SameText(Trim(LOutput), 'true');
  if not Result then
    AError := TRadIAGitResult.Failed(
      'git_repository_not_found',
      'The active project is not inside a Git work tree.'
    );
end;

function TRadIAOTAGitFacade.BuildFingerprint(
  const ARootPath: string;
  const APaths: TArray<string>
): string;
var
  LAbsolutePath: string;
  LContentHash: string;
  LMaterial: string;
  LPath: string;
  LStatus: string;
begin
  LMaterial := '';
  for LPath in APaths do
  begin
    ExecuteGit(
      ARootPath,
      AddPaths(['status', '--porcelain=v1'], [LPath]),
      LStatus
    );
    LAbsolutePath := TPath.Combine(ARootPath, LPath);
    if TFile.Exists(LAbsolutePath) then
      LContentHash := THashSHA2.GetHashStringFromFile(
        LAbsolutePath
      )
    else
      LContentHash := '<missing>';
    LMaterial := LMaterial + LPath + #10 + LStatus + #10 +
      LContentHash + #10;
  end;
  Result := LowerCase(THashSHA2.GetHashString(LMaterial));
end;

function TRadIAOTAGitFacade.Commit(
  const APreviewId: string
): TRadIAGitResult;
var
  LPreview: TRadIAGitCommitPreview;
begin
  TMonitor.Enter(FOperationLock);
  try
    TMonitor.Enter(FPreviews);
    try
      if not FPreviews.TryGetValue(APreviewId, LPreview) then
        Exit(TRadIAGitResult.Failed(
          'invalid_preview',
          'Git commit preview was not found.'
        ));
      Result := CommitPreview(LPreview);
      if Result.Success then
        FPreviews.Remove(APreviewId);
    finally
      TMonitor.Exit(FPreviews);
    end;
  finally
    TMonitor.Exit(FOperationLock);
  end;
end;

function TRadIAOTAGitFacade.CommitPreview(
  const APreview: TRadIAGitCommitPreview
): TRadIAGitResult;
var
  LCommitOutput: string;
  LExitCode: Cardinal;
  LHead: string;
  LMessagePath: string;
  LOutput: string;
begin
  if BuildFingerprint(APreview.RootPath, APreview.Paths) <>
    APreview.Fingerprint then
    Exit(TRadIAGitResult.Failed(
      'precondition_failed',
      'Selected files changed after the commit preview.'
    ));
  if HasStagedChanges(APreview.RootPath) then
    Exit(TRadIAGitResult.Failed(
      'staged_changes_present',
      'Existing staged changes must be committed or unstaged by the user.'
    ));
  LExitCode := ExecuteGit(
    APreview.RootPath,
    AddPaths(['add'], APreview.Paths),
    LOutput
  );
  if LExitCode <> 0 then
    Exit(TRadIAGitResult.Failed('git_add_failed', Trim(LOutput)));

  LMessagePath := TPath.Combine(
    TPath.GetTempPath,
    'radia-git-message-' + TGUID.NewGuid.ToString + '.txt'
  );
  TFile.WriteAllBytes(
    LMessagePath,
    TEncoding.UTF8.GetBytes(APreview.Message)
  );
  try
    LExitCode := ExecuteGit(
      APreview.RootPath,
      AddPaths(
        ['commit', '--file', LMessagePath],
        APreview.Paths
      ),
      LCommitOutput
    );
  finally
    if TFile.Exists(LMessagePath) then
      System.SysUtils.DeleteFile(LMessagePath);
  end;
  if LExitCode <> 0 then
  begin
    ExecuteGit(
      APreview.RootPath,
      AddPaths(['reset'], APreview.Paths),
      LOutput
    );
    Exit(TRadIAGitResult.Failed(
      'git_commit_failed',
      Trim(LCommitOutput)
    ));
  end;
  if ExecuteGit(APreview.RootPath, ['rev-parse', 'HEAD'], LHead) <> 0 then
    LHead := '';
  Result := TRadIAGitResult.Succeeded(
    '{"committed":true,"commit":' +
    JsonString(Trim(LHead)) + '}'
  );
end;

constructor TRadIAOTAGitFacade.Create(
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
  FPreviews := TObjectDictionary<
    string,
    TRadIAGitCommitPreview
  >.Create([doOwnsValues]);
  FOperationLock := TObject.Create;
end;

destructor TRadIAOTAGitFacade.Destroy;
begin
  FOperationLock.Free;
  FPreviews.Free;
  inherited Destroy;
end;

function TRadIAOTAGitFacade.ExecuteGit(
  const ARootPath: string;
  const AArguments: TArray<string>;
  out AOutput: string
): Cardinal;
var
  LArgument: string;
  LCommandLine: string;
  LOutputHandle: THandle;
  LOutputPath: string;
  LProcessInfo: Winapi.Windows.TProcessInformation;
  LSecurityAttributes: Winapi.Windows.TSecurityAttributes;
  LStartupInfo: Winapi.Windows.TStartupInfo;
  LWaitResult: Cardinal;
begin
  AOutput := '';
  Result := Cardinal(-1);
  LOutputPath := TPath.Combine(
    TPath.GetTempPath,
    'radia-git-' + TGUID.NewGuid.ToString + '.log'
  );
  Winapi.Windows.ZeroMemory(
    @LSecurityAttributes,
    SizeOf(LSecurityAttributes)
  );
  LSecurityAttributes.nLength := SizeOf(LSecurityAttributes);
  LSecurityAttributes.bInheritHandle := True;
  LOutputHandle := Winapi.Windows.CreateFile(
    PChar(LOutputPath),
    Winapi.Windows.GENERIC_WRITE,
    Winapi.Windows.FILE_SHARE_READ,
    @LSecurityAttributes,
    Winapi.Windows.CREATE_ALWAYS,
    Winapi.Windows.FILE_ATTRIBUTE_TEMPORARY,
    0
  );
  if LOutputHandle = Winapi.Windows.INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    LCommandLine :=
      '"git.exe" -c color.ui=false -c i18n.logOutputEncoding=utf-8 -C ' +
      QuoteArgument(ARootPath);
    for LArgument in AArguments do
      LCommandLine := LCommandLine + ' ' + QuoteArgument(LArgument);
    Winapi.Windows.ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
    LStartupInfo.cb := SizeOf(LStartupInfo);
    LStartupInfo.dwFlags := Winapi.Windows.STARTF_USESTDHANDLES;
    LStartupInfo.hStdOutput := LOutputHandle;
    LStartupInfo.hStdError := LOutputHandle;
    LStartupInfo.hStdInput := 0;
    Winapi.Windows.ZeroMemory(@LProcessInfo, SizeOf(LProcessInfo));
    if not Winapi.Windows.CreateProcess(
      nil,
      PChar(LCommandLine),
      nil,
      nil,
      True,
      Winapi.Windows.CREATE_NO_WINDOW,
      nil,
      PChar(ARootPath),
      LStartupInfo,
      LProcessInfo
    ) then
      RaiseLastOSError;
    try
      LWaitResult := Winapi.Windows.WaitForSingleObject(
        LProcessInfo.hProcess,
        60000
      );
      if LWaitResult = Winapi.Windows.WAIT_TIMEOUT then
      begin
        Winapi.Windows.TerminateProcess(LProcessInfo.hProcess, 4);
        Winapi.Windows.WaitForSingleObject(LProcessInfo.hProcess, 5000);
      end;
      Winapi.Windows.GetExitCodeProcess(LProcessInfo.hProcess, Result);
    finally
      Winapi.Windows.CloseHandle(LProcessInfo.hThread);
      Winapi.Windows.CloseHandle(LProcessInfo.hProcess);
    end;
  finally
    Winapi.Windows.CloseHandle(LOutputHandle);
  end;
  if TFile.Exists(LOutputPath) then
  begin
    try
      AOutput := TFile.ReadAllText(LOutputPath, TEncoding.UTF8);
    finally
      System.SysUtils.DeleteFile(LOutputPath);
    end;
  end;
end;

function TRadIAOTAGitFacade.GetDiff(
  const APaths: TArray<string>
): TRadIAGitResult;
var
  LDiff: string;
  LError: TRadIAGitResult;
  LPaths: TArray<string>;
  LRootPath: string;
begin
  if not ActiveRoot(LRootPath, LError) then
    Exit(LError);
  if not NormalizePaths(
    LRootPath,
    APaths,
    LPaths,
    LError
  ) then
    Exit(LError);
  if RunDiff(LRootPath, LPaths, LDiff) <> 0 then
    Exit(TRadIAGitResult.Failed('git_diff_failed', Trim(LDiff)));
  if Length(LDiff) > 200000 then
    LDiff := Copy(LDiff, 1, 200000);
  Result := TRadIAGitResult.Succeeded(
    '{"diff":' + JsonString(LDiff) + '}'
  );
end;

function TRadIAOTAGitFacade.GetStatus: TRadIAGitResult;
var
  LError: TRadIAGitResult;
  LOutput: string;
  LRootPath: string;
begin
  if not ActiveRoot(LRootPath, LError) then
    Exit(LError);
  if ExecuteGit(
    LRootPath,
    ['status', '--porcelain=v1', '--branch', '--', '.'],
    LOutput
  ) <> 0 then
    Exit(TRadIAGitResult.Failed(
      'git_status_failed',
      Trim(LOutput)
    ));
  Result := TRadIAGitResult.Succeeded(
    '{"status":' + JsonString(LOutput) + '}'
  );
end;

function TRadIAOTAGitFacade.HasStagedChanges(
  const ARootPath: string
): Boolean;
var
  LOutput: string;
begin
  ExecuteGit(
    ARootPath,
    ['diff', '--cached', '--name-only'],
    LOutput
  );
  Result := Trim(LOutput) <> '';
end;

function TRadIAOTAGitFacade.NormalizePaths(
  const ARootPath: string;
  const APaths: TArray<string>;
  out ANormalizedPaths: TArray<string>;
  out AError: TRadIAGitResult
): Boolean;
var
  LIndex: Integer;
  LPath: string;
  LValidation: TRadIAPathValidation;
begin
  Result := False;
  SetLength(ANormalizedPaths, 0);
  if Length(APaths) > 100 then
  begin
    AError := TRadIAGitResult.Failed(
      'too_many_paths',
      'At most 100 paths can be selected.'
    );
    Exit;
  end;
  SetLength(ANormalizedPaths, Length(APaths));
  for LIndex := Low(APaths) to High(APaths) do
  begin
    LPath := Trim(APaths[LIndex]);
    if LPath = '' then
    begin
      AError := TRadIAGitResult.Failed(
        'invalid_path',
        'Git paths cannot be empty.'
      );
      Exit;
    end;
    LValidation := FBoundary.ValidatePath(ARootPath, LPath);
    if not LValidation.Allowed then
    begin
      AError := TRadIAGitResult.Failed(
        LValidation.ErrorCode,
        LValidation.ErrorMessage
      );
      Exit;
    end;
    ANormalizedPaths[LIndex] := ExtractRelativePath(
      IncludeTrailingPathDelimiter(ARootPath),
      LValidation.ResolvedPath
    ).Replace(PathDelim, '/');
  end;
  Result := True;
end;

function TRadIAOTAGitFacade.PreviewCommit(
  const APaths: TArray<string>;
  const AMessage: string
): TRadIAGitResult;
var
  LDiff: string;
  LError: TRadIAGitResult;
  LFingerprint: string;
  LJson: TJSONObject;
  LPath: string;
  LPathArray: TJSONArray;
  LPaths: TArray<string>;
  LPreview: TRadIAGitCommitPreview;
  LPreviewId: string;
  LRootPath: string;
begin
  TMonitor.Enter(FOperationLock);
  try
  if (Trim(AMessage) = '') or
    (Length(AMessage) > 500) or
    AMessage.Contains(#13) or AMessage.Contains(#10) then
    Exit(TRadIAGitResult.Failed(
      'invalid_commit_message',
      'Commit message must be one line with 1 to 500 characters.'
    ));
  if Length(APaths) = 0 then
    Exit(TRadIAGitResult.Failed(
      'paths_required',
      'Select at least one path for the commit.'
    ));
  if not ActiveRoot(LRootPath, LError) then
    Exit(LError);
  if not NormalizePaths(LRootPath, APaths, LPaths, LError) then
    Exit(LError);
  if HasStagedChanges(LRootPath) then
    Exit(TRadIAGitResult.Failed(
      'staged_changes_present',
      'Existing staged changes must be reviewed by the user first.'
    ));
  if RunDiff(LRootPath, LPaths, LDiff) <> 0 then
    Exit(TRadIAGitResult.Failed('git_diff_failed', Trim(LDiff)));
  LFingerprint := BuildFingerprint(LRootPath, LPaths);
  LPreviewId := LowerCase(
    THashSHA2.GetHashString(
      LRootPath + '|' + AMessage + '|' + LFingerprint + '|' +
      TGUID.NewGuid.ToString
    )
  );
  LPreview := TRadIAGitCommitPreview.Create(
    LPreviewId,
    LRootPath,
    LPaths,
    AMessage,
    LFingerprint
  );
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Add(LPreviewId, LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('previewId', LPreviewId);
    LJson.AddPair('message', AMessage);
    LJson.AddPair('fingerprint', LFingerprint);
    LJson.AddPair('diff', LDiff);
    LPathArray := TJSONArray.Create;
    for LPath in LPaths do
      LPathArray.Add(LPath);
    LJson.AddPair('paths', LPathArray);
    Result := TRadIAGitResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
  finally
    TMonitor.Exit(FOperationLock);
  end;
end;

function TRadIAOTAGitFacade.RunDiff(
  const ARootPath: string;
  const APaths: TArray<string>;
  out ADiff: string
): Cardinal;
var
  LArguments: TArray<string>;
  LExitCode: Cardinal;
  LPath: string;
  LTrackedOutput: string;
  LUntrackedDiff: string;
begin
  LArguments := ['diff', '--no-ext-diff', '--unified=3'];
  if Length(APaths) = 0 then
    Result := ExecuteGit(
      ARootPath,
      AddPaths(LArguments, ['.']),
      ADiff
    )
  else
    Result := ExecuteGit(
      ARootPath,
      AddPaths(LArguments, APaths),
      ADiff
    );
  if Result <> 0 then
    Exit;
  for LPath in APaths do
  begin
    LExitCode := ExecuteGit(
      ARootPath,
      AddPaths(['ls-files', '--error-unmatch'], [LPath]),
      LTrackedOutput
    );
    if (LExitCode = 0) or
      not TFile.Exists(TPath.Combine(ARootPath, LPath)) then
      Continue;
    LExitCode := ExecuteGit(
      ARootPath,
      AddPaths(
        ['diff', '--no-index', '--unified=3'],
        ['NUL', LPath]
      ),
      LUntrackedDiff
    );
    if (LExitCode <> 0) and (LExitCode <> 1) then
      Exit(LExitCode);
    ADiff := ADiff + LUntrackedDiff;
  end;
end;

end.
