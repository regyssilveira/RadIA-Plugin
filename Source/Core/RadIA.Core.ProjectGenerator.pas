unit RadIA.Core.ProjectGenerator;

interface

uses
  System.Classes, System.JSON, RadIA.Core.Interfaces;

type
  { Specialist service for generating complete Delphi projects on disk }
  TRadIAProjectGenerator = class(TInterfacedObject, IRadIAProjectGenerator)
  private
    function ChooseDestinationFolder(const ADestDir: string): string;
    function ValidateOrCreateFolder(const AFolder: string; out AErrorMsg: string): Boolean;
    function WriteFilesToDisk(

  const AFolder: string;
  AJsonArr: TJSONArray;

  AWrittenFiles: TStringList;

  out AErrorMsg: string): Boolean;
    procedure ProcessFileJson(const AFolder: string; AObj: TJSONObject; AWrittenFiles: TStringList);
    function ResolveTargetPath(
      const AFolder: string;
      const ARelativePath: string
    ): string;
    procedure HandleWriteError(const AExceptionMsg: string; AWrittenFiles: TStringList; out AErrorMsg: string);
    function IdentifyProjectFile(AWrittenFiles: TStringList): string;
    procedure OpenProjectInIDE(const AProjectFile: string);
  public
    { Generates a project structure from a JSON array of files.
      Opens a directory selection dialog, validates that it is empty,
      saves all files using UTF-8, and opens the main project file in the IDE. }
    function GenerateFromJSON(const AFilesJSON: string; out AErrorMsg: string; const ADestDir: string = ''): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Vcl.Dialogs,
  RadIA.Core.Logger, RadIA.Core.Container;

{ TRadIAProjectGenerator }

function TRadIAProjectGenerator.ChooseDestinationFolder(const ADestDir: string): string;
var
  LOpenDlg: TFileOpenDialog;
begin
  Result := ADestDir;
  if Result.IsEmpty then
  begin
    LOpenDlg := TFileOpenDialog.Create(nil);
    try
      LOpenDlg.Title := 'Select a completely empty folder for the project';
      LOpenDlg.Options := [fdoPickFolders, fdoPathMustExist, fdoForceFileSystem];
      if LOpenDlg.Execute then
      begin
        Result := LOpenDlg.FileName;
      end;
    finally
      LOpenDlg.Free;
    end;
  end;
end;

function TRadIAProjectGenerator.ValidateOrCreateFolder(const AFolder: string; out AErrorMsg: string): Boolean;
var
  LFileEntries: TArray<string>;
begin
  Result := False;
  AErrorMsg := '';
  if TDirectory.Exists(AFolder) then
  begin
    LFileEntries := TDirectory.GetFileSystemEntries(AFolder);
    if Length(LFileEntries) > 0 then
    begin
      AErrorMsg := 'The chosen folder is not empty. Please select a completely empty folder for the project.';
      Exit;
    end;
  end
  else
  begin
    try
      TDirectory.CreateDirectory(AFolder);
    except
      on E: Exception do
      begin
        AErrorMsg := 'Failed to create destination folder: ' + E.Message;
        Exit;
      end;
    end;
  end;
  Result := True;
end;

function TRadIAProjectGenerator.WriteFilesToDisk(

  const AFolder: string;
  AJsonArr: TJSONArray;

  AWrittenFiles: TStringList;

  out AErrorMsg: string): Boolean;
var
  I: Integer;
  LVal: TJSONValue;
begin
  Result := False;
  AErrorMsg := '';
  try
    if AJsonArr.Count > 1000 then
      raise EArgumentOutOfRangeException.Create(
        'Project generation supports at most 1000 files.'
      );
    for I := 0 to AJsonArr.Count - 1 do
    begin
      LVal := AJsonArr[I];
      if not (LVal is TJSONObject) then
        raise EConvertError.CreateFmt(
          'Project file entry %d must be a JSON object.',
          [I]
        );
      ProcessFileJson(AFolder, LVal as TJSONObject, AWrittenFiles);
    end;
    Result := True;
  except
    on E: Exception do
      HandleWriteError(E.Message, AWrittenFiles, AErrorMsg);
  end;
end;

procedure TRadIAProjectGenerator.ProcessFileJson(const AFolder: string; AObj: TJSONObject; AWrittenFiles: TStringList);
var
  LRelPath, LContent, LAbsPath, LSubFolder: string;
begin
  LRelPath := AObj.GetValue<string>('path', '');
  LContent := AObj.GetValue<string>('content', '');

  if LRelPath.IsEmpty then
    raise EArgumentException.Create(
      'Project file path must not be empty.'
    );
  if Length(LContent) > 5 * 1024 * 1024 then
    raise EArgumentOutOfRangeException.Create(
      'Project file content exceeds the 5 MB limit.'
    );

  LAbsPath := ResolveTargetPath(AFolder, LRelPath);
  if AWrittenFiles.IndexOf(LAbsPath) >= 0 then
    raise EArgumentException.Create(
      'Project contains a duplicate file path: ' + LRelPath
    );
  LSubFolder := TPath.GetDirectoryName(LAbsPath);

  if not LSubFolder.IsEmpty and not TDirectory.Exists(LSubFolder) then
    TDirectory.CreateDirectory(LSubFolder);

  TFile.WriteAllText(LAbsPath, LContent, TEncoding.UTF8);
  AWrittenFiles.Add(LAbsPath);
