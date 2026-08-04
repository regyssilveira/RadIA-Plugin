unit RadIA.Core.ProjectFiles;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAProjectFileKind = (
    pfkUnit,
    pfkVclForm,
    pfkFmxForm
  );

  TRadIAProjectFileOperation = (
    pfoAdd,
    pfoRemove
  );

  TRadIAProjectFileContent = record
  private
    FFileName: string;
    FContent: string;
  public
    constructor Create(
      const AFileName: string;
      const AContent: string
    );
    property FileName: string read FFileName;
    property Content: string read FContent;
  end;

  TRadIAProjectFilePreview = class
  private
    FId: string;
    FOperation: TRadIAProjectFileOperation;
    FKind: TRadIAProjectFileKind;
    FMainFileName: string;
    FFiles: TArray<TRadIAProjectFileContent>;
    FApplied: Boolean;
    FExpiresAtUtc: TDateTime;
  public
    constructor Create(
      const AId: string;
      const AOperation: TRadIAProjectFileOperation;
      const AKind: TRadIAProjectFileKind;
      const AMainFileName: string;
      const AFiles: TArray<TRadIAProjectFileContent>;
      const AExpiresAtUtc: TDateTime
    );
    property Id: string read FId;
    property Operation: TRadIAProjectFileOperation read FOperation;
    property Kind: TRadIAProjectFileKind read FKind;
    property MainFileName: string read FMainFileName;
    property Files: TArray<TRadIAProjectFileContent> read FFiles;
    property Applied: Boolean read FApplied write FApplied;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
  end;

  TRadIAProjectFileResult = record
  private
    FSuccess: Boolean;
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAProjectFilePreview;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAProjectFileResult; static;
    class function Succeeded(
      const APreview: TRadIAProjectFilePreview
    ): TRadIAProjectFileResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAProjectFilePreview read FPreview;
  end;

  IRadIAProjectFileFacade = interface
    ['{04F42B08-F984-4EF9-8747-1D71EA557532}']
    function AddFile(
      const AFileName: string;
      const AIsUnitOrForm: Boolean
    ): Boolean;
    function RemoveFile(const AFileName: string): Boolean;
    function FileInProject(const AFileName: string): Boolean;
  end;

  IRadIAProjectFileService = interface
    ['{DF2D7DC8-C4B8-48C8-B3CC-F364136281C0}']
    function PrepareAdd(
      const AUnitName: string;
      const ARelativeDirectory: string;
      const AKind: TRadIAProjectFileKind
    ): TRadIAProjectFileResult;
    function PrepareRemove(
      const AFileName: string
    ): TRadIAProjectFileResult;
    function Apply(
      const APreviewId: string
    ): TRadIAProjectFileResult;
    function Revert(
      const APreviewId: string
    ): TRadIAProjectFileResult;
    procedure Clear;
  end;

  TRadIAProjectFileService = class(
    TInterfacedObject,
    IRadIAProjectFileService
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    FFacade: IRadIAProjectFileFacade;
    FPreviews: TObjectDictionary<string, TRadIAProjectFilePreview>;
    FExpirationMinutes: Integer;
    function ApplyAdd(
      const APreview: TRadIAProjectFilePreview
    ): TRadIAProjectFileResult;
    function ApplyRemove(
      const APreview: TRadIAProjectFilePreview
    ): TRadIAProjectFileResult;
    function BuildFiles(
      const AUnitName: string;
      const ADirectoryPath: string;
      const AKind: TRadIAProjectFileKind
    ): TArray<TRadIAProjectFileContent>;
    procedure CleanupFiles(
      const AFiles: TArray<TRadIAProjectFileContent>
    );
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAProjectFilePreview
    ): TRadIAProjectFileResult;
    function RevertAdd(
      const APreview: TRadIAProjectFilePreview
    ): TRadIAProjectFileResult;
    function RevertRemove(
      const APreview: TRadIAProjectFilePreview
    ): TRadIAProjectFileResult;
    function ValidateUnitName(const AUnitName: string): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AFacade: IRadIAProjectFileFacade;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function PrepareAdd(
      const AUnitName: string;
      const ARelativeDirectory: string;
      const AKind: TRadIAProjectFileKind
    ): TRadIAProjectFileResult;
    function PrepareRemove(
      const AFileName: string
    ): TRadIAProjectFileResult;
    function Apply(
      const APreviewId: string
    ): TRadIAProjectFileResult;
    function Revert(
      const APreviewId: string
    ): TRadIAProjectFileResult;
    procedure Clear;
  end;

