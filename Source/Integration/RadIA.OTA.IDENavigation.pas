unit RadIA.OTA.IDENavigation;

interface

uses
  System.Classes,
  RadIA.Core.IDENavigation,
  RadIA.Core.Interfaces;

type
  TRadIAOTAIDENavigationFacade = class(
    TInterfacedObject,
    IRadIAIDENavigationFacade
  )
  private
    FEditorAdapter: IRadIAEditorAdapter;
    procedure RunOnMainThread(const AAction: TThreadProcedure);
  public
    constructor Create(
      const AEditorAdapter: IRadIAEditorAdapter
    );
    function ListProjectGroupProjects: TArray<string>;
    function GetProjectDependencies: TArray<string>;
    function GetUnitSymbols(
      const AMaxSymbols: Integer
    ): TArray<TRadIAUnitSymbol>;
    function GetEditorSemanticContext: string;
    function NavigateToFile(
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer
    ): TRadIANavigationResult;
    function NavigateToSymbol(
      const ASymbol: string
    ): TRadIANavigationResult;
    function NavigateToDevelopmentSurface(
      const AFileName: string;
      const ASurface: TRadIADevelopmentSurface
    ): TRadIANavigationResult;
    function ListIDEActions: TArray<TRadIAIDEAction>;
    function ExecuteIDEAction(
      const AActionName: string
    ): TRadIANavigationResult;
  end;

implementation

uses
  System.Actions,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  Vcl.ActnList,
  Winapi.Windows,
  RadIA.Core.EditorContext,
  RadIA.Core.Types;

const
  CNavigationUnavailable = 'The IDE navigation service is shutting down.';
  CSafeActionNames: array[0..6] of string = (
    'ViewProjectManager',
    'ViewProjectManagerCommand',
    'ViewToolPalette',
    'ViewStructure',
    'ViewObjectInspector',
    'SearchFind',
    'SearchFindInFiles'
  );

function FindIDEAction(
  const AActionName: string
): TContainedAction;
var
  LActionIndex: Integer;
  LActionList: TCustomActionList;
  LServices: INTAServices;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, INTAServices, LServices) then
    Exit;
  LActionList := LServices.ActionList;
  if not Assigned(LActionList) then
    Exit;
  for LActionIndex := 0 to LActionList.ActionCount - 1 do
    if Assigned(LActionList[LActionIndex]) and
      SameText(
        LActionList[LActionIndex].Name,
        AActionName
      ) then
      Exit(LActionList[LActionIndex]);
end;

function IsSafeActionName(
  const AActionName: string
): Boolean;
var
  LSafeName: string;
begin
  for LSafeName in CSafeActionNames do
    if SameText(LSafeName, Trim(AActionName)) then
      Exit(True);
  Result := False;
end;

