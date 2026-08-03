unit RadIA.OTA.Knowledge;

interface

uses
  System.Classes,
  RadIA.Core.Knowledge,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAOTAKnowledgeSource = class(
    TInterfacedObject,
    IRadIAKnowledgeSource
  )
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FWorkspace: IRadIAWorkspaceFacade;
    function IsSupportedSourceFile(const AFileName: string): Boolean;
    function ReadOpenBuffer(
      const AFileName: string;
      out AContent: string
    ): Boolean;
    procedure RunOnMainThread(const AAction: TThreadProcedure);
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function GetProjectId: string;
    function ListSourceFiles: TArray<string>;
    function ReadSourceFile(
      const AFileName: string;
      out ADocument: TRadIAKnowledgeDocument
    ): Boolean;
  end;

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  Winapi.Windows,
  RadIA.Core.Types,
  RadIA.OTA.TextReader;

const
  CKnowledgeUnavailable = 'The knowledge source is shutting down.';
  CMaxKnowledgeFileBytes = 2 * 1024 * 1024;

{ TRadIAOTAKnowledgeSource }

constructor TRadIAOTAKnowledgeSource.Create(
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
end;

function TRadIAOTAKnowledgeSource.GetProjectId: string;
begin
  Result := FWorkspace.GetActiveProject.FileName;
end;

function TRadIAOTAKnowledgeSource.IsSupportedSourceFile(
  const AFileName: string
): Boolean;
var
  LExtension: string;
begin
  LExtension := LowerCase(TPath.GetExtension(AFileName));
  Result := (LExtension = '.pas') or
    (LExtension = '.dpr') or
    (LExtension = '.dpk') or
    (LExtension = '.inc');
end;

function TRadIAOTAKnowledgeSource.ListSourceFiles:
  TArray<string>;
var
  LFileName: string;
  LFiles: TList<string>;
begin
  LFiles := TList<string>.Create;
  try
    for LFileName in FWorkspace.ListProjectUnits do
    begin
      if IsSupportedSourceFile(LFileName) then
        LFiles.Add(LFileName);
    end;
    Result := LFiles.ToArray;
  finally
    LFiles.Free;
  end;
end;

function TRadIAOTAKnowledgeSource.ReadOpenBuffer(
  const AFileName: string;
  out AContent: string
): Boolean;
var
  LContent: string;
  LResult: Boolean;
begin
  LContent := '';
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LEditor: IOTAEditor;
      LEditorIndex: Integer;
      LModule: IOTAModule;
      LModuleIndex: Integer;
      LModuleServices: IOTAModuleServices;
      LSourceEditor: IOTASourceEditor;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;

      for LModuleIndex := 0 to
        LModuleServices.ModuleCount - 1 do
      begin
        LModule := LModuleServices.Modules[LModuleIndex];
        if not Assigned(LModule) then
          Continue;
        for LEditorIndex := 0 to
          LModule.GetModuleFileCount - 1 do
        begin
          LEditor := LModule.GetModuleFileEditor(LEditorIndex);
          if Supports(
            LEditor,
            IOTASourceEditor,
            LSourceEditor
          ) and SameFileName(
            LSourceEditor.FileName,
            AFileName
          ) then
          begin
            LContent := ReadRadIAEditReaderText(
              LSourceEditor.CreateReader
            );
            LResult := True;
            Exit;
          end;
        end;
      end;
    end
  );
  AContent := LContent;
  Result := LResult;
end;

function TRadIAOTAKnowledgeSource.ReadSourceFile(
  const AFileName: string;
  out ADocument: TRadIAKnowledgeDocument
): Boolean;
var
  LContent: string;
  LPathValidation: TRadIAPathValidation;
  LProject: TRadIAProjectSnapshot;
begin
  ADocument := Default(TRadIAKnowledgeDocument);
  Result := False;
  if not IsSupportedSourceFile(AFileName) then
    Exit;

  LProject := FWorkspace.GetActiveProject;
  LPathValidation := FBoundary.ValidatePath(
    LProject.RootPath,
    AFileName
  );
  if not LPathValidation.Allowed then
    Exit;

  if not ReadOpenBuffer(AFileName, LContent) then
  begin
    if not TFile.Exists(AFileName) then
      Exit;
    if TFile.GetSize(AFileName) > CMaxKnowledgeFileBytes then
      Exit;
    try
      LContent := TFile.ReadAllText(AFileName);
    except
      on Exception do
        Exit;
    end;
  end;

  ADocument := TRadIAKnowledgeDocument.Create(
    AFileName,
    THashSHA2.GetHashString(LContent),
    LContent
  );
  Result := True;
end;

procedure TRadIAOTAKnowledgeSource.RunOnMainThread(
  const AAction: TThreadProcedure
);
begin
  if GIsShuttingDown then
    raise EInvalidOperation.Create(CKnowledgeUnavailable);
  if GetCurrentThreadId = MainThreadID then
    AAction()
  else
    TThread.Synchronize(nil, AAction);
end;

end.
