unit RadIA.Core.ProjectTransaction;

interface

uses
  RadIA.Core.ProjectTemplates;

type
  TRadIAProjectTransactionState = (
    ptsNew,
    ptsPrepared,
    ptsCommitted,
    ptsRolledBack
  );

  TRadIAProjectTemplateTransaction = class
  private
    FState: TRadIAProjectTransactionState;
    FDestinationPath: string;
    FStagingPath: string;
    FDestinationExisted: Boolean;
    procedure ValidateDestination(const ADestinationPath: string);
    function ResolveStagingFile(
      const ARelativePath: string
    ): string;
    procedure DeleteStaging;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Prepare(
      const APlan: TRadIAProjectTemplatePlan;
      const ADestinationPath: string
    );
    procedure Commit;
    procedure Rollback;
    property State: TRadIAProjectTransactionState read FState;
    property DestinationPath: string read FDestinationPath;
    property DestinationExisted: Boolean read FDestinationExisted;
    property StagingPath: string read FStagingPath;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils;

constructor TRadIAProjectTemplateTransaction.Create;
begin
  inherited Create;
  FState := ptsNew;
end;

destructor TRadIAProjectTemplateTransaction.Destroy;
begin
  if FState = ptsPrepared then
    DeleteStaging;
  inherited Destroy;
end;

procedure TRadIAProjectTemplateTransaction.Commit;
begin
  if FState <> ptsPrepared then
    raise EInvalidOp.Create(
      'Project transaction must be prepared before commit.'
    );
  if TDirectory.Exists(FDestinationPath) then
  begin
    if Length(TDirectory.GetFileSystemEntries(FDestinationPath)) > 0 then
      raise EInvalidOp.Create(
        'Project destination changed after transaction preparation.'
      );
    TDirectory.Delete(FDestinationPath, False);
  end;
  try
    TDirectory.Move(FStagingPath, FDestinationPath);
    FStagingPath := '';
    FState := ptsCommitted;
  except
    if FDestinationExisted and not TDirectory.Exists(FDestinationPath) then
      TDirectory.CreateDirectory(FDestinationPath);
    raise;
  end;
end;

procedure TRadIAProjectTemplateTransaction.DeleteStaging;
begin
  if (FStagingPath <> '') and TDirectory.Exists(FStagingPath) then
    TDirectory.Delete(FStagingPath, True);
  FStagingPath := '';
end;

procedure TRadIAProjectTemplateTransaction.Prepare(
  const APlan: TRadIAProjectTemplatePlan;
  const ADestinationPath: string
);
var
  LDirectory: string;
  LFile: TRadIAProjectTemplateFile;
  LTargetPath: string;
begin
  if FState <> ptsNew then
    raise EInvalidOp.Create(
      'Project transaction can only be prepared once.'
    );
  if not Assigned(APlan) then
    raise EArgumentNilException.Create('APlan');
  ValidateDestination(ADestinationPath);
  FDestinationPath := TPath.GetFullPath(ADestinationPath);
  FDestinationExisted := TDirectory.Exists(FDestinationPath);
  FStagingPath := FDestinationPath + '.radia-stage-' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
  TDirectory.CreateDirectory(FStagingPath);
  try
    for LFile in APlan.Files do
    begin
      LTargetPath := ResolveStagingFile(LFile.RelativePath);
      LDirectory := TPath.GetDirectoryName(LTargetPath);
      if not TDirectory.Exists(LDirectory) then
        TDirectory.CreateDirectory(LDirectory);
      TFile.WriteAllText(
        LTargetPath,
        LFile.Content,
        TEncoding.UTF8
      );
    end;
    FState := ptsPrepared;
  except
    DeleteStaging;
    raise;
  end;
end;

function TRadIAProjectTemplateTransaction.ResolveStagingFile(
  const ARelativePath: string
): string;
var
  LRelativePath: string;
  LStagingPrefix: string;
begin
  LRelativePath := Trim(ARelativePath).Replace('/', '\');
  if (LRelativePath = '') or TPath.IsPathRooted(LRelativePath) then
    raise EArgumentException.Create(
      'Project template file path must be relative.'
    );
  LStagingPrefix := IncludeTrailingPathDelimiter(
    TPath.GetFullPath(FStagingPath)
  );
  Result := TPath.GetFullPath(
    TPath.Combine(FStagingPath, LRelativePath)
  );
  if not Result.StartsWith(LStagingPrefix, True) then
    raise EArgumentException.Create(
      'Project template file path escapes the staging directory.'
    );
end;

procedure TRadIAProjectTemplateTransaction.Rollback;
begin
  if FState = ptsRolledBack then
    Exit;
  if FState = ptsPrepared then
    DeleteStaging
  else if FState = ptsCommitted then
  begin
    if TDirectory.Exists(FDestinationPath) then
      TDirectory.Delete(FDestinationPath, True);
    if FDestinationExisted then
      TDirectory.CreateDirectory(FDestinationPath);
  end;
  FState := ptsRolledBack;
end;

procedure TRadIAProjectTemplateTransaction.ValidateDestination(
  const ADestinationPath: string
);
var
  LDestinationPath: string;
  LRootPath: string;
begin
  if Trim(ADestinationPath) = '' then
    raise EArgumentException.Create(
      'Project destination path must not be empty.'
    );
  LDestinationPath := ExcludeTrailingPathDelimiter(
    TPath.GetFullPath(ADestinationPath)
  );
  LRootPath := ExcludeTrailingPathDelimiter(
    TPath.GetPathRoot(LDestinationPath)
  );
  if SameText(LDestinationPath, LRootPath) then
    raise EArgumentException.Create(
      'Project destination must not be a filesystem root.'
    );
  if TFile.Exists(LDestinationPath) then
    raise EArgumentException.Create(
      'Project destination points to an existing file.'
    );
  if TDirectory.Exists(LDestinationPath) and
    (Length(TDirectory.GetFileSystemEntries(LDestinationPath)) > 0) then
    raise EArgumentException.Create(
      'Project destination folder must be empty.'
    );
end;

end.
