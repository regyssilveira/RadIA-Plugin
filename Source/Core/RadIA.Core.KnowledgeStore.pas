unit RadIA.Core.KnowledgeStore;

interface

uses
  System.JSON,
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
    function ReadEmbedding(
      const AItem: TJSONObject;
      out AProviderId: string;
      out AEmbedding: TArray<Single>
    ): Boolean;
    function ReadChunks(
      const AArray: TJSONArray;
      const AVersion: Integer;
      out AChunks: TArray<TRadIAKnowledgeChunk>
    ): Boolean;
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
  System.Math,
  System.SysUtils,
  Winapi.Windows;

const
  CFormatVersion = 2;
  CMaximumEmbeddingDimensions = 4096;
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
  LJson: TJSONObject;
  LText: string;
  LVersion: Integer;
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
      LVersion := LJson.GetValue<Integer>('version', 0);
      if (LVersion < 1) or (LVersion > CFormatVersion) then
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
      if not ReadChunks(LArray, LVersion, LChunks) then
        Exit(False);
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

function TRadIAJsonKnowledgeStore.ReadEmbedding(
  const AItem: TJSONObject;
  out AProviderId: string;
  out AEmbedding: TArray<Single>
): Boolean;
var
  LArray: TJSONArray;
  LIndex: Integer;
begin
  Result := False;
  AProviderId := '';
  SetLength(AEmbedding, 0);
  AProviderId := AItem.GetValue<string>('embeddingProviderId', '');
  if AProviderId = '' then
    Exit(True);
  if Length(AProviderId) > 128 then
    Exit;
  LArray := AItem.GetValue('embedding') as TJSONArray;
  if not Assigned(LArray) or (LArray.Count = 0) or
    (LArray.Count > CMaximumEmbeddingDimensions) then
    Exit;
  SetLength(AEmbedding, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    AEmbedding[LIndex] := LArray[LIndex].AsType<Double>;
    if IsNan(AEmbedding[LIndex]) or IsInfinite(AEmbedding[LIndex]) then
      Exit;
  end;
  Result := True;
end;

function TRadIAJsonKnowledgeStore.ReadChunks(
  const AArray: TJSONArray;
  const AVersion: Integer;
  out AChunks: TArray<TRadIAKnowledgeChunk>
): Boolean;
var
  LEmbedding: TArray<Single>;
  LIndex: Integer;
  LItem: TJSONObject;
  LProviderId: string;
begin
  Result := False;
  SetLength(AChunks, AArray.Count);
  for LIndex := 0 to AArray.Count - 1 do
  begin
    if not (AArray[LIndex] is TJSONObject) then
      Exit;
    LItem := TJSONObject(AArray[LIndex]);
    AChunks[LIndex] := TRadIAKnowledgeChunk.Create(
      LItem.GetValue<string>('id', ''),
      LItem.GetValue<string>('fileName', ''),
      LItem.GetValue<string>('revision', ''),
      LItem.GetValue<string>('symbol', ''),
      LItem.GetValue<Integer>('startLine', 0),
      LItem.GetValue<Integer>('endLine', 0),
      LItem.GetValue<string>('content', '')
    );
    if (AChunks[LIndex].Id = '') or
      (AChunks[LIndex].FileName = '') or
      (AChunks[LIndex].Revision = '') or
      (AChunks[LIndex].StartLine < 1) or
      (AChunks[LIndex].EndLine < AChunks[LIndex].StartLine) then
      Exit;
    if AVersion < 2 then
      Continue;
    if not ReadEmbedding(LItem, LProviderId, LEmbedding) then
      Exit;
    if Length(LEmbedding) > 0 then
      AChunks[LIndex] := AChunks[LIndex].WithEmbedding(
        LProviderId,
        LEmbedding
      );
  end;
  Result := True;
end;

procedure TRadIAJsonKnowledgeStore.Save(
  const ASnapshot: TRadIAKnowledgeIndexSnapshot
);
var
  LArray: TJSONArray;
  LChunk: TRadIAKnowledgeChunk;
  LFileName: string;
  LItem: TJSONObject;
  LEmbeddingArray: TJSONArray;
  LEmbeddingValue: Single;
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
      if Length(LChunk.Embedding) > 0 then
      begin
        LItem.AddPair(
          'embeddingProviderId',
          LChunk.EmbeddingProviderId
        );
        LEmbeddingArray := TJSONArray.Create;
        for LEmbeddingValue in LChunk.Embedding do
          LEmbeddingArray.Add(LEmbeddingValue);
        LItem.AddPair('embedding', LEmbeddingArray);
      end;
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
