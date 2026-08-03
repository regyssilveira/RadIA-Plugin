unit RadIA.Core.KnowledgeStore;

interface

uses
  RadIA.Core.Knowledge;

type
  TRadIAJsonKnowledgeStore = class(
    TInterfacedObject,
    IRadIAKnowledgeStore
  )
  private
    FRootPath: string;
    function GetProjectFileName(
      const AProjectId: string
    ): string;
  public
    constructor Create(const ARootPath: string);
    function Load(
      const AProjectId: string;
      out ASnapshot: TRadIAKnowledgeIndexSnapshot
    ): Boolean;
    procedure Save(
      const ASnapshot: TRadIAKnowledgeIndexSnapshot
    );
    procedure Delete(const AProjectId: string);
    procedure Clear;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows;

const
  CFormatVersion = 1;
  CMaxPersistedChunks = 100000;
  CMaxStoreFileBytes = 128 * 1024 * 1024;

{ TRadIAJsonKnowledgeStore }

procedure TRadIAJsonKnowledgeStore.Clear;
var
  LFileName: string;
begin
  if not TDirectory.Exists(FRootPath) then
    Exit;
  for LFileName in TDirectory.GetFiles(
    FRootPath,
    '*.knowledge.json',
    TSearchOption.soTopDirectoryOnly
  ) do
    TFile.Delete(LFileName);
end;

constructor TRadIAJsonKnowledgeStore.Create(
  const ARootPath: string
);
begin
  inherited Create;
  if Trim(ARootPath) = '' then
    raise EArgumentException.Create('ARootPath');
  FRootPath := ExcludeTrailingPathDelimiter(
    TPath.GetFullPath(ARootPath)
  );
end;

procedure TRadIAJsonKnowledgeStore.Delete(
  const AProjectId: string
);
var
  LFileName: string;
begin
  LFileName := GetProjectFileName(AProjectId);
  if TFile.Exists(LFileName) then
    TFile.Delete(LFileName);
end;

function TRadIAJsonKnowledgeStore.GetProjectFileName(
  const AProjectId: string
): string;
var
  LHash: string;
begin
  LHash := LowerCase(THashSHA2.GetHashString(AProjectId));
  Result := TPath.Combine(
    FRootPath,
    LHash + '.knowledge.json'
  );
end;

function TRadIAJsonKnowledgeStore.Load(
  const AProjectId: string;
  out ASnapshot: TRadIAKnowledgeIndexSnapshot
): Boolean;
var
  LArray: TJSONArray;
  LChunks: TArray<TRadIAKnowledgeChunk>;
  LFileName: string;
  LIndex: Integer;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LText: string;
begin
  ASnapshot := Default(TRadIAKnowledgeIndexSnapshot);
  LFileName := GetProjectFileName(AProjectId);
  if not TFile.Exists(LFileName) then
    Exit(False);
  if TFile.GetSize(LFileName) > CMaxStoreFileBytes then
    Exit(False);

  try
    LText := TFile.ReadAllText(LFileName, TEncoding.UTF8);
    LJson := TJSONObject.ParseJSONValue(LText) as TJSONObject;
    if not Assigned(LJson) then
      Exit(False);
    try
      if LJson.GetValue<Integer>('version', 0) <> CFormatVersion then
        Exit(False);
      if not SameText(
        LJson.GetValue<string>('projectId', ''),
        AProjectId
      ) then
        Exit(False);
      LArray := LJson.GetValue('chunks') as TJSONArray;
      if not Assigned(LArray) or
        (LArray.Count > CMaxPersistedChunks) then
        Exit(False);

      SetLength(LChunks, LArray.Count);
      for LIndex := 0 to LArray.Count - 1 do
      begin
        if not (LArray.Items[LIndex] is TJSONObject) then
          Exit(False);
        LItem := TJSONObject(LArray.Items[LIndex]);
        LChunks[LIndex] := TRadIAKnowledgeChunk.Create(
          LItem.GetValue<string>('id', ''),
          LItem.GetValue<string>('fileName', ''),
          LItem.GetValue<string>('revision', ''),
          LItem.GetValue<string>('symbol', ''),
          LItem.GetValue<Integer>('startLine', 0),
          LItem.GetValue<Integer>('endLine', 0),
          LItem.GetValue<string>('content', '')
        );
        if (LChunks[LIndex].Id = '') or
          (LChunks[LIndex].FileName = '') or
          (LChunks[LIndex].Revision = '') or
          (LChunks[LIndex].StartLine < 1) or
          (LChunks[LIndex].EndLine < LChunks[LIndex].StartLine) then
          Exit(False);
      end;
      ASnapshot := TRadIAKnowledgeIndexSnapshot.Create(
        AProjectId,
        LChunks
      );
      Result := True;
    finally
      LJson.Free;
    end;
  except
    Result := False;
  end;
end;

procedure TRadIAJsonKnowledgeStore.Save(
  const ASnapshot: TRadIAKnowledgeIndexSnapshot
);
var
  LArray: TJSONArray;
  LChunk: TRadIAKnowledgeChunk;
  LFileName: string;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LTempFileName: string;
begin
  if Trim(ASnapshot.ProjectId) = '' then
    raise EArgumentException.Create('Snapshot project id must not be empty.');
  if Length(ASnapshot.Chunks) > CMaxPersistedChunks then
    raise EArgumentOutOfRangeException.Create(
      'Snapshot exceeds the persisted chunk limit.'
    );

  TDirectory.CreateDirectory(FRootPath);
  LFileName := GetProjectFileName(ASnapshot.ProjectId);
  LTempFileName := LFileName + '.' +
    StringReplace(TGUID.NewGuid.ToString, '-', '', [rfReplaceAll]) +
    '.tmp';
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('version', TJSONNumber.Create(CFormatVersion));
    LJson.AddPair('projectId', ASnapshot.ProjectId);
    LArray := TJSONArray.Create;
    LJson.AddPair('chunks', LArray);
    for LChunk in ASnapshot.Chunks do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('id', LChunk.Id);
      LItem.AddPair('fileName', LChunk.FileName);
      LItem.AddPair('revision', LChunk.Revision);
      LItem.AddPair('symbol', LChunk.Symbol);
      LItem.AddPair(
        'startLine',
        TJSONNumber.Create(LChunk.StartLine)
      );
      LItem.AddPair(
        'endLine',
        TJSONNumber.Create(LChunk.EndLine)
      );
      LItem.AddPair('content', LChunk.Content);
      LArray.AddElement(LItem);
    end;
    TFile.WriteAllText(
      LTempFileName,
      LJson.ToJSON,
      TEncoding.UTF8
    );
    if not MoveFileEx(
      PChar(LTempFileName),
      PChar(LFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    ) then
      RaiseLastOSError;
  finally
    LJson.Free;
    if TFile.Exists(LTempFileName) then
      TFile.Delete(LTempFileName);
  end;
end;

end.
