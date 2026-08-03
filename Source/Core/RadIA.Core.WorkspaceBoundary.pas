unit RadIA.Core.WorkspaceBoundary;

interface

type
  TRadIAPathValidation = record
  private
    FAllowed: Boolean;
    FResolvedPath: string;
    FErrorCode: string;
    FErrorMessage: string;
  public
    class function Accepted(
      const AResolvedPath: string
    ): TRadIAPathValidation; static;
    class function Rejected(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAPathValidation; static;
    property Allowed: Boolean read FAllowed;
    property ResolvedPath: string read FResolvedPath;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
  end;

  IRadIAWorkspaceBoundary = interface
    ['{16DE5BFD-610D-4E28-A9E0-273AD8E55ABC}']
    function ValidatePath(
      const AWorkspaceRoot: string;
      const ACandidatePath: string
    ): TRadIAPathValidation;
  end;

  TRadIAWorkspaceBoundary = class(
    TInterfacedObject,
    IRadIAWorkspaceBoundary
  )
  private
    function ContainsReparsePoint(
      const ARootPath: string;
      const ATargetPath: string
    ): Boolean;
    function IsBroadRoot(const APath: string): Boolean;
    function IsWithinRoot(
      const ARootPath: string;
      const ATargetPath: string
    ): Boolean;
    function NormalizeDirectory(const APath: string): string;
  public
    function ValidatePath(
      const AWorkspaceRoot: string;
      const ACandidatePath: string
    ): TRadIAPathValidation;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows;

const
  CInvalidRoot = 'invalid_workspace_root';
  CInvalidPath = 'invalid_path';
  COutsideWorkspace = 'outside_workspace';
  CReparsePoint = 'reparse_point_denied';

{ TRadIAPathValidation }

class function TRadIAPathValidation.Accepted(
  const AResolvedPath: string
): TRadIAPathValidation;
begin
  Result.FAllowed := True;
  Result.FResolvedPath := AResolvedPath;
  Result.FErrorCode := '';
  Result.FErrorMessage := '';
end;

class function TRadIAPathValidation.Rejected(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAPathValidation;
begin
  Result.FAllowed := False;
  Result.FResolvedPath := '';
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

{ TRadIAWorkspaceBoundary }

function TRadIAWorkspaceBoundary.ContainsReparsePoint(
  const ARootPath: string;
  const ATargetPath: string
): Boolean;
var
  LAttributes: Cardinal;
  LCurrentPath: string;
  LIndex: Integer;
  LRelativePath: string;
  LSegments: TArray<string>;
begin
  Result := False;
  LCurrentPath := ExcludeTrailingPathDelimiter(ARootPath);
  LAttributes := GetFileAttributes(PChar(LCurrentPath));
  if (LAttributes <> INVALID_FILE_ATTRIBUTES) and
    ((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
    Exit(True);

  LRelativePath := Copy(
    ATargetPath,
    Length(IncludeTrailingPathDelimiter(ARootPath)) + 1,
    MaxInt
  );
  LSegments := LRelativePath.Split(
    [PathDelim],
    TStringSplitOptions.ExcludeEmpty
  );

  for LIndex := Low(LSegments) to High(LSegments) do
  begin
    LCurrentPath := TPath.Combine(LCurrentPath, LSegments[LIndex]);
    LAttributes := GetFileAttributes(PChar(LCurrentPath));
    if LAttributes = INVALID_FILE_ATTRIBUTES then
      Continue;
    if (LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
      Exit(True);
  end;
end;

function TRadIAWorkspaceBoundary.IsBroadRoot(
  const APath: string
): Boolean;
begin
  Result := SameText(
    ExcludeTrailingPathDelimiter(APath),
    ExcludeTrailingPathDelimiter(TPath.GetPathRoot(APath))
  );
end;

function TRadIAWorkspaceBoundary.IsWithinRoot(
  const ARootPath: string;
  const ATargetPath: string
): Boolean;
var
  LRootPrefix: string;
begin
  LRootPrefix := IncludeTrailingPathDelimiter(ARootPath);
  Result := SameText(ATargetPath, ARootPath) or
    ATargetPath.StartsWith(LRootPrefix, True);
end;

function TRadIAWorkspaceBoundary.NormalizeDirectory(
  const APath: string
): string;
begin
  Result := ExcludeTrailingPathDelimiter(TPath.GetFullPath(APath));
end;

function TRadIAWorkspaceBoundary.ValidatePath(
  const AWorkspaceRoot: string;
  const ACandidatePath: string
): TRadIAPathValidation;
var
  LRootPath: string;
  LTargetPath: string;
begin
  if Trim(AWorkspaceRoot) = '' then
    Exit(TRadIAPathValidation.Rejected(
      CInvalidRoot,
      'Workspace root must not be empty.'
    ));
  if Trim(ACandidatePath) = '' then
    Exit(TRadIAPathValidation.Rejected(
      CInvalidPath,
      'Candidate path must not be empty.'
    ));

  try
    LRootPath := NormalizeDirectory(AWorkspaceRoot);
    if IsBroadRoot(LRootPath) then
      Exit(TRadIAPathValidation.Rejected(
        CInvalidRoot,
        'A volume root cannot be used as an implicit workspace.'
      ));

    if TPath.IsPathRooted(ACandidatePath) then
      LTargetPath := TPath.GetFullPath(ACandidatePath)
    else
      LTargetPath := TPath.GetFullPath(
        TPath.Combine(LRootPath, ACandidatePath)
      );
  except
    on E: Exception do
      Exit(TRadIAPathValidation.Rejected(
        CInvalidPath,
        E.Message
      ));
  end;

  if not IsWithinRoot(LRootPath, LTargetPath) then
    Exit(TRadIAPathValidation.Rejected(
      COutsideWorkspace,
      'Path resolves outside the authorized workspace.'
    ));
  if ContainsReparsePoint(LRootPath, LTargetPath) then
    Exit(TRadIAPathValidation.Rejected(
      CReparsePoint,
      'Paths containing reparse points are not allowed.'
    ));

  Result := TRadIAPathValidation.Accepted(LTargetPath);
end;

end.
