unit RadIA.Core.Cache;

interface

uses  System.Generics.Collections, System.SyncObjs;

type
  TRadIACacheEntrySnapshot = record
  private
    FHash: string;
    FLastAccessed: TDateTime;
    FResponseCharacters: Integer;
    FTimestamp: TDateTime;
  public
    constructor Create(
      const AHash: string;
      const AResponseCharacters: Integer;
      const ATimestamp: TDateTime;
      const ALastAccessed: TDateTime
    );
    property Hash: string read FHash;
    property LastAccessed: TDateTime read FLastAccessed;
    property ResponseCharacters: Integer read FResponseCharacters;
    property Timestamp: TDateTime read FTimestamp;
  end;

  TRadIACacheEntry = class
  private
    FHash: string;
    FResponse: string;
    FTimestamp: TDateTime;
    FLastAccessed: TDateTime;
  public
    property Hash: string read FHash write FHash;
    property Response: string read FResponse write FResponse;
    property Timestamp: TDateTime read FTimestamp write FTimestamp;
    property LastAccessed: TDateTime read FLastAccessed write FLastAccessed;
  end;

  TRadIACacheManager = class
  private
    FFilePath: string;
    FEntries: TObjectList<TRadIACacheEntry>;
    FDictionary: TDictionary<string, TRadIACacheEntry>;
    FLimit: Integer;
    FCriticalSection: TCriticalSection;
    FIsDirty: Boolean;

    procedure LoadCache;
    procedure SaveCache;
    procedure EvictOldEntries;
  public
    constructor Create(const AFilePath: string = ''; ALimit: Integer = 500);
    destructor Destroy; override;

    function Get(const AHash: string; out AResponse: string): Boolean;
    function ListEntries: TArray<TRadIACacheEntrySnapshot>;
    procedure Put(const AHash: string; const AResponse: string);
    function Remove(const AHash: string): Boolean;
    procedure Clear;

    class function GenerateHash(const AProvider: string; const AModel: string;
      const ASystemPrompt: string; const APrompt: string;
      const AHistory: string): string;
  end;

implementation

uses
  System.IOUtils, System.JSON, System.Hash, System.DateUtils, RadIA.Core.Logger, System.SysUtils;

{ TRadIACacheManager }

constructor TRadIACacheEntrySnapshot.Create(
  const AHash: string;
  const AResponseCharacters: Integer;
  const ATimestamp: TDateTime;
  const ALastAccessed: TDateTime
);
begin
  FHash := AHash;
  FResponseCharacters := AResponseCharacters;
  FTimestamp := ATimestamp;
  FLastAccessed := ALastAccessed;
end;

constructor TRadIACacheManager.Create(const AFilePath: string; ALimit: Integer);
begin
  inherited Create;
  FLimit := ALimit;
  FCriticalSection := TCriticalSection.Create;
  FIsDirty := False;
  FEntries := TObjectList<TRadIACacheEntry>.Create(True);
  FDictionary := TDictionary<string, TRadIACacheEntry>.Create;

  if AFilePath.IsEmpty then
    FFilePath := TPath.Combine(TPath.GetHomePath, 'RadIA\cache.json')
  else
    FFilePath := AFilePath;

  LoadCache;
end;

function TRadIACacheManager.ListEntries: TArray<TRadIACacheEntrySnapshot>;
var
  LEntry: TRadIACacheEntry;
  LEntries: TList<TRadIACacheEntrySnapshot>;
begin
  LEntries := TList<TRadIACacheEntrySnapshot>.Create;
  try
    FCriticalSection.Enter;
    try
      for LEntry in FEntries do
        LEntries.Add(TRadIACacheEntrySnapshot.Create(
          LEntry.Hash,
          Length(LEntry.Response),
          LEntry.Timestamp,
          LEntry.LastAccessed
        ));
    finally
      FCriticalSection.Leave;
    end;
    Result := LEntries.ToArray;
  finally
    LEntries.Free;
  end;
end;

destructor TRadIACacheManager.Destroy;
begin
  if FIsDirty then
  begin
    try
      SaveCache;
    except
      on E: Exception do
        TLogger.Log('~TRadIACacheManager: Failed to save cache on destroy: ' + E.Message, 'Cache');
    end;
  end;
  FEntries.Free;
  FDictionary.Free;
  FCriticalSection.Free;
  inherited Destroy;
end;

procedure TRadIACacheManager.Clear;
begin
  FCriticalSection.Enter;
  try
    FDictionary.Clear;
    FEntries.Clear;
    if TFile.Exists(FFilePath) then
    begin
      try
        TFile.Delete(FFilePath);
      except
        on E: Exception do
          TLogger.Log('TRadIACacheManager.Clear: Failed to delete cache file: ' + E.Message, 'Cache');
      end;
    end;
    FIsDirty := False;
  finally
    FCriticalSection.Leave;
  end;
end;

class function TRadIACacheManager.GenerateHash(const AProvider: string; const AModel: string;
  const ASystemPrompt: string; const APrompt: string;
  const AHistory: string): string;
var
  LConcat: string;
begin
  LConcat := AProvider + '||' + AModel + '||' + ASystemPrompt + '||' + APrompt + '||' + AHistory;
  Result := THashSHA2.GetHashString(LConcat);
end;

function TRadIACacheManager.Get(const AHash: string; out AResponse: string): Boolean;
var
  LEntry: TRadIACacheEntry;
