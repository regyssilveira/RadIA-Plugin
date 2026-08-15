unit RadIA.OTA.SemanticWorkspace;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.ExtCtrls,
  RadIA.Core.DelphiEnvironment,
  RadIA.Semantic.Workspace;

type
  TRadIAOTASemanticWorkspaceSource = class(
    TInterfacedObject,
    IRadIASemanticWorkspaceSource
  )
  private
    FEnvironment: IRadIADelphiEnvironmentService;
    FLibraryFiles: TDictionary<string, Integer>;
    procedure AddLibraryFiles(
      const ARoot: string;
      const AScopeValue: Integer
    );
    procedure EnsureLibraryFiles;
  public
    constructor Create(const AEnvironment: IRadIADelphiEnvironmentService);
    destructor Destroy; override;
    function Capture(
      out AFiles: TArray<TRadIASemanticWorkspaceFile>;
      out ADefines: TArray<string>;
      out AError: string
    ): Boolean;
  end;

  TRadIAOTASemanticWorkspaceMonitor = class(TComponent)
  private
    FCoordinator: IRadIASemanticWorkspaceCoordinator;
    FTimer: TTimer;
    procedure TimerEvent(Sender: TObject);
  public
    constructor Create(
      AOwner: TComponent;
      const ACoordinator: IRadIASemanticWorkspaceCoordinator
    ); reintroduce;
    destructor Destroy; override;
    procedure Install;
    procedure MarkDirty;
    procedure Stop;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  ToolsAPI,
  RadIA.Core.Types,
  RadIA.OTA.TextReader,
  RadIA.Semantic.Index;

function IsSemanticSource(const AFileName: string): Boolean;
var
  LExtension: string;
begin
  LExtension := ExtractFileExt(AFileName);
  Result := SameText(LExtension, '.pas') or
    SameText(LExtension, '.dpr') or SameText(LExtension, '.dfm');
end;

function SemanticScopeName(const AScope: TRadIASemanticUnitScope): string;
begin
  case AScope of
    susProject: Result := 'project';
    susGroup: Result := 'group';
    susRTL: Result := 'rtl';
    susVCL: Result := 'vcl';
  else
    Result := 'project';
  end;
end;

function FileFingerprint(const AFileName: string): string;
begin
  Result := '';
  if not TFile.Exists(AFileName) then
    Exit;
  Result := IntToStr(TFile.GetSize(AFileName)) + ':' +
    FloatToStr(TFile.GetLastWriteTimeUtc(AFileName));
end;

function FindOpenContent(
  const AFileName: string;
  out AContent: string
): Boolean;
var
  LEditorIndex: Integer;
  LModule: IOTAModule;
  LModuleIndex: Integer;
  LModuleServices: IOTAModuleServices;
  LSourceEditor: IOTASourceEditor;
begin
  Result := False;
  AContent := '';
  if not Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    Exit;
  for LModuleIndex := 0 to LModuleServices.ModuleCount - 1 do
  begin
    LModule := LModuleServices.Modules[LModuleIndex];
    if not Assigned(LModule) then
      Continue;
    for LEditorIndex := 0 to LModule.ModuleFileCount - 1 do
      if Supports(
        LModule.ModuleFileEditors[LEditorIndex],
        IOTASourceEditor,
        LSourceEditor
      ) and SameFileName(LSourceEditor.FileName, AFileName) then
      begin
        AContent := ReadRadIAEditReaderText(LSourceEditor.CreateReader);
        Exit(True);
      end;
  end;
end;

procedure AddWorkspaceFile(
  const AFiles: TDictionary<string, TRadIASemanticWorkspaceFile>;
  const AFileName: string;
  const AScope: TRadIASemanticUnitScope
);
var
  LContent: string;
  LFingerprint: string;
  LFullName: string;
  LKey: string;
begin
  if not IsSemanticSource(AFileName) then
    Exit;
  LFullName := TPath.GetFullPath(AFileName);
  if FindOpenContent(LFullName, LContent) then
    LFingerprint := THashSHA2.GetHashString(LContent)
  else
  begin
    LFingerprint := FileFingerprint(LFullName);
    LContent := '';
  end;
  if LFingerprint = '' then
    Exit;
  LKey := LowerCase(LFullName);
  AFiles.AddOrSetValue(
    LKey,
    TRadIASemanticWorkspaceFile.Create(
      LKey,
      LFullName,
      AScope,
      SemanticScopeName(AScope) + ':' + LFingerprint,
      LContent
    )
  );
end;

procedure AddLibraryWorkspaceFile(
  const AFiles: TDictionary<string, TRadIASemanticWorkspaceFile>;
  const AFileName: string;
  const AScope: TRadIASemanticUnitScope
);
var
  LFullName: string;
  LKey: string;
begin
  LFullName := TPath.GetFullPath(AFileName);
  LKey := LowerCase(LFullName);
  if AFiles.ContainsKey(LKey) then
    Exit;
  AFiles.Add(
    LKey,
    TRadIASemanticWorkspaceFile.Create(
      LKey,
      LFullName,
      AScope,
      SemanticScopeName(AScope) + ':installed',
      ''
    )
  );
end;

procedure AddProjectFiles(
  const AFiles: TDictionary<string, TRadIASemanticWorkspaceFile>;
  const AProject: IOTAProject;
  const AScope: TRadIASemanticUnitScope
);
var
  LIndex: Integer;
  LModuleInfo: IOTAModuleInfo;
