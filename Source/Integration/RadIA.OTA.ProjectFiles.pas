unit RadIA.OTA.ProjectFiles;

interface

uses
  System.Classes,
  RadIA.Core.ProjectFiles;

type
  TRadIAOTAProjectFileFacade = class(
    TInterfacedObject,
    IRadIAProjectFileFacade
  )
  private
    procedure RunOnMainThread(const AAction: TThreadProcedure);
  public
    function AddFile(
      const AFileName: string;
      const AIsUnitOrForm: Boolean
    ): Boolean;
    function RemoveFile(const AFileName: string): Boolean;
    function FileInProject(const AFileName: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  ToolsAPI,
  Winapi.Windows,
  RadIA.Core.Types;

function ActiveProject: IOTAProject;
var
  LModuleServices: IOTAModuleServices;
begin
  Result := nil;
  if Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    Result := LModuleServices.GetActiveProject;
end;

function ProjectContainsFile(
  const AProject: IOTAProject;
  const AFileName: string
): Boolean;
var
  LIndex: Integer;
  LModuleInfo: IOTAModuleInfo;
begin
  Result := False;
  if not Assigned(AProject) then
    Exit;
  for LIndex := 0 to AProject.GetModuleCount - 1 do
  begin
    LModuleInfo := AProject.GetModule(LIndex);
    if Assigned(LModuleInfo) and
      SameFileName(LModuleInfo.FileName, AFileName) then
      Exit(True);
  end;
end;

function TRadIAOTAProjectFileFacade.AddFile(
  const AFileName: string;
  const AIsUnitOrForm: Boolean
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LProject: IOTAProject;
    begin
      LProject := ActiveProject;
      if not Assigned(LProject) or
        ProjectContainsFile(LProject, AFileName) then
        Exit;
      LProject.AddFile(AFileName, AIsUnitOrForm);
      LResult := ProjectContainsFile(LProject, AFileName);
    end
  );
  Result := LResult;
end;

function TRadIAOTAProjectFileFacade.FileInProject(
  const AFileName: string
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    begin
      LResult := ProjectContainsFile(ActiveProject, AFileName);
    end
  );
  Result := LResult;
end;

function TRadIAOTAProjectFileFacade.RemoveFile(
  const AFileName: string
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LProject: IOTAProject;
    begin
      LProject := ActiveProject;
      if not ProjectContainsFile(LProject, AFileName) then
        Exit;
      LProject.RemoveFile(AFileName);
      LResult := not ProjectContainsFile(LProject, AFileName);
    end
  );
  Result := LResult;
end;

procedure TRadIAOTAProjectFileFacade.RunOnMainThread(
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

end.