begin
  Result := False;
  AResponse := '';
  FCriticalSection.Enter;
  try
    if FDictionary.TryGetValue(AHash, LEntry) then
    begin
      { Check expiration (24 hours) }
      if HoursBetween(Now, LEntry.Timestamp) >= 24 then
      begin
        { Expired entry â€” remove it and flag for persistence }
        FDictionary.Remove(AHash);
        FEntries.Remove(LEntry);
        FIsDirty := True;
        Exit;
      end;

      { Update LRU metadata without triggering a full cache save }
      LEntry.LastAccessed := Now;
      AResponse := LEntry.Response;
      Result := True;
      { NOTE: Not marking FIsDirty here â€” LastAccessed is best-effort metadata.
        It will be persisted on the next Put or on destruction. }
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TRadIACacheManager.LoadCache;
var
  LContent: string;
  LJsonArr: TJSONArray;
  LVal: TJSONValue;
  LEntryObj: TJSONObject;
  LEntry: TRadIACacheEntry;
  LHash, LResponse: string;
begin
  FEntries.Clear;
  FDictionary.Clear;

  { Ensure directory exists }
  ForceDirectories(TPath.GetDirectoryName(FFilePath));

  if not TFile.Exists(FFilePath) then
    Exit;

  try
    LContent := TFile.ReadAllText(FFilePath, TEncoding.UTF8);
    if LContent.IsEmpty then
      Exit;

    LJsonArr := TJSONObject.ParseJSONValue(LContent) as TJSONArray;
    if Assigned(LJsonArr) then
    begin
      try
        for LVal in LJsonArr do
        begin
          if LVal is TJSONObject then
          begin
            LEntryObj := LVal as TJSONObject;
            LHash := LEntryObj.GetValue<string>('hash', '');
            LResponse := LEntryObj.GetValue<string>('response', '');

            if LHash.IsEmpty then
              Continue;

            LEntry := TRadIACacheEntry.Create;
            LEntry.Hash := LHash;
            LEntry.Response := LResponse;

            try
              LEntry.Timestamp := ISO8601ToDate(LEntryObj.GetValue<string>('timestamp', ''));
            except
              LEntry.Timestamp := Now;
            end;

            try
              LEntry.LastAccessed := ISO8601ToDate(LEntryObj.GetValue<string>('last_accessed', ''));
            except
              LEntry.LastAccessed := Now;
            end;

            FEntries.Add(LEntry);
            FDictionary.Add(LEntry.Hash, LEntry);
          end;
        end;
      finally
        LJsonArr.Free;
      end;
    end;
  except
    FEntries.Clear;
    FDictionary.Clear;
  end;
end;

procedure TRadIACacheManager.EvictOldEntries;
var
  LEvictCount, K, I, LMinIndex: Integer;
  LMinDate: TDateTime;
begin
  if FEntries.Count < FLimit then
    Exit;

  LEvictCount := FLimit div 10;
  if LEvictCount < 1 then
    LEvictCount := 1;

  for K := 1 to LEvictCount do
  begin
    if FEntries.Count = 0 then
      Break;

    LMinIndex := 0;
    LMinDate := FEntries[0].LastAccessed;

    for I := 1 to FEntries.Count - 1 do
    begin
      if FEntries[I].LastAccessed < LMinDate then
      begin
        LMinDate := FEntries[I].LastAccessed;
        LMinIndex := I;
      end;
    end;

    FDictionary.Remove(FEntries[LMinIndex].Hash);
    FEntries.Delete(LMinIndex);
  end;
end;

procedure TRadIACacheManager.Put(const AHash: string; const AResponse: string);
var
  LEntry: TRadIACacheEntry;
begin
  FCriticalSection.Enter;
  try
    { If already exists, update response and refresh timestamp }
    if FDictionary.TryGetValue(AHash, LEntry) then
    begin
      LEntry.Response := AResponse;
      LEntry.Timestamp := Now;
      LEntry.LastAccessed := Now;
      FIsDirty := True;
      SaveCache;
      Exit;
    end;

    EvictOldEntries;

    { Add new entry }
    LEntry := TRadIACacheEntry.Create;
    LEntry.Hash := AHash;
    LEntry.Response := AResponse;
    LEntry.Timestamp := Now;
    LEntry.LastAccessed := Now;
    FEntries.Add(LEntry);
    FDictionary.Add(AHash, LEntry);
    FIsDirty := True;
    SaveCache;
  finally
    FCriticalSection.Leave;
  end;
end;

function TRadIACacheManager.Remove(const AHash: string): Boolean;
var
  LEntry: TRadIACacheEntry;
begin
  FCriticalSection.Enter;
  try
    Result := FDictionary.TryGetValue(AHash, LEntry);
    if not Result then
      Exit;
    FDictionary.Remove(AHash);
    FEntries.Remove(LEntry);
    FIsDirty := True;
    SaveCache;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TRadIACacheManager.SaveCache;
var
  LJsonArr: TJSONArray;
  LEntryObj: TJSONObject;
  LEntry: TRadIACacheEntry;
begin
  LJsonArr := TJSONArray.Create;
  try
    for LEntry in FEntries do
    begin
      LEntryObj := TJSONObject.Create;
      LEntryObj.AddPair('hash', LEntry.Hash);
      LEntryObj.AddPair('response', LEntry.Response);
      LEntryObj.AddPair('timestamp', DateToISO8601(LEntry.Timestamp));
      LEntryObj.AddPair('last_accessed', DateToISO8601(LEntry.LastAccessed));
      LJsonArr.AddElement(LEntryObj);
    end;

    TFile.WriteAllText(FFilePath, LJsonArr.ToJSON, TEncoding.UTF8);
  finally
    LJsonArr.Free;
  end;
end;

end.
