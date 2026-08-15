unit RadIA.Core.GeneratedArtifacts;

interface

uses
  System.Generics.Collections,
  RadIA.Core.ProjectFiles,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAGeneratedArtifactState = (
    gasPrepared,
    gasApplied,
    gasReverted
  );

  TRadIAGeneratedArtifactPreview = class
  private
    FContent: string;
    FExpiresAtUtc: TDateTime;
    FFileName: string;
    FId: string;
    FRegisterInProject: Boolean;
    FRevision: string;
    FState: TRadIAGeneratedArtifactState;
  public
    constructor Create(
      const AId: string;
      const AFileName: string;
      const AContent: string;
      const ARegisterInProject: Boolean;
      const AExpiresAtUtc: TDateTime
    );
    property Content: string read FContent;
    property ExpiresAtUtc: TDateTime read FExpiresAtUtc;
    property FileName: string read FFileName;
    property Id: string read FId;
    property RegisterInProject: Boolean read FRegisterInProject;
    property Revision: string read FRevision;
    property State: TRadIAGeneratedArtifactState read FState write FState;
  end;

  TRadIAGeneratedArtifactResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPreview: TRadIAGeneratedArtifactPreview;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAGeneratedArtifactResult; static;
    class function Succeeded(
      const APreview: TRadIAGeneratedArtifactPreview
    ): TRadIAGeneratedArtifactResult; static;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Preview: TRadIAGeneratedArtifactPreview read FPreview;
    property Success: Boolean read FSuccess;
  end;

  IRadIAGeneratedArtifactService = interface
    ['{89A2B063-0FD9-4808-8729-09AF1591CDF2}']
    function Prepare(
      const ARelativeFileName: string;
      const AContent: string;
      const ARegisterInProject: Boolean
    ): TRadIAGeneratedArtifactResult;
    function Apply(
      const APreviewId: string
    ): TRadIAGeneratedArtifactResult;
    function Revert(
      const APreviewId: string
    ): TRadIAGeneratedArtifactResult;
    procedure Clear;
  end;

  TRadIAGeneratedArtifactService = class(
    TInterfacedObject,
    IRadIAGeneratedArtifactService
  )
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FExpirationMinutes: Integer;
    FPreviews: TObjectDictionary<string, TRadIAGeneratedArtifactPreview>;
    FProjectFiles: IRadIAProjectFileFacade;
    FWorkspace: IRadIAWorkspaceFacade;
    function GetPreview(
      const APreviewId: string;
      out APreview: TRadIAGeneratedArtifactPreview
    ): TRadIAGeneratedArtifactResult;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AProjectFiles: IRadIAProjectFileFacade;
      const AExpirationMinutes: Integer = 10
    );
    destructor Destroy; override;
    function Prepare(
      const ARelativeFileName: string;
      const AContent: string;
      const ARegisterInProject: Boolean
    ): TRadIAGeneratedArtifactResult;
    function Apply(
      const APreviewId: string
    ): TRadIAGeneratedArtifactResult;
    function Revert(
      const APreviewId: string
    ): TRadIAGeneratedArtifactResult;
    procedure Clear;
  end;

implementation

uses
  System.DateUtils,
  System.Hash,
  System.IOUtils,
  System.SysUtils;

const
  CMaxArtifactCharacters = 2 * 1024 * 1024;
  CMaxPreviews = 32;

{ TRadIAGeneratedArtifactPreview }

constructor TRadIAGeneratedArtifactPreview.Create(
  const AId: string;
  const AFileName: string;
  const AContent: string;
  const ARegisterInProject: Boolean;
  const AExpiresAtUtc: TDateTime
);
begin
  inherited Create;
  FId := AId;
  FFileName := AFileName;
  FContent := AContent;
  FRegisterInProject := ARegisterInProject;
  FExpiresAtUtc := AExpiresAtUtc;
  FRevision := LowerCase(THashSHA2.GetHashString(AContent));
  FState := gasPrepared;
end;

{ TRadIAGeneratedArtifactResult }

class function TRadIAGeneratedArtifactResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAGeneratedArtifactResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
  Result.FPreview := nil;
end;

class function TRadIAGeneratedArtifactResult.Succeeded(
  const APreview: TRadIAGeneratedArtifactPreview
): TRadIAGeneratedArtifactResult;
begin
  Result.FSuccess := True;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
  Result.FPreview := APreview;
end;

{ TRadIAGeneratedArtifactService }