implementation

uses
  System.Character,
  System.DateUtils,
  System.IOUtils,
  System.SysUtils;

const
  CPreconditionFailed = 'precondition_failed';
  CPreviewExpired = 'preview_expired';
  CPreviewNotFound = 'preview_not_found';
  CResourceLimit = 'resource_limit';
  CMaxPreviews = 32;

{ TRadIAProjectFileContent }

constructor TRadIAProjectFileContent.Create(
  const AFileName: string;
  const AContent: string
);
begin
  FFileName := AFileName;
  FContent := AContent;
end;

{ TRadIAProjectFilePreview }

constructor TRadIAProjectFilePreview.Create(
  const AId: string;
  const AOperation: TRadIAProjectFileOperation;
  const AKind: TRadIAProjectFileKind;
  const AMainFileName: string;
  const AFiles: TArray<TRadIAProjectFileContent>;
  const AExpiresAtUtc: TDateTime
);
begin
  inherited Create;
  FId := AId;
  FOperation := AOperation;
  FKind := AKind;
  FMainFileName := AMainFileName;
  FFiles := Copy(AFiles);
  FExpiresAtUtc := AExpiresAtUtc;
end;

{ TRadIAProjectFileResult }

class function TRadIAProjectFileResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAProjectFileResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIAProjectFileResult.Succeeded(
  const APreview: TRadIAProjectFilePreview
): TRadIAProjectFileResult;
begin
  Result.FSuccess := True;
  Result.FPreview := APreview;
end;

{ TRadIAProjectFileService }

function TRadIAProjectFileService.Apply(
  const APreviewId: string
): TRadIAProjectFileResult;
var
  LPreview: TRadIAProjectFilePreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if LPreview.Applied then
      Exit(TRadIAProjectFileResult.Failed(
        CPreconditionFailed,
        'Project file preview was already applied.'
      ));
    if LPreview.Operation = pfoAdd then
      Result := ApplyAdd(LPreview)
    else
      Result := ApplyRemove(LPreview);
    if Result.Success then
      LPreview.Applied := True;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIAProjectFileService.ApplyAdd(
  const APreview: TRadIAProjectFilePreview
): TRadIAProjectFileResult;
var
  LFile: TRadIAProjectFileContent;
  LIndex: Integer;
  LStagingFiles: TArray<string>;
begin
  for LFile in APreview.Files do
  begin
    if TFile.Exists(LFile.FileName) then
      Exit(TRadIAProjectFileResult.Failed(
        CPreconditionFailed,
        'A project file target already exists.'
      ));
  end;
  SetLength(LStagingFiles, Length(APreview.Files));
  try
    for LIndex := Low(APreview.Files) to High(APreview.Files) do
    begin
      LFile := APreview.Files[LIndex];
      TDirectory.CreateDirectory(
        TPath.GetDirectoryName(LFile.FileName)
      );
      LStagingFiles[LIndex] := LFile.FileName +
        '.radia-stage-' + TGUID.NewGuid.ToString;
      TFile.WriteAllText(
        LStagingFiles[LIndex],
        LFile.Content,
        TEncoding.UTF8
      );
    end;
    for LIndex := Low(APreview.Files) to High(APreview.Files) do
      TFile.Move(
        LStagingFiles[LIndex],
        APreview.Files[LIndex].FileName
      );
    if not FFacade.AddFile(APreview.MainFileName, True) then
    begin
      CleanupFiles(APreview.Files);
      Exit(TRadIAProjectFileResult.Failed(
        'project_registration_failed',
        'Files were created but could not be registered in the project.'
      ));
    end;
  except
    for LIndex := Low(LStagingFiles) to High(LStagingFiles) do
    begin
      if (LStagingFiles[LIndex] <> '') and
        TFile.Exists(LStagingFiles[LIndex]) then
        TFile.Delete(LStagingFiles[LIndex]);
    end;
    CleanupFiles(APreview.Files);
    raise;
  end;
  Result := TRadIAProjectFileResult.Succeeded(APreview);