end;

function TRadIAProjectGenerator.ResolveTargetPath(
  const AFolder: string;
  const ARelativePath: string
): string;
var
  LRelativePath: string;
  LRootPath: string;
  LRootPrefix: string;
begin
  LRelativePath := Trim(ARelativePath).Replace('/', '\');
  if TPath.IsPathRooted(LRelativePath) or
    LRelativePath.StartsWith('\') then
    raise EArgumentException.Create(
      'Project file path must be relative to the destination.'
    );
  LRootPath := TPath.GetFullPath(AFolder);
  LRootPrefix := IncludeTrailingPathDelimiter(LRootPath);
  Result := TPath.GetFullPath(TPath.Combine(LRootPath, LRelativePath));
  if not Result.StartsWith(LRootPrefix, True) then
    raise EArgumentException.Create(
      'Project file path escapes the destination folder.'
    );
end;

procedure TRadIAProjectGenerator.HandleWriteError(

  const AExceptionMsg: string;

  AWrittenFiles: TStringList;

  out AErrorMsg: string);
var
  LRelPath: string;
begin
  AErrorMsg := 'Error writing files: ' + AExceptionMsg;
  TLogger.Log('TRadIAProjectGenerator.GenerateFromJSON: Exception writing files. Rollback initiated.', 'Core');
  for LRelPath in AWrittenFiles do
  begin
    try
      if TFile.Exists(LRelPath) then
        TFile.Delete(LRelPath);
    except
      on EDel: Exception do
        TLogger.Log('TRadIAProjectGenerator.GenerateFromJSON rollback: Failed to delete ' +
          LRelPath + ': ' + EDel.Message, 'Core');
    end;
  end;
end;

function TRadIAProjectGenerator.IdentifyProjectFile(AWrittenFiles: TStringList): string;
var
  LRelPath: string;
begin
  Result := '';
  for LRelPath in AWrittenFiles do
  begin
    if SameText(TPath.GetExtension(LRelPath), '.dproj') then
    begin
      Result := LRelPath;
      Break;
    end;
  end;

  if Result.IsEmpty then
  begin
    for LRelPath in AWrittenFiles do
    begin
      if SameText(TPath.GetExtension(LRelPath), '.dpr') then
      begin
        Result := LRelPath;
        Break;
      end;
    end;
  end;
end;

procedure TRadIAProjectGenerator.OpenProjectInIDE(const AProjectFile: string);
begin
  if not AProjectFile.IsEmpty then
  begin
    TLogger.Log('TRadIAProjectGenerator.GenerateFromJSON: Opening project: ' + AProjectFile, 'Core');
    TThread.Queue(nil,
      procedure
      var
        LAdapter: IRadIAIDEAdapter;
      begin
        if TRadIAContainer.TryResolve<IRadIAIDEAdapter>(LAdapter) then
          LAdapter.OpenProjectInIDE(AProjectFile);
      end);
  end
  else
  begin
    TLogger.Log('TRadIAProjectGenerator.GenerateFromJSON: No project file (.dproj/.dpr) found to open.', 'Core');
  end;
end;

function TRadIAProjectGenerator.GenerateFromJSON(const AFilesJSON: string; out AErrorMsg: string;
    const ADestDir: string): Boolean;
var
  LChosenDir: string;
  LJsonValue: TJSONValue;
  LJsonArr: TJSONArray;
  LWrittenFiles: TStringList;
  LProjectFileToOpen: string;
begin
  Result := False;
  AErrorMsg := '';

  if AFilesJSON.Trim.IsEmpty then
  begin
    AErrorMsg := 'No files data provided.';
    Exit;
  end;

  LJsonValue := TJSONObject.ParseJSONValue(AFilesJSON);
  if not Assigned(LJsonValue) then
  begin
    AErrorMsg := 'Invalid JSON files data.';
    Exit;
  end;

  try
    if not (LJsonValue is TJSONArray) then
    begin
      AErrorMsg := 'Files data must be a JSON array.';
      Exit;
    end;

    LJsonArr := LJsonValue as TJSONArray;
    if LJsonArr.Count = 0 then
    begin
      AErrorMsg := 'Files list is empty.';
      Exit;
    end;

    LChosenDir := ChooseDestinationFolder(ADestDir);
    if LChosenDir.IsEmpty then
      Exit;

    if not ValidateOrCreateFolder(LChosenDir, AErrorMsg) then
      Exit;

    LWrittenFiles := TStringList.Create;
    try
      if not WriteFilesToDisk(LChosenDir, LJsonArr, LWrittenFiles, AErrorMsg) then
        Exit;

      Result := True;
      LProjectFileToOpen := IdentifyProjectFile(LWrittenFiles);
      OpenProjectInIDE(LProjectFileToOpen);
    finally
      LWrittenFiles.Free;
    end;

  finally
    LJsonValue.Free;
  end;
end;

end.
