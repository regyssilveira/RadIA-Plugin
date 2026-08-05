unit RadIA.OTA.Knowledge;

interface

uses
  System.Classes,
  System.Generics.Collections,
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
    procedure AddCompanionFiles(
      const AFileName: string;
      const AFiles: TList<string>;
      const ASeen: TDictionary<string, Boolean>
    );
    procedure AddDocumentationFiles(
      const ARootPath: string;
      const AFiles: TList<string>;
      const ASeen: TDictionary<string, Boolean>
    );
    procedure AddDocumentationTree(
      const ARootPath: string;
      const AFiles: TList<string>;
      const ASeen: TDictionary<string, Boolean>
    );
    procedure AddUniqueFile(
      const AFileName: string;
      const AFiles: TList<string>;
      const ASeen: TDictionary<string, Boolean>;
      const ARequireExists: Boolean
    );
    function IsSupportedSourceFile(const AFileName: string): Boolean;
    function IsReparseDirectory(const ADirectory: string): Boolean;
    function ReadDiskContent(
      const AFileName: string;
      out AContent: string
    ): Boolean;
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
  CMaxKnowledgeFiles = 5000;
  CMaxKnowledgeDirectories = 1000;

procedure TRadIAOTAKnowledgeSource.AddCompanionFiles(
  const AFileName: string;
  const AFiles: TList<string>;
  const ASeen: TDictionary<string, Boolean>
);
var
  LBaseName: string;
begin
  if not SameText(TPath.GetExtension(AFileName), '.pas') then
    Exit;
  LBaseName := TPath.Combine(
    TPath.GetDirectoryName(AFileName),
    TPath.GetFileNameWithoutExtension(AFileName)
  );
  AddUniqueFile(LBaseName + '.dfm', AFiles, ASeen, True);
  AddUniqueFile(LBaseName + '.fmx', AFiles, ASeen, True);
end;

procedure TRadIAOTAKnowledgeSource.AddDocumentationFiles(
  const ARootPath: string;
  const AFiles: TList<string>;
  const ASeen: TDictionary<string, Boolean>
);
var
  LDirectory: string;
  LDirectories: TArray<string>;
  LFileName: string;
begin
  if not TDirectory.Exists(ARootPath) or
    IsReparseDirectory(ARootPath) then
    Exit;
  try
    for LFileName in TDirectory.GetFiles(
      ARootPath,
      '*',
      TSearchOption.soTopDirectoryOnly
    ) do
      AddUniqueFile(LFileName, AFiles, ASeen, True);
  except
    on Exception do
      Exit;
  end;
  LDirectories := [
    TPath.Combine(ARootPath, 'docs'),
    TPath.Combine(ARootPath, 'doc')
  ];
  for LDirectory in LDirectories do
    AddDocumentationTree(LDirectory, AFiles, ASeen);
end;

procedure TRadIAOTAKnowledgeSource.AddDocumentationTree(
  const ARootPath: string;
  const AFiles: TList<string>;
  const ASeen: TDictionary<string, Boolean>
);
var
  LCurrent: string;
  LDirectory: string;
  LDirectoryCount: Integer;
  LFileName: string;
  LQueue: TQueue<string>;
begin
  if not TDirectory.Exists(ARootPath) or
    IsReparseDirectory(ARootPath) then
    Exit;
  LQueue := TQueue<string>.Create;
  try
    LQueue.Enqueue(ARootPath);
    LDirectoryCount := 0;
    while (LQueue.Count > 0) and
      (LDirectoryCount < CMaxKnowledgeDirectories) and
      (AFiles.Count < CMaxKnowledgeFiles) do
    begin
      LCurrent := LQueue.Dequeue;
      Inc(LDirectoryCount);
      try
        for LFileName in TDirectory.GetFiles(
          LCurrent,
          '*',
          TSearchOption.soTopDirectoryOnly
        ) do
          AddUniqueFile(LFileName, AFiles, ASeen, True);
        for LDirectory in TDirectory.GetDirectories(LCurrent) do
          if not IsReparseDirectory(LDirectory) then
            LQueue.Enqueue(LDirectory);
      except
        on E: Exception do
          OutputDebugString(PChar(
            'RadIA knowledge documentation scan skipped: ' + E.Message
          ));
      end;
    end;
  finally
    LQueue.Free;
  end;
end;

procedure TRadIAOTAKnowledgeSource.AddUniqueFile(
  const AFileName: string;
  const AFiles: TList<string>;
  const ASeen: TDictionary<string, Boolean>;
  const ARequireExists: Boolean
);
begin
  if (AFiles.Count >= CMaxKnowledgeFiles) or
    not IsSupportedSourceFile(AFileName) or
    (ARequireExists and not TFile.Exists(AFileName)) or
    ASeen.ContainsKey(AFileName) then
    Exit;
  ASeen.Add(AFileName, True);
  AFiles.Add(AFileName);
end;

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
begin
  Result := TRadIAKnowledgeFilePolicy.IsSupported(AFileName);
end;

function TRadIAOTAKnowledgeSource.IsReparseDirectory(
  const ADirectory: string
): Boolean;
var
  LAttributes: Cardinal;
begin
  LAttributes := GetFileAttributes(PChar(ADirectory));
  Result := (LAttributes <> INVALID_FILE_ATTRIBUTES) and
    ((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0);
end;

function TRadIAOTAKnowledgeSource.ListSourceFiles:
  TArray<string>;
var
  LFileName: string;
  LFiles: TList<string>;
  LProject: TRadIAProjectSnapshot;
  LSeen: TDictionary<string, Boolean>;
begin
  LFiles := TList<string>.Create;
  LSeen := TDictionary<string, Boolean>.Create;
  try
    LProject := FWorkspace.GetActiveProject;
    for LFileName in FWorkspace.ListProjectUnits do
    begin
      AddUniqueFile(LFileName, LFiles, LSeen, False);
      AddCompanionFiles(LFileName, LFiles, LSeen);
    end;
    AddUniqueFile(LProject.FileName, LFiles, LSeen, True);
    AddDocumentationFiles(LProject.RootPath, LFiles, LSeen);
    Result := LFiles.ToArray;
  finally
    LSeen.Free;
    LFiles.Free;
  end;
end;

function TRadIAOTAKnowledgeSource.ReadDiskContent(
  const AFileName: string;
  out AContent: string
): Boolean;
var
  LBytes: TBytes;
begin
  Result := False;
  AContent := '';
  if not TFile.Exists(AFileName) or
    (TFile.GetSize(AFileName) > CMaxKnowledgeFileBytes) then
    Exit;
  try
    LBytes := TFile.ReadAllBytes(AFileName);
    if (Length(LBytes) >= 4) and
      (LBytes[0] = Ord('T')) and
      (LBytes[1] = Ord('P')) and
      (LBytes[2] = Ord('F')) and
      (LBytes[3] = Ord('0')) then
      Exit;
    AContent := TEncoding.UTF8.GetString(LBytes);
    Result := True;
  except
    on Exception do
      Result := False;
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
    if not ReadDiskContent(AFileName, LContent) then
      Exit;

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