end;

function TRadIAProjectFileService.ApplyRemove(
  const APreview: TRadIAProjectFilePreview
): TRadIAProjectFileResult;
begin
  if not FFacade.FileInProject(APreview.MainFileName) then
    Exit(TRadIAProjectFileResult.Failed(
      CPreconditionFailed,
      'Project file is no longer registered.'
    ));
  if not FFacade.RemoveFile(APreview.MainFileName) then
    Exit(TRadIAProjectFileResult.Failed(
      'project_unregistration_failed',
      'Project file could not be removed from the project.'
    ));
  Result := TRadIAProjectFileResult.Succeeded(APreview);
end;

function TRadIAProjectFileService.BuildFiles(
  const AUnitName: string;
  const ADirectoryPath: string;
  const AKind: TRadIAProjectFileKind
): TArray<TRadIAProjectFileContent>;
var
  LClassName: string;
  LFormExtension: string;
  LPascalContent: string;
begin
  if AKind = pfkUnit then
  begin
    LPascalContent :=
      'unit ' + AUnitName + ';' + sLineBreak + sLineBreak +
      'interface' + sLineBreak + sLineBreak +
      'implementation' + sLineBreak + sLineBreak +
      'end.' + sLineBreak;
    Result := [
      TRadIAProjectFileContent.Create(
        TPath.Combine(ADirectoryPath, AUnitName + '.pas'),
        LPascalContent
      )
    ];
    Exit;
  end;
  LClassName := 'T' + AUnitName + 'Form';
  if AKind = pfkVclForm then
    LFormExtension := '.dfm'
  else
    LFormExtension := '.fmx';
  LPascalContent :=
    'unit ' + AUnitName + ';' + sLineBreak + sLineBreak +
    'interface' + sLineBreak + sLineBreak +
    'uses' + sLineBreak +
    '  System.Classes,' + sLineBreak;
  if AKind = pfkVclForm then
    LPascalContent := LPascalContent + '  Vcl.Forms;' + sLineBreak
  else
    LPascalContent := LPascalContent + '  FMX.Forms;' + sLineBreak;
  LPascalContent := LPascalContent + sLineBreak +
    'type' + sLineBreak +
    '  ' + LClassName + ' = class(TForm)' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak +
    '{$R *' + LFormExtension + '}' + sLineBreak + sLineBreak +
    'end.' + sLineBreak;
  Result := [
    TRadIAProjectFileContent.Create(
      TPath.Combine(ADirectoryPath, AUnitName + '.pas'),
      LPascalContent
    ),
    TRadIAProjectFileContent.Create(
      TPath.Combine(ADirectoryPath, AUnitName + LFormExtension),
      'object ' + AUnitName + 'Form: ' + LClassName + sLineBreak +
      '  Caption = ''' + AUnitName + '''' + sLineBreak +
      '  ClientHeight = 480' + sLineBreak +
      '  ClientWidth = 720' + sLineBreak +
      'end' + sLineBreak
    )
  ];
end;

procedure TRadIAProjectFileService.CleanupFiles(
  const AFiles: TArray<TRadIAProjectFileContent>
);
var
  LFile: TRadIAProjectFileContent;
begin
  for LFile in AFiles do
  begin
    if TFile.Exists(LFile.FileName) then
      TFile.Delete(LFile.FileName);
  end;
end;

procedure TRadIAProjectFileService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

constructor TRadIAProjectFileService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AFacade: IRadIAProjectFileFacade;
  const AExpirationMinutes: Integer
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  if not Assigned(AFacade) then
    raise EArgumentNilException.Create('AFacade');
  if AExpirationMinutes <= 0 then
    raise EArgumentOutOfRangeException.Create('AExpirationMinutes');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FFacade := AFacade;
  FExpirationMinutes := AExpirationMinutes;
  FPreviews := TObjectDictionary<
    string,
    TRadIAProjectFilePreview
  >.Create([doOwnsValues]);
end;

destructor TRadIAProjectFileService.Destroy;
begin
  FPreviews.Free;
  inherited Destroy;
end;

function TRadIAProjectFileService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAProjectFilePreview
): TRadIAProjectFileResult;
begin
  APreview := nil;
  if not FPreviews.TryGetValue(APreviewId, APreview) then
    Exit(TRadIAProjectFileResult.Failed(
      CPreviewNotFound,
      'Project file preview was not found.'
    ));
  if TTimeZone.Local.ToUniversalTime(Now) >
    APreview.ExpiresAtUtc then
  begin
    FPreviews.Remove(APreviewId);
    APreview := nil;
    Exit(TRadIAProjectFileResult.Failed(
      CPreviewExpired,
      'Project file preview expired.'
    ));
  end;
  Result := TRadIAProjectFileResult.Succeeded(APreview);
end;

function TRadIAProjectFileService.PrepareAdd(
  const AUnitName: string;
  const ARelativeDirectory: string;
  const AKind: TRadIAProjectFileKind
): TRadIAProjectFileResult;
var
  LDirectoryPath: string;
  LFiles: TArray<TRadIAProjectFileContent>;
  LFile: TRadIAProjectFileContent;
  LPathValidation: TRadIAPathValidation;
  LPreview: TRadIAProjectFilePreview;
  LProject: TRadIAProjectSnapshot;
  LRelativeDirectory: string;
begin
  if not ValidateUnitName(AUnitName) then
    Exit(TRadIAProjectFileResult.Failed(
      'invalid_unit_name',
      'Unit name must be a valid Pascal identifier.'
    ));
  LProject := FWorkspace.GetActiveProject;
  LRelativeDirectory := ARelativeDirectory;
  if Trim(LRelativeDirectory) = '' then
    LRelativeDirectory := '.';
  LPathValidation := FBoundary.ValidatePath(
    LProject.RootPath,
    LRelativeDirectory
  );
  if not LPathValidation.Allowed then
    Exit(TRadIAProjectFileResult.Failed(
      LPathValidation.ErrorCode,
      LPathValidation.ErrorMessage
    ));
  LDirectoryPath := LPathValidation.ResolvedPath;
  LFiles := BuildFiles(AUnitName, LDirectoryPath, AKind);
  for LFile in LFiles do
  begin
    if TFile.Exists(LFile.FileName) then
      Exit(TRadIAProjectFileResult.Failed(
        CPreconditionFailed,
        'A project file target already exists.'
      ));
  end;
  if FFacade.FileInProject(LFiles[0].FileName) then
    Exit(TRadIAProjectFileResult.Failed(
      CPreconditionFailed,
      'The project already contains the requested unit.'
    ));
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPreviews then
      Exit(TRadIAProjectFileResult.Failed(
        CResourceLimit,
        'Too many project file previews are active.'
      ));
    LPreview := TRadIAProjectFilePreview.Create(
      TGUID.NewGuid.ToString,
      pfoAdd,
      AKind,
      LFiles[0].FileName,
      LFiles,
      IncMinute(
        TTimeZone.Local.ToUniversalTime(Now),
        FExpirationMinutes
      )
    );
    FPreviews.Add(LPreview.Id, LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAProjectFileResult.Succeeded(LPreview);
end;

function TRadIAProjectFileService.PrepareRemove(
  const AFileName: string
): TRadIAProjectFileResult;
var
  LPathValidation: TRadIAPathValidation;
  LPreview: TRadIAProjectFilePreview;
  LProject: TRadIAProjectSnapshot;
begin
  LProject := FWorkspace.GetActiveProject;
  LPathValidation := FBoundary.ValidatePath(
    LProject.RootPath,
    AFileName
  );
  if not LPathValidation.Allowed then
    Exit(TRadIAProjectFileResult.Failed(
      LPathValidation.ErrorCode,
      LPathValidation.ErrorMessage
    ));
  if not FFacade.FileInProject(LPathValidation.ResolvedPath) then
    Exit(TRadIAProjectFileResult.Failed(
      CPreconditionFailed,
      'File is not registered in the active project.'
    ));
  LPreview := TRadIAProjectFilePreview.Create(
    TGUID.NewGuid.ToString,
    pfoRemove,
    pfkUnit,
    LPathValidation.ResolvedPath,
    [],
    IncMinute(
      TTimeZone.Local.ToUniversalTime(Now),
      FExpirationMinutes
    )
  );
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPreviews then
    begin
      LPreview.Free;
      Exit(TRadIAProjectFileResult.Failed(
        CResourceLimit,
        'Too many project file previews are active.'
      ));
    end;
    FPreviews.Add(LPreview.Id, LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAProjectFileResult.Succeeded(LPreview);
end;

function TRadIAProjectFileService.Revert(
  const APreviewId: string
): TRadIAProjectFileResult;
var
  LPreview: TRadIAProjectFilePreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if not LPreview.Applied then
      Exit(TRadIAProjectFileResult.Failed(
        CPreconditionFailed,
        'Project file preview has not been applied.'
      ));
    if LPreview.Operation = pfoAdd then
      Result := RevertAdd(LPreview)
    else
      Result := RevertRemove(LPreview);
    if Result.Success then
      LPreview.Applied := False;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

function TRadIAProjectFileService.RevertAdd(
  const APreview: TRadIAProjectFilePreview
): TRadIAProjectFileResult;
begin
  if not FFacade.RemoveFile(APreview.MainFileName) then
    Exit(TRadIAProjectFileResult.Failed(
      'project_unregistration_failed',
      'Created file could not be removed from the project.'
    ));
  CleanupFiles(APreview.Files);
  Result := TRadIAProjectFileResult.Succeeded(APreview);
end;

function TRadIAProjectFileService.RevertRemove(
  const APreview: TRadIAProjectFilePreview
): TRadIAProjectFileResult;
begin
  if not FFacade.AddFile(APreview.MainFileName, True) then
    Exit(TRadIAProjectFileResult.Failed(
      'project_registration_failed',
      'Removed file could not be restored to the project.'
    ));
  Result := TRadIAProjectFileResult.Succeeded(APreview);
end;

function TRadIAProjectFileService.ValidateUnitName(
  const AUnitName: string
): Boolean;
var
  LCharacter: Char;
  LIndex: Integer;
begin
  Result := (AUnitName <> '') and
    (Length(AUnitName) <= 128) and
    (AUnitName[Low(AUnitName)].IsLetter or
    (AUnitName[Low(AUnitName)] = '_'));
  if not Result then
    Exit;
  if AUnitName.EndsWith('.') or AUnitName.Contains('..') then
    Exit(False);
  for LIndex := Low(AUnitName) to High(AUnitName) do
  begin
    LCharacter := AUnitName[LIndex];
    if not (
      LCharacter.IsLetterOrDigit or
      CharInSet(LCharacter, ['_', '.'])
    ) then
      Exit(False);
    if (LCharacter = '.') and
      ((LIndex = High(AUnitName)) or
      not (
        AUnitName[LIndex + 1].IsLetter or
        (AUnitName[LIndex + 1] = '_')
      )) then
      Exit(False);
  end;
end;

end.