function TRadIAGeneratedArtifactService.Apply(
  const APreviewId: string
): TRadIAGeneratedArtifactResult;
var
  LPreview: TRadIAGeneratedArtifactPreview;
  LStagingFile: string;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if LPreview.State <> gasPrepared then
      Exit(TRadIAGeneratedArtifactResult.Failed(
        'precondition_failed',
        'Generated artifact preview must be prepared before apply.'
      ));
    if TFile.Exists(LPreview.FileName) then
      Exit(TRadIAGeneratedArtifactResult.Failed(
        'target_exists',
        'Generated artifact target already exists.'
      ));
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LPreview.FileName));
    LStagingFile := LPreview.FileName + '.radia-stage-' +
      TGUID.NewGuid.ToString;
    try
      TFile.WriteAllText(LStagingFile, LPreview.Content, TEncoding.UTF8);
      TFile.Move(LStagingFile, LPreview.FileName);
      if LPreview.RegisterInProject and not FProjectFiles.AddFile(
        LPreview.FileName,
        True
      ) then
      begin
        TFile.Delete(LPreview.FileName);
        Exit(TRadIAGeneratedArtifactResult.Failed(
          'project_registration_failed',
          'Generated unit could not be registered in the project.'
        ));
      end;
    finally
      if TFile.Exists(LStagingFile) then
        TFile.Delete(LStagingFile);
    end;
    LPreview.State := gasApplied;
    Result := TRadIAGeneratedArtifactResult.Succeeded(LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

procedure TRadIAGeneratedArtifactService.Clear;
begin
  TMonitor.Enter(FPreviews);
  try
    FPreviews.Clear;
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

constructor TRadIAGeneratedArtifactService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AProjectFiles: IRadIAProjectFileFacade;
  const AExpirationMinutes: Integer
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  if not Assigned(AProjectFiles) then
    raise EArgumentNilException.Create('AProjectFiles');
  if AExpirationMinutes <= 0 then
    raise EArgumentOutOfRangeException.Create('AExpirationMinutes');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FProjectFiles := AProjectFiles;
  FExpirationMinutes := AExpirationMinutes;
  FPreviews := TObjectDictionary<
    string,
    TRadIAGeneratedArtifactPreview
  >.Create([doOwnsValues]);
end;

destructor TRadIAGeneratedArtifactService.Destroy;
begin
  FPreviews.Free;
  inherited Destroy;
end;

function TRadIAGeneratedArtifactService.GetPreview(
  const APreviewId: string;
  out APreview: TRadIAGeneratedArtifactPreview
): TRadIAGeneratedArtifactResult;
begin
  APreview := nil;
  if not FPreviews.TryGetValue(APreviewId, APreview) then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'preview_not_found',
      'Generated artifact preview was not found.'
    ));
  if TTimeZone.Local.ToUniversalTime(Now) > APreview.ExpiresAtUtc then
  begin
    FPreviews.Remove(APreviewId);
    APreview := nil;
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'preview_expired',
      'Generated artifact preview expired.'
    ));
  end;
  Result := TRadIAGeneratedArtifactResult.Succeeded(APreview);
end;

function TRadIAGeneratedArtifactService.Prepare(
  const ARelativeFileName: string;
  const AContent: string;
  const ARegisterInProject: Boolean
): TRadIAGeneratedArtifactResult;
var
  LPath: TRadIAPathValidation;
  LPreview: TRadIAGeneratedArtifactPreview;
  LProject: TRadIAProjectSnapshot;
begin
  if Trim(ARelativeFileName) = '' then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'invalid_request',
      'Generated artifact file name must not be empty.'
    ));
  if (AContent = '') or (Length(AContent) > CMaxArtifactCharacters) then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'resource_limit',
      'Generated artifact content must contain between 1 and 2097152 characters.'
    ));
  LProject := FWorkspace.GetActiveProject;
  if LProject.RootPath = '' then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'precondition_failed',
      'No active project is available.'
    ));
  LPath := FBoundary.ValidatePath(LProject.RootPath, ARelativeFileName);
  if not LPath.Allowed then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      LPath.ErrorCode,
      LPath.ErrorMessage
    ));
  if TFile.Exists(LPath.ResolvedPath) then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'target_exists',
      'Generated artifact target already exists.'
    ));
  TMonitor.Enter(FPreviews);
  try
    if FPreviews.Count >= CMaxPreviews then
      Exit(TRadIAGeneratedArtifactResult.Failed(
        'resource_limit',
        'Too many generated artifact previews are active.'
      ));
    LPreview := TRadIAGeneratedArtifactPreview.Create(
      TGUID.NewGuid.ToString,
      LPath.ResolvedPath,
      AContent,
      ARegisterInProject,
      IncMinute(
        TTimeZone.Local.ToUniversalTime(Now),
        FExpirationMinutes
      )
    );
    FPreviews.Add(LPreview.Id, LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
  Result := TRadIAGeneratedArtifactResult.Succeeded(LPreview);
end;

function TRadIAGeneratedArtifactService.Revert(
  const APreviewId: string
): TRadIAGeneratedArtifactResult;
var
  LCurrentRevision: string;
  LPreview: TRadIAGeneratedArtifactPreview;
begin
  TMonitor.Enter(FPreviews);
  try
    Result := GetPreview(APreviewId, LPreview);
    if not Result.Success then
      Exit;
    if LPreview.State <> gasApplied then
      Exit(TRadIAGeneratedArtifactResult.Failed(
        'precondition_failed',
        'Generated artifact must be applied before revert.'
      ));
    if not TFile.Exists(LPreview.FileName) then
      Exit(TRadIAGeneratedArtifactResult.Failed(
        'precondition_failed',
        'Generated artifact no longer exists.'
      ));
    LCurrentRevision := LowerCase(THashSHA2.GetHashString(
      TFile.ReadAllText(LPreview.FileName, TEncoding.UTF8)
    ));
    if not SameText(LCurrentRevision, LPreview.Revision) then
      Exit(TRadIAGeneratedArtifactResult.Failed(
        'precondition_failed',
        'Generated artifact changed after apply and cannot be reverted.'
      ));
    if LPreview.RegisterInProject and
      not FProjectFiles.RemoveFile(LPreview.FileName) then
      Exit(TRadIAGeneratedArtifactResult.Failed(
        'project_unregistration_failed',
        'Generated unit could not be removed from the project.'
      ));
    TFile.Delete(LPreview.FileName);
    LPreview.State := gasReverted;
    Result := TRadIAGeneratedArtifactResult.Succeeded(LPreview);
  finally
    TMonitor.Exit(FPreviews);
  end;
end;

end.
