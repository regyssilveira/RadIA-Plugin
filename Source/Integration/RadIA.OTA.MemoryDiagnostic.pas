unit RadIA.OTA.MemoryDiagnostic;

interface

procedure StartRadIAMemoryDiagnosticIfRequested;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Container,
  RadIA.Core.Logger,
  RadIA.Core.MemoryDiagnosticSession,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

function BuildSmokeScenario: TRadIARuntimeScenario;
var
  LActions: TArray<TRadIARuntimeScenarioAction>;
  LPlaceholder: TRadIARuntimeSessionIdentity;
begin
  LPlaceholder := TRadIARuntimeSessionIdentity.Create(
    'memory-smoke-preview',
    1,
    Now,
    'RadIARuntimeLab.exe',
    'RadIARuntimeLab.dproj',
    'memory-smoke'
  );
  LActions := [
    TRadIARuntimeScenarioAction.Create(
      rakWait,
      Default(TRadIARuntimeSelector),
      '',
      20000
    ),
    TRadIARuntimeScenarioAction.Create(
      rakInvoke,
      TRadIARuntimeSelector.Create(
        '',
        'TButton',
        '',
        'Fail when form cancels',
        ''
      ),
      '',
      5000
    ),
    TRadIARuntimeScenarioAction.Create(
      rakWait,
      Default(TRadIARuntimeSelector),
      '',
      500
    ),
    TRadIARuntimeScenarioAction.Create(
      rakCancel,
      TRadIARuntimeSelector.Create(
        '',
        'TButton',
        '',
        'Cancel',
        ''
      ),
      '',
      5000
    ),
    TRadIARuntimeScenarioAction.Create(
      rakWait,
      Default(TRadIARuntimeSelector),
      '',
      500
    ),
    TRadIARuntimeScenarioAction.Create(
      rakClose,
      TRadIARuntimeSelector.Create(
        '',
        'TRadIARuntimeLabMainForm',
        '',
        'RadIA Runtime Automation Laboratory',
        '$root'
      ),
      '',
      5000
    )
  ];
  Result := TRadIARuntimeScenario.Create(
    'FastMM5 IDE smoke',
    LPlaceholder,
    TRadIARuntimeScenarioLimits.Create(6, 60000, 1),
    LActions
  );
end;

function PreviewId(const AJson: string): string;
var
  LRoot: TJSONObject;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    Result := LRoot.GetValue<string>('previewId', '');
  finally
    LRoot.Free;
  end;
end;

procedure WriteDiagnosticResult(
  const AFileName: string;
  const AResult: TRadIAToolResult
);
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('success', TJSONBool.Create(AResult.Success));
    LRoot.AddPair('errorCode', AResult.ErrorCode);
    LRoot.AddPair('errorMessage', AResult.ErrorMessage);
    if AResult.Success then
      LRoot.AddPair(
        'evidence',
        TJSONObject.ParseJSONValue(AResult.ContentJson)
      );
    TDirectory.CreateDirectory(ExtractFilePath(AFileName));
    TFile.WriteAllText(AFileName, LRoot.ToJSON, TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

procedure RunDiagnostic(
  const ACoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AOutputPath: string
);
var
  LDeadline: TDateTime;
  LPrepare: TRadIAToolResult;
  LProject: TRadIAProjectSnapshot;
  LResult: TRadIAToolResult;
begin
  LDeadline := IncSecond(Now, 120);
  repeat
    LProject := AWorkspace.GetActiveProject;
    if SameText(
      ExtractFileName(LProject.FileName),
      'RadIARuntimeLab.dproj'
    ) and SameText(LProject.Configuration, 'Debug') then
      Break;
    TThread.Sleep(250);
  until Now >= LDeadline;
  if not SameText(
    ExtractFileName(LProject.FileName),
    'RadIARuntimeLab.dproj'
  ) or not SameText(LProject.Configuration, 'Debug') then
  begin
    WriteDiagnosticResult(
      AOutputPath,
      TRadIAToolResult.Failed(
        'memory_smoke_project_timeout',
        'RuntimeLab did not become active in Debug. Active project: ' +
        LProject.FileName + '; configuration: ' +
        LProject.Configuration
      )
    );
    Exit;
  end;
  LPrepare := ACoordinator.Prepare(BuildSmokeScenario, 0);
  if LPrepare.Success then
    LResult := ACoordinator.Run(PreviewId(LPrepare.ContentJson), nil)
  else
    LResult := LPrepare;
  WriteDiagnosticResult(AOutputPath, LResult);
end;

procedure StartRadIAMemoryDiagnosticIfRequested;
var
  LCoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
  LOutputPath: string;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  LOutputPath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_MEMORY_DIAGNOSTIC')
  );
  if LOutputPath.IsEmpty then
    Exit;
  if not TRadIAContainer.TryResolve<
    IRadIAMemoryDiagnosticSessionCoordinator
  >(LCoordinator) or
    not TRadIAContainer.TryResolve<IRadIAWorkspaceFacade>(LWorkspace) then
  begin
    TLogger.Log(
      'Memory diagnostic smoke coordinator is unavailable.',
      'MemoryDiagnostic'
    );
    Exit;
  end;
  TThread.CreateAnonymousThread(
    procedure
    begin
      TThread.Sleep(15000);
      try
        RunDiagnostic(LCoordinator, LWorkspace, LOutputPath);
      except
        on E: Exception do
        begin
          TLogger.Log(
            'Memory diagnostic smoke failed: ' + E.Message,
            'MemoryDiagnostic'
          );
          WriteDiagnosticResult(
            LOutputPath,
            TRadIAToolResult.Failed(
              'memory_diagnostic_smoke_failed',
              E.Message
            )
          );
        end;
      end;
    end
  ).Start;
end;

end.