begin
  if not Assigned(AProject) then
    Exit;
  AddWorkspaceFile(AFiles, ChangeFileExt(AProject.FileName, '.dpr'), AScope);
  for LIndex := 0 to AProject.GetModuleCount - 1 do
  begin
    LModuleInfo := AProject.GetModule(LIndex);
    if Assigned(LModuleInfo) then
    begin
      AddWorkspaceFile(AFiles, LModuleInfo.FileName, AScope);
      if SameText(ExtractFileExt(LModuleInfo.FileName), '.pas') then
        AddWorkspaceFile(
          AFiles,
          ChangeFileExt(LModuleInfo.FileName, '.dfm'),
          AScope
        );
    end;
  end;
end;

{ TRadIAOTASemanticWorkspaceSource }

constructor TRadIAOTASemanticWorkspaceSource.Create(
  const AEnvironment: IRadIADelphiEnvironmentService
);
begin
  inherited Create;
  if not Assigned(AEnvironment) then
    raise EArgumentNilException.Create('AEnvironment');
  FEnvironment := AEnvironment;
  FLibraryFiles := TDictionary<string, Integer>.Create;
end;

destructor TRadIAOTASemanticWorkspaceSource.Destroy;
begin
  FLibraryFiles.Free;
  inherited Destroy;
end;

procedure TRadIAOTASemanticWorkspaceSource.AddLibraryFiles(
  const ARoot: string;
  const AScopeValue: Integer
);
var
  LFileName: string;
begin
  if not TDirectory.Exists(ARoot) then
    Exit;
  for LFileName in TDirectory.GetFiles(
    ARoot,
    '*.pas',
    TSearchOption.soAllDirectories
  ) do
    FLibraryFiles.AddOrSetValue(LFileName, AScopeValue);
end;

procedure TRadIAOTASemanticWorkspaceSource.EnsureLibraryFiles;
var
  LOTAServices: IOTAServices;
  LSourceRoot: string;
begin
  if FLibraryFiles.Count > 0 then
    Exit;
  if not Supports(BorlandIDEServices, IOTAServices, LOTAServices) then
    Exit;
  LSourceRoot := TPath.Combine(LOTAServices.GetRootDirectory, 'source');
  AddLibraryFiles(TPath.Combine(LSourceRoot, 'rtl'), Ord(susRTL));
  AddLibraryFiles(TPath.Combine(LSourceRoot, 'vcl'), Ord(susVCL));
end;

function TRadIAOTASemanticWorkspaceSource.Capture(
  out AFiles: TArray<TRadIASemanticWorkspaceFile>;
  out ADefines: TArray<string>;
  out AError: string
): Boolean;
var
  LActiveProject: IOTAProject;
  LFiles: TDictionary<string, TRadIASemanticWorkspaceFile>;
  LLibraryFile: TPair<string, Integer>;
  LModuleServices: IOTAModuleServices;
  LProfile: TRadIADelphiEnvironmentProfile;
  LProject: IOTAProject;
  LProjectGroup: IOTAProjectGroup;
  LProjectIndex: Integer;
begin
  Result := False;
  AError := '';
  SetLength(AFiles, 0);
  SetLength(ADefines, 0);
  if GIsShuttingDown or not Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
  begin
    AError := 'The IDE workspace is unavailable.';
    Exit;
  end;
  LFiles := TDictionary<string, TRadIASemanticWorkspaceFile>.Create;
  try
    LActiveProject := LModuleServices.GetActiveProject;
    LProjectGroup := LModuleServices.MainProjectGroup;
    if Assigned(LProjectGroup) then
      for LProjectIndex := 0 to LProjectGroup.ProjectCount - 1 do
      begin
        LProject := LProjectGroup.Projects[LProjectIndex];
        if Assigned(LProject) and (LProject <> LActiveProject) then
          AddProjectFiles(LFiles, LProject, susGroup);
      end;
    AddProjectFiles(LFiles, LActiveProject, susProject);
    EnsureLibraryFiles;
    for LLibraryFile in FLibraryFiles do
      AddLibraryWorkspaceFile(
        LFiles,
        LLibraryFile.Key,
        TRadIASemanticUnitScope(LLibraryFile.Value)
      );
    LProfile := FEnvironment.BuildProfile;
    ADefines := LProfile.Defines;
    AFiles := LFiles.Values.ToArray;
    Result := True;
  except
    on E: Exception do
      AError := E.Message;
  end;
  LFiles.Free;
end;

{ TRadIAOTASemanticWorkspaceMonitor }

constructor TRadIAOTASemanticWorkspaceMonitor.Create(
  AOwner: TComponent;
  const ACoordinator: IRadIASemanticWorkspaceCoordinator
);
begin
  inherited Create(AOwner);
  if not Assigned(ACoordinator) then
    raise EArgumentNilException.Create('ACoordinator');
  FCoordinator := ACoordinator;
end;

destructor TRadIAOTASemanticWorkspaceMonitor.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TRadIAOTASemanticWorkspaceMonitor.Install;
begin
  if Assigned(FTimer) then
    Exit;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 1500;
  FTimer.OnTimer := TimerEvent;
  FTimer.Enabled := True;
  FCoordinator.MarkDirty;
end;

procedure TRadIAOTASemanticWorkspaceMonitor.MarkDirty;
begin
  if Assigned(FCoordinator) then
    FCoordinator.MarkDirty;
end;

procedure TRadIAOTASemanticWorkspaceMonitor.Stop;
begin
  if Assigned(FTimer) then
    FTimer.Enabled := False;
  if Assigned(FCoordinator) then
    FCoordinator.Stop;
  FreeAndNil(FTimer);
  FCoordinator := nil;
end;

procedure TRadIAOTASemanticWorkspaceMonitor.TimerEvent(Sender: TObject);
begin
  if GIsShuttingDown then
  begin
    FTimer.Enabled := False;
    FCoordinator.Stop;
    Exit;
  end;
  FCoordinator.MarkDirty;
  FCoordinator.Poll;
end;

end.