function IsProjectFile(
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
  if SameFileName(AProject.FileName, AFileName) then
    Exit(True);
  if SameFileName(
    ChangeFileExt(AProject.FileName, '.dpr'),
    AFileName
  ) then
    Exit(True);
  for LIndex := 0 to AProject.GetModuleCount - 1 do
  begin
    LModuleInfo := AProject.GetModule(LIndex);
    if Assigned(LModuleInfo) and
      SameFileName(LModuleInfo.FileName, AFileName) then
      Exit(True);
  end;
end;

function ResolveProjectModule(
  const AFileName: string;
  const AModuleServices: IOTAModuleServices;
  out AErrorMessage: string
): IOTAModule;
var
  LProject: IOTAProject;
  LProjectGroup: IOTAProjectGroup;
begin
  Result := nil;
  AErrorMessage := '';
  LProjectGroup := AModuleServices.MainProjectGroup;
  LProject := AModuleServices.GetActiveProject;
  if Assigned(LProjectGroup) then
    LProject := LProjectGroup.FindProject(AFileName);
  if not Assigned(LProject) then
    LProject := AModuleServices.GetActiveProject;
  if not IsProjectFile(LProject, AFileName) then
  begin
    AErrorMessage :=
      'Code/Design navigation is restricted to the active project.';
    Exit;
  end;
  Result := AModuleServices.FindModule(AFileName);
  if not Assigned(Result) then
    Result := AModuleServices.OpenModule(AFileName);
  if not Assigned(Result) then
    AErrorMessage := 'The requested project module could not be opened.';
end;

function ShowDevelopmentSurface(
  const AModule: IOTAModule;
  const ASurface: TRadIADevelopmentSurface
): Boolean;
var
  LEditor: IOTAEditor;
  LIndex: Integer;
begin
  Result := False;
  for LIndex := 0 to AModule.ModuleFileCount - 1 do
  begin
    LEditor := AModule.ModuleFileEditors[LIndex];
    if not Assigned(LEditor) then
      Continue;
    Result :=
      ((ASurface = dsCode) and Supports(LEditor, IOTASourceEditor)) or
      ((ASurface = dsDesign) and Supports(LEditor, IOTAFormEditor));
    if Result then
    begin
      LEditor.Show;
      Exit;
    end;
  end;
end;

{ TRadIAOTAIDENavigationFacade }

constructor TRadIAOTAIDENavigationFacade.Create(
  const AEditorAdapter: IRadIAEditorAdapter
);
begin
  inherited Create;
  if not Assigned(AEditorAdapter) then
    raise EArgumentNilException.Create('AEditorAdapter');
  FEditorAdapter := AEditorAdapter;
end;

function TRadIAOTAIDENavigationFacade.ExecuteIDEAction(
  const AActionName: string
): TRadIANavigationResult;
var
  LResult: TRadIANavigationResult;
begin
  LResult := TRadIANavigationResult.Failed(
    'The requested IDE action is not available.'
  );
  RunOnMainThread(
    procedure
    var
      LAction: TContainedAction;
    begin
      if not IsSafeActionName(AActionName) then
      begin
        LResult := TRadIANavigationResult.Failed(
          'The requested IDE action is not in the safe allowlist.'
        );
        Exit;
      end;
      LAction := FindIDEAction(AActionName);
      if not Assigned(LAction) or not LAction.Enabled then
        Exit;
      LAction.Execute;
      LResult := TRadIANavigationResult.Succeeded(
        '',
        0,
        0,
        'The IDE action was executed.'
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.GetProjectDependencies:
  TArray<string>;
var
  LResult: TArray<string>;
begin
  RunOnMainThread(
    procedure
    var
      LDependencies: IOTAProjectDependenciesList;
      LDependencyServices: IOTAProjectGroupProjectDependencies;
      LIndex: Integer;
      LList: TList<string>;
      LModuleServices: IOTAModuleServices;
      LProject: IOTAProject;
      LProjectGroup: IOTAProjectGroup;
    begin
      SetLength(LResult, 0);
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;
      LProjectGroup := LModuleServices.MainProjectGroup;
      LProject := LModuleServices.GetActiveProject;
      if not Assigned(LProjectGroup) or
        not Assigned(LProject) or
        not Supports(
          LProjectGroup,
          IOTAProjectGroupProjectDependencies,
          LDependencyServices
        ) then
        Exit;
      LDependencies := LDependencyServices.GetProjectDependencies(LProject);
      if not Assigned(LDependencies) then
        Exit;
      LList := TList<string>.Create;
      try
        for LIndex := 0 to LDependencies.ProjectCount - 1 do
          if Assigned(LDependencies.Projects[LIndex]) then
            LList.Add(LDependencies.Projects[LIndex].FileName);
        LResult := LList.ToArray;
      finally
        LList.Free;
      end;
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.GetUnitSymbols(
  const AMaxSymbols: Integer
): TArray<TRadIAUnitSymbol>;
var
  LResult: TArray<TRadIAUnitSymbol>;
begin
  RunOnMainThread(
    procedure
    begin
      LResult := TRadIAUnitSymbolScanner.Scan(
        FEditorAdapter.GetText,
        AMaxSymbols
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.GetEditorSemanticContext: string;
var
  LResult: string;
begin
  RunOnMainThread(
    procedure
    var
      LContext: TRadIAEditorSemanticContext;
    begin
      LContext := TRadIAEditorContextAnalyzer.Analyze(
        FEditorAdapter.GetText,
        FEditorAdapter.GetCursorLine
      );
      LResult := LContext.ToPromptContext;
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.ListIDEActions:
  TArray<TRadIAIDEAction>;
var
  LResult: TArray<TRadIAIDEAction>;
begin
  RunOnMainThread(
    procedure
    var
      LAction: TContainedAction;
      LActionName: string;
      LList: TList<TRadIAIDEAction>;
    begin
      LList := TList<TRadIAIDEAction>.Create;
      try
        for LActionName in CSafeActionNames do
        begin
          LAction := FindIDEAction(LActionName);
          if Assigned(LAction) then
            LList.Add(
              TRadIAIDEAction.Create(
                LAction.Name,
                LAction.Caption,
                LAction.Enabled
              )
            );
        end;
        LResult := LList.ToArray;
      finally
        LList.Free;
      end;
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.ListProjectGroupProjects:
  TArray<string>;
var
  LResult: TArray<string>;
begin
  RunOnMainThread(
    procedure
    var
      LIndex: Integer;
      LList: TList<string>;
      LModuleServices: IOTAModuleServices;
      LProjectGroup: IOTAProjectGroup;
    begin
      SetLength(LResult, 0);
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;
      LProjectGroup := LModuleServices.MainProjectGroup;
      if not Assigned(LProjectGroup) then
        Exit;
      LList := TList<string>.Create;
      try
        for LIndex := 0 to LProjectGroup.ProjectCount - 1 do
          if Assigned(LProjectGroup.Projects[LIndex]) then
            LList.Add(LProjectGroup.Projects[LIndex].FileName);
        LResult := LList.ToArray;
      finally
        LList.Free;
      end;
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.NavigateToFile(
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer
): TRadIANavigationResult;
var
  LResult: TRadIANavigationResult;
begin
  LResult := TRadIANavigationResult.Failed(
    'The requested project file could not be opened.'
  );
  RunOnMainThread(
    procedure
    var
      LActionServices: IOTAActionServices;
      LModuleServices: IOTAModuleServices;
      LProject: IOTAProject;
      LProjectGroup: IOTAProjectGroup;
      LResolvedFile: string;
    begin
      if (Trim(AFileName) = '') or (ALine < 1) or (AColumn < 1) then
      begin
        LResult := TRadIANavigationResult.Failed(
          'File name, line, and column must identify a valid source position.'
        );
        Exit;
      end;
      LResolvedFile := TPath.GetFullPath(AFileName);
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;
      LProjectGroup := LModuleServices.MainProjectGroup;
      LProject := nil;
      if Assigned(LProjectGroup) then
        LProject := LProjectGroup.FindProject(LResolvedFile);
      if not Assigned(LProject) then
        LProject := LModuleServices.GetActiveProject;
      if not IsProjectFile(LProject, LResolvedFile) then
      begin
        LResult := TRadIANavigationResult.Failed(
          'Navigation is restricted to files owned by an open project.'
        );
        Exit;
      end;
      if not Supports(
        BorlandIDEServices,
        IOTAActionServices,
        LActionServices
      ) or not LActionServices.OpenFile(LResolvedFile) then
        Exit;
      FEditorAdapter.SetCursorPosition(ALine, AColumn);
      LResult := TRadIANavigationResult.Succeeded(
        LResolvedFile,
        ALine,
        AColumn,
        'The source position is active in the editor.'
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.NavigateToDevelopmentSurface(
  const AFileName: string;
  const ASurface: TRadIADevelopmentSurface
): TRadIANavigationResult;
var
  LResult: TRadIANavigationResult;
begin
  LResult := TRadIANavigationResult.Failed(
    'The requested development surface is unavailable.'
  );
  RunOnMainThread(
    procedure
    var
      LErrorMessage: string;
      LModule: IOTAModule;
      LModuleServices: IOTAModuleServices;
      LResolvedFile: string;
    begin
      if Trim(AFileName) = '' then
      begin
        LResult := TRadIANavigationResult.Failed(
          'A project file is required for Code/Design navigation.'
        );
        Exit;
      end;
      LResolvedFile := TPath.GetFullPath(AFileName);
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;
      LModule := ResolveProjectModule(
        LResolvedFile,
        LModuleServices,
        LErrorMessage
      );
      if not Assigned(LModule) then
      begin
        LResult := TRadIANavigationResult.Failed(
          LErrorMessage
        );
        Exit;
      end;
      if not ShowDevelopmentSurface(LModule, ASurface) then
        Exit;
      LResult := TRadIANavigationResult.Succeeded(
        LResolvedFile,
        0,
        0,
        'The requested Code/Design surface is active.'
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAIDENavigationFacade.NavigateToSymbol(
  const ASymbol: string
): TRadIANavigationResult;
var
  LResult: TRadIANavigationResult;
begin
  LResult := TRadIANavigationResult.Failed(
    'The requested symbol was not found in the active unit.'
  );
  RunOnMainThread(
    procedure
    var
      LSymbol: TRadIAUnitSymbol;
      LSymbols: TArray<TRadIAUnitSymbol>;
    begin
      if Trim(ASymbol) = '' then
        Exit;
      LSymbols := TRadIAUnitSymbolScanner.Scan(
        FEditorAdapter.GetText,
        5000
      );
      for LSymbol in LSymbols do
        if SameText(LSymbol.Name, Trim(ASymbol)) then
        begin
          FEditorAdapter.SetCursorPosition(LSymbol.Line, 1);
          LResult := TRadIANavigationResult.Succeeded(
            FEditorAdapter.GetActiveUnitName,
            LSymbol.Line,
            1,
            'The symbol is active in the editor.'
          );
          Exit;
        end;
    end
  );
  Result := LResult;
end;

procedure TRadIAOTAIDENavigationFacade.RunOnMainThread(
  const AAction: TThreadProcedure
);
begin
  if GIsShuttingDown then
    raise EInvalidOperation.Create(CNavigationUnavailable);
  if GetCurrentThreadId = MainThreadID then
    AAction()
  else
    TThread.Synchronize(nil, AAction);
end;

end.
