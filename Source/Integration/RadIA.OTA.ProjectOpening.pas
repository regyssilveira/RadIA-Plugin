unit RadIA.OTA.ProjectOpening;

interface

uses
  RadIA.Core.ProjectOpening;

type
  TRadIAOTAProjectOpeningFacade = class(
    TInterfacedObject,
    IRadIAProjectOpeningFacade
  )
  private
    function CloseProjectOnMainThread(
      const AProjectFileName: string
    ): Boolean;
    function OpenProjectOnMainThread(
      const AProjectFileName: string
    ): Boolean;
    function IsProjectOpenOnMainThread(
      const AProjectFileName: string
    ): Boolean;
    function WaitForProjectOpen(
      const AProjectFileName: string
    ): Boolean;
    function WaitForMainThreadQueue: Boolean;
  public
    function CloseProject(const AProjectFileName: string): Boolean;
    function OpenProject(const AProjectFileName: string): Boolean;
  end;

implementation

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  ToolsAPI,
  RadIA.Core.Types,
  RadIA.OTA.DockableForm,
  Winapi.Windows;

function TRadIAOTAProjectOpeningFacade.CloseProject(
  const AProjectFileName: string
): Boolean;
var
  LClosed: Boolean;
begin
  if GetCurrentThreadId = MainThreadID then
    Exit(CloseProjectOnMainThread(AProjectFileName));

  LClosed := False;
  TThread.Synchronize(
    nil,
    procedure
    begin
      LClosed := CloseProjectOnMainThread(AProjectFileName);
    end
  );
  if not LClosed or not WaitForMainThreadQueue then
    Exit(False);
  TThread.Sleep(500);
  Result := WaitForMainThreadQueue;
end;

function TRadIAOTAProjectOpeningFacade.CloseProjectOnMainThread(
  const AProjectFileName: string
): Boolean;
var
  LIndex: Integer;
  LModule: IOTAModule;
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
  LProjectGroup: IOTAProjectGroup;
begin
  Result := False;
  if not Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    Exit;
  for LIndex := 0 to LModuleServices.ModuleCount - 1 do
  begin
    LModule := LModuleServices.Modules[LIndex];
    if Assigned(LModule) and
      SameText(LModule.FileName, AProjectFileName) then
    begin
      TInterlocked.Increment(GProjectTransitionCount);
      try
        LProjectGroup := LModuleServices.MainProjectGroup;
        if Assigned(LProjectGroup) and
          Supports(LModule, IOTAProject, LProject) then
        begin
          LProjectGroup.RemoveProject(LProject);
          Exit(LProject.CloseModule(True));
        end;
        Exit(LModule.CloseModule(True));
      finally
        TInterlocked.Decrement(GProjectTransitionCount);
      end;
    end;
  end;
  Result := True;
end;

function TRadIAOTAProjectOpeningFacade.OpenProject(
  const AProjectFileName: string
): Boolean;
var
  LOpened: Boolean;
begin
  if GetCurrentThreadId = MainThreadID then
  begin
    Result := OpenProjectOnMainThread(AProjectFileName);
    if Result then
      Result := IsProjectOpenOnMainThread(AProjectFileName);
    Exit;
  end;

  LOpened := False;
  TThread.Synchronize(
    nil,
    procedure
    begin
      LOpened := OpenProjectOnMainThread(AProjectFileName);
    end
  );
  if not LOpened or not WaitForMainThreadQueue then
    Exit(False);
  Result := WaitForProjectOpen(AProjectFileName);
end;

function TRadIAOTAProjectOpeningFacade.IsProjectOpenOnMainThread(
  const AProjectFileName: string
): Boolean;
var
  LIndex: Integer;
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
  LProjectGroup: IOTAProjectGroup;
begin
  Result := False;
  if not Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    Exit;
  LProjectGroup := LModuleServices.MainProjectGroup;
  if Assigned(LProjectGroup) then
    for LIndex := 0 to LProjectGroup.ProjectCount - 1 do
    begin
      LProject := LProjectGroup.Projects[LIndex];
      if Assigned(LProject) and
        SameFileName(LProject.FileName, AProjectFileName) then
        Exit(True);
    end;
  LProject := LModuleServices.GetActiveProject;
  Result := Assigned(LProject) and
    SameFileName(LProject.FileName, AProjectFileName);
end;

function TRadIAOTAProjectOpeningFacade.WaitForProjectOpen(
  const AProjectFileName: string
): Boolean;
const
  CAttemptCount = 40;
  CAttemptDelayMs = 250;
var
  LAttempt: Integer;
  LProjectOpen: Boolean;
begin
  Result := False;
  for LAttempt := 1 to CAttemptCount do
  begin
    LProjectOpen := False;
    TThread.Synchronize(
      nil,
      procedure
      begin
        LProjectOpen := IsProjectOpenOnMainThread(AProjectFileName);
      end
    );
    if LProjectOpen then
      Exit(True);
    if not WaitForMainThreadQueue then
      Exit;
    TThread.Sleep(CAttemptDelayMs);
  end;
end;

function TRadIAOTAProjectOpeningFacade.OpenProjectOnMainThread(
  const AProjectFileName: string
): Boolean;
var
  LActionServices: IOTAActionServices;
begin
  Result := False;
  if Trim(AProjectFileName) = '' then
    Exit;
  ShowRadIAChat;
  if not Supports(
    BorlandIDEServices,
    IOTAActionServices,
    LActionServices
  ) then
    Exit;
  TInterlocked.Increment(GProjectTransitionCount);
  try
    Result := LActionServices.OpenFile(AProjectFileName);
  finally
    TInterlocked.Decrement(GProjectTransitionCount);
  end;
  if Result then
    ShowRadIAChat;
end;

function TRadIAOTAProjectOpeningFacade.WaitForMainThreadQueue: Boolean;
var
  LEvent: TEvent;
begin
  LEvent := TEvent.Create(nil, True, False, '');
  TThread.ForceQueue(
    nil,
    procedure
    begin
      LEvent.SetEvent;
    end
  );
  Result := LEvent.WaitFor(10000) = wrSignaled;
  if Result then
    LEvent.Free;
end;

end.
